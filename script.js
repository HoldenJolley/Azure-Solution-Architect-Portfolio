const portfolioScriptUrl = document.currentScript?.src;

function ensureStylesheet(href, marker) {
  if (!portfolioScriptUrl || document.querySelector(`link[${marker}]`)) return;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = new URL(href, portfolioScriptUrl).href;
  link.setAttribute(marker, 'true');
  document.head.appendChild(link);
}

ensureStylesheet('easter-eggs.css', 'data-portfolio-enhancements');

const navItems = [...document.querySelectorAll('.nav-item[href^="#"]')];
const navTargets = navItems
  .map(item => {
    const id = decodeURIComponent(item.getAttribute('href').slice(1));
    return {item, id, target: document.getElementById(id)};
  })
  .filter(entry => entry.target);

function setActiveNav(id) {
  navItems.forEach(item => item.classList.toggle('active', item.getAttribute('href') === `#${id}`));
}

function updateActiveNav() {
  if (!navTargets.length) return;
  const activationLine = 96;
  const atPageBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4;
  let active = navTargets[0];
  for (const entry of navTargets) {
    if (entry.target.getBoundingClientRect().top <= activationLine) active = entry;
    else break;
  }
  if (atPageBottom) active = navTargets[navTargets.length - 1];
  setActiveNav(active.id);
}

if (navTargets.length) {
  let scrollFrame = null;
  const scheduleNavUpdate = () => {
    if (scrollFrame !== null) return;
    scrollFrame = window.requestAnimationFrame(() => {
      updateActiveNav();
      scrollFrame = null;
    });
  };
  navTargets.forEach(({item, id}) => item.addEventListener('click', () => setActiveNav(id)));
  window.addEventListener('scroll', scheduleNavUpdate, {passive: true});
  window.addEventListener('resize', scheduleNavUpdate);
  window.addEventListener('load', updateActiveNav);
  updateActiveNav();
}

console.info('%cHoldenJolley.CloudArchitecture/portfolio', 'font-weight:700;color:#0078d4');
console.info('Tip: Ctrl+` opens Cloud Shell. The hybrid Kubernetes lab is Arc connected and Flux reconciled.');

const shellCommands = {
  help: `Available commands:\n  az portfolio show\n  az architecture list\n  az deployment sub what-if\n  az aks list\n  az connectedk8s show\n  az k8s-configuration flux show\n  kubectl get nodes\n  kubectl get pods -n hybrid-lab\n  az account show\n  az group list\n  clear\n  exit`,
  'az portfolio show': `Name:           Holden Jolley\nRole:           Azure Solution Architect\nLocation:       North Carolina\nRelocation:     Bay Area\nArchitectures:  4\nIaC / GitOps:   Bicep + Flux\nValidation:     ARM What-If + runtime chaos evidence\nAuthentication: GitHub OIDC`,
  'az architecture list': `NAME                      PRIORITY             VALIDATION\nportfolio-hosting         Cost Optimization    Live on Azure\necommerce                 Reliability          ARM What-If\nage-assurance             Security / Privacy   Foundation ARM What-If\nhybrid-kubernetes         Hybrid Resilience    Arc + Flux + runtime chaos`,
  'az deployment sub what-if': `Resource changes: 0 destructive changes.\n\nArchitectural changes:\n+ Requirements documented\n+ Tradeoffs documented\n+ Infrastructure automated\n+ Azure control plane validated\n+ Hybrid runtime evidence captured where tested`,
  'az aks list': `[]\n\nNo managed AKS clusters found.\nThe Kubernetes lab is a physical kubeadm cluster connected through Azure Arc.\nTry: az connectedk8s show`,
  'az connectedk8s show': `Name:           k8s-edge-01\nResource group: rg-k8s-hybrid-lab\nLocation:       eastus2\nDistribution:   kubeadm / Ubuntu Server\nConnectivity:   Azure Arc-enabled Kubernetes\nGitOps:         Flux enabled\nStatus:         Connected`,
  'az k8s-configuration flux show': `Name:           hybrid-lab-gitops\nCluster:        k8s-edge-01\nSource:         GitHub main branch\nPath:           ./projects/hybrid-kubernetes-chaos/gitops\nReconciliation: Active\nObserved proof: replica change 2 -> 3 reconciled without kubectl apply`,
  'kubectl get nodes': `NAME          STATUS   ROLES           VERSION\nk8s-edge-01   Ready    control-plane   v1.37.1`,
  'kubectl get pods -n hybrid-lab': `NAME                            READY   STATUS    RESTARTS\nhybrid-demo-<replica-a>          1/1     Running   0\nhybrid-demo-<replica-b>          1/1     Running   0\nhybrid-demo-<replica-c>          1/1     Running   0\n\nDesired state: 3 replicas via Flux GitOps\nChaos evidence: pod deletion, CPU saturation, NetworkPolicy isolation`,
  'az account show': `Name:           Portfolio Validation Subscription\nAuthentication: Workload identity federation (OIDC)\nClient secret:  Not configured\nScope:          Architecture validation + hybrid management`,
  'az group list': `NAME                 PURPOSE\nrg-k8s-hybrid-lab    Azure Arc-connected physical Kubernetes lab\n\nOther reference architectures remain deployment-gated or short-lived validation environments.`
};

function appendShellOutput(text, prompt = false) {
  const output = document.querySelector('.cloud-shell-output');
  if (!output) return;
  const block = document.createElement('pre');
  block.className = prompt ? 'cloud-shell-command' : '';
  block.textContent = text;
  output.appendChild(block);
  output.scrollTop = output.scrollHeight;
}

function runShellCommand(command) {
  const normalized = command.toLowerCase().replace(/\s+/g, ' ').trim();
  appendShellOutput(`PS /home/holden> ${command}`, true);
  if (normalized === 'clear') {
    document.querySelector('.cloud-shell-output')?.replaceChildren();
    return;
  }
  if (normalized === 'exit') {
    toggleCloudShell(false);
    return;
  }
  appendShellOutput(shellCommands[normalized] || `az: '${command}' is not a portfolio command.\nTry: help`);
}

function toggleCloudShell(forceState) {
  const shell = document.querySelector('.cloud-shell');
  if (!shell) return;
  const shouldOpen = typeof forceState === 'boolean' ? forceState : !shell.classList.contains('open');
  shell.classList.toggle('open', shouldOpen);
  shell.setAttribute('aria-hidden', shouldOpen ? 'false' : 'true');
  document.body.classList.toggle('cloud-shell-open', shouldOpen);
  if (shouldOpen) window.setTimeout(() => shell.querySelector('.cloud-shell-input')?.focus(), 30);
}

function createCloudShell() {
  if (document.querySelector('.cloud-shell')) return;
  const triggerHost = document.querySelector('.top-actions');
  if (triggerHost) {
    const trigger = document.createElement('button');
    trigger.type = 'button';
    trigger.className = 'cloud-shell-trigger';
    trigger.setAttribute('aria-label', 'Open portfolio Cloud Shell');
    trigger.setAttribute('title', 'Cloud Shell');
    trigger.textContent = '>_';
    trigger.addEventListener('click', () => toggleCloudShell());
    triggerHost.prepend(trigger);
  }
  const shell = document.createElement('section');
  shell.className = 'cloud-shell';
  shell.setAttribute('role', 'dialog');
  shell.setAttribute('aria-modal', 'true');
  shell.setAttribute('aria-label', 'Portfolio Cloud Shell');
  shell.setAttribute('aria-hidden', 'true');
  shell.innerHTML = `
    <div class="cloud-shell-header">
      <div><span class="cloud-shell-icon">>_</span><strong>Cloud Shell</strong><span class="cloud-shell-context">Portfolio subscription</span></div>
      <button type="button" class="cloud-shell-close" aria-label="Close Cloud Shell">×</button>
    </div>
    <div class="cloud-shell-output" aria-live="polite"></div>
    <form class="cloud-shell-form">
      <label class="sr-only" for="portfolio-shell-input">Cloud Shell command</label>
      <span class="cloud-shell-prompt">PS /home/holden&gt;</span>
      <input id="portfolio-shell-input" class="cloud-shell-input" autocomplete="off" spellcheck="false" aria-label="Cloud Shell command">
    </form>`;
  document.body.appendChild(shell);
  shell.querySelector('.cloud-shell-close').addEventListener('click', () => toggleCloudShell(false));
  shell.querySelector('.cloud-shell-form').addEventListener('submit', event => {
    event.preventDefault();
    const input = shell.querySelector('.cloud-shell-input');
    const command = input.value.trim();
    if (!command) return;
    input.value = '';
    runShellCommand(command);
  });
  appendShellOutput('Azure Cloud Shell — portfolio sandbox');
  appendShellOutput('Type "help" for commands. Nothing here executes against Azure or Kubernetes.');
}

function activityDetails(label) {
  const normalized = label.toLowerCase();
  if (normalized.includes('azure connected')) {
    return {
      operation: 'Azure/login with OIDC',
      status: 'Succeeded',
      scope: 'Portfolio validation workflows',
      authentication: 'Federated workload identity',
      credential: 'No reusable client secret',
      deployment: 'Portfolio + hybrid management active'
    };
  }
  if (normalized.includes('runtime chaos') || normalized.includes('runtime tested')) {
    return {
      operation: 'Hybrid Kubernetes resilience validation',
      status: 'Succeeded',
      scope: 'k8s-edge-01 / hybrid-lab',
      evidence: 'Pod deletion, CPU saturation, NetworkPolicy isolation',
      availability: '100% observed in matched experiment windows',
      limitation: 'Single physical node; node HA not claimed'
    };
  }
  if (normalized.includes('arm') || normalized.includes('preflight') || normalized.includes('cloud validated')) {
    return {
      operation: 'Microsoft.Resources/deployments/whatIf',
      status: 'Succeeded',
      scope: normalized.includes('foundation') ? 'Age assurance dev foundation' : 'Subscription-scope architecture preflight',
      authentication: 'GitHub Actions OIDC',
      credential: 'Short-lived federated token',
      deployment: 'Reference workload runtime not implied'
    };
  }
  return null;
}

function closeActivityBlade() {
  const overlay = document.querySelector('.activity-overlay');
  if (!overlay) return;
  overlay.classList.remove('open');
  overlay.setAttribute('aria-hidden', 'true');
}

function createActivityBlade() {
  if (document.querySelector('.activity-overlay')) return;
  const overlay = document.createElement('div');
  overlay.className = 'activity-overlay';
  overlay.setAttribute('aria-hidden', 'true');
  overlay.innerHTML = `
    <aside class="activity-blade" role="dialog" aria-modal="true" aria-labelledby="activity-title">
      <div class="activity-header"><div><div class="activity-kicker">AZURE ACTIVITY LOG</div><h2 id="activity-title">Validation event</h2></div><button type="button" class="activity-close" aria-label="Close activity log">×</button></div>
      <div class="activity-body"></div>
      <div class="activity-footnote">Portfolio evidence view — no live Azure request is made from this page.</div>
    </aside>`;
  document.body.appendChild(overlay);
  overlay.querySelector('.activity-close').addEventListener('click', closeActivityBlade);
  overlay.addEventListener('click', event => {
    if (event.target === overlay) closeActivityBlade();
  });
}

function openActivityBlade(label) {
  const details = activityDetails(label);
  const overlay = document.querySelector('.activity-overlay');
  const body = overlay?.querySelector('.activity-body');
  if (!details || !overlay || !body) return;
  body.replaceChildren();
  Object.entries(details).forEach(([key, value]) => {
    const row = document.createElement('div');
    const name = document.createElement('span');
    const detail = document.createElement('strong');
    name.textContent = key.charAt(0).toUpperCase() + key.slice(1);
    detail.textContent = value;
    row.append(name, detail);
    body.appendChild(row);
  });
  overlay.classList.add('open');
  overlay.setAttribute('aria-hidden', 'false');
  overlay.querySelector('.activity-close')?.focus();
}

createCloudShell();
createActivityBlade();

document.querySelectorAll('.status-chip.success').forEach(chip => {
  if (!activityDetails(chip.textContent.trim())) return;
  chip.classList.add('activity-trigger');
  chip.setAttribute('role', 'button');
  chip.setAttribute('tabindex', '0');
  chip.setAttribute('title', 'View validation activity');
  const open = event => {
    event.preventDefault();
    event.stopPropagation();
    openActivityBlade(chip.textContent.trim());
  };
  chip.addEventListener('click', open);
  chip.addEventListener('keydown', event => {
    if (event.key === 'Enter' || event.key === ' ') open(event);
  });
});

const portfolioProfile = {
  name: 'Holden Jolley',
  type: 'Microsoft.Portfolio/solutionArchitects',
  properties: {
    focus: ['Azure', 'Hybrid Cloud', 'Kubernetes', 'Cloud Infrastructure', 'Identity', 'Security'],
    location: 'North Carolina',
    relocation: 'Bay Area',
    infrastructureAsCode: 'Bicep',
    gitOps: 'Flux',
    hybridManagement: 'Azure Arc-enabled Kubernetes',
    validation: 'ARM What-If + runtime chaos evidence',
    authentication: 'OIDC',
    sameAs: [
      'https://holdenjolley.com/',
      'https://github.com/HoldenJolley',
      'https://www.linkedin.com/in/holden-jolley/'
    ]
  }
};

let profileReturnFocus = null;

function closeProfileBlade() {
  const overlay = document.querySelector('.profile-overlay');
  const trigger = document.querySelector('.profile');
  if (!overlay) return;
  const wasOpen = overlay.classList.contains('open');
  overlay.classList.remove('open');
  overlay.setAttribute('aria-hidden', 'true');
  trigger?.setAttribute('aria-expanded', 'false');
  if (wasOpen && profileReturnFocus instanceof HTMLElement) profileReturnFocus.focus();
  profileReturnFocus = null;
}

function openProfileBlade() {
  const overlay = document.querySelector('.profile-overlay');
  const trigger = document.querySelector('.profile');
  if (!overlay || !trigger) return;
  toggleCloudShell(false);
  closeActivityBlade();
  profileReturnFocus = document.activeElement;
  overlay.classList.add('open');
  overlay.setAttribute('aria-hidden', 'false');
  trigger.setAttribute('aria-expanded', 'true');
  window.setTimeout(() => overlay.querySelector('.profile-close')?.focus(), 30);
}

function createProfileBlade() {
  const trigger = document.querySelector('.profile');
  if (!trigger || document.querySelector('.profile-overlay')) return;
  trigger.type = 'button';
  trigger.setAttribute('aria-label', 'Open Holden Jolley portfolio profile');
  trigger.setAttribute('aria-haspopup', 'dialog');
  trigger.setAttribute('aria-expanded', 'false');
  trigger.setAttribute('title', 'Portfolio profile');

  const overlay = document.createElement('div');
  overlay.className = 'profile-overlay';
  overlay.setAttribute('aria-hidden', 'true');
  overlay.innerHTML = `
    <aside class="profile-blade" role="dialog" aria-modal="true" aria-labelledby="profile-title">
      <div class="profile-header">
        <div class="profile-heading">
          <div class="profile-avatar" aria-hidden="true">HJ</div>
          <div><div class="profile-kicker">PORTFOLIO PROFILE</div><h2 id="profile-title">Holden Jolley</h2><div class="profile-subtitle">Azure Solution Architect · Cloud Infrastructure &amp; Security</div></div>
        </div>
        <button type="button" class="profile-close" aria-label="Close portfolio profile">×</button>
      </div>
      <div class="profile-body">
        <div class="profile-section profile-location"><span class="profile-label">Location</span><strong>North Carolina</strong><span>Open to Bay Area relocation for the right opportunity</span></div>
        <div class="profile-section">
          <span class="profile-label">Professional</span>
          <div class="profile-links">
            <a class="profile-link" href="https://www.linkedin.com/in/holden-jolley/" target="_blank" rel="me noreferrer"><span>LinkedIn</span><span aria-hidden="true">↗</span></a>
            <a class="profile-link" href="https://github.com/HoldenJolley" target="_blank" rel="me noreferrer"><span>GitHub</span><span aria-hidden="true">↗</span></a>
            <a class="profile-link" href="mailto:Jolleyholden@gmail.com"><span>Email</span><span aria-hidden="true">→</span></a>
            <a class="profile-link" href="${window.location.pathname.includes('/projects/') ? '../../resume.pdf' : 'resume.pdf'}"><span>Resume</span><span aria-hidden="true">↓</span></a>
          </div>
        </div>
        <div class="profile-section">
          <span class="profile-label">Portfolio</span>
          <div class="profile-facts">
            <div class="profile-fact"><span>Architectures</span><strong>4 Azure / hybrid projects</strong></div>
            <div class="profile-fact"><span>Infrastructure as Code</span><strong>Bicep + Kubernetes manifests</strong></div>
            <div class="profile-fact"><span>Validation</span><strong>ARM What-If + runtime evidence</strong></div>
            <div class="profile-fact"><span>Delivery</span><strong>GitHub Actions + OIDC + Flux</strong></div>
          </div>
        </div>
        <div class="profile-section"><button type="button" class="profile-json-toggle" aria-expanded="false" aria-controls="profile-json">View profile as JSON</button><pre id="profile-json" class="profile-json" hidden></pre></div>
      </div>
      <div class="profile-footnote">Portfolio identity view — this is not a Microsoft or Azure sign-in session.</div>
    </aside>`;
  document.body.appendChild(overlay);
  const jsonView = overlay.querySelector('.profile-json');
  jsonView.textContent = JSON.stringify(portfolioProfile, null, 2);
  trigger.addEventListener('click', openProfileBlade);
  overlay.querySelector('.profile-close').addEventListener('click', closeProfileBlade);
  overlay.addEventListener('click', event => {
    if (event.target === overlay) closeProfileBlade();
  });
  overlay.querySelector('.profile-json-toggle').addEventListener('click', event => {
    const button = event.currentTarget;
    const expanded = button.getAttribute('aria-expanded') === 'true';
    button.setAttribute('aria-expanded', expanded ? 'false' : 'true');
    button.textContent = expanded ? 'View profile as JSON' : 'Hide profile JSON';
    jsonView.hidden = expanded;
  });
}

createProfileBlade();

document.addEventListener('keydown', event => {
  if (event.ctrlKey && event.key === '`') {
    event.preventDefault();
    toggleCloudShell();
    return;
  }
  if (event.key === 'Escape') {
    toggleCloudShell(false);
    closeActivityBlade();
    closeProfileBlade();
  }
});

const portfolioThemeKey = 'portfolio-theme';
const portfolioThemeMedia = window.matchMedia('(prefers-color-scheme: dark)');

function readPortfolioThemePreference() {
  try {
    const saved = localStorage.getItem(portfolioThemeKey);
    return saved === 'light' || saved === 'dark' ? saved : null;
  } catch {
    return null;
  }
}

function writePortfolioThemePreference(theme) {
  try { localStorage.setItem(portfolioThemeKey, theme); } catch {}
}

function resolvePortfolioTheme() {
  return readPortfolioThemePreference() || (portfolioThemeMedia.matches ? 'dark' : 'light');
}

function syncThemeToggle(theme) {
  const toggle = document.querySelector('.theme-toggle');
  if (!toggle) return;
  const isDark = theme === 'dark';
  toggle.textContent = isDark ? '☀' : '☾';
  toggle.setAttribute('aria-pressed', String(isDark));
  toggle.setAttribute('aria-label', isDark ? 'Switch to light mode' : 'Switch to dark mode');
  toggle.setAttribute('title', isDark ? 'Switch to light mode' : 'Switch to dark mode');
}

function applyPortfolioTheme(theme, persist = false) {
  const resolved = theme === 'dark' ? 'dark' : 'light';
  document.documentElement.dataset.theme = resolved;
  if (persist) writePortfolioThemePreference(resolved);
  syncThemeToggle(resolved);
  const themeColor = document.querySelector('meta[name="theme-color"]');
  if (themeColor) themeColor.setAttribute('content', resolved === 'dark' ? '#0d141b' : '#0078d4');
}

function createThemeToggle() {
  ensureStylesheet('theme.css', 'data-portfolio-theme');
  applyPortfolioTheme(resolvePortfolioTheme());
  const triggerHost = document.querySelector('.top-actions');
  if (triggerHost && !triggerHost.querySelector('.theme-toggle')) {
    const toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'theme-toggle';
    const profileTrigger = triggerHost.querySelector('.profile');
    triggerHost.insertBefore(toggle, profileTrigger || null);
    toggle.addEventListener('click', () => {
      const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
      applyPortfolioTheme(next, true);
    });
  }
  syncThemeToggle(document.documentElement.dataset.theme || resolvePortfolioTheme());
}

portfolioThemeMedia.addEventListener?.('change', event => {
  if (readPortfolioThemePreference()) return;
  applyPortfolioTheme(event.matches ? 'dark' : 'light');
});
createThemeToggle();

const projectAudiencePreferenceKey = 'portfolio-project-audience';
const projectAudienceConfigs = {
  resume: {
    match: '/projects/resume/',
    executiveHero: 'A production portfolio platform designed to keep recurring Azure hosting at $0 within Free-tier limits, minimize operating overhead, and preserve a clean upgrade path when a real requirement justifies more spend.',
    panelLabel: 'Executive at a glance', panelBadge: 'Cost discipline',
    panel: [['Business value','Professional presence with near-zero Azure run cost'],['Risk posture','Minimal runtime and patching surface'],['Operating model','Automated delivery + simple recovery']],
    recommendation: 'Keep the platform intentionally small until availability, traffic, backend functionality, or business criticality creates a measurable reason to add cost and complexity.',
    cards: [
      ['Business objective','Deliver a credible, secure professional web presence without funding infrastructure that does not create additional business value.'],
      ['Financial impact','Azure hosting is designed to remain at $0/month while usage stays inside Static Web Apps Free quotas. Paid Azure edge, compute, database, and monitoring services are deliberately omitted.'],
      ['Operational impact','A static architecture removes server patching, runtime scaling, database recovery, and most day-two application operations. Git remains the source of truth for fast recovery.'],
      ['Risk & governance','GitHub OIDC avoids reusable Azure client secrets, production changes are gated by validation and ARM What-If, and Cloudflare edge routing is separated from the Azure hosting origin.'],
      ['Accepted tradeoff','The Free tier has no enterprise SLA. That is appropriate for a personal portfolio, but it becomes an explicit upgrade trigger if the site becomes business-critical.'],
      ['Confidence level','This project is deployed in production. Azure deployment, custom-domain delivery, Cloudflare routing, recovery access, and the portfolio bypass path have been exercised.']
    ]
  },
  ecommerce: {
    match: '/projects/ecommerce/',
    executiveHero: 'A commerce platform design focused on protecting checkout revenue, preserving inventory integrity, and limiting the customer impact of regional failures without taking on Kubernetes overhead before the business needs it.',
    panelLabel: 'Executive at a glance', panelBadge: 'Revenue protection',
    panel: [['Customer experience','Short, responsive checkout path'],['Business resilience','Regional API continuity by design'],['Cost posture','Managed PaaS before platform complexity']],
    recommendation: 'Invest first in checkout availability, inventory correctness, and observable recovery. Add platform complexity only where it directly reduces a measured revenue, continuity, or scale risk.',
    cards: [
      ['Business objective','Keep checkout responsive during normal demand and infrastructure disruption while preventing ambiguous inventory ownership that can lead to overselling or failed fulfillment.'],
      ['Customer & revenue impact','The synchronous customer path stays small while payment, shipping, inventory processing, and analytics are decoupled. That reduces the number of downstream systems that can directly slow or block checkout.'],
      ['Risk reduction','A single inventory authority makes stock ownership explicit. Idempotent asynchronous processing is intended to reduce duplicate side effects during retries and worker failures.'],
      ['Continuity posture','Front Door and regional App Service origins provide an API failover strategy, while Cosmos has a defined regional recovery model. Service Bus regional continuity remains an explicit gap rather than an overstated resilience claim.'],
      ['Investment & operating model','App Service is favored over AKS because this commerce workload does not currently justify a Kubernetes control plane. The separate hybrid lab uses Kubernetes where the platform itself is part of the learning and validation objective.'],
      ['Confidence level','Dev, test, and production infrastructure compile cleanly and the dev architecture passes live ARM What-If. Runtime commerce behavior is not claimed until it is deployed and exercised.']
    ]
  },
  age: {
    match: '/projects/age-verification/',
    executiveHero: 'A privacy-first age-assurance platform designed to produce an eligibility decision while minimizing custody of highly sensitive imagery, reducing exposure if systems are compromised, and avoiding a retained photo repository.',
    panelLabel: 'Executive at a glance', panelBadge: 'Privacy by design',
    panel: [['Privacy objective','Minimize possession of source imagery'],['Governance posture','Fail closed; model governance stays explicit'],['Data retention','No intentional verification image store']],
    recommendation: 'Treat data minimization as a product architecture decision, not a retention policy added later. Preserve the security boundary even when that means a verification request must fail closed.',
    cards: [
      ['Business objective','Support an age-gating decision without turning sensitive verification imagery into a durable company data asset or expanding the number of systems trusted with plaintext.'],
      ['Privacy & breach impact','The image is encrypted before the public edge, remains ciphertext through the gateway, and is decrypted only inside the private inference boundary. No verification image store is intentionally provisioned.'],
      ['Regulatory & governance posture','The platform reduces data exposure, but it does not claim that an age-estimation model is legally sufficient, unbiased, accurate for every threshold, or appropriate in every jurisdiction. Those remain product and model governance decisions.'],
      ['Security vs. availability','Key, anti-replay state, and model-health failures are designed to deny or make verification unavailable instead of weakening controls. The business tradeoff is lower availability in exchange for preserving the trust boundary.'],
      ['Operating model','Customers can bring an approved model container while the Azure platform standardizes network isolation, identity, key management, telemetry boundaries, and no-image-retention controls.'],
      ['Confidence level','Foundation and workload IaC compile cleanly and the dev foundation passes live ARM What-If through GitHub OIDC. End-to-end runtime privacy and model behavior are not claimed until a temporary deployment is completed and tested.']
    ]
  },
  hybrid: {
    match: '/projects/hybrid-kubernetes-chaos/',
    executiveHero: 'A cost-conscious hybrid-cloud lab that connects physical Kubernetes to Azure Arc, uses GitOps for desired-state management, and replaces generic resilience claims with measured failure and recovery evidence.',
    panelLabel: 'Executive at a glance', panelBadge: 'Runtime evidence',
    panel: [['Hybrid strategy','Physical Kubernetes governed through Azure Arc'],['Operating model','GitHub source of truth + Flux reconciliation'],['Resilience proof','Pod, CPU, and network faults measured']],
    recommendation: 'Keep the current single-node lab for low-cost pod and service experimentation, then add a second physical worker before making any node-level resilience claim.',
    cards: [
      ['Business objective','Demonstrate a practical hybrid-cloud operating model and measurable Kubernetes resilience without carrying the recurring cost of an always-on managed cloud cluster.'],
      ['Cloud operating model','Azure Arc supplies the hybrid management plane while the workload remains on physical infrastructure. Flux continuously reconciles the cluster from the GitHub source of truth.'],
      ['Runtime resilience','A deleted replica recovered to the three-replica desired state in 6.89 seconds with 109/109 successful Service requests. CPU saturation and network isolation experiments also maintained 100% observed Service availability.'],
      ['Evidence quality','The test harness measures availability from inside Kubernetes and records timestamped experiment evidence. A misleading port-forward measurement was explicitly discarded rather than presented as application availability.'],
      ['Risk insight','The network experiment proved that a pod can remain Kubernetes Ready while another workload cannot reach its pod IP, reinforcing that local readiness is not the same thing as every end-to-end client path.'],
      ['Known limitation','All current replicas share one physical node, so the project demonstrates pod/service resilience but does not claim node-level high availability.']
    ]
  }
};

const projectAudienceStyles = `
.audience-switcher{display:flex;align-items:center;justify-content:space-between;gap:24px;margin:-8px 0 24px;padding:16px 18px;background:rgba(255,255,255,.96);border:1px solid var(--line,#d8e2e9);border-radius:9px;box-shadow:0 8px 24px rgba(24,55,76,.06);position:sticky;top:66px;z-index:9;backdrop-filter:blur(10px)}
.audience-switch-copy{display:grid;gap:3px}.audience-switch-copy strong{font-size:14px}.audience-switch-copy>span:last-child{font-size:11px;color:var(--muted,#63727d)}.audience-toggle{display:grid;grid-template-columns:1fr 1fr;border:1px solid #bfd0dc;background:#f4f8fb;padding:3px;min-width:360px}.audience-toggle button{border:0;background:transparent;color:#53636e;padding:9px 13px;cursor:pointer;text-align:left;font:600 12px/1.25 "Segoe UI",Arial,sans-serif}.audience-toggle button small{display:block;font-size:9px;font-weight:500;color:#7a8994;margin-top:2px}.audience-toggle button[aria-pressed="true"]{background:#0078d4;color:#fff;box-shadow:0 2px 7px rgba(0,120,212,.2)}.audience-toggle button[aria-pressed="true"] small{color:#e8f5fd}.audience-executive-hero-copy,.audience-executive-panel,.audience-executive-actions,.audience-executive-section{display:none}.audience-executive-panel{border:1px solid #d7e2ea;background:#f8fbfd;min-height:235px}.audience-executive-actions{gap:10px;margin-top:24px;flex-wrap:wrap}.audience-executive-actions .button{cursor:pointer;font-family:inherit}.audience-executive-section{display:none;margin:0 0 30px}.audience-executive-intro{display:flex;align-items:end;justify-content:space-between;gap:24px;margin-bottom:14px}.audience-executive-intro h2{font-size:27px;margin:5px 0 0}.audience-executive-intro p{max-width:560px;margin:0;color:var(--muted,#63727d);font-size:12px;line-height:1.6}.audience-executive-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.audience-executive-card{background:var(--surface,#fff);border:1px solid var(--line,#d8e2e9);padding:21px;min-height:165px}.audience-executive-card span{display:block;color:#0078d4;font-size:9px;font-weight:700;letter-spacing:.09em;text-transform:uppercase;margin-bottom:16px}.audience-executive-card strong{display:block;font-size:14px;margin-bottom:8px}.audience-executive-card p{margin:0;color:var(--muted,#63727d);font-size:12px;line-height:1.65}.audience-executive-recommendation{margin-top:12px;padding:20px 22px;background:#edf6fc;border-left:4px solid #0078d4;display:grid;grid-template-columns:auto 1fr;gap:18px;align-items:start}.audience-executive-recommendation span{font-size:9px;font-weight:700;letter-spacing:.09em;color:#0078d4;text-transform:uppercase}.audience-executive-recommendation strong{font-size:13px;line-height:1.55}.audience-engineer-note{display:none;margin:0 0 20px;padding:12px 16px;border-left:3px solid #0078d4;background:#f7fbfd;color:var(--muted,#63727d);font-size:11px;line-height:1.5}.audience-engineer-note strong{color:var(--ink,#17212b)}
body[data-project-audience="executive"] .project-page>.project-toc,body[data-project-audience="executive"] .project-page>.project-summary-strip,body[data-project-audience="executive"] .project-page>.section{display:none}body[data-project-audience="executive"] .project-page>.audience-executive-section{display:block}body[data-project-audience="executive"] .hero>.hero-panel{display:none}body[data-project-audience="executive"] .hero .hero-copy:not(.audience-executive-hero-copy){display:none}body[data-project-audience="executive"] .hero .hero-actions:not(.audience-executive-actions){display:none}body[data-project-audience="executive"] .audience-executive-hero-copy{display:block}body[data-project-audience="executive"] .audience-executive-panel{display:block}body[data-project-audience="executive"] .audience-executive-actions{display:flex}body[data-project-audience="engineer"] .audience-engineer-note{display:block}
:root[data-theme="dark"] .audience-switcher{background:rgba(18,28,36,.96);border-color:var(--theme-line);box-shadow:0 8px 24px rgba(0,0,0,.18)}:root[data-theme="dark"] .audience-switch-copy>span:last-child,:root[data-theme="dark"] .audience-executive-intro p,:root[data-theme="dark"] .audience-executive-card p,:root[data-theme="dark"] .audience-engineer-note{color:var(--theme-muted)}:root[data-theme="dark"] .audience-toggle{background:#101a22;border-color:var(--theme-line)}:root[data-theme="dark"] .audience-toggle button{color:#b5c5cf}:root[data-theme="dark"] .audience-toggle button small{color:var(--theme-subtle)}:root[data-theme="dark"] .audience-toggle button[aria-pressed="true"]{background:#0878c9;color:#fff}:root[data-theme="dark"] .audience-toggle button[aria-pressed="true"] small{color:#dff3ff}:root[data-theme="dark"] .audience-executive-panel,:root[data-theme="dark"] .audience-executive-card{background:var(--theme-surface);border-color:var(--theme-line);color:var(--theme-text)}:root[data-theme="dark"] .audience-executive-card span,:root[data-theme="dark"] .audience-executive-recommendation span{color:var(--theme-accent)}:root[data-theme="dark"] .audience-executive-recommendation{background:#112736;border-color:#279ee5}:root[data-theme="dark"] .audience-executive-recommendation strong,:root[data-theme="dark"] .audience-engineer-note strong{color:var(--theme-text)}:root[data-theme="dark"] .audience-engineer-note{background:#111f28;border-color:#279ee5}
@media(max-width:850px){.audience-switcher{align-items:stretch;flex-direction:column;gap:12px;position:static}.audience-toggle{min-width:0;width:100%}.audience-executive-grid{grid-template-columns:1fr 1fr}.audience-executive-intro{align-items:start;flex-direction:column;gap:8px}}
@media(max-width:650px){.audience-switcher{margin:-4px 0 18px;padding:14px}.audience-toggle{grid-template-columns:1fr}.audience-toggle button{text-align:center}.audience-executive-grid{grid-template-columns:1fr}.audience-executive-intro h2{font-size:23px}.audience-executive-recommendation{grid-template-columns:1fr;gap:6px}}
@media(prefers-reduced-motion:reduce){.audience-toggle button{transition:none}}
`;

function readProjectAudiencePreference() {
  try {
    const saved = localStorage.getItem(projectAudiencePreferenceKey);
    return saved === 'executive' || saved === 'engineer' ? saved : null;
  } catch { return null; }
}

function writeProjectAudiencePreference(view) {
  try { localStorage.setItem(projectAudiencePreferenceKey, view); } catch {}
}

function resolveProjectAudiencePreference() {
  const requested = new URLSearchParams(window.location.search).get('view');
  if (requested === 'executive' || requested === 'engineer') return requested;
  return readProjectAudiencePreference() || 'executive';
}

function findProjectAudienceConfig() {
  const path = window.location.pathname.endsWith('/') ? window.location.pathname : `${window.location.pathname}/`;
  return Object.values(projectAudienceConfigs).find(config => path.includes(config.match)) || null;
}

function createExecutivePanel(config) {
  const panel = document.createElement('div');
  panel.className = 'hero-panel validation-panel audience-executive-panel';
  const rows = config.panel.map(([label, value]) => `<div><span>${label}</span><strong>${value}</strong></div>`).join('');
  panel.innerHTML = `<div class="panel-header"><span>${config.panelLabel}</span><span class="status-chip success">${config.panelBadge}</span></div><div class="validation-list">${rows}</div>`;
  return panel;
}

function createExecutiveSection(config) {
  const section = document.createElement('section');
  section.className = 'audience-executive-section';
  section.id = 'executive-overview';
  const cards = config.cards.map(([title, copy], index) => `<article class="audience-executive-card"><span>${String(index + 1).padStart(2, '0')}</span><strong>${title}</strong><p>${copy}</p></article>`).join('');
  section.innerHTML = `
    <div class="audience-executive-intro">
      <div><div class="eyebrow">EXECUTIVE VIEW</div><h2>Business impact, risk, and decision logic.</h2></div>
      <p>This view intentionally removes implementation detail and focuses on the outcomes, exposure, investment choices, and tradeoffs a decision-maker needs to evaluate the architecture.</p>
    </div>
    <div class="audience-executive-grid">${cards}</div>
    <div class="audience-executive-recommendation" id="executive-recommendation"><span>Architect recommendation</span><strong>${config.recommendation}</strong></div>`;
  return section;
}

function initializeProjectAudienceView() {
  const page = document.querySelector('.project-page');
  const hero = page?.querySelector('.hero');
  const config = findProjectAudienceConfig();
  if (!page || !hero || !config || document.querySelector('.audience-switcher')) return;

  if (!document.querySelector('style[data-project-audience-styles]')) {
    const style = document.createElement('style');
    style.dataset.projectAudienceStyles = 'true';
    style.textContent = projectAudienceStyles;
    document.head.appendChild(style);
  }

  const originalHeroCopy = hero.querySelector('.hero-copy');
  if (originalHeroCopy) {
    const executiveHeroCopy = document.createElement('p');
    executiveHeroCopy.className = 'hero-copy audience-executive-hero-copy';
    executiveHeroCopy.textContent = config.executiveHero;
    originalHeroCopy.after(executiveHeroCopy);
  }

  const originalPanel = hero.querySelector(':scope > .hero-panel');
  if (originalPanel) originalPanel.after(createExecutivePanel(config));

  const originalActions = hero.querySelector('.hero-actions');
  if (originalActions) {
    const executiveActions = document.createElement('div');
    executiveActions.className = 'hero-actions audience-executive-actions';
    executiveActions.innerHTML = '<a class="button primary" href="#executive-overview">Business case</a><a class="button" href="#executive-recommendation">Recommendation</a><button class="button" type="button" data-set-project-audience="engineer">Open engineer view</button>';
    originalActions.after(executiveActions);
  }

  const switcher = document.createElement('section');
  switcher.className = 'audience-switcher';
  switcher.setAttribute('aria-label', 'Project audience view');
  switcher.innerHTML = `
    <div class="audience-switch-copy"><span class="eyebrow">AUDIENCE VIEW</span><strong>Same architecture. Different decision lens.</strong><span class="audience-view-description" aria-live="polite"></span></div>
    <div class="audience-toggle" role="group" aria-label="Choose project presentation">
      <button type="button" data-project-audience-option="executive" aria-pressed="false">Executive<small>Business impact · risk · investment</small></button>
      <button type="button" data-project-audience-option="engineer" aria-pressed="false">Engineer<small>Architecture · implementation · evidence</small></button>
    </div>`;
  hero.after(switcher);

  const engineerNote = document.createElement('div');
  engineerNote.className = 'audience-engineer-note';
  engineerNote.innerHTML = '<strong>Engineer view:</strong> implementation detail, service topology, trust boundaries, failure behavior, Infrastructure as Code, GitOps, and validation evidence are shown below.';
  switcher.after(engineerNote);
  engineerNote.after(createExecutiveSection(config));

  const setView = (view, persist = true) => {
    const resolved = view === 'engineer' ? 'engineer' : 'executive';
    document.body.dataset.projectAudience = resolved;
    if (persist) writeProjectAudiencePreference(resolved);
    document.querySelectorAll('[data-project-audience-option]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.projectAudienceOption === resolved)));
    const description = document.querySelector('.audience-view-description');
    if (description) description.textContent = resolved === 'executive'
      ? 'Showing outcomes, risk, cost, governance, and decision tradeoffs.'
      : 'Showing technical design, implementation choices, failure modes, and evidence.';
  };

  switcher.addEventListener('click', event => {
    const option = event.target.closest('[data-project-audience-option]');
    if (option) setView(option.dataset.projectAudienceOption);
  });

  page.querySelectorAll('[data-set-project-audience]').forEach(button => {
    button.addEventListener('click', () => {
      setView(button.dataset.setProjectAudience);
      switcher.scrollIntoView({behavior: 'smooth', block: 'start'});
    });
  });

  let initialView = resolveProjectAudiencePreference();
  const explicitView = new URLSearchParams(window.location.search).get('view');
  if (!explicitView && window.location.hash && document.querySelector(window.location.hash)?.classList.contains('section')) initialView = 'engineer';
  setView(initialView, true);
}

initializeProjectAudienceView();
