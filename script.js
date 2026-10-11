const portfolioScriptUrl = document.currentScript?.src;
if (portfolioScriptUrl && !document.querySelector('link[data-portfolio-enhancements]')) {
  const enhancementStyles = document.createElement('link');
  enhancementStyles.rel = 'stylesheet';
  enhancementStyles.href = new URL('easter-eggs.css', portfolioScriptUrl).href;
  enhancementStyles.dataset.portfolioEnhancements = 'true';
  document.head.appendChild(enhancementStyles);
}

const navItems = [...document.querySelectorAll('.nav-item[href^="#"]')];
const navTargets = navItems
  .map(item => {
    const id = decodeURIComponent(item.getAttribute('href').slice(1));
    return {item, id, target: document.getElementById(id)};
  })
  .filter(entry => entry.target);

function setActiveNav(id) {
  navItems.forEach(item => {
    item.classList.toggle('active', item.getAttribute('href') === `#${id}`);
  });
}

function updateActiveNav() {
  if (!navTargets.length) return;

  const activationLine = 96;
  const atPageBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4;
  let active = navTargets[0];

  for (const entry of navTargets) {
    if (entry.target.getBoundingClientRect().top <= activationLine) {
      active = entry;
    } else {
      break;
    }
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

  navTargets.forEach(({item, id}) => {
    item.addEventListener('click', () => setActiveNav(id));
  });
  window.addEventListener('scroll', scheduleNavUpdate, {passive: true});
  window.addEventListener('resize', scheduleNavUpdate);
  window.addEventListener('load', updateActiveNav);
  updateActiveNav();
}

console.info('%cHoldenJolley.CloudArchitecture/portfolio', 'font-weight:700;color:#0078d4');
console.info('Tip: Ctrl+` opens Cloud Shell. No Azure client secrets were harmed in the deployment of this website.');

const shellCommands = {
  help: `Available commands:\n  az portfolio show\n  az architecture list\n  az deployment sub what-if\n  az aks list\n  az account show\n  az group list\n  clear\n  exit`,
  'az portfolio show': `Name:           Holden Jolley\nRole:           Azure Solution Architect\nLocation:       North Carolina\nRelocation:     Bay Area\nArchitectures:  3\nIaC:            Bicep\nValidation:     ARM What-If\nAuthentication: GitHub OIDC`,
  'az architecture list': `NAME                      PRIORITY             VALIDATION\nportfolio-hosting         Cost Optimization    ARM What-If\necommerce                 Reliability          ARM What-If\nage-assurance             Security / Privacy   Foundation ARM What-If`,
  'az deployment sub what-if': `Resource changes: 0 destructive changes.\n\nArchitectural changes:\n+ Requirements documented\n+ Tradeoffs documented\n+ Infrastructure automated\n+ Azure control plane validated\n~ Production deployment intentionally gated`,
  'az aks list': `[]\n\nNo AKS clusters found.\nReason: the workload didn't require Kubernetes.\nSee: ADR-001`,
  'az account show': `Name:           Portfolio Validation Subscription\nAuthentication: Workload identity federation (OIDC)\nClient secret:  Not configured\nScope:          Architecture validation only`,
  'az group list': `[]\n\nNo portfolio resource groups have been deployed yet.\nWhat-If means what-if.`
};

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
    trigger.addEventListener('click', toggleCloudShell);
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
  appendShellOutput('Type "help" for commands. Nothing here executes against Azure.');
}

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
    const output = document.querySelector('.cloud-shell-output');
    if (output) output.replaceChildren();
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

function activityDetails(label) {
  const normalized = label.toLowerCase();
  if (normalized.includes('azure connected')) {
    return {
      operation: 'Azure/login with OIDC',
      status: 'Succeeded',
      scope: 'Portfolio validation workflows',
      authentication: 'Federated workload identity',
      credential: 'No reusable client secret',
      deployment: 'Not executed'
    };
  }
  if (normalized.includes('arm') || normalized.includes('preflight') || normalized.includes('cloud validated')) {
    return {
      operation: 'Microsoft.Resources/deployments/whatIf',
      status: 'Succeeded',
      scope: normalized.includes('foundation') ? 'Age assurance dev foundation' : 'Subscription-scope architecture preflight',
      authentication: 'GitHub Actions OIDC',
      credential: 'Short-lived federated token',
      deployment: 'Not executed'
    };
  }
  return null;
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
  if (!details) return;
  const overlay = document.querySelector('.activity-overlay');
  const body = overlay?.querySelector('.activity-body');
  if (!overlay || !body) return;

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

function closeActivityBlade() {
  const overlay = document.querySelector('.activity-overlay');
  if (!overlay) return;
  overlay.classList.remove('open');
  overlay.setAttribute('aria-hidden', 'true');
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

document.addEventListener('keydown', event => {
  if (event.ctrlKey && event.key === '`') {
    event.preventDefault();
    toggleCloudShell();
    return;
  }
  if (event.key === 'Escape') {
    toggleCloudShell(false);
    closeActivityBlade();
  }
});
