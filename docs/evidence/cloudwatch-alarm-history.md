# CloudWatch 告警历史核验

2026-11-16 在 AWS 东京区域查询 `cloudwatch describe-alarm-history`，并在 CloudWatch Console 的各告警 **History** 标签核对。下列时间统一为 UTC。此文件记录 AWS 返回的状态转换和 SNS action，属于可重复的命令行证据；它不是控制台截图，也不能证明邮件到达收件箱。

| 告警 | 进入 `ALARM` | SNS topic action | 恢复 `OK` |
| --- | --- | --- | --- |
| `poper-test-application-error` | 03:39:13，`OK → ALARM` | 03:39:13，`Successfully executed action` | 03:53:05，`ALARM → OK` |
| `poper-test-alb-exact-500-ratio` | 03:40:23，`OK → ALARM` | 03:40:23，`Successfully executed action` | 03:44:23，`ALARM → OK` |
| `poper-test-backup-failed` | 03:47:32，`OK → ALARM` | 03:47:32，`Successfully executed action` | 03:58:27，`ALARM → OK` |

Action 目标为 `arn:aws:sns:ap-northeast-1:966674798543:poper-test-alerts`。备份告警的 [Console History 截图](cloudwatch-backup-failed-history.png) 已收录。应用错误和 ALB 精确 HTTP 500 比例的 History 在控制台中已核对；对应截图尚未落盘。

复核命令（使用已配置的 AWS CLI 凭证）：

```sh
aws cloudwatch describe-alarm-history \
  --region ap-northeast-1 \
  --alarm-name poper-test-application-error \
  --query 'AlarmHistoryItems[].{time:Timestamp,type:HistoryItemType,summary:HistorySummary}'

aws cloudwatch describe-alarm-history \
  --region ap-northeast-1 \
  --alarm-name poper-test-alb-exact-500-ratio \
  --query 'AlarmHistoryItems[].{time:Timestamp,type:HistoryItemType,summary:HistorySummary}'
```

CloudWatch 告警的状态和 SNS 订阅是独立环节。核验时八条告警均为 `OK`；新别名的两条 SNS 邮件订阅均为 `PendingConfirmation`；旧别名的一条未确认订阅暂时残留。SNS action 成功表示已发布到 topic，不能据此断定两位收件人都收到邮件。
