# Backup e recuperação

## Arquitetura
`pg_dump -Fc` do PostgreSQL dedicado + arquivo `.env`, Compose e `n8n_n8n_data`; envio via Restic com criptografia ao bucket Cloudflare R2 `arc-n8n-backups`. O repositório Restic inicial foi criado e os dados testados em outubro de 2026.

## Configuração do Restic (fora do Git)
1. Instale `restic` e garanta Docker + `flock`.
2. Crie `~/.config/restic/n8n.env` usando `config/restic-n8n.env.example` como modelo.
3. Gere senha de repositório com `openssl rand -hex 32 > ~/.config/restic/n8n.password`.
4. `chmod 700 ~/.config/restic; chmod 600 ~/.config/restic/n8n.env ~/.config/restic/n8n.password`.
5. Guarde a senha do Restic **fora da VPS**; perder a senha inviabiliza a recuperação.
6. Em instalação NOVA apenas, inicialize com `restic init`. Em repositório existente, **não reinicializar**.

## Executar
```bash
bash ~/scripts/backup-n8n.sh
set -a; source ~/.config/restic/n8n.env; set +a
restic snapshots
restic check
restic check --read-data
```

## Restaurar arquivos de forma não destrutiva
```bash
mkdir -p ~/restore-test/n8n
restic restore latest --target ~/restore-test/n8n
find ~/restore-test/n8n -type f
```
O Restic restaura a hierarquia absoluta dentro do diretório de destino. Não restaurar diretamente sobre `~/services/n8n` em operação.

## Validar dump em banco isolado
Consulte o caminho real do arquivo `postgres.dump` recuperado. Exemplo (ajuste `DUMP`):
```bash
DUMP="/caminho/restaurado/postgres.dump"
docker run -d --name n8n-postgres-restore-test --network none \
  -e POSTGRES_USER=n8n -e POSTGRES_PASSWORD=restore-test-only \
  -e POSTGRES_DB=n8n --tmpfs /var/lib/postgresql/data:rw,size=256m \
  postgres:16-alpine
until docker exec n8n-postgres-restore-test pg_isready -U n8n -d n8n >/dev/null 2>&1; do sleep 1; done
docker exec -i n8n-postgres-restore-test \
  pg_restore -U n8n -d n8n --exit-on-error --no-owner --no-acl < "$DUMP"
docker exec n8n-postgres-restore-test \
  psql -U n8n -d n8n -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';"
docker rm -f n8n-postgres-restore-test
```

## Resultados do teste original
- `restic check --read-data`: 2/2 packs, sem erro.
- `restic restore`: 9 arquivos/diretórios, ~483 KiB.
- `pg_restore --exit-on-error` executado sem erro em container temporário isolado.
- 142 tabelas retornadas e zero workflows (instalação recém-criada).
- **Limitação:** ainda não foi testada a inicialização de uma instância completa do n8n com as credenciais restauradas.

## Retenção
A rotina semanal usa **`--dry-run`**, de propósito. A política desejada é 7 diários, 4 semanais e 3 mensais, aplicada aos snapshots com a tag `automatico`. O snapshot `inicial` não é selecionado pelo comando mostrado. O bucket/tokens ainda precisam de proteção contra exclusão maliciosa. Não adicionar `--prune` nem remover `--dry-run` sem revisão explícita.

## Limitações operacionais
- A cópia do volume é feita com o n8n ativo e não é atomicamente consistente; uma recuperação funcional completa é pendente.
- Um dump validado não garante restauração de todas as credenciais sem a mesma chave `N8N_ENCRYPTION_KEY`.
- Antes de automatizar exclusões, adicionar monitoramento, testes de restauração e controle de proteção contra apagamento no R2.
