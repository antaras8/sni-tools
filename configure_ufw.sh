#!/bin/bash
set -e

# Проверка аргумента
if [ -z "$1" ]; then
    echo "❌ Использование: $0 <TRUSTED_IP>"
    exit 1
fi

TRUSTED_IP="$1"

# Проверка и установка ufw при необходимости
if ! command -v ufw >/dev/null 2>&1; then
    echo "📦 UFW не установлен. Устанавливаем..."
    apt update && apt install -y ufw
else
    echo "✅ UFW уже установлен"
fi

echo "[1/6] Сброс UFW и установка политики по умолчанию"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

echo "[2/6] Разрешаем SSH (22) для всех"
ufw allow 22/tcp

echo "[3/6] Разрешаем HTTP/HTTPS для всех"
ufw allow 80/tcp
ufw allow 443/tcp

echo "[4/6] Разрешаем Xray (8443) для всех"
ufw allow 8443/tcp
ufw allow 8443/udp

echo "[5/6] Разрешаем Node Exporter (9100) только для $TRUSTED_IP"
ufw allow from "$TRUSTED_IP" to any port 9100 proto tcp

echo "[6/6] Разрешаем 2222 только для $TRUSTED_IP"
ufw allow from "$TRUSTED_IP" to any port 2222 proto tcp

echo "✅ Включаем UFW"
ufw --force enable

echo "📋 Текущий статус UFW:"
ufw status verbose