#!/bin/bash
set -e

# === Проверка аргумента ===
if [[ -z "$1" || ! "$1" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    echo "❌ Укажите домен как аргумент. Пример: bash setup.sh node1.example.com"
    exit 1
fi

DOMAIN="$1"

# === Установка зависимостей ===
sudo apt update
sudo apt install -y nginx git curl

# === Удаление старого certbot ===
if [ -f "/usr/bin/certbot" ] || [ -f "/usr/local/bin/certbot" ]; then
    echo "🧹 Удаляю старую версию certbot..."
    sudo apt purge -y certbot python3-certbot-nginx || true
    sudo rm -f /usr/bin/certbot /usr/local/bin/certbot
fi

# === Установка snap-версии certbot ===
if ! command -v snap >/dev/null 2>&1; then
    echo "📦 Установка snapd..."
    sudo apt install -y snapd
fi

if ! snap list | grep -q certbot; then
    echo "📦 Установка certbot через snap..."
    sudo snap install core
    sudo snap refresh core
    sudo snap install --classic certbot
fi

# === Симлинк certbot в /usr/bin ===
if [ ! -L /usr/bin/certbot ]; then
    sudo ln -s /snap/bin/certbot /usr/bin/certbot
fi

# === Клонируем шаблоны ===
TEMPLATE_DIR="/opt/sni-templates"
if [ ! -d "$TEMPLATE_DIR" ]; then
  sudo git clone https://github.com/antaras8/sni-templates.git "$TEMPLATE_DIR"
fi

# === Выбор случайного шаблона ===
TEMPLATE=$(find "$TEMPLATE_DIR" -mindepth 1 -maxdepth 1 -type d | shuf -n 1)
echo "Выбран шаблон: $TEMPLATE"

# === Установка шаблона ===
TARGET="/var/www/html/$DOMAIN"
sudo mkdir -p "$TARGET"
sudo cp -r "$TEMPLATE/"* "$TARGET/"

# === Nginx конфиг ===
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

# === Активация сайта и перезапуск nginx ===
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# === Выпуск сертификата ===
sudo certbot --nginx --non-interactive --agree-tos -m admin@$DOMAIN -d $DOMAIN

# === Перезапуск для надёжности ===
sudo systemctl reload nginx

echo "✅ Установлен HTTPS-шаблон на https://$DOMAIN"
