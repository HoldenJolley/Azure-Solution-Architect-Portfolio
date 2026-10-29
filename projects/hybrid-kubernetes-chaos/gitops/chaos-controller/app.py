import json
import os
import random
import ssl
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

NAMESPACE = os.getenv("LAB_NAMESPACE", "hybrid-lab")
DEPLOYMENT = os.getenv("LAB_DEPLOYMENT", "hybrid-demo")
LABEL_SELECTOR = os.getenv("LAB_LABEL_SELECTOR", "app.kubernetes.io/name=hybrid-demo")
LEASE_NAME = os.getenv("CHAOS_LEASE_NAME", "hybrid-chaos-lock")
COOLDOWN_SECONDS = int(os.getenv("CHAOS_COOLDOWN_SECONDS", "90"))
MAX_RECOVERY_SECONDS = int(os.getenv("CHAOS_MAX_RECOVERY_SECONDS", "45"))
PORT = int(os.getenv("PORT", "8080"))
TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
KUBE_HOST = os.getenv("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
KUBE_PORT = os.getenv("KUBERNETES_SERVICE_PORT_HTTPS", "443")
KUBE_BASE = f"https://{KUBE_HOST}:{KUBE_PORT}"
SSL_CONTEXT = ssl.create_default_context(cafile=CA_PATH)
REQUEST_LOCK = threading.Lock()

ANNOTATION_PREFIX = "chaos.holdenjolley.com/"
STATE_KEY = ANNOTATION_PREFIX + "state"
EXPERIMENT_KEY = ANNOTATION_PREFIX + "experiment"
TARGET_KEY = ANNOTATION_PREFIX + "target"
STARTED_KEY = ANNOTATION_PREFIX + "started-at"
COMPLETED_KEY = ANNOTATION_PREFIX + "completed-at"
RECOVERY_KEY = ANNOTATION_PREFIX + "recovery-seconds"
MESSAGE_KEY = ANNOTATION_PREFIX + "message"


def utc_now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_time(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def read_token():
    with open(TOKEN_PATH, "r", encoding="utf-8") as handle:
        return handle.read().strip()


def kube_request(path, method="GET", payload=None, timeout=3.0):
    body = None
    headers = {
        "Authorization": f"Bearer {read_token()}",
        "Accept": "application/json",
    }
    if payload is not None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = Request(
        f"{KUBE_BASE}{path}",
        data=body,
        headers=headers,
        method=method,
    )
    with urlopen(request, context=SSL_CONTEXT, timeout=timeout) as response:
        if response.status == 204:
            return None
        data = response.read()
        return json.loads(data) if data else None


def condition_true(conditions, condition_type):
    for condition in conditions or []:
        if condition.get("type") == condition_type:
            return condition.get("status") == "True"
    return False


def deployment_status():
    return kube_request(
        f"/apis/apps/v1/namespaces/{quote(NAMESPACE)}/deployments/{quote(DEPLOYMENT)}"
    )


def workload_pods():
    selector = urlencode({"labelSelector": LABEL_SELECTOR})
    data = kube_request(f"/api/v1/namespaces/{quote(NAMESPACE)}/pods?{selector}")
    return data.get("items", []) if data else []


def healthy_candidates(pods):
    candidates = []
    for pod in pods:
        metadata = pod.get("metadata") or {}
        status = pod.get("status") or {}
        deletion_timestamp = metadata.get("deletionTimestamp")
        if (
            not deletion_timestamp
            and status.get("phase") == "Running"
            and condition_true(status.get("conditions"), "Ready")
        ):
            name = metadata.get("name")
            if name and name.startswith(f"{DEPLOYMENT}-"):
                candidates.append(name)
    return sorted(candidates)


def baseline():
    deployment = deployment_status()
    pods = workload_pods()
    spec = deployment.get("spec") or {}
    status = deployment.get("status") or {}
    desired = int(spec.get("replicas") or 0)
    ready = int(status.get("readyReplicas") or 0)
    available = int(status.get("availableReplicas") or 0)
    candidates = healthy_candidates(pods)

    healthy = (
        desired >= 3
        and ready == desired
        and available == desired
        and len(candidates) == desired
    )
    return {
        "healthy": healthy,
        "desired": desired,
        "ready": ready,
        "available": available,
        "candidates": candidates,
    }


def lease_path():
    return (
        f"/apis/coordination.k8s.io/v1/namespaces/{quote(NAMESPACE)}/"
        f"leases/{quote(LEASE_NAME)}"
    )


def get_lease():
    return kube_request(lease_path())


def lease_annotations(lease):
    return ((lease or {}).get("metadata") or {}).get("annotations") or {}


def update_lease(lease, updates):
    metadata = lease.get("metadata") or {}
    annotations = dict(metadata.get("annotations") or {})
    annotations.update({key: str(value) for key, value in updates.items() if value is not None})
    for key, value in updates.items():
        if value is None:
            annotations.pop(key, None)

    payload = {
        "apiVersion": "coordination.k8s.io/v1",
        "kind": "Lease",
        "metadata": {
            "name": LEASE_NAME,
            "namespace": NAMESPACE,
            "resourceVersion": metadata.get("resourceVersion"),
            "annotations": annotations,
        },
        "spec": (lease.get("spec") or {}),
    }
    return kube_request(lease_path(), method="PUT", payload=payload)


def seconds_since(value):
    parsed = parse_time(value)
    if not parsed:
        return None
    return max(0.0, (datetime.now(timezone.utc) - parsed).total_seconds())


def public_lease_state(lease):
    annotations = lease_annotations(lease)
    state = annotations.get(STATE_KEY, "idle")
    completed = annotations.get(COMPLETED_KEY)
    elapsed = seconds_since(completed)
    cooldown_remaining = 0
    if elapsed is not None:
        cooldown_remaining = max(0, int(COOLDOWN_SECONDS - elapsed + 0.999))

    recovery = annotations.get(RECOVERY_KEY)
    try:
        recovery = float(recovery) if recovery else None
    except ValueError:
        recovery = None

    return {
        "state": state,
        "experiment": annotations.get(EXPERIMENT_KEY),
        "target": annotations.get(TARGET_KEY),
        "startedAt": annotations.get(STARTED_KEY),
        "completedAt": completed,
        "recoverySeconds": recovery,
        "message": annotations.get(MESSAGE_KEY),
        "cooldownSeconds": COOLDOWN_SECONDS,
        "cooldownRemainingSeconds": cooldown_remaining,
        "available": state != "running" and cooldown_remaining == 0,
    }


def mark_finished(outcome, recovery_seconds=None, message=None):
    for _ in range(3):
        try:
            lease = get_lease()
            update_lease(
                lease,
                {
                    STATE_KEY: outcome,
                    COMPLETED_KEY: utc_now(),
                    RECOVERY_KEY: f"{recovery_seconds:.2f}" if recovery_seconds is not None else None,
                    MESSAGE_KEY: message,
                },
            )
            return
        except HTTPError as exc:
            if exc.code == 409:
                time.sleep(0.2)
                continue
            raise


def monitor_recovery(started_monotonic):
    deadline = started_monotonic + MAX_RECOVERY_SECONDS
    try:
        while time.monotonic() < deadline:
            current = baseline()
            if current["healthy"]:
                recovery = time.monotonic() - started_monotonic
                mark_finished(
                    "passed",
                    recovery_seconds=recovery,
                    message="Deployment returned to its healthy desired replica state.",
                )
                return
            time.sleep(0.5)
        mark_finished(
            "failed",
            message=f"Recovery exceeded {MAX_RECOVERY_SECONDS} seconds.",
        )
    except Exception as exc:
        try:
            mark_finished(
                "failed",
                message=f"Recovery monitor failed: {type(exc).__name__}.",
            )
        except Exception:
            pass


def start_pod_deletion():
    with REQUEST_LOCK:
        lease = get_lease()
        state = public_lease_state(lease)
        if state["state"] == "running":
            return 409, {"error": "experiment already running", "experiment": state}
        if state["cooldownRemainingSeconds"] > 0:
            return 429, {"error": "cooldown active", "experiment": state}

        current = baseline()
        if not current["healthy"]:
            return 409, {
                "error": "baseline is not healthy",
                "baseline": {
                    "desiredReplicas": current["desired"],
                    "readyReplicas": current["ready"],
                    "availableReplicas": current["available"],
                    "healthyCandidates": len(current["candidates"]),
                },
            }

        target = random.SystemRandom().choice(current["candidates"])
        started_at = utc_now()
        started_monotonic = time.monotonic()

        try:
            lease = update_lease(
                lease,
                {
                    STATE_KEY: "running",
                    EXPERIMENT_KEY: "delete-pod",
                    TARGET_KEY: target,
                    STARTED_KEY: started_at,
                    COMPLETED_KEY: None,
                    RECOVERY_KEY: None,
                    MESSAGE_KEY: "Deleting one healthy workload replica and observing self-healing.",
                },
            )
        except HTTPError as exc:
            if exc.code == 409:
                return 409, {"error": "experiment lock changed; retry later"}
            raise

        try:
            kube_request(
                f"/api/v1/namespaces/{quote(NAMESPACE)}/pods/{quote(target)}",
                method="DELETE",
            )
        except Exception as exc:
            mark_finished(
                "failed",
                message=f"Pod deletion failed: {type(exc).__name__}.",
            )
            raise

        thread = threading.Thread(
            target=monitor_recovery,
            args=(started_monotonic,),
            daemon=True,
        )
        thread.start()

        return 202, {
            "accepted": True,
            "experiment": "delete-pod",
            "target": target,
            "startedAt": started_at,
            "guardrails": {
                "namespace": NAMESPACE,
                "deployment": DEPLOYMENT,
                "minimumHealthyReplicas": 3,
                "cooldownSeconds": COOLDOWN_SECONDS,
                "maxRecoverySeconds": MAX_RECOVERY_SECONDS,
                "oneExperimentAtATime": True,
            },
        }


class Handler(BaseHTTPRequestHandler):
    server_version = "hybrid-chaos-controller/0.1"

    def send_json(self, status, payload):
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/healthz":
            self.send_json(200, {"status": "ok", "mode": "bounded-mutation"})
            return
        if self.path == "/api/chaos/status":
            try:
                self.send_json(200, {"experiment": public_lease_state(get_lease())})
            except Exception as exc:
                self.send_json(503, {"error": "status unavailable", "detail": type(exc).__name__})
            return
        self.send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/api/chaos/delete-pod":
            self.send_json(404, {"error": "not found"})
            return
        try:
            status, payload = start_pod_deletion()
            self.send_json(status, payload)
        except HTTPError as exc:
            self.send_json(502, {"error": "Kubernetes API rejected operation", "status": exc.code})
        except URLError:
            self.send_json(503, {"error": "Kubernetes API unavailable"})
        except Exception as exc:
            self.send_json(500, {"error": "experiment failed", "detail": type(exc).__name__})

    def do_PUT(self):
        self.send_json(405, {"error": "method not allowed"})

    def do_PATCH(self):
        self.send_json(405, {"error": "method not allowed"})

    def do_DELETE(self):
        self.send_json(405, {"error": "method not allowed"})

    def log_message(self, fmt, *args):
        print(
            f"{self.address_string()} - [{self.log_date_time_string()}] {fmt % args}",
            flush=True,
        )


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
