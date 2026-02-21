"""
Sample DAG to test KEDA worker scaling.

Creates multiple parallel tasks that run concurrently, which should trigger
KEDA to scale up Celery workers. Use this to verify scale-to-zero and
scale-up behavior.

Trigger manually from the Airflow UI, then watch:
  kubectl get pods -n airflow -w
  kubectl get scaledobject -n airflow
"""
from datetime import datetime

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator


def simulate_work(task_id: str, duration_seconds: int = 45, **kwargs):
    """Simulate CPU-bound work to keep a worker busy."""
    import time
    print(f"Task {task_id} starting, will run for {duration_seconds}s")
    time.sleep(duration_seconds)
    print(f"Task {task_id} done")
    return task_id


# 10 parallel tasks - enough to trigger worker scale-up (KEDA scales on queued+running count)
NUM_TASKS = 10
TASK_DURATION = 45  # seconds - long enough to observe scaling

with DAG(
    dag_id="example_keda_scale_test",
    start_date=datetime(2025, 1, 1),
    schedule=None,  # Manual trigger only
    catchup=False,
    tags=["test", "keda"],
) as dag:
    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    tasks = []
    for i in range(NUM_TASKS):
        task = PythonOperator(
            task_id=f"work_{i}",
            python_callable=simulate_work,
            op_kwargs={
                "task_id": f"work_{i}",
                "duration_seconds": TASK_DURATION,
            },
        )
        tasks.append(task)

    start >> tasks >> end
