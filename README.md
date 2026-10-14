# ARC n8n — infraestrutura self-hosted

Infraestrutura reproduzível do **n8n** em VPS, usando Docker Compose, PostgreSQL, Traefik e backups criptografados com Restic no Cloudflare R2.

> **Estado documentado:** instalação operacional validada em 13–14/10/2026. Este repositório **não contém segredos nem backups reais**. Reproduz o ambiente descrito e testado, mas não substitui uma cópia dos volumes de produção.

## Componentes

- n8n `2.43.4` (versão proposta no template; confirmar versão instalada na VPS) — interface web em `https://n8n.arc.tec.br`.
- PostgreSQL `16-alpine` — banco dedicado ao n8n, isolado da rede pública.
- Traefik existente — rede externa Docker `proxy`, entrypoint `websecure`, resolver `letsencrypt`.
- Restic + Cloudflare R2 — dumps PostgreSQL e arquivos persistentes criptografados.
- `systemd` — backup diário às 03h e simulação de retenção domingo às 04h, em `America/Fortaleza`.

## Estrutura

```text
compose.yaml
.env.example
.gitignore
scripts/
  backup-n8n.sh
  retention-n8n.sh
systemd/
  n8n-backup.service
  n8n-backup.timer
  n8n-retention.service
  n8n-retention.timer
config/
  restic-n8n.env.example
docs/
  DEPLOY.md
  BACKUP-RESTORE.md
  OPERATIONS.md
```

## Implantação e recuperação

1. Leia [DEPLOY.md](docs/DEPLOY.md) antes de implantar em outra VPS.
2. Preencha um `.env` local usando `.env.example`; **nunca comite o arquivo real**.
3. Garanta Traefik ativo na rede externa `proxy` e DNS apontando para a VPS.
4. Rode `docker compose config --quiet && docker compose up -d`.
5. Configure o Restic conforme [BACKUP-RESTORE.md](docs/BACKUP-RESTORE.md), preservando a senha fora da VPS.
6. Instale os timers após revisar os caminhos e o fuso em [OPERATIONS.md](docs/OPERATIONS.md).

## Evidências registradas da implantação

- `n8n-n8n-1` ativo, com restart `unless-stopped`; `n8n-postgres-1` saudável.
- Volumes persistentes `n8n_n8n_data` e `n8n_postgres_data`.
- Restic: verificação `check --read-data` sem erros, download de 9 arquivos/diretórios.
- `pg_restore --exit-on-error` executado em PostgreSQL temporário isolado: 142 tabelas, zero workflows (instalação nova).
- Serviço diário concluiu com `status=0/SUCCESS`; snapshot `42453356`, seguido de `39a65456`.
- A rotina de retenção **continua somente em dry-run**. Não habilitar exclusões sem revisar a política e testar restauração funcional completa.

## Segurança

- Não adicionar `.env`, `*.password`, chaves, tokens, certificados, dumps, volumes, backups ou credenciais a este repositório.
- O endpoint web usa HTTPS; recomenda-se proteção adicional da interface administrativa (ex.: Cloudflare Access) preservando webhooks externos.
- Backup remoto não é imutável por si só: planejar proteção contra exclusão, alertas e teste periódico de restauração.
- Não rodar `docker compose down -v` em produção.

## Próximos passos

- Monitoramento e alertas de falha dos backups.
- Revisão da retenção antes de remover `--dry-run` e habilitar `prune`.
- Teste do n8n completo com banco restaurado.
- Primeiro workflow de captura de notas de corretagem do Gmail para Cloudflare R2.
