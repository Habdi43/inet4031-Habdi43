#!/usr/bin/env bash
set -eu

psql_in_pod() {
  kubectl exec -i deploy/db -- sh -c \
    'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 "$@"' sh "$@"
}

if [ "$#" -eq 1 ]; then
  printf '%s\n' "$1" | psql_in_pod
  exit 0
fi

counts="$(psql_in_pod -tA <<'SQL'
SELECT format('SELECT %L || '': '' || count(*) FROM %I.%I',
              relname, schemaname, relname)
FROM pg_stat_user_tables ORDER BY relname \gexec
SQL
)"
echo "${counts:-(no tables)}"
