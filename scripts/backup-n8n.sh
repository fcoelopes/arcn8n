#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export TZ=America/Fortaleza

APP_DIR="/home/fcoedls/services/n8n"
BACKUP_DIR="/home/fcoedls/backups/n8n"
RESTIC_ENV="/home/fcoedls/.config/restic/n8n.env"
VOLUME="n8n_n8n_data"

set -a
# shellcheck disable=SC1090
source "$RESTIC_ENV"
set +a

mkdir -p "$BACKUP_DIR"
exec 9>"$BACKUP_DIR/.backup.lock"
flock -n 9 || { echo "Backup já em execução" >&2; exit 1; }

STAGING="$BACKUP_DIR/staging-current"
if [[ -L "$STAGING" ]]; then
  echo "Staging é link simbólico; abortando" >&2
  exit 1
fi
# O staging é dedicado a este script e protegido pelo flock.
if [[ -e "$STAGING" ]]; then rm -rf -- "$STAGING"; fi
mkdir -m 700 -- "$STAGING"
trap 'rm -rf -- "$STAGING"' EXIT

cd "$APP_DIR"
echo "[$(date -Is)] Iniciando backup"

docker compose exec -T postgres \
  sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "$STAGING/postgres.dump"
test -s "$STAGING/postgres.dump"
docker compose exec -T postgres pg_restore --list \
  < "$STAGING/postgres.dump" > /dev/null

cp .env "$STAGING/env.backup"
cp compose.yaml "$STAGING/compose.yaml"
test -s "$STAGING/env.backup"
test -s "$STAGING/compose.yaml"

docker run --rm \
  --mount "type=volume,source=${VOLUME},target=/data,readonly" \
  busybox:1.36 \
  tar -czf - -C /data . > "$STAGING/n8n_data.tar.gz"
test -s "$STAGING/n8n_data.tar.gz"
tar -tzf "$STAGING/n8n_data.tar.gz" > /dev/null

restic backup "$STAGING" --tag n8n --tag automatico
echo "[$(date -Is)] Backup remoto concluído"
