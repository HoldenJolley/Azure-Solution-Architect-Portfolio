// Runtime portfolio updates for the live hybrid Kubernetes lab.
// Loaded after script.js so existing portfolio UI behavior stays intact.

if (typeof shellCommands !== 'undefined') {
  shellCommands.help = `Available commands:\n  az portfolio show\n  az architecture list\n  az deployment sub what-if\n  az aks list\n  az connectedk8s show\n  az k8s-configuration flux show\n  kubectl get nodes\n  kubectl get pods -n hybrid-lab\n  az account show\n  az group list\n  clear\n  exit`;

  shellCommands['az portfolio show'] = `Name:           Holden Jolley\nRole:           Azure Solution Architect\nLocation:       North Carolina\nRelocation:     Bay Area\nArchitectures:  4\nIaC / GitOps:   Bicep + Flux\nValidation:     ARM What-If + runtime chaos evidence\nAuthentication: GitHub OIDC`;

  shellCommands['az architecture list'] = `NAME                      PRIORITY             VALIDATION\nportfolio-hosting         Cost Optimization    Live on Azure\necommerce                 Reliability          ARM What-If\nage-assurance             Security / Privacy   Foundation ARM What-If\nhybrid-kubernetes         Hybrid Resilience    Arc + Flux + runtime chaos`;

  shellCommands['az aks list'] = `[]\n\nNo managed AKS clusters found.\nThe Kubernetes lab is a physical kubeadm cluster connected through Azure Arc.\nTry: az connectedk8s show`;

  shellCommands['az connectedk8s show'] = `Name:           k8s-edge-01\nResource group: rg-k8s-hybrid-lab\nLocation:       eastus2\nDistribution:   kubeadm / Ubuntu Server\nConnectivity:   Azure Arc-enabled Kubernetes\nGitOps:         Flux enabled\nStatus:         Connected`;

  shellCommands['az k8s-configuration flux show'] = `Name:          hybrid-lab-gitops\nCluster:       k8s-edge-01\nSource:        GitHub main branch\nPath:          ./projects/hybrid-kubernetes-chaos/gitops\nReconciliation: Active\nObserved proof: replica change 2 -> 3 reconciled without kubectl apply`;

  shellCommands['kubectl get nodes'] = `NAME          STATUS   ROLES           VERSION\nk8s-edge-01   Ready    control-plane   v1.37.1`;

  shellCommands['kubectl get pods -n hybrid-lab'] = `NAME                            READY   STATUS    RESTARTS\nhybrid-demo-<replica-a>          1/1     Running   0\nhybrid-demo-<replica-b>          1/1     Running   0\nhybrid-demo-<replica-c>          1/1     Running   0\n\nDesired state: 3 replicas via Flux GitOps\nChaos evidence: pod deletion, CPU saturation, NetworkPolicy isolation`;

  shellCommands['az group list'] = `NAME                 PURPOSE\nrg-k8s-hybrid-lab    Azure Arc-connected physical Kubernetes lab\n\nOther reference architectures remain deployment-gated or short-lived validation environments.`;
}

if (typeof portfolioProfile !== 'undefined') {
  portfolioProfile.properties.focus = ['Azure', 'Hybrid Cloud', 'Kubernetes', 'Cloud Infrastructure', 'Identity', 'Security'];
  portfolioProfile.properties.validation = 'ARM What-If + runtime chaos evidence';
  portfolioProfile.properties.gitOps = 'Flux';
  portfolioProfile.properties.hybridManagement = 'Azure Arc-enabled Kubernetes';

  const jsonView = document.querySelector('#profile-json');
  if (jsonView) jsonView.textContent = JSON.stringify(portfolioProfile, null, 2);
}

document.querySelectorAll('.profile-fact').forEach(fact => {
  const label = fact.querySelector('span')?.textContent.trim();
  const value = fact.querySelector('strong');
  if (!value) return;
  if (label === 'Architectures') value.textContent = '4 Azure / hybrid projects';
  if (label === 'Validation') value.textContent = 'ARM What-If + runtime';
  if (label === 'Delivery') value.textContent = 'GitHub Actions + OIDC + Flux';
});

if (typeof projectAudienceConfigs !== 'undefined') {
  projectAudienceConfigs.hybrid = {
    match: '/projects/hybrid-kubernetes-chaos/',
    executiveHero: 'A cost-conscious hybrid-cloud lab that connects physical Kubernetes to Azure Arc, uses GitOps for desired-state management, and replaces generic resilience claims with measured failure and recovery evidence.',
    panelLabel: 'Executive at a glance',
    panelBadge: 'Runtime evidence',
    panel: [
      ['Hybrid strategy', 'Physical Kubernetes governed through Azure Arc'],
      ['Operating model', 'GitHub source of truth + Flux reconciliation'],
      ['Resilience proof', 'Pod, CPU, and network faults measured']
    ],
    recommendation: 'Keep the current single-node lab for low-cost pod and service experimentation, then add a second physical worker before making any node-level resilience claim.',
    cards: [
      ['Business objective', 'Demonstrate a practical hybrid-cloud operating model and measurable Kubernetes resilience without carrying the recurring cost of an always-on managed cloud cluster.'],
      ['Cloud operating model', 'Azure Arc supplies the hybrid management plane while the workload remains on physical infrastructure. Flux continuously reconciles the cluster from the GitHub source of truth.'],
      ['Runtime resilience', 'A deleted replica recovered to the three-replica desired state in 6.89 seconds with 109/109 successful service requests. CPU saturation and network isolation experiments also maintained 100% observed Service availability.'],
      ['Evidence quality', 'The test harness measures availability from inside Kubernetes and records timestamped experiment evidence. A misleading port-forward measurement was explicitly discarded rather than presented as application availability.'],
      ['Risk insight', 'The network experiment proved that a pod can remain Kubernetes Ready while another workload cannot reach its pod IP, reinforcing that local readiness is not the same thing as every end-to-end client path.'],
      ['Known limitation', 'All current replicas share one physical node, so the project demonstrates pod/service resilience but does not claim node-level high availability.']
    ]
  };

  if (window.location.pathname.includes('/projects/hybrid-kubernetes-chaos/') && typeof initializeProjectAudienceView === 'function') {
    initializeProjectAudienceView();
  }
}

console.info('%cHybrid Kubernetes lab: Azure Arc connected, Flux reconciled, chaos tested.', 'font-weight:600;color:#107c10');