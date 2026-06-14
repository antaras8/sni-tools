# sni-tools

### Включить BBR на сервере (рекомендуется для лучшей скорости сети)
```curl
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf && echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf && sysctl -p
```

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
Ububtu
```curl
sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf && sudo systemctl restart ssh
```

Debian
```
sh -c 'sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config; for f in /etc/ssh/sshd_config.d/*.conf; do [ -f "$f" ] && sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" "$f"; done; systemctl restart sshd'
```

### Отключить ipV6 ubuntu
```curl
echo -e "net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```

### проверка пропускного канала VPS с РФ
```curl
curl -s https://raw.githubusercontent.com/antaras8/sni-tools/refs/heads/main/vless_capacity.sh |   bash -s -- iperf -h spd-rudp.hostkey.ru -p 5201 -P 10 --ipv4
```

### Проверка IP сервера на блокировку зарубежными сервисами и чистоту IP:
```curl
bash <(curl -Ls IP.Check.Place | sed '/^\s*show_ad\s*$/d') -l en
```
### Проверка скорости к российским провайдерам:
```curl
wget -qO- bench.openode.xyz | bash
```
### Проверка ип на страны
```curl
bash <(curl -L -s https://bench.gig.ovh/ipregion.sh) -g primary
```
### Параметры сервера и проверка скорости к зарубежным провайдерам:
```curl
wget -qO- bench.sh | bash
```
### Гео тест IP (IP Region), проверка региона ютуба и т.д. :
```curl
bash <(wget -qO- https://github.com/Davoyan/ipregion/raw/main/ipregion.sh)
```
### Yabs:
```curl
curl -sL yabs.sh | bash -s -- -4
```
### Тест на процессор, можно понять примерно какой процент CPU выделен:
# В threads писать количество ядер процессора
```curl
sysbench cpu run --threads=1
```

```curl
wget -qO- censorcheck.tlab.pw | bash
```
