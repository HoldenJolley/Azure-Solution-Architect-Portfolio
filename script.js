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

const portfolioProfile = {
  name: 'Holden Jolley',
  type: 'Microsoft.Portfolio/solutionArchitects',
  properties: {
    focus: ['Azure', 'Cloud Infrastructure', 'Identity', 'Security'],
    location: 'North Carolina',
    relocation: 'Bay Area',
    infrastructureAsCode: 'Bicep',
    validation: 'ARM What-If',
    authentication: 'OIDC',
    sameAs: [
      'https://holdenjolley.com/',
      'https://github.com/HoldenJolley',
      'https://www.linkedin.com/in/holden-jolley/'
    ]
  }
};

let profileReturnFocus = null;

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
        <div class="profile-section profile-location">
          <span class="profile-label">Location</span>
          <strong>North Carolina</strong>
          <span>Open to Bay Area relocation for the right opportunity</span>
        </div>
        <div class="profile-section">
          <span class="profile-label">Professional</span>
          <div class="profile-links">
            <a class="profile-link" href="https://www.linkedin.com/in/holden-jolley/" target="_blank" rel="me noreferrer"><span>LinkedIn</span><span aria-hidden="true">↗</span></a>
            <a class="profile-link" href="https://github.com/HoldenJolley" target="_blank" rel="me noreferrer"><span>GitHub</span><span aria-hidden="true">↗</span></a>
            <a class="profile-link" href="mailto:Jolleyholden@gmail.com"><span>Email</span><span aria-hidden="true">→</span></a>
            <a class="profile-link" href="resume.pdf"><span>Resume</span><span aria-hidden="true">↓</span></a>
          </div>
        </div>
        <div class="profile-section">
          <span class="profile-label">Portfolio</span>
          <div class="profile-facts">
            <div class="profile-fact"><span>Architectures</span><strong>3 Azure projects</strong></div>
            <div class="profile-fact"><span>Infrastructure as Code</span><strong>Bicep</strong></div>
            <div class="profile-fact"><span>Validation</span><strong>ARM What-If</strong></div>
            <div class="profile-fact"><span>Delivery</span><strong>GitHub Actions + OIDC</strong></div>
          </div>
        </div>
        <div class="profile-section">
          <button type="button" class="profile-json-toggle" aria-expanded="false" aria-controls="profile-json">View profile as JSON</button>
          <pre id="profile-json" class="profile-json" hidden></pre>
        </div>
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

createProfileBlade();

document.addEventListener('keydown', event => {
  if (event.key === 'Escape') closeProfileBlade();
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
  try {
    localStorage.setItem(portfolioThemeKey, theme);
  } catch {
    // The theme still works for this page when storage is unavailable.
  }
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
  if (portfolioScriptUrl && !document.querySelector('link[data-portfolio-theme]')) {
    const themeStyles = document.createElement('link');
    themeStyles.rel = 'stylesheet';
    themeStyles.href = new URL('theme.css', portfolioScriptUrl).href;
    themeStyles.dataset.portfolioTheme = 'true';
    document.head.appendChild(themeStyles);
  }

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
