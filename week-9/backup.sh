#!/usr/bin/env bash
set -eu
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
umask 077

log() { echo "$(date '+%F %T') $*"; }
trap 'log "FAILED: backup did not finish"' ERR

exec 9>"$HOME/.backup.lock"
if ! flock -n 9; then
  log "Another backup is running, skipping"
  exit 0
fi

if ! kubectl wait --for=condition=Ready pod -l app=db --timeout=30s >/dev/null; then
  log "WAITING: database pod is not ready"
  exit 0
fi

BACKUPS="$HOME/backups"
mkdir -p "$BACKUPS"
FILE="$BACKUPS/db-$(date +%Y%m%d-%H%M%S).dump"
PARTIAL="$FILE.partial"
trap 'rm -f "$PARTIAL"' EXIT

kubectl exec deploy/db -- sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom' > "$PARTIAL"
listing="$(kubectl exec -i deploy/db -- pg_restore --list < "$PARTIAL")"

if ! grep -q ' TABLE DATA ' <<< "$listing"; then
  log "SKIPPED: the database has no tables, so the existing backups are kept as they are"
  exit 1
fi

mv "$PARTIAL" "$FILE"
ls -1t "$BACKUPS"/db-*.dump | tail -n +13 | xargs -r -d '\n' rm --
log "backed up ${FILE##*/}, keeping the newest 12"
