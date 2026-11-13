#!/usr/bin/env bash
set -Eeuo pipefail

app_image="${1:-poper-app:local}"
web_image="${2:-poper-web:local}"
backup_image="${3:-poper-backup:local}"
name="poper-smoke-$$"
app_name="${name}-app"
web_name="${name}-web"
config_name="${name}-config"
cleanup() {
    docker rm -f "$web_name" "$config_name" "$app_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm --platform linux/arm64 --entrypoint php "$app_image" -l routes/web.php
docker run --rm --platform linux/arm64 --entrypoint nginx "$web_image" -t
docker run --rm --platform linux/arm64 --entrypoint pg_dump "$backup_image" --version | grep -q '17\.'
docker run --rm --platform linux/arm64 --entrypoint python3 "$backup_image" -c 'import boto3'

docker run -d --platform linux/arm64 --memory 384m --name "$app_name" -p 127.0.0.1::8080 \
    -e 'APP_KEY=base64:MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=' \
    -e 'DEMO_MESSAGE=<script>unsafe</script>' \
    -e 'APPCONFIG_URL=http://127.0.0.1:2772/applications/demo/environments/demo/configurations/homepage' \
    "$app_image" >/dev/null
docker run -d --platform linux/arm64 --memory 96m --name "$config_name" --network "container:$app_name" \
    --entrypoint php "$app_image" -r \
    '$body=json_encode(["homepage_message"=>"Live AppConfig value"]); $server=stream_socket_server("tcp://127.0.0.1:2772"); while ($client=stream_socket_accept($server)) { fread($client,4096); fwrite($client,"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ".strlen($body)."\r\nConnection: close\r\n\r\n".$body); fclose($client); }' >/dev/null
docker run -d --platform linux/arm64 --memory 32m --name "$web_name" --network "container:$app_name" \
    "$web_image" >/dev/null
address="$(docker port "$app_name" 8080/tcp)"
base_url="http://$address"

for attempt in {1..30}; do
    if curl --silent --fail "$base_url/healthz" | grep -q '"status":"ok"'; then
        break
    fi
    sleep 1
done

curl --silent --fail "$base_url/healthz" | grep -q '"status":"ok"'
curl --silent --fail "$base_url/" | grep -q '&lt;script&gt;unsafe&lt;/script&gt;'
for attempt in {1..10}; do
    if curl --silent --fail "$base_url/" | grep -q 'Live AppConfig value'; then
        break
    fi
    sleep 1
done
curl --silent --fail "$base_url/" | grep -q 'Live AppConfig value'
test "$(curl --silent --output /dev/null --write-out '%{http_code}' "$base_url/__test/500")" = '404'
curl --silent --fail -H 'X-Amzn-Trace-Id: Root=1-smoke' "$base_url/healthz" >/dev/null
docker logs "$web_name" 2>&1 | grep -q '"X-Amzn-Trace-Id":"Root=1-smoke"'
docker logs "$app_name" 2>&1 | grep -q '"trace_id":"Root=1-smoke"'
echo 'ARM64 image and HTTP smoke checks passed.'
