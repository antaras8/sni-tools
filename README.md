# sni-tools

### Установка сайта заглушки (Получение сертифика, загрузка шаблока, запуск nginx)

```curl
curl -s https://raw.githubusercontent.com/antaras8/sni-tools/refs/heads/main/setup.sh | bash -s your.domain.com
```

### Установка node_exporter

```curl
curl -s https://raw.githubusercontent.com/antaras8/sni-tools/refs/heads/main/install_node_exporter.sh | bash
```

### Установка фаерволла

```curl
curl -s https://raw.githubusercontent.com/antaras8/sni-tools/refs/heads/main/configure_ufw.sh | bash -s backend_ip
```