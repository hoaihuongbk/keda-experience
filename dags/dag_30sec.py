"""
DAG scheduled to run every 30 seconds.
Each run creates 2 tasks that take 10s each.
Provides a constant baseline load.
"""
from datetime import datetime
import time

from airflow import DAG
from airflow.operators.python import PythonOperator

def simulate_work(task_id: str, duration_seconds: int = 10):
    print(f"Task {task_id} starting, will run for {duration_seconds}s")
    time.sleep(duration_seconds)
    print(f"Task {task_id} done")

with DAG(
    dag_id="dag_30sec",
    start_date=datetime(2025, 1, 1),
    schedule="*/1 * * * *", # Note: Airflow standard cron is 1min, but we can use @continuous or handle high freq
    catchup=False,
    tags=["test", "keda"],
) as dag:
    for i in range(2):
        PythonOperator(
            task_id=f"work_{i}",
            python_callable=simulate_work,
            op_kwargs={"task_id": f"work_{i}"},
        )
