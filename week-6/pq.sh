#!/usr/bin/env bash
url="${PROM_URL:-http://localhost:9090}"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 'promql expression'" >&2
  exit 2
fi

if ! response=$(curl -sS "$url/api/v1/query" --data-urlencode "query=$1"); then
  echo "Could not reach Prometheus" >&2
  exit 1
fi

printf '%s' "$response" | python3 -c '
import json, sys
r = json.load(sys.stdin)
if r.get("status") != "success":
    sys.exit("Prometheus said: " + str(r.get("error")))
data = r["data"]
if data["resultType"] != "vector":
    print(data["result"])
    sys.exit(0)
if not data["result"]:
    print("(no results)")
for s in data["result"]:
    labels = " ".join(k + "=" + v for k, v in s["metric"].items() if k != "__name__")
    print(labels or "(no labels)", "->", s["value"][1])
'
