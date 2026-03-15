# Настройка Caddy для Self-Steal Reality (Wildcard + Cloudflare DNS)

## Структура файлов

```
/opt/caddy/
├── docker-compose.yml
├── Dockerfile
├── Caddyfile
└── .env

/opt/html/
└── index.html          ← страница-заглушка (selfsteal)
```

---

## Создание директорий

```bash
mkdir -p /opt/caddy && cd /opt/caddy
mkdir -p /opt/html
```

---

## Страница-заглушка

```bash
printf '%s\n' '<!doctype html><meta charset="utf-8"><title>Moscow CDN</title><h1>It works.</h1>' \
  > /opt/html/index.html
```

---

## .env

```bash
cat > .env << 'EOF'
CF_API_TOKEN=твой_токен_cloudflare
SELF_STEAL_DOMAIN=moscow.cdn-video.world
SELF_STEAL_PORT=8443
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
    https_port {$SELF_STEAL_PORT}
    default_bind 127.0.0.1

    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }

    auto_https disable_redirects
}

http://{$SELF_STEAL_DOMAIN} {
    bind 0.0.0.0
    redir https://{$SELF_STEAL_DOMAIN}{uri} permanent
}

https://{$SELF_STEAL_DOMAIN} {
    tls {
        dns cloudflare {$CF_API_TOKEN}
    }

    root * /var/www/html
    try_files {path} /index.html
    file_server
}

:{$SELF_STEAL_PORT} {
    tls internal
    respond 204
}

:80 {
    bind 0.0.0.0
    respond 204
}
EOF
```

> **Важно:** `https_port 8443` и `default_bind 127.0.0.1` — это то, куда Xray будет
> направлять TLS-рукопожатие. Порт **должен совпадать** с `realitySettings.dest` в
> конфиге Xray.

---

## docker-compose.yml

```bash
cat > docker-compose.yml << 'EOF'
services:
  caddy:
    build: .
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - /opt/html:/var/www/html
      - caddy_data:/data
      - caddy_config:/config
    env_file:
      - .env

volumes:
  caddy_data:
  caddy_config:
EOF
```

> **Важно:** `network_mode: host` обязателен — без него Xray (работающий на хосте)
> не сможет подключиться к `127.0.0.1:8443` внутри контейнера.

---

## Запуск

```bash
# Сборка образа и запуск
docker compose up -d --build

# Логи в реальном времени
docker compose logs -f caddy
```

Caddy получит wildcard-сертификат через Cloudflare DNS и будет автоматически обновлять его.

---

## Проверка

```bash
# Убедиться что 8443 слушается локально (для Xray)
ss -tlnp | grep 8443
# Ожидаемый вывод: 127.0.0.1:8443

# Проверить что сайт отдаёт HTML
curl -sk https://moscow.cdn-video.world | head -5
```

---

## Настройка Xray (realitySettings)

Ключевые поля, которые должны совпадать с Caddyfile:

```json
"realitySettings": {
  "dest": "8443",
  "serverNames": [
    "moscow.cdn-video.world"
  ]
}
```

| Xray | Caddy |
|------|-------|
| `dest: "8443"` | `https_port 8443` |
| `serverNames[0]` | `{env.SUBDOMAIN}.{env.DOMAIN}` |

---

## Полезные команды

```bash
# Перезагрузить конфиг без перезапуска контейнера
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Проверить переменные окружения
docker exec caddy caddy environ | grep -E 'DOMAIN|PORT'

# Посмотреть сохранённые сертификаты
docker exec caddy ls /data/caddy/certificates/

# Остановить
docker compose down
```
