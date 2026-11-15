#!/usr/bin/env bash
set -eu

label="${1:?Enter a run label}"
here="$(cd "$(dirname "$0")" && pwd)"
query='sum(rate(container_cpu_cfs_throttled_periods_total{container="web"}[3m])) / sum(rate(container_cpu_cfs_periods_total{container="web"}[3m]))'
answer="$("$here/../week-6/pq.sh" "$query")"
value="$(printf '%s\n' "$answer" | awk '/->/ {print $NF; exit}')"
if [ -z "$value" ]; then
  echo "Prometheus has no CPU-period data yet. Wait a minute and retry." >&2
  exit 1
fi
percent="$(python3 -c 'import math, sys; v = float(sys.argv[1]); print(0 if math.isnan(v) else round(v * 100))' "$value")"
echo "$percent" > "$HOME/.throttle-$label"
echo "$label: the web container was held back by its CPU limit in $percent% of its CPU periods"
