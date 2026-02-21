# Use host helm/kubectl so -f values paths work (microk8s helm runs inside VM, can't see host files)
# Requires: brew install helm, and microk8s config > ~/.kube/config
HELM := helm
KUBECTL := kubectl

.PHONY: airflow-repo airflow-install airflow-uninstall airflow-status kustomize-build airflow-dag-copy airflow-watch

# Add Apache Airflow Helm repo
airflow-repo:
	$(HELM) repo add apache-airflow https://airflow.apache.org
	$(HELM) repo update

# Kustomize overlays: base + overlay values are merged (overlay wins)
AIRFLOW_BASE := airflow/base/values.yaml
AIRFLOW_OVERLAY ?= airflow/overlays/dev/values.yaml

# Install or upgrade Airflow into MicroK8s (dev overlay by default)
# Use: make airflow-install OVERLAY=airflow/overlays/staging/values.yaml
# Uses host helm so values files (on host) are readable; targets cluster from KUBECONFIG
airflow-install: airflow-repo
	$(HELM) upgrade --install airflow apache-airflow/airflow \
		--namespace airflow \
		--create-namespace \
		-f $(AIRFLOW_BASE) \
		-f $(AIRFLOW_OVERLAY)

# Uninstall Airflow
airflow-uninstall:
	$(HELM) uninstall airflow --namespace airflow

# Show Airflow pods status
airflow-status:
	$(KUBECTL) get pods -n airflow

# Build and print Kustomize manifests (test overlay)
# Use: make kustomize-build OVERLAY=airflow/overlays/staging
KUSTOMIZE_OVERLAY ?= airflow/overlays/dev
kustomize-build:
	$(KUBECTL) kustomize $(KUSTOMIZE_OVERLAY)

# Sync local dags/ folder to persistent volume (via dag-processor pod)
# This will copy your DAGs into /opt/airflow/dags/ and they will persist on the PV
airflow-dag-install:
	@POD=$$($(KUBECTL) get pods -n airflow -l component=dag-processor -o jsonpath='{.items[0].metadata.name}'); \
	if [ -z "$$POD" ]; then echo "DAG Processor pod not found. Run 'make airflow-install' first."; exit 1; fi; \
	$(KUBECTL) cp dags/. airflow/$$POD:/opt/airflow/dags/ -n airflow; \
	echo "DAGs synced to dag-processor $$POD (and onto shared persistent volume)"

# Watch pods and KEDA ScaledObject while testing scaling
airflow-watch:
	@echo "Watching airflow pods and KEDA ScaledObject (Ctrl+C to stop)..."
	$(KUBECTL) get pods -n airflow -w &
	$(KUBECTL) get scaledobject -n airflow -w 2>/dev/null || true

# Port-forward Airflow UI to localhost:18080 (Press Ctrl+C to stop)
# Using api-server service for Airflow 3
airflow-ui:
	@echo "Access Airflow UI at http://localhost:18080"
	$(KUBECTL) port-forward svc/airflow-api-server 18080:8080 -n airflow

# Show KEDA scaling stats for the last 1 hour
airflow-keda-stats:
	@echo "=== KEDA Worker Scaling Activity (Last 1h) ==="
	@echo "KEDA Scaler Activations (from zero):"
	@$(KUBECTL) get events -n airflow --no-headers | grep "scaledobject/airflow-worker" | grep "KEDAScaleTargetActivated" | \
		wc -l | xargs -I {} echo "  Count: {}"
	@echo "KEDA Scaler Deactivations (to zero):"
	@$(KUBECTL) get events -n airflow --no-headers | grep "scaledobject/airflow-worker" | grep "KEDAScaleTargetDeactivated" | \
		wc -l | xargs -I {} echo "  Count: {}"
	@echo ""
	@echo "HPA Scaling Decisions (Size Changes):"
	@$(KUBECTL) get events -n airflow --no-headers | grep "keda-hpa-airflow-worker" | grep "SuccessfulRescale" | \
		awk '{for(i=1;i<=NF;i++) if($$i=="size:") print $$(i+1)}' | sed 's/;//' | \
		sort | uniq -c | awk '{print "  Scaled to " $$2 " replicas: " $$1 " times"}'
	@echo ""
	@echo "Detailed Scaling Timeline (Last 20):"
	@$(KUBECTL) get events -n airflow --sort-by='.lastTimestamp' | \
		grep -E "scaledobject/airflow-worker|keda-hpa-airflow-worker" | \
		awk '{printf "%-10s %-25s ", $$1, $$4; for(i=7;i<=NF;i++) printf "%s ", $$i; print ""}' | tail -n 20
