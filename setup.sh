#!/bin/bash

set -e

if [[ -z "$1" || ! "$1" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    echo "❌ Укажите домен как аргумент. Пример: bash setup.sh node1.example.com"
    exit 1
fi

DOMAIN="$1"

# === Установка нужного ПО ===
sudo apt update
sudo apt install -y nginx git curl certbot python3-certbot-nginx

# === Клонируем твой форк, если ещё не ===
TEMPLATE_DIR="/opt/sni-templates"
if [ ! -d "$TEMPLATE_DIR" ]; then
  sudo git clone https://github.com/antaras8/sni-templates.git "$TEMPLATE_DIR"
fi

# === Случайный шаблон ===
TEMPLATE=$(find "$TEMPLATE_DIR" -mindepth 1 -maxdepth 1 -type d | shuf -n 1)
echo "Выбран шаблон: $TEMPLATE"

# === Установка шаблона в /var/www/html/$DOMAIN ===
TARGET="/var/www/html/$DOMAIN"
sudo mkdir -p "$TARGET"
sudo cp -r "$TEMPLATE/"* "$TARGET/"

# === Конфиг nginx ===
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $TARGET;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# === Выпуск сертификата ===
sudo certbot --nginx --non-interactive --agree-tos -m admin@$DOMAIN -d $DOMAIN

# === Перезапуск на всякий случай ===
sudo systemctl reload nginx

echo "✅ Установлен HTTPS-сайт на https://$DOMAIN"
