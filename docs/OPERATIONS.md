# Operação e manutenção

## Caminhos do ambiente original
- Compose: `/home/fcoedls/services/n8n/compose.yaml`
- Configuração e secrets: `/home/fcoedls/services/n8n/.env`
- Scripts: `/home/fcoedls/scripts/`
- Restic: `/home/fcoedls/.config/restic/n8n.env` + senha fora do Git
- Backup local / staging: `/home/fcoedls/backups/n8n/`
- Rede Traefik: `proxy`

## Instalar scripts e unidades em ambiente novo
```bash
mkdir -p ~/scripts ~/backups/n8n
install -m 700 scripts/backup-n8n.sh ~/scripts/backup-n8n.sh
install -m 700 scripts/retention-n8n.sh ~/scripts/retention-n8n.sh
sudo install -m 644 systemd/n8n-backup.service /etc/systemd/system/
sudo install -m 644 systemd/n8n-backup.timer /etc/systemd/system/
sudo install -m 644 systemd/n8n-retention.service /etc/systemd/system/
sudo install -m 644 systemd/n8n-retention.timer /etc/systemd/system/
sudo systemd-analyze verify /etc/systemd/system/n8n-{backup,retention}.{service,timer}
sudo systemctl daemon-reload
sudo systemctl enable --now n8n-backup.timer n8n-retention.timer
```
**Atenção:** antes de executar, revise o usuário `fcoedls`, os caminhos absolutos e as permissões Docker.

## Agendamentos
- Backup: `03:00 America/Fortaleza` todos os dias.
- Retenção: `04:00 America/Fortaleza` aos domingos (**simulação**).
- No ambiente original a VPS opera em `Europe/Berlin`; o timer traduz os horários automaticamente, respeitando mudanças de horário de verão locais.

## Inspeção
```bash
systemctl list-timers --all n8n-backup.timer n8n-retention.timer
sudo systemctl status n8n-backup.service --no-pager
sudo systemctl status n8n-retention.service --no-pager
sudo journalctl -u n8n-backup.service -n 50 --no-pager
sudo journalctl -u n8n-retention.service -n 50 --no-pager
docker compose ps
```

## Execução manual
```bash
sudo systemctl start n8n-backup.service
sudo systemctl start n8n-retention.service
```
Serviços oneshot aparecem como `inactive (dead)` depois de concluídos normalmente; verificar `status=0/SUCCESS`.

## Atualizações controladas

O arquivo `.github/dependabot.yml` usa o Dependabot nativo do GitHub para verificar atualizações do Docker Compose semanalmente às segundas, 08h (America/Fortaleza). Ele propõe Pull Requests, com limite de três PRs abertos, sem automerge nem deploy automático. Atualizações semver-major do `n8nio/n8n` ficam ignoradas para exigir análise manual. Revisar changelog e realizar backup antes de aprovar uma atualização. Dependabot deve estar habilitado nas configurações do repositório para gerar PRs.

Antes de atualizar a VPS:

```bash
cd ~/services/n8n
sudo systemctl start n8n-backup.service
sudo systemctl status n8n-backup.service --no-pager
```

Confirme `status=0/SUCCESS` e o snapshot remoto, então altere apenas a versão do n8n no Compose de produção (não copie cegamente o modelo do GitHub sobre o arquivo local com alterações), valide e recrie o serviço:

```bash
docker compose config --quiet
docker compose pull n8n
docker compose up -d --no-deps n8n
docker compose ps
docker compose logs --tail=50 n8n
```

Migrações de banco podem impedir rollback apenas trocando a imagem; uma recuperação completa pode exigir restaurar banco e configurações do snapshot pré-atualização. Confira as breaking changes da versão antes de implantar. Recomendado validar editor, credenciais e execuções após atualizar.

## Pendências
- Confirmar proteção adicional do editor do n8n sem impedir webhooks.
- Testar inicialização completa do n8n a partir de backup.
- Implementar alerta de falhas no systemd/Restic.
- Avaliar retenção protegida e isolamento de privilégios no R2.
- Revisar e ativar retenção destrutiva somente após aprovação e teste.
- Workflow Gmail → PDFs de corretagem → Cloudflare R2 ainda não implementado.
