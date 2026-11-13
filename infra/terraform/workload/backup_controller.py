"""Launch a daily ECS backup and classify its eventual STOPPED event."""

import hashlib
import json
import os


def classify(event):
    """Return (succeeded, reason, task_arn) for one ECS task state event."""
    detail = event.get("detail") or {}
    task_arn = detail.get("taskArn", "unknown-task")
    stop_code = detail.get("stopCode", "unknown-stop-code")
    stopped_reason = detail.get("stoppedReason", "")

    if detail.get("lastStatus") != "STOPPED":
        return False, "task did not report STOPPED", task_arn

    container = next(
        (item for item in detail.get("containers", []) if item.get("name") == "backup"),
        None,
    )
    if container is None:
        return False, f"backup container missing; {stop_code}: {stopped_reason}", task_arn

    exit_code = container.get("exitCode")
    if stop_code == "TaskFailedToStart" or exit_code != 0:
        return (
            False,
            f"backup exit code {exit_code!r}; {stop_code}: {stopped_reason}",
            task_arn,
        )

    return True, "backup container exited 0", task_arn


def publish_metric(cloudwatch, namespace, name):
    cloudwatch.put_metric_data(
        Namespace=namespace,
        MetricData=[{"MetricName": name, "Value": 1, "Unit": "Count"}],
    )


def report_failure(cloudwatch, sns, settings, task_arn, reason):
    publish_metric(cloudwatch, settings["METRIC_NAMESPACE"], "BackupFailed")
    sns.publish(
        TopicArn=settings["SNS_TOPIC_ARN"],
        Subject="POPER PostgreSQL backup failed",
        Message=f"Backup ECS task failed: {task_arn}\n{reason}",
    )


def launch(event, ecs, cloudwatch, sns, settings, request_id=None):
    """Run exactly one backup task and reject ECS HTTP-200 Failures responses."""
    request_key = event.get("scheduled_time") or event.get("request_id") or request_id
    if not request_key:
        raise ValueError("launch request needs a scheduled time or request ID")

    # ECS RunTask is idempotent for retries with the same client token and
    # request parameters. The scheduled time remains stable across retries.
    token_source = f"{event.get('schedule_arn', 'manual')}|{request_key}"
    client_token = hashlib.sha256(token_source.encode("utf-8")).hexdigest()

    parameters = {
        "cluster": settings["ECS_CLUSTER_ARN"],
        "taskDefinition": settings["BACKUP_TASK_DEFINITION_ARN"],
        "launchType": "FARGATE",
        "platformVersion": "1.4.0",
        "count": 1,
        "group": settings["BACKUP_TASK_GROUP"],
        "clientToken": client_token,
        "networkConfiguration": {
            "awsvpcConfiguration": {
                "subnets": settings["BACKUP_SUBNET_IDS"].split(","),
                "securityGroups": [settings["BACKUP_SECURITY_GROUP_ID"]],
                "assignPublicIp": "ENABLED",
            }
        },
    }

    try:
        response = ecs.run_task(**parameters)
    except Exception as exc:
        report_failure(cloudwatch, sns, settings, "not-started", f"RunTask API error: {exc}")
        raise

    failures = response.get("failures") or []
    tasks = response.get("tasks") or []
    if failures or len(tasks) != 1 or not tasks[0].get("taskArn"):
        reason = f"RunTask returned failures={json.dumps(failures, default=str)} and {len(tasks)} tasks"
        report_failure(cloudwatch, sns, settings, "not-started", reason)
        raise RuntimeError(reason)

    task_arn = tasks[0]["taskArn"]
    print(json.dumps({"action": "launch", "task_arn": task_arn}))
    return {"started": True, "task_arn": task_arn}


def check_stopped(event, cloudwatch, sns, settings):
    succeeded, reason, task_arn = classify(event)
    if succeeded:
        publish_metric(cloudwatch, settings["METRIC_NAMESPACE"], "BackupSucceeded")
    else:
        report_failure(cloudwatch, sns, settings, task_arn, reason)

    print(json.dumps({"action": "check", "task_arn": task_arn, "succeeded": succeeded, "reason": reason}))
    return {"succeeded": succeeded, "task_arn": task_arn, "reason": reason}


def handler(event, context):
    # The Lambda runtime includes boto3. Import here so pure classification
    # and launch logic can be tested locally without AWS credentials.
    import boto3

    settings = os.environ
    cloudwatch = boto3.client("cloudwatch")
    sns = boto3.client("sns")

    if event.get("action") == "launch":
        return launch(event, boto3.client("ecs"), cloudwatch, sns, settings, context.aws_request_id)
    if "detail" in event:
        return check_stopped(event, cloudwatch, sns, settings)
    raise ValueError("Unsupported backup controller event")
