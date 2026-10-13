#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
set -a
# shellcheck disable=SC1091
source /home/fcoedls/.config/restic/n8n.env
set +a

# APENAS SIMULAÇÃO: não retirar --dry-run nem adicionar --prune
# antes de testar restauração funcional completa e rever a retenção.
restic forget \
  --tag automatico \
  --group-by host,tags \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 3 \
  --dry-run

echo "Retenção simulada; nenhum snapshot foi excluído."
