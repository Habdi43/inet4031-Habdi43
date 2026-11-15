#!/usr/bin/env bash
set -eu

python3 - "$HOME/.k6-${1:?Enter a run label}.json" "${2:?Enter p50, p95, or rps}" <<'PY'
import json
import sys

with open(sys.argv[1]) as result:
    metrics = json.load(result)["metrics"]

values = {
    "p50": f"{metrics['http_req_duration']['med']:.0f}",
    "p95": f"{metrics['http_req_duration']['p(95)']:.0f}",
    "rps": f"{metrics['http_reqs']['rate']:.1f}",
}
if sys.argv[2] not in values:
    sys.exit("Pick one of: p50, p95, rps")
print(values[sys.argv[2]])
PY
