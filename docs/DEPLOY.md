# Implantação em VPS

## Pré-requisitos
- Docker Engine e Compose plugin.
- Traefik pré-existente conectado à rede externa Docker `proxy`.
- Traefik com entrypoint `websecure` e certresolver `letsencrypt` (nomes do ambiente original).
- Registro DNS `n8n.arc.tec.br` direcionado corretamente à VPS. Se houver proxy Cloudflare, configurar HTTPS de origem válido e modo Full (strict).
- Não criar outro Traefik, socket-proxy ou container de PostgreSQL compartilhado do Arcoilstate.

## Preparar
```bash
mkdir -p ~/services/n8n
cd ~/services/n8n
# Clone este repositório em outro diretório e copie os arquivos necessários,
# ou faça o clone diretamente aqui em uma VPS nova.
cp .env.example .env
chmod 600 .env
# Edite .env e defina segredos novos e fortes:
# openssl rand -hex 32
docker network inspect proxy >/dev/null
docker compose config --quiet
docker compose up -d
docker compose ps
```

**Atenção em uma VPS já existente:** não substitua o `.env` de produção, nem recrie volumes nem rode `down -v`. Guarde a chave `N8N_ENCRYPTION_KEY` original; sem ela as credenciais antigas não poderão ser descriptografadas. Ao migrar, restaure os dados e o banco em vez de inicializar uma instalação vazia.

## Acesso
- `https://n8n.arc.tec.br`
- Criação da conta de administrador apenas na primeira inicialização.
- Licença self-hosted e demais segredos devem ser provisionados fora do Git.

## Verificações
```bash
docker compose ps
docker compose exec -T postgres pg_isready -U n8n -d n8n
docker volume ls --filter name=n8n
docker inspect n8n-n8n-1 --format '{{.HostConfig.RestartPolicy.Name}}'
```

## Segurança
- Porta `5678` apenas na rede Docker, sem `ports:` público.
- Interface protegida pelo login nativo; avaliar Cloudflare Access/MFA sem bloquear webhooks necessários.
- Token S3 restrito ao bucket `arc-n8n-backups`; armazenar em arquivo fora do repositório.
- Atualizar imagens por mudança controlada no Compose, com snapshot testado e plano de rollback.
- O `compose.yaml` neste repositório reproduz a configuração discutida. Confira o diff com o arquivo realmente implantado na VPS antes de sincronizar com produção.
