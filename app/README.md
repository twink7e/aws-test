# Demo application

This is a Laravel 13 application running on PHP 8.4 FPM. It serves a static environment message and a live `homepage_message` read from the local AWS AppConfig Agent on each request. Blade escapes both values before rendering. `/healthz` is independent of the database and AppConfig agent.

The PHP image installs Composer dependencies from `composer.lock` in a build stage, then copies the PHP source and `vendor/` into the runtime image. The application source has no JavaScript bundle or binary compilation step; it is neither injected nor obfuscated. PHP extensions are built into the image, and OPcache caches PHP bytecode at runtime. The Nginx image contains only `public/` and forwards PHP requests to FPM on `127.0.0.1:9000` in the shared ECS task network. Both processes run as nonroot users and listen on unprivileged ports.

The ECS task defaults to 256 CPU units and 512 MiB, Fargate's smallest Linux
size. PHP-FPM allows at most two workers so this short-lived demonstration fits
the memory budget. CPU and memory metrics should guide any later increase.

Nginx writes JSON HTTP access logs to stdout, including `X-Amzn-Trace-Id`. Laravel writes JSON request and application logs to stderr; PHP-FPM and PHP errors also go to stderr. ECS `awslogs` collects these streams. `ENABLE_DEMO_FAILURE_ROUTES=true` enables `/__test/error` and `/__test/500` for controlled alarm tests; it is false by default.

Build locally on ARM64:

```sh
docker build --platform linux/arm64 -t poper-app:local app
docker build --platform linux/arm64 -f app/docker/nginx.Dockerfile -t poper-web:local app
docker build --platform linux/arm64 -t poper-backup:local backup
bash app/docker/smoke.sh
```
