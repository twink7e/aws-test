# 访问日志 Trace ID 关联验收

2026-11-16 07:51:33 UTC，向东京区域 ALB 的 `/healthz` 发出一次带以下自定义请求头的 GET；响应为 HTTP 200、`{"status":"ok"}`。

```text
X-Amzn-Trace-Id: Root=1-6afab604-654b384beb0bd5190bc87780
```

随后用 CloudWatch Logs `filter-log-events` 查询到同一请求：

| 日志组 | 已观察字段 |
| --- | --- |
| `/poper-test/web` | Nginx JSON：`path=/healthz`、`status=200`、`X-Amzn-Trace-Id=Self=1-6afab605-6ef3768f04cefc12704a2ac7;Root=1-6afab604-654b384beb0bd5190bc87780`。 |
| `/poper-test/app` | Laravel JSON：`message=http_request`、`context.path=healthz`、`context.status=200`、`context.trace_id=Self=1-6afab605-6ef3768f04cefc12704a2ac7;Root=1-6afab604-654b384beb0bd5190bc87780`。 |
| `/aws/vendedlogs/elasticloadbalancing/poper-test/access` | ALB JSON：`request_line` 为同一 `/healthz` 请求、`elb_status_code=200`、`target_status_code=200`、`trace_id=Self=1-6afab605-6ef3768f04cefc12704a2ac7;Root=1-6afab604-654b384beb0bd5190bc87780`。 |

ALB 在转发时给头部加了 `Self` 段，原始 `Root` 段在 ALB、Nginx 和 Laravel 三处日志中相同。此证据验证请求经过负载均衡器与两个容器的日志关联；ALB 访问日志由独立的 CloudWatch vended log delivery 收集，投递比容器日志略晚。
