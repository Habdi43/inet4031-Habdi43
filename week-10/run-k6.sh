#!/usr/bin/env bash
set -eu

test_file="${1:?Usage: run-k6.sh TEST_FILE LABEL}"
label="${2:?Usage: run-k6.sh TEST_FILE LABEL}"
out="$HOME/.k6-$label.json"
ip="$(kubectl get service web -o jsonpath='{.spec.clusterIP}')"
export BASE_URL="http://${ip}:8080"

status=0
k6 run --quiet --no-color --summary-export="$out" "$test_file" || status=$?

python3 - "$out" "$label" <<'PY'
import json
import sys

with open(sys.argv[1]) as result:
    metrics = json.load(result)["metrics"]

duration = metrics["http_req_duration"]
requests = metrics["http_reqs"]
failed = metrics["http_req_failed"]["value"] * 100
kb = metrics["data_received"]["count"] / max(requests["count"], 1) / 1024
print(f"{sys.argv[2]}: p50 {duration['med']:.0f} ms | p95 {duration['p(95)']:.0f} ms | "
      f"{requests['rate']:.1f} requests/s | {failed:.1f}% failed | {kb:.0f} KB per response")
PY

if [ "$status" -eq 0 ]; then
  echo "Thresholds: all passed."
else
  echo "Thresholds: at least one FAILED (k6 exit code $status)."
fi
exit "$status"
