"""
DAG scheduled to run every 2 minutes.
Each run creates 4 tasks that take 30s each.
"""
from datetime import datetime
import time

from airflow import DAG
from airflow.operators.python import PythonOperator

def simulate_work(task_id: str, duration_seconds: int = 30):
    print(f"Task {task_id} starting, will run for {duration_seconds}s")
    time.sleep(duration_seconds)
    print(f"Task {task_id} done")

with DAG(
    dag_id="dag_2min",
    start_date=datetime(2025, 1, 1),
    schedule="*/2 * * * *",
    catchup=False,
    tags=["test", "keda"],
) as dag:
    for i in range(4):
        PythonOperator(
            task_id=f"work_{i}",
            python_callable=simulate_work,
            op_kwargs={"task_id": f"work_{i}"},
        )
