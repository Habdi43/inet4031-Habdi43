#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."

failed=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; failed=1; }

sql_value() {
  kubectl exec deploy/db -- sh -c \
    'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -tA -c "$1"' \
    sh "$1"
}

if command -v k6 >/dev/null; then
  pass 'k6 is installed'
else
  fail 'k6 is missing'
fi

preload=$(sql_value 'SHOW shared_preload_libraries')
extension=$(sql_value "SELECT count(*) FROM pg_extension WHERE extname = 'pg_stat_statements'")
if [[ "$preload" == *pg_stat_statements* && "$extension" == 1 ]]; then
  pass 'pg_stat_statements is loaded and created'
else
  fail 'pg_stat_statements setup is incomplete'
fi

index=$(sql_value "SELECT count(*) FROM pg_indexes WHERE indexname = 'idx_tickets_status_created'")
if [[ "$index" == 1 ]]; then
  pass 'the index idx_tickets_status_created exists'
else
  fail 'the ticket index is missing'
fi

ip=$(kubectl get service web -o jsonpath='{.spec.clusterIP}')
page=''
if [[ -n "$ip" ]]; then
  url="http://${ip}:8080/"
  if ! page=$(curl --noproxy '*' -fsS --connect-timeout 2 --max-time 5 "$url" 2>/dev/null); then
    node=$(kubectl get pods -l app=web -o jsonpath='{.items[0].spec.nodeName}')
    if pid=$(docker inspect -f '{{.State.Pid}}' "$node" 2>/dev/null) && [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
      page=$(sudo -n nsenter -t "$pid" -n -- curl --noproxy '*' -fsS --max-time 10 "$url") || page=''
    fi
  fi
fi
rows=$(printf '%s\n' "$page" | grep -o '<tr class="status-' | wc -l)
if [[ -n "$page" && "$rows" -le 50 ]]; then
  pass "the live page shows $rows tickets (at most 50)"
else
  fail "the live page did not answer or shows more than 50 tickets"
fi

cpu=$(kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}')
if [[ "$cpu" == 500m ]] && grep -Eq 'cpu[[:space:]]*=[[:space:]]*"500m"' week-5/web.tf; then
  pass 'web CPU limit is 500m in the cluster and in week-5/web.tf'
else
  fail "web CPU limit check failed (live: $cpu)"
fi

image=$(kubectl get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}')
if [[ "$image" == *week-4-web:v2 ]] && grep -q 'week-4-web:v2' week-5/web.tf; then
  pass 'web runs the v2 image in the cluster and in week-5/web.tf'
else
  fail "web image check failed (live: $image)"
fi

(cd week-5 && tofu plan -input=false -lock=false -detailed-exitcode >/dev/null)
case "$?" in
  0) pass 'tofu plan finds no drift' ;;
  2) fail 'tofu plan shows drift' ;;
  *) fail 'tofu plan could not run' ;;
esac

if [[ -f .github/workflows/load-test.yml ]] && grep -Fq 'p(95)<500' week-10/smoke-test.js; then
  pass 'the load-test workflow and p95 threshold are present'
else
  fail 'the load-test workflow or p95 threshold is missing'
fi

p95=$(./week-10/k6-stat.sh restored p95 2>/dev/null)
if [[ "$p95" =~ ^[0-9]+$ && "$p95" -lt 500 ]]; then
  pass "the saved restored ramped test had a p95 of $p95 ms"
else
  fail "the saved restored p95 is missing or at least 500 ms"
fi

if [[ "$failed" == 0 ]]; then
  echo 'All checks passed.'
else
  echo 'Some checks failed.'
  exit 1
fi
