# Настройка Caddy для Self-Steal Reality

## Структура файлов

```
/opt/caddy/
├── docker-compose.yml
├── Dockerfile
├── Caddyfile
└── .env
```

---

## .env

```env
CF_API_TOKEN=твой_токен_cloudflare
DOMAIN=cdn-video.world
SUBDOMAIN=moscow
```

---

## Dockerfile

```dockerfile
FROM caddy:2-builder AS builder
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

---

## Caddyfile

```caddy
{
    email admin@{env.DOMAIN}
}

{env.SUBDOMAIN}.{env.DOMAIN} {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }

    respond "Not Found" 404
}
```

---

## docker-compose.yml

```yaml
services:
  caddy:
    build: .
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "127.0.0.1:8443:8443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    env_file:
      - .env

volumes:
  caddy_data:
  caddy_config:
```

---

## Запуск

```bash
cd /opt/caddy
docker compose up -d
docker compose logs -f caddy
```

Caddy сам получит сертификат через Cloudflare DNS и будет автоматически обновлять его.
