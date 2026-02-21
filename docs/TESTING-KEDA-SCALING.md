# Testing KEDA Worker Scaling

This guide walks through testing KEDA autoscaling of Airflow Celery workers using a sample DAG.

## 1. Load the sample DAG into Airflow

**Option A (recommended):** Mount DAGs via ConfigMap – persists across restarts, works with git-sync

```bash
make airflow-dag-install
```

This creates a ConfigMap from the DAG and upgrades Airflow to mount it on scheduler, api-server, and workers. Restart pods if needed: `kubectl rollout restart deployment -n airflow -l component=scheduler`.

**Option B:** Quick copy (may be overwritten by git-sync)

```bash
make airflow-dag-copy
```

The DAG should appear in the Airflow UI within ~30–60 seconds. If it doesn't, check **Browse → Import Errors** for parsing issues.

## 2. Open Airflow UI (Airflow 3 – API server)

Get the API server URL (NodePort):

```bash
microk8s kubectl get svc -n airflow -l component=api-server -o jsonpath='{.items[0].spec.ports[0].nodePort}'
```

Then open `http://<node-ip>:<nodePort>`. For MicroK8s, the node IP is often `127.0.0.1` or the Multipass VM IP. Or use port-forward:

```bash
microk8s kubectl port-forward -n airflow svc/airflow-api-server 8080:8080
```

Then open http://localhost:8080

## 3. Trigger the DAG

1. In the Airflow UI, find **example_keda_scale_test**
2. Toggle it **On** (unpause)
3. Click the **Play** button → **Trigger DAG**

The DAG runs 10 parallel tasks, each sleeping ~45 seconds. This should trigger KEDA to scale workers up.

## 4. Watch scaling in real time

In a separate terminal:

```bash
# Watch pods (workers should scale up)
make airflow-status
# or
kubectl get pods -n airflow -w

# Watch KEDA ScaledObject
kubectl get scaledobject -n airflow -w

# Check HPA created by KEDA
kubectl get hpa -n airflow
```

You should see:

- **Before trigger:** 0 workers (scale to zero)
- **After trigger:** Workers scaling up as tasks queue
- **After completion:** Workers scaling back down to 0

## 5. Verify in Freelens

If using Freelens, open the KEDA dashboard to see ScaledObject metrics and scaling events.

## Troubleshooting

- **DAG not appearing:** 
  - Wait 30–60s for the scheduler to parse DAGs
  - Use **Browse → Import Errors** in the Airflow UI to check for parsing errors
  - Check scheduler logs: `kubectl logs -n airflow -l component=scheduler -f`
  - If using `airflow-dag-copy` and git-sync is enabled, it may overwrite the file – use `make airflow-dag-install` instead
- **Workers not scaling:** Ensure KEDA is running: `kubectl get pods -n keda`
- **Tasks stuck in queued:** Workers may be starting; give them 1–2 minutes to come up
