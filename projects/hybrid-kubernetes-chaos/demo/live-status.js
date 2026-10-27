(() => {
  const root = document.getElementById('chaos-demo');
  if (!root || root.dataset.liveStatusInitialized === 'true') return;
  root.dataset.liveStatusInitialized = 'true';

  const endpoint = root.dataset.statusEndpoint || '/api/status';
  const liveHost = window.location.hostname === 'chaos.holdenjolley.com';
  const pollIntervalMs = 5000;
  const failureThreshold = 3;

  const byId = id => root.querySelector('#' + id);
  const modeBanner = byId('telemetry-banner');
  const modeTitle = byId('telemetry-title');
  const modeDetail = byId('telemetry-detail');
  const maintenance = byId('maintenance');
  const onlineUi = byId('online-ui');
  const activity = byId('activity');
  const podGrid = byId('pod-grid');

  let failures = 0;
  let lastSnapshot = null;
  let lastMode = null;

  const safeText = value => value === null || value === undefined || value === '' ? '—' : String(value);
  const now = () => new Date().toLocaleTimeString([], {hour:'2-digit', minute:'2-digit', second:'2-digit'});

  const addLog = (message, type = 'info') => {
    if (!activity) return;
    const row = document.createElement('div');
    row.className = 'activity-row ' + type;
    const time = document.createElement('time');
    time.textContent = now();
    const dot = document.createElement('i');
    dot.className = 'activity-dot';
    const text = document.createElement('span');
    text.textContent = message;
    row.append(time, dot, text);
    activity.prepend(row);
    while (activity.children.length > 14) activity.lastElementChild.remove();
  };

  const setBanner = (mode, title, detail) => {
    if (!modeBanner) return;
    modeBanner.dataset.mode = mode;
    if (modeTitle) modeTitle.textContent = title;
    if (modeDetail) modeDetail.textContent = detail;
  };

  const setChip = (id, text, state) => {
    const chip = byId(id);
    if (!chip) return;
    chip.classList.remove('good', 'info', 'warn');
    chip.classList.add(state);
    const textNode = [...chip.childNodes].find(node => node.nodeType === Node.TEXT_NODE);
    if (textNode) textNode.nodeValue = text;
    else chip.append(document.createTextNode(text));
  };

  const setStatusTile = (id, text, healthy) => {
    const element = byId(id);
    if (!element) return;
    element.textContent = text;
    const light = element.previousElementSibling;
    if (light && light.classList.contains('status-light')) {
      light.style.background = healthy === false ? 'var(--red)' : healthy === null ? 'var(--yellow)' : 'var(--green)';
    }
  };

  const updatePodCard = (card, pod) => {
    card.classList.remove('failed', 'recovering', 'isolated');
    const name = card.querySelector('.pod-name');
    const state = card.querySelector('.state');
    const values = card.querySelectorAll('.metric strong');
    const ready = Boolean(pod.ready);

    name.textContent = safeText(pod.name);
    state.textContent = ready ? 'Ready' : safeText(pod.phase || 'Not ready');
    if (!ready) card.classList.add(pod.phase === 'Running' ? 'recovering' : 'failed');

    if (values[0]) values[0].textContent = `${safeText(pod.cpu)} / ${safeText(pod.cpuLimit)}`;
    if (values[1]) values[1].textContent = `${safeText(pod.memory)} / ${safeText(pod.memoryLimit)}`;
    if (values[2]) values[2].textContent = safeText(pod.restarts);
    if (values[3]) values[3].textContent = safeText(pod.podIP);
  };

  const updatePods = pods => {
    if (!podGrid) return;
    const cards = [...podGrid.querySelectorAll('.pod')];
    cards.forEach((card, index) => {
      const pod = pods[index];
      if (!pod) {
        card.hidden = true;
        return;
      }
      card.hidden = false;
      updatePodCard(card, pod);
    });
  };

  const isPreviewExperimentRunning = () => byId('run-status')?.textContent === 'Running';

  const snapshot = data => JSON.stringify({
    nodeReady: data.cluster?.nodeReady,
    fluxReady: data.flux?.ready,
    desired: data.workload?.desiredReplicas,
    ready: data.workload?.readyReplicas,
    service: data.workload?.service?.reachable,
    pods: (data.workload?.pods || []).map(p => [p.name, p.phase, p.ready, p.restarts])
  });

  const applyStatus = data => {
    if (!data || !data.cluster || !data.workload) throw new Error('Invalid status payload');

    const workload = data.workload;
    const service = workload.service || {};
    const flux = data.flux || {};
    const desired = Number(workload.desiredReplicas || 0);
    const ready = Number(workload.readyReplicas || 0);
    const healthyReplicas = desired > 0 && ready === desired;
    const serviceHealthy = service.reachable === true;
    const clusterHealthy = data.cluster.nodeReady === true;
    const fluxHealthy = flux.ready === true;
    const degraded = Boolean(data.degraded) || !clusterHealthy || !healthyReplicas || !serviceHealthy || !fluxHealthy;

    const desiredField = byId('desired-count');
    const readyField = byId('ready-count');
    const readyDetail = byId('ready-detail');
    const availability = byId('availability');
    const requestCount = byId('request-count');
    const serviceHealth = byId('service-health');
    const serviceDetail = byId('service-detail');

    if (desiredField) desiredField.textContent = desired;
    if (readyField) readyField.textContent = `${ready} / ${desired}`;
    if (readyDetail) readyDetail.textContent = healthyReplicas ? 'All healthy' : `${Math.max(0, desired - ready)} replica(s) unavailable`;
    if (availability) availability.textContent = serviceHealthy ? `HTTP ${safeText(service.statusCode)}` : 'Unreachable';
    if (requestCount) requestCount.textContent = service.latencyMs == null ? 'Live Service probe' : `${service.latencyMs} ms latest probe`;
    if (serviceHealth) serviceHealth.textContent = serviceHealthy ? 'Healthy' : 'Unavailable';
    if (serviceDetail) serviceDetail.textContent = serviceHealthy ? `HTTP ${safeText(service.statusCode)} · ${safeText(service.latencyMs)} ms` : 'Probe failed';

    setStatusTile('node-status-value', safeText(data.cluster.name), clusterHealthy);
    setStatusTile('kubernetes-status-value', safeText(data.cluster.kubernetesVersion), data.cluster.kubernetesVersion ? true : null);
    setStatusTile('flux-status-value', fluxHealthy ? 'Flux reconciled' : safeText(flux.status), flux.ready === null ? null : fluxHealthy);
    setStatusTile('service-status-value', serviceHealthy ? `${safeText(service.latencyMs)} ms` : 'Unavailable', serviceHealthy);

    setChip('lab-chip', clusterHealthy && serviceHealthy ? 'Lab online' : 'Lab degraded', clusterHealthy && serviceHealthy ? 'good' : 'warn');
    setChip('arc-chip', data.cluster.arc?.configured ? 'Azure Arc configured' : 'Arc unknown', data.cluster.arc?.configured ? 'info' : 'warn');
    setChip('flux-chip', fluxHealthy ? 'Flux reconciled' : 'Flux status unknown', fluxHealthy ? 'info' : 'warn');

    if (!isPreviewExperimentRunning()) {
      updatePods(workload.pods || []);
      const runReady = byId('run-ready');
      const runService = byId('run-service');
      if (runReady) runReady.textContent = `${ready} / ${desired}`;
      if (runService) runService.textContent = serviceHealthy ? `HTTP ${safeText(service.statusCode)}` : 'Unavailable';
    }

    const currentSnapshot = snapshot(data);
    if (lastMode !== 'live') {
      addLog(`Live telemetry connected: ${ready}/${desired} Ready, Service ${serviceHealthy ? 'reachable' : 'unreachable'}.`, serviceHealthy && healthyReplicas ? 'good' : 'warn');
    } else if (lastSnapshot && lastSnapshot !== currentSnapshot) {
      addLog(`Live state changed: ${ready}/${desired} Ready, Flux ${flux.status || 'unknown'}, Service ${serviceHealthy ? 'reachable' : 'unreachable'}.`, degraded ? 'warn' : 'good');
    }

    lastSnapshot = currentSnapshot;
    lastMode = 'live';
    failures = 0;
    root.dataset.telemetryMode = 'live';
    setBanner('live', 'Live read-only telemetry', `Updated ${new Date(data.generatedAt || Date.now()).toLocaleTimeString()} · chaos buttons remain simulated`);

    if (liveHost && maintenance?.classList.contains('visible') && maintenance.dataset.autoOffline === 'true') {
      maintenance.classList.remove('visible');
      maintenance.dataset.autoOffline = 'false';
      if (onlineUi) onlineUi.hidden = false;
    }
  };

  const handleFailure = () => {
    failures += 1;

    if (!liveHost) {
      root.dataset.telemetryMode = 'simulation';
      setBanner('simulation', 'Portfolio preview mode', 'Live telemetry is only available on chaos.holdenjolley.com; chaos interactions are simulated here.');
      if (lastMode !== 'simulation') addLog('Read-only API not present on this host; dashboard is using preview data.', 'info');
      lastMode = 'simulation';
      return;
    }

    setBanner('degraded', 'Live telemetry unavailable', `Status API check failed ${failures}/${failureThreshold}; retrying automatically.`);
    if (failures === 1) addLog('Live status API became unreachable; retrying before declaring the lab offline.', 'warn');

    if (failures >= failureThreshold && maintenance && onlineUi) {
      maintenance.classList.add('visible');
      maintenance.dataset.autoOffline = 'true';
      onlineUi.hidden = true;
      addLog('Live status API remained unavailable; maintenance state activated.', 'bad');
    }
  };

  const poll = async () => {
    try {
      const response = await fetch(endpoint, {
        method: 'GET',
        headers: {'Accept': 'application/json'},
        cache: 'no-store',
        credentials: 'same-origin'
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      applyStatus(await response.json());
    } catch (error) {
      handleFailure();
    }
  };

  poll();
  window.setInterval(poll, pollIntervalMs);
})();
