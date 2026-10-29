(() => {
  const root = document.getElementById('chaos-demo');
  if (!root || root.dataset.liveStatusInitialized === 'true') return;
  root.dataset.liveStatusInitialized = 'true';

  const endpoint = root.dataset.statusEndpoint || '/api/status';
  const chaosStatusEndpoint = root.dataset.chaosStatusEndpoint || '/api/chaos/status';
  const chaosDeleteEndpoint = root.dataset.chaosDeleteEndpoint || '/api/chaos/delete-pod';
  const liveHost = window.location.hostname === 'chaos.holdenjolley.com';
  const pollIntervalMs = 5000;
  const failureThreshold = 3;

  const byId = id => root.querySelector('#' + id);
  const modeBanner = byId('telemetry-banner') || root.querySelector('.sim-banner');
  const modeTitle = byId('telemetry-title') || modeBanner?.querySelector('strong');
  const modeDetail = byId('telemetry-detail') || modeBanner?.querySelector('span');
  const maintenance = byId('maintenance');
  const onlineUi = byId('online-ui');
  const activity = byId('activity');
  const podGrid = byId('pod-grid');
  const footerNote = root.querySelector('.footer-note');
  const brandSubtitle = root.querySelector('.brand-copy span');
  const healthLabels = root.querySelectorAll('.health-item > span');
  const heroChips = [...root.querySelectorAll('.hero-meta .chip')];
  const statusTiles = [...root.querySelectorAll('.status-tile strong')];
  const deleteButton = root.querySelector('[data-experiment="pod"]');

  let failures = 0;
  let lastSnapshot = null;
  let lastMode = null;
  let controllerReachable = false;
  let lastChaosState = null;

  const safeText = value => value === null || value === undefined || value === '' ? '—' : String(value);
  const now = () => new Date().toLocaleTimeString([], {hour:'2-digit', minute:'2-digit', second:'2-digit'});

  const formatCpu = value => {
    if (!value) return '—';
    const text = String(value);
    const match = text.match(/^([0-9.]+)(n|u|m)?$/);
    if (!match) return text;
    const number = Number(match[1]);
    const unit = match[2] || '';
    const millicores = unit === 'n' ? number / 1e6 : unit === 'u' ? number / 1e3 : unit === 'm' ? number : number * 1000;
    return `${millicores < 10 ? millicores.toFixed(2) : millicores.toFixed(1)}m`;
  };

  const formatMemory = value => {
    if (!value) return '—';
    const text = String(value);
    const match = text.match(/^([0-9.]+)(Ki|Mi|Gi)?$/i);
    if (!match) return text;
    const number = Number(match[1]);
    const unit = (match[2] || 'Ki').toLowerCase();
    const mebibytes = unit === 'gi' ? number * 1024 : unit === 'mi' ? number : number / 1024;
    return `${mebibytes < 10 ? mebibytes.toFixed(1) : mebibytes.toFixed(0)} Mi`;
  };

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

  const setButtonLabel = (button, label) => {
    if (!button) return;
    const arrow = button.querySelector('span:last-child');
    const textNode = [...button.childNodes].find(node => node.nodeType === Node.TEXT_NODE);
    if (textNode) textNode.nodeValue = label + ' ';
    else button.prepend(document.createTextNode(label + ' '));
    if (arrow) arrow.textContent = '→';
  };

  const chipFallbackIndex = {
    'lab-chip': 0,
    'arc-chip': 1,
    'flux-chip': 2
  };

  const setChip = (id, text, state) => {
    const chip = byId(id) || heroChips[chipFallbackIndex[id]];
    if (!chip) return;
    chip.classList.remove('good', 'info', 'warn');
    chip.classList.add(state);
    const textNode = [...chip.childNodes].find(node => node.nodeType === Node.TEXT_NODE);
    if (textNode) textNode.nodeValue = text;
    else chip.append(document.createTextNode(text));
  };

  const tileFallbackIndex = {
    'node-status-value': 0,
    'kubernetes-status-value': 1,
    'flux-status-value': 3,
    'service-status-value': 4
  };

  const setStatusTile = (id, text, healthy) => {
    const element = byId(id) || statusTiles[tileFallbackIndex[id]];
    if (!element) return;
    const light = element.querySelector('.status-light');
    const textNode = [...element.childNodes].find(node => node.nodeType === Node.TEXT_NODE && node.nodeValue.trim());
    if (textNode) textNode.nodeValue = text;
    else element.append(document.createTextNode(text));
    if (light) {
      light.style.background = healthy === false ? 'var(--red)' : healthy === null ? 'var(--yellow)' : 'var(--green)';
    }
  };

  const sanitizeStaticPodCards = () => {
    [...root.querySelectorAll('.pod')].forEach(card => {
      const metrics = card.querySelectorAll('.metric');
      if (metrics[3]) {
        const label = metrics[3].querySelector('span');
        const value = metrics[3].querySelector('strong');
        if (label) label.textContent = 'Node';
        if (value) value.textContent = 'k8s-edge-01';
      }
    });
  };

  const updatePodCard = (card, pod) => {
    card.classList.remove('failed', 'recovering', 'isolated');
    const name = card.querySelector('.pod-name');
    const state = card.querySelector('.state');
    const metrics = card.querySelectorAll('.metric');
    const values = card.querySelectorAll('.metric strong');
    const ready = Boolean(pod.ready);

    if (name) name.textContent = safeText(pod.name);
    if (state) state.textContent = ready ? 'Ready' : safeText(pod.phase || 'Not ready');
    if (!ready) card.classList.add(pod.phase === 'Running' ? 'recovering' : 'failed');

    if (values[0]) values[0].textContent = `${formatCpu(pod.cpu)} / ${safeText(pod.cpuLimit)}`;
    if (values[1]) values[1].textContent = `${formatMemory(pod.memory)} / ${safeText(pod.memoryLimit)}`;
    if (values[2]) values[2].textContent = safeText(pod.restarts);
    if (metrics[3]) {
      const label = metrics[3].querySelector('span');
      if (label) label.textContent = 'Node';
    }
    if (values[3]) values[3].textContent = safeText(pod.node);
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

  const isPreviewExperimentRunning = () =>
    byId('run-status')?.textContent === 'Running' && root.dataset.realChaosRunning !== 'true';

  const snapshot = data => JSON.stringify({
    nodeReady: data.cluster?.nodeReady,
    fluxReady: data.flux?.ready,
    desired: data.workload?.desiredReplicas,
    ready: data.workload?.readyReplicas,
    service: data.workload?.service?.reachable,
    pods: (data.workload?.pods || []).map(p => [p.name, p.phase, p.ready, p.restarts])
  });

  const setDeleteButtonFromController = experiment => {
    if (!deleteButton || !liveHost) return;

    if (!controllerReachable || !experiment) {
      deleteButton.disabled = true;
      setButtonLabel(deleteButton, 'Live action unavailable');
      return;
    }

    const cooldown = Number(experiment.cooldownRemainingSeconds || 0);
    if (experiment.state === 'running') {
      deleteButton.disabled = true;
      setButtonLabel(deleteButton, 'Experiment running');
    } else if (cooldown > 0) {
      deleteButton.disabled = true;
      setButtonLabel(deleteButton, `Cooldown ${cooldown}s`);
    } else if (experiment.available === true) {
      deleteButton.disabled = false;
      setButtonLabel(deleteButton, 'Delete one real pod');
    } else {
      deleteButton.disabled = true;
      setButtonLabel(deleteButton, 'Live action unavailable');
    }
  };

  const applyChaosStatus = payload => {
    const experiment = payload?.experiment;
    if (!experiment) throw new Error('Invalid chaos status payload');

    controllerReachable = true;
    setDeleteButtonFromController(experiment);

    const experimentHealth = byId('experiment-health');
    const experimentDetail = byId('experiment-detail');
    const runClock = byId('run-clock');
    const runName = byId('run-name');
    const runDescription = byId('run-description');
    const runStatus = byId('run-status');
    const runTarget = byId('run-target');
    const runRecovery = byId('run-recovery');

    const cooldown = Number(experiment.cooldownRemainingSeconds || 0);
    const state = experiment.state || 'idle';

    if (state === 'running') {
      root.dataset.realChaosRunning = 'true';
      if (experimentHealth) experimentHealth.textContent = 'Running';
      if (experimentDetail) experimentDetail.textContent = 'Real single-pod deletion';
      if (runClock) runClock.textContent = 'Live experiment in progress';
      if (runName) runName.textContent = 'Single-pod failure';
      if (runDescription) runDescription.textContent = 'One healthy hybrid-demo replica was deleted by the bounded chaos controller.';
      if (runStatus) runStatus.textContent = 'Running';
      if (runTarget) runTarget.textContent = safeText(experiment.target);
      if (runRecovery) runRecovery.textContent = 'Measuring…';
    } else {
      root.dataset.realChaosRunning = 'false';

      if (state === 'passed' || state === 'failed') {
        if (runClock) runClock.textContent = cooldown > 0 ? `Cooldown · ${cooldown}s remaining` : 'Experiment complete';
        if (runName) runName.textContent = 'Single-pod failure';
        if (runDescription) runDescription.textContent = safeText(experiment.message);
        if (runStatus) runStatus.textContent = state === 'passed' ? 'Pass' : 'Failed';
        if (runTarget) runTarget.textContent = safeText(experiment.target);
        if (runRecovery) runRecovery.textContent =
          experiment.recoverySeconds == null ? '—' : `${Number(experiment.recoverySeconds).toFixed(2)}s`;
      }

      if (cooldown > 0) {
        if (experimentHealth) experimentHealth.textContent = 'Cooldown';
        if (experimentDetail) experimentDetail.textContent = `${cooldown}s until next live run`;
      } else {
        if (experimentHealth) experimentHealth.textContent = 'Idle';
        if (experimentDetail) experimentDetail.textContent = 'Live pod deletion available';
      }
    }

    if (lastChaosState !== state) {
      if (state === 'running') addLog(`Real chaos started against ${safeText(experiment.target)}.`, 'warn');
      if (state === 'passed') addLog(`Real chaos passed; recovery measured at ${safeText(experiment.recoverySeconds)}s.`, 'good');
      if (state === 'failed') addLog(`Real chaos experiment failed: ${safeText(experiment.message)}.`, 'bad');
      lastChaosState = state;
    }
  };

  const pollChaosStatus = async () => {
    if (!liveHost) return;
    try {
      const response = await fetch(chaosStatusEndpoint, {
        method: 'GET',
        headers: {'Accept': 'application/json'},
        cache: 'no-store',
        credentials: 'same-origin'
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      applyChaosStatus(await response.json());
    } catch (error) {
      const wasReachable = controllerReachable;
      controllerReachable = false;
      setDeleteButtonFromController(null);
      if (wasReachable) addLog('Chaos controller became unavailable; live mutation control locked.', 'warn');
    }
  };

  const runRealPodDeletion = async event => {
    if (!liveHost) return;
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();

    if (!controllerReachable || deleteButton?.disabled) {
      addLog('Live pod deletion is unavailable or currently locked.', 'warn');
      return;
    }

    deleteButton.disabled = true;
    setButtonLabel(deleteButton, 'Requesting…');

    try {
      const response = await fetch(chaosDeleteEndpoint, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        cache: 'no-store',
        credentials: 'same-origin',
        body: '{}'
      });

      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        const detail = payload.error || `HTTP ${response.status}`;
        addLog(`Live chaos request rejected: ${detail}.`, response.status === 429 ? 'warn' : 'bad');
        await pollChaosStatus();
        return;
      }

      root.dataset.realChaosRunning = 'true';
      addLog(`Live pod deletion accepted for ${safeText(payload.target)}.`, 'warn');

      const runName = byId('run-name');
      const runDescription = byId('run-description');
      const runStatus = byId('run-status');
      const runTarget = byId('run-target');
      const runRecovery = byId('run-recovery');
      const experimentHealth = byId('experiment-health');
      const experimentDetail = byId('experiment-detail');

      if (runName) runName.textContent = 'Single-pod failure';
      if (runDescription) runDescription.textContent = 'Controller accepted a bounded deletion and is measuring Kubernetes recovery.';
      if (runStatus) runStatus.textContent = 'Running';
      if (runTarget) runTarget.textContent = safeText(payload.target);
      if (runRecovery) runRecovery.textContent = 'Measuring…';
      if (experimentHealth) experimentHealth.textContent = 'Running';
      if (experimentDetail) experimentDetail.textContent = 'Real single-pod deletion';

      await pollChaosStatus();
    } catch (error) {
      controllerReachable = false;
      root.dataset.realChaosRunning = 'false';
      setDeleteButtonFromController(null);
      addLog('Live chaos request failed before the controller could confirm acceptance.', 'bad');
    }
  };

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
    const previewRunning = isPreviewExperimentRunning();

    setStatusTile('node-status-value', safeText(data.cluster.name), clusterHealthy);
    setStatusTile('kubernetes-status-value', safeText(data.cluster.kubernetesVersion), data.cluster.kubernetesVersion ? true : null);
    setStatusTile('flux-status-value', fluxHealthy ? 'Flux reconciled' : safeText(flux.status), flux.ready === null ? null : fluxHealthy);
    setStatusTile('service-status-value', serviceHealthy ? `${safeText(service.latencyMs)} ms` : 'Unavailable', serviceHealthy);

    setChip('lab-chip', clusterHealthy && serviceHealthy ? 'Lab online' : 'Lab degraded', clusterHealthy && serviceHealthy ? 'good' : 'warn');
    setChip('arc-chip', data.cluster.arc?.configured ? 'Azure Arc configured' : 'Arc unknown', data.cluster.arc?.configured ? 'info' : 'warn');
    setChip('flux-chip', fluxHealthy ? 'Flux reconciled' : 'Flux status unknown', fluxHealthy ? 'info' : 'warn');

    if (!previewRunning) {
      const desiredField = byId('desired-count');
      const readyField = byId('ready-count');
      const readyDetail = byId('ready-detail');
      const availability = byId('availability');
      const requestCount = byId('request-count');
      const serviceHealth = byId('service-health');
      const serviceDetail = byId('service-detail');
      const runReady = byId('run-ready');
      const runService = byId('run-service');

      if (desiredField) desiredField.textContent = desired;
      if (readyField) readyField.textContent = `${ready} / ${desired}`;
      if (readyDetail) readyDetail.textContent = healthyReplicas ? 'All healthy' : `${Math.max(0, desired - ready)} replica(s) unavailable`;
      if (availability) availability.textContent = serviceHealthy ? `HTTP ${safeText(service.statusCode)}` : 'Unreachable';
      if (requestCount) requestCount.textContent = service.latencyMs == null ? 'Live Service probe' : `${service.latencyMs} ms latest probe`;
      if (serviceHealth) serviceHealth.textContent = serviceHealthy ? 'Healthy' : 'Unavailable';
      if (serviceDetail) serviceDetail.textContent = serviceHealthy ? `HTTP ${safeText(service.statusCode)} · ${safeText(service.latencyMs)} ms` : 'Probe failed';
      if (runReady) runReady.textContent = `${ready} / ${desired}`;
      if (runService) runService.textContent = serviceHealthy ? `HTTP ${safeText(service.statusCode)}` : 'Unavailable';
      updatePods(workload.pods || []);
    }

    if (healthLabels[2]) healthLabels[2].textContent = 'Service probe';
    if (brandSubtitle) brandSubtitle.textContent = liveHost ? 'chaos.holdenjolley.com · live hybrid telemetry' : 'chaos.holdenjolley.com · portfolio preview';
    if (footerNote) {
      footerNote.textContent = liveHost
        ? 'Live boundary: cluster, Flux, pod, replica, resource-usage, and Service-probe values come from the read-only status API. Internal pod IP addresses are omitted. Single-pod deletion uses a separately permissioned controller with a healthy-baseline check, one-at-a-time lock, measured recovery, and cooldown. CPU and network experiments remain browser simulations.'
        : 'Portfolio-preview boundary: this host does not expose the live lab APIs, so telemetry and chaos interactions are simulated here. Internal pod IP addresses are intentionally not shown.';
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
    setBanner(
      'live',
      'Live hybrid telemetry',
      controllerReachable
        ? `Updated ${new Date(data.generatedAt || Date.now()).toLocaleTimeString()} · pod deletion is live; CPU/network remain simulated`
        : `Updated ${new Date(data.generatedAt || Date.now()).toLocaleTimeString()} · live mutation route is locked`
    );

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
      if (brandSubtitle) brandSubtitle.textContent = 'chaos.holdenjolley.com · portfolio preview';
      if (footerNote) {
        footerNote.textContent = 'Portfolio-preview boundary: this host does not expose the lab APIs, so the dashboard uses simulated values and interactions here. Internal pod IP addresses are intentionally not shown.';
      }
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

  sanitizeStaticPodCards();

  if (deleteButton) {
    deleteButton.addEventListener('click', runRealPodDeletion, true);
    if (liveHost) {
      deleteButton.disabled = true;
      setButtonLabel(deleteButton, 'Checking live controller…');
    }
  }

  poll();
  pollChaosStatus();
  window.setInterval(poll, pollIntervalMs);
  window.setInterval(pollChaosStatus, 1000);
})();
