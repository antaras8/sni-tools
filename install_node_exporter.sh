#!/bin/bash
set -e

INSTALL_DIR="/opt/node_exporter"

echo "[1/3] Создание каталога: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

echo "[2/3] Запись docker-compose.yml"
cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
version: '3.8'

services:
  node_exporter:
    image: quay.io/prometheus/node-exporter:latest
    container_name: node_exporter
    restart: always
    network_mode: host
    pid: host
    cap_add:
      - SYS_TIME
      - SYS_RAWIO
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--collector.disable-defaults'
      - '--collector.cpu'
      - '--collector.meminfo'
      - '--collector.netdev'
      - '--collector.netdev.device-include=^eth0$'
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
EOF

echo "[3/3] Запуск node_exporter"
cd "$INSTALL_DIR"
docker compose up -d

echo "✅ node_exporter установлен и запущен"