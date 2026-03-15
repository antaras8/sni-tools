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

## Создание директории

```bash
mkdir -p /opt/caddy && cd /opt/caddy
```

---

## .env

```bash
cat > .env << 'EOF'
CF_API_TOKEN=твой_токен_cloudflare
DOMAIN=cdn-video.world
SUBDOMAIN=moscow
EOF
```

---

## Dockerfile

```bash
cat > Dockerfile << 'EOF'
FROM caddy:2-builder AS builder
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
EOF
```

---

## Caddyfile

```bash
cat > Caddyfile << 'EOF'
{
    email admin@{env.DOMAIN}
}

{env.SUBDOMAIN}.{env.DOMAIN} {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
    }

    respond "Not Found" 404
}
EOF
```

---

## docker-compose.yml

```bash
cat > docker-compose.yml << 'EOF'
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
EOF
```

---

## Запуск

```bash
# Сборка образа и запуск
docker compose up -d --build

# Логи в реальном времени
docker compose logs -f caddy
```

Caddy сам получит сертификат через Cloudflare DNS и будет автоматически обновлять его.

---

## Полезные команды

```bash
# Перезагрузить конфиг без перезапуска контейнера
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Проверить статус сертификата
docker exec caddy caddy environ | grep DOMAIN

# Остановить
docker compose down

# Посмотреть сохранённые сертификаты
docker exec caddy ls /data/caddy/certificates/
```
