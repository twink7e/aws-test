# AppConfig 受控回滚验收

2026-11-16 在 AWS 东京区域对 Terraform 创建的 AppConfig 应用 `poper-test`、环境 `interview`、配置 `runtime` 做受控演练。以下时间均为 UTC。演练使用一次性非敏感托管配置版本与专用测试日志流；现有监控告警、渐进发布策略、EventBridge 规则及 SNS topic 均由 Terraform 管理。

| 时间 | 可核对的结果 |
| --- | --- |
| 07:29:06 | 使用现有 5 分钟发布、5 分钟烘焙的渐进策略 `iq59bya`，启动配置版本 4 的部署 `#4`；测试消息为 `Rollback drill: temporary message`。 |
| 07:29 | 向 `/poper-test/app` 的 `rollback-drill-2026-11-16` 日志流写入一条 `level_name=ERROR` 的受控 JSON 事件；现有 metric filter 生成 `poper-test/Application` / `ApplicationErrors` 指标值 1。 |
| 07:30:06 | CloudWatch 告警 `poper-test-application-error` 从 `OK` 进入 `ALARM`。 |
| 07:30:07 | AppConfig 部署 `#4` 返回 `ROLLED_BACK`；事件 `ROLLBACK_COMPLETED` 的 `TriggeredBy` 为 `CLOUDWATCH_ALARM`，描述指向上述告警。AppConfig 扩展记录了 `NotifyOnDeploymentRolledBack` 调用。 |
| 07:36:06 | 应用错误告警由 `ALARM` 自然恢复 `OK`；没有使用 `SetAlarmState` 手动覆盖状态。 |
| 07:36:38 | 用同一渐进策略启动稳定托管配置版本 3 的恢复部署 `#5`。 |
| 07:46:42 | 恢复部署 `#5` 进入 `COMPLETE`，AppConfig 记录 `NotifyOnDeploymentComplete` 调用；环境状态回到 `ReadyForDeployment`。 |

回滚后再次请求 ALB 首页，仍显示此前的 `Hello from AppConfig`，临时消息未继续生效。EventBridge 规则 `poper-test-appconfig-rollback` 在 07:30 的 `MatchedEvents` 和 `Invocations` 均为 1，目标为 `poper-test-alerts` SNS topic；同一分钟 topic 的 `NumberOfMessagesPublished` 为 2，与告警及回滚事件各发布一条相符。由指标归因可推断回滚事件经过 EventBridge 到达 SNS，但这些指标和 AppConfig 事件**不能证明邮件送达**；两条 `shuo.xiao` 邮件订阅仍待收件人确认。

恢复后 ALB 首页再次实测同时包含 `Hello from POPER test` 和 `Hello from AppConfig`，不包含临时回滚演练文案。EventBridge 规则 `poper-test-appconfig-complete` 在 07:46 UTC 记录 `MatchedEvents=1`、`Invocations=1`；SNS topic 当分钟 `NumberOfMessagesPublished=1`，与完成事件发布相符。邮件订阅未确认，仍不能证明邮件送达。

回滚后及恢复发布完成后，`foundation` 的 `terraform plan -detailed-exitcode` 均返回 0、无差异。这只表示 Terraform 管理的资源没有配置漂移；一次性版本 4 和部署 `#4` 是诊断记录，未纳入 Terraform state。

可在有权限的东京区域 AWS CLI 会话中复核关键状态：

```bash
aws appconfig get-deployment --application-id xgr2pgr --environment-id bd7zdpb --deployment-number 4 \
  --query '{State:State,EventLog:EventLog[0]}'
aws appconfig get-deployment --application-id xgr2pgr --environment-id bd7zdpb --deployment-number 5 \
  --query '{State:State,EventLog:EventLog[0]}'
aws appconfig get-environment --application-id xgr2pgr --environment-id bd7zdpb \
  --query '{State:State}'
```
