import json
import os
import ssl
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

NAMESPACE = os.getenv("LAB_NAMESPACE", "hybrid-lab")
DEPLOYMENT = os.getenv("LAB_DEPLOYMENT", "hybrid-demo")
NODE_NAME = os.getenv("LAB_NODE_NAME", "k8s-edge-01")
FLUX_NAMESPACE = os.getenv("FLUX_NAMESPACE", "hybrid-gitops")
FLUX_NAME = os.getenv("FLUX_NAME", "hybrid-lab-gitops-hybrid-lab")
SERVICE_URL = os.getenv(
    "LAB_SERVICE_URL",
    "http://hybrid-demo.hybrid-lab.svc.cluster.local",
)
PORT = int(os.getenv("PORT", "8080"))
TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
KUBE_HOST = os.getenv("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
KUBE_PORT = os.getenv("KUBERNETES_SERVICE_PORT_HTTPS", "443")
KUBE_BASE = f"https://{KUBE_HOST}:{KUBE_PORT}"
SSL_CONTEXT = ssl.create_default_context(cafile=CA_PATH)


def utc_now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def read_token():
    with open(TOKEN_PATH, "r", encoding="utf-8") as handle:
        return handle.read().strip()


def kube_json(path, timeout=2.5):
    request = Request(
        f"{KUBE_BASE}{path}",
        headers={
            "Authorization": f"Bearer {read_token()}",
            "Accept": "application/json",
        },
    )
    with urlopen(request, context=SSL_CONTEXT, timeout=timeout) as response:
        return json.load(response)


def safe_kube(path, errors, label):
    try:
        return kube_json(path)
    except HTTPError as exc:
        errors.append(f"{label}: Kubernetes API returned HTTP {exc.code}")
    except URLError as exc:
        errors.append(f"{label}: Kubernetes API unavailable ({exc.reason})")
    except Exception as exc:
        errors.append(f"{label}: {type(exc).__name__}")
    return None


def condition_true(conditions, condition_type):
    for condition in conditions or []:
        if condition.get("type") == condition_type:
            return condition.get("status") == "True"
    return False


def get_metrics():
    selector = urlencode({"labelSelector": "app.kubernetes.io/name=hybrid-demo"})
    path = (
        f"/apis/metrics.k8s.io/v1beta1/namespaces/{quote(NAMESPACE)}/pods?"
        f"{selector}"
    )
    try:
        data = kube_json(path)
    except Exception:
        # Metrics Server is optional in this low-cost lab. Missing metrics must
        # not make otherwise healthy cluster status appear degraded.
        return {}

    metrics = {}
    for item in data.get("items", []):
        containers = item.get("containers") or []
        if not containers:
            continue
        usage = containers[0].get("usage") or {}
        metrics[item.get("metadata", {}).get("name", "")] = {
            "cpu": usage.get("cpu"),
            "memory": usage.get("memory"),
        }
    return metrics


def service_probe():
    started = time.perf_counter()
    try:
        request = Request(
            SERVICE_URL,
            headers={"User-Agent": "hybrid-status-api/1.0"},
        )
        with urlopen(request, timeout=1.5) as response:
            response.read(256)
            elapsed = round((time.perf_counter() - started) * 1000, 1)
            return {
                "reachable": 200 <= response.status < 400,
                "statusCode": response.status,
                "latencyMs": elapsed,
            }
    except Exception as exc:
        elapsed = round((time.perf_counter() - started) * 1000, 1)
        return {
            "reachable": False,
            "statusCode": None,
            "latencyMs": elapsed,
            "error": type(exc).__name__,
        }


def flux_status(errors):
    for version in ("v1", "v1beta2"):
        path = (
            f"/apis/kustomize.toolkit.fluxcd.io/{version}/namespaces/"
            f"{quote(FLUX_NAMESPACE)}/kustomizations/{quote(FLUX_NAME)}"
        )
        local_errors = []
        data = safe_kube(path, local_errors, "Flux")
        if data:
            status = data.get("status") or {}
            ready = condition_true(status.get("conditions"), "Ready")
            condition = next(
                (
                    item
                    for item in status.get("conditions") or []
                    if item.get("type") == "Ready"
                ),
                {},
            )
            return {
                "name": FLUX_NAME,
                "namespace": FLUX_NAMESPACE,
                "ready": ready,
                "status": "reconciled" if ready else "not-ready",
                "revision": status.get("lastAppliedRevision")
                or status.get("lastAttemptedRevision"),
                "message": condition.get("message"),
            }
        if version == "v1":
            continue
        errors.extend(local_errors)

    return {
        "name": FLUX_NAME,
        "namespace": FLUX_NAMESPACE,
        "ready": None,
        "status": "unknown",
        "revision": None,
        "message": None,
    }


def build_status():
    errors = []

    deployment = safe_kube(
        f"/apis/apps/v1/namespaces/{quote(NAMESPACE)}/deployments/{quote(DEPLOYMENT)}",
        errors,
        "Deployment",
    )
    selector = urlencode({"labelSelector": "app.kubernetes.io/name=hybrid-demo"})
    pods_data = safe_kube(
        f"/api/v1/namespaces/{quote(NAMESPACE)}/pods?{selector}",
        errors,
        "Pods",
    )
    node = safe_kube(
        f"/api/v1/nodes/{quote(NODE_NAME)}",
        errors,
        "Node",
    )
    version = safe_kube("/version", errors, "Kubernetes version")
    metrics = get_metrics()

    pod_items = []
    for pod in (pods_data or {}).get("items", []):
        metadata = pod.get("metadata") or {}
        spec = pod.get("spec") or {}
        status = pod.get("status") or {}
        container_statuses = status.get("containerStatuses") or []
        container_specs = spec.get("containers") or []
        limits = (
            (container_specs[0].get("resources") or {}).get("limits")
            if container_specs
            else {}
        )
        limits = limits or {}
        name = metadata.get("name", "")
        pod_items.append(
            {
                "name": name,
                "phase": status.get("phase", "Unknown"),
                "ready": condition_true(status.get("conditions"), "Ready"),
                "restarts": sum(
                    int(container.get("restartCount") or 0)
                    for container in container_statuses
                ),
                "node": spec.get("nodeName"),
                "cpu": (metrics.get(name) or {}).get("cpu"),
                "memory": (metrics.get(name) or {}).get("memory"),
                "cpuLimit": limits.get("cpu"),
                "memoryLimit": limits.get("memory"),
            }
        )

    pod_items.sort(key=lambda item: item["name"])

    deployment_spec = (deployment or {}).get("spec") or {}
    deployment_status = (deployment or {}).get("status") or {}
    desired = int(deployment_spec.get("replicas") or 0)
    ready = int(deployment_status.get("readyReplicas") or 0)
    available = int(deployment_status.get("availableReplicas") or 0)

    node_status = (node or {}).get("status") or {}
    node_info = node_status.get("nodeInfo") or {}
    service = service_probe()
    flux = flux_status(errors)

    return {
        "generatedAt": utc_now(),
        "api": {
            "mode": "read-only",
            "mutationsEnabled": False,
            "version": "1.0",
        },
        "cluster": {
            "name": NODE_NAME,
            "nodeReady": condition_true(node_status.get("conditions"), "Ready")
            if node
            else None,
            "kubernetesVersion": (version or {}).get("gitVersion"),
            "osImage": node_info.get("osImage"),
            "containerRuntime": node_info.get("containerRuntimeVersion"),
            "arc": {
                "configured": True,
                "status": "configured",
                "note": "Azure Arc registration is a configured architecture fact; this endpoint does not call Azure APIs.",
            },
        },
        "flux": flux,
        "workload": {
            "namespace": NAMESPACE,
            "deployment": DEPLOYMENT,
            "desiredReplicas": desired,
            "readyReplicas": ready,
            "availableReplicas": available,
            "pods": pod_items,
            "service": service,
        },
        "experiment": {
            "status": "idle",
            "mutationsEnabled": False,
        },
        "degraded": bool(errors),
        "errors": errors,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "hybrid-status-api/1.0"

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
            self.send_json(200, {"status": "ok", "mode": "read-only"})
            return
        if self.path == "/api/status":
            try:
                self.send_json(200, build_status())
            except Exception as exc:
                self.send_json(
                    503,
                    {
                        "generatedAt": utc_now(),
                        "error": "status collection failed",
                        "detail": type(exc).__name__,
                    },
                )
            return
        self.send_json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        print(
            f"{self.address_string()} - [{self.log_date_time_string()}] {fmt % args}",
            flush=True,
        )


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
