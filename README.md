# KEDA Experience Setup Guide

This repo is for gaining experience with [KEDA](https://keda.sh/) and seeing how it enables intelligent autoscaling, including scale-to-zero. The goal is to test with Airflow and auto-scale workers, scheduler, and other components.

## Prerequisites

- macOS (Apple Silicon or Intel)
- [Homebrew](https://brew.sh/)
- VPN **off** during setup (VPNs often break Multipass networking)
- Helm on host (`brew install helm`) – used by `make airflow-install` so values files are readable

---

## 1. MicroK8s Installation (macOS)

MicroK8s on macOS runs inside a Multipass VM. Install via Homebrew:

```bash
# Install Multipass first (MicroK8s dependency)
brew install multipass

# Install MicroK8s
brew install ubuntu/microk8s/microk8s

# Create the MicroK8s VM and install Kubernetes inside it
microk8s install
```

### Enable Addons

```bash
# DNS – required for KEDA (internal service resolution)
# Helm – package manager for KEDA deployment (use "helm", not "helm3use")
microk8s enable dns helm
```

### Verify Installation

```bash
microk8s status --wait-ready
microk8s kubectl get nodes
```

---

## 2. KEDA Installation

KEDA (Kubernetes Event-driven Autoscaler) enables scale-to-zero and event-driven scaling.

> **Reference:** [Deploying KEDA on MicroK8s](https://keda.sh/docs/2.19/deploy/#microk8s) (official docs)

```bash
# Add KEDA Helm repo and install (use microk8s helm, not helm3)
microk8s helm3 repo add kedacore https://kedacore.github.io/charts
microk8s helm3 repo update
microk8s helm3 install keda kedacore/keda --namespace keda --create-namespace
```

Verify:

```bash
microk8s kubectl get pods -n keda
```

---

## 3. Freelens (Optional Monitoring)

[Freelens](https://github.com/astefanutti/freelens) provides a Grafana-like dashboard for KEDA. Install if you want visual monitoring of ScaledObjects and scaling metrics.

Generate the kubeconfig so Freelens IDE can access the cluster:

```bash
microk8s config > ~/.kube/config
```

Then load the cluster from Freelens IDE.

---

## 4. Airflow Setup

Airflow will be deployed to the cluster for testing autoscaling. KEDA can scale:

- **Workers** – based on queue depth, message count, or custom metrics
- **Scheduler** – based on active DAG runs or task load
- Other components as needed

Ensure kubeconfig is set (`microk8s config > ~/.kube/config`) and Helm is on the host (`brew install helm`). Then:

```bash
make airflow-install
```

This adds the [Apache Airflow Helm repo](https://airflow.apache.org) and installs Airflow into the `airflow` namespace.

### Kustomize structure

```
airflow/
  base/
    kustomization.yaml   # Base config (inherited by overlays)
    values.yaml         # Shared values (KEDA, executor, etc.)
  overlays/
    dev/
      kustomization.yaml # Dev overlay (MicroK8s)
      values.yaml       # Dev-specific overrides
    # Add more: staging/, prod/ for remote clusters
```

Values are merged: `base/values.yaml` + `overlays/<env>/values.yaml` (overlay wins on conflicts).

### Base values (shared)

| Setting | Purpose |
|---------|---------|
| `executor: CeleryExecutor` | Celery workers for KEDA scaling |
| `workers.keda.enabled: true` | Enable KEDA autoscaling on workers |
| `workers.keda.minReplicaCount: 0` | Scale to zero when idle |
| `workers.keda.maxReplicaCount: 10` | Upper bound for workers |
| `apiServer.service.type: NodePort` | Expose UI for MicroK8s access (Airflow 3) |

Edit `airflow/overlays/dev/values.yaml` for dev-only overrides. Add new overlays (e.g. `overlays/staging/`, `overlays/prod/`) for remote clusters that inherit from base.

### Make targets

| Target | Description |
|--------|-------------|
| `make airflow-install` | Install/upgrade (dev overlay; use `OVERLAY=...` for another) |
| `make airflow-status` | Show Airflow pods |
| `make airflow-uninstall` | Remove Airflow |

---

## 5. Quick Reference

| Command | Description |
|---------|-------------|
| `microk8s status` | Cluster status |
| `microk8s kubectl` | kubectl (alias: add `alias kubectl='microk8s kubectl'`) |
| `microk8s helm` | Helm |
| `microk8s enable <addon>` | Enable addon (e.g., `dns`, `helm`) |
| `microk8s uninstall` | Remove MicroK8s |
| `multipass list` | List VMs |
| `multipass delete --purge microk8s-vm` | Remove MicroK8s VM |

---

## Next Steps

1. Deploy Airflow (Helm or manifests).
2. Create KEDA `ScaledObject`s for workers and scheduler.
3. Trigger workloads and observe scaling behavior and scale-to-zero.
4. Tune KEDA triggers and thresholds for your use case.
