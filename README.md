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

### Запрет на авторизацию SSH через пароль
```curl
sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf && sudo systemctl restart ssh
```

### Отключить ipV6 ubuntu
```curl
echo -e "net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```

### проверка пропускного канала VPS с РФ
```curl
curl -s https://raw.githubusercontent.com/antaras8/sni-tools/refs/heads/main/vless_capacity.sh |   bash -s -- iperf -h spd-rudp.hostkey.ru -p 5201 -P 10 --ipv4
```
