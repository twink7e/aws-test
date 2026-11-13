"""Backup RunTask response and STOPPED event tests."""

import unittest

from backup_controller import classify, launch


SETTINGS = {
    "ECS_CLUSTER_ARN": "arn:aws:ecs:ap-northeast-1:123456789012:cluster/test",
    "BACKUP_TASK_DEFINITION_ARN": "arn:aws:ecs:ap-northeast-1:123456789012:task-definition/test-backup:1",
    "BACKUP_TASK_GROUP": "family:test-backup",
    "BACKUP_SUBNET_IDS": "subnet-a,subnet-b",
    "BACKUP_SECURITY_GROUP_ID": "sg-test",
    "METRIC_NAMESPACE": "test/Backup",
    "SNS_TOPIC_ARN": "arn:aws:sns:ap-northeast-1:123456789012:test-alerts",
}

LAUNCH_EVENT = {
    "action": "launch",
    "schedule_arn": "arn:aws:scheduler:ap-northeast-1:123456789012:schedule/test/daily",
    "scheduled_time": "2026-11-13T17:00:00Z",
}


class FakeECS:
    def __init__(self, response):
        self.response = response
        self.parameters = []

    def run_task(self, **parameters):
        self.parameters.append(parameters)
        return self.response


class FakeCloudWatch:
    def __init__(self):
        self.metrics = []

    def put_metric_data(self, **parameters):
        self.metrics.append(parameters)


class FakeSNS:
    def __init__(self):
        self.messages = []

    def publish(self, **parameters):
        self.messages.append(parameters)


def event(exit_code=None, stop_code="EssentialContainerExited", containers=True):
    items = [{"name": "backup", "exitCode": exit_code}] if containers else []
    return {
        "detail": {
            "lastStatus": "STOPPED",
            "taskArn": "arn:aws:ecs:ap-northeast-1:123456789012:task/test/abc",
            "stopCode": stop_code,
            "stoppedReason": "Essential container in task exited",
            "containers": items,
        }
    }


class BackupControllerTest(unittest.TestCase):
    def test_successful_dump(self):
        self.assertTrue(classify(event(0))[0])

    def test_failed_dump(self):
        succeeded, reason, _ = classify(event(1))
        self.assertFalse(succeeded)
        self.assertIn("exit code 1", reason)

    def test_task_failed_to_start_without_container(self):
        self.assertFalse(classify(event(stop_code="TaskFailedToStart", containers=False))[0])

    def test_missing_exit_code(self):
        self.assertFalse(classify(event())[0])

    def test_run_task_success_and_stable_retry_token(self):
        ecs = FakeECS({"tasks": [{"taskArn": "task-abc"}], "failures": []})
        cloudwatch = FakeCloudWatch()
        sns = FakeSNS()

        result = launch(LAUNCH_EVENT, ecs, cloudwatch, sns, SETTINGS)
        launch(LAUNCH_EVENT, ecs, cloudwatch, sns, SETTINGS)

        self.assertTrue(result["started"])
        self.assertEqual(result["task_arn"], "task-abc")
        self.assertEqual(ecs.parameters[0]["clientToken"], ecs.parameters[1]["clientToken"])
        self.assertEqual(ecs.parameters[0]["networkConfiguration"]["awsvpcConfiguration"]["assignPublicIp"], "ENABLED")
        self.assertEqual(cloudwatch.metrics, [])
        self.assertEqual(sns.messages, [])

    def test_run_task_http_200_with_failures_is_alerted(self):
        ecs = FakeECS({"tasks": [], "failures": [{"reason": "RESOURCE:CPU"}]})
        cloudwatch = FakeCloudWatch()
        sns = FakeSNS()

        with self.assertRaisesRegex(RuntimeError, "RESOURCE:CPU"):
            launch(LAUNCH_EVENT, ecs, cloudwatch, sns, SETTINGS)

        self.assertEqual(cloudwatch.metrics[0]["MetricData"][0]["MetricName"], "BackupFailed")
        self.assertIn("RESOURCE:CPU", sns.messages[0]["Message"])

    def test_run_task_without_task_or_failure_is_alerted(self):
        ecs = FakeECS({"tasks": [], "failures": []})
        cloudwatch = FakeCloudWatch()
        sns = FakeSNS()

        with self.assertRaisesRegex(RuntimeError, "0 tasks"):
            launch(LAUNCH_EVENT, ecs, cloudwatch, sns, SETTINGS)

        self.assertEqual(cloudwatch.metrics[0]["MetricData"][0]["MetricName"], "BackupFailed")


if __name__ == "__main__":
    unittest.main()
