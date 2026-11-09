#!/usr/bin/env bash
set -eu
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

file="${1:-}"
if [ -z "$file" ]; then
  file="$(ls -1t "$HOME"/backups/db-*.dump 2>/dev/null | head -n 1)"
fi
if [ ! -s "$file" ]; then
  echo "No backup file found." >&2
  exit 1
fi

echo "Restoring from $file"
kubectl exec -i deploy/db -- sh -c \
  'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner --exit-on-error' < "$file"
echo "Restore finished. Rows now:"
"$(dirname "$0")/sql.sh"
