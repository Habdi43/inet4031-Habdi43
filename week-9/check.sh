#!/usr/bin/env bash
set -u
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

failed=0
ok() { echo "PASS  $*"; }
bad() { echo "FAIL  $*"; failed=1; }

if kubectl exec deploy/db -- sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
  ok "Postgres is accepting connections"
else
  bad "Postgres is not accepting connections"
fi

if metrics="$(kubectl exec deploy/web -- python -c 'import urllib.request; print(urllib.request.urlopen("http://db-exporter:9187/metrics", timeout=5).read().decode())')" &&
   grep -Eq '^pg_up 1([[:space:]]|$)' <<< "$metrics"; then
  ok "Exporter can reach Postgres (pg_up is 1)"
else
  bad "Exporter check failed"
fi

newest="$(ls -1t "$HOME"/backups/db-*.dump 2>/dev/null | head -n 1)"
if [ -n "$newest" ] && modified="$(stat -c %Y "$newest")"; then
  age=$(( $(date +%s) - modified ))
  if [ "$age" -le 900 ]; then
    ok "Newest backup is $age seconds old"
  else
    bad "Newest backup is over 15 minutes old ($age seconds)"
  fi

  if listing="$(kubectl exec -i deploy/db -- pg_restore --list < "$newest")" &&
     grep -q ' TABLE DATA ' <<< "$listing"; then
    ok "Newest backup is readable and contains table data"
  else
    bad "Newest backup is unreadable or has no table data"
  fi
else
  bad "No backup file found"
fi

if crontab -l 2>/dev/null | grep -Fq 'week-9/backup.sh'; then
  ok "Cron has a backup job"
else
  bad "Cron backup job is missing"
fi

if [ "$failed" -eq 0 ]; then
  echo "All checks passed."
else
  exit 1
fi
