#!/usr/bin/env sh
set -eu

# ===== Defaults =====
OVERHEAD_FACTOR="${OVERHEAD_FACTOR:-0.90}"   # доля полезной нагрузки после накладных расходов (0.85–0.95)
IPERF_PARALLEL="${IPERF_PARALLEL:-4}"        # количество потоков для iperf3
IPERF_TIME="${IPERF_TIME:-10}"               # длительность теста, сек
IPERF_PORT="${IPERF_PORT:-5201}"
CURL_URL="${CURL_URL:-https://proof.ovh.net/files/1Gb.dat}"  # большой файл для curl

LC_ALL=C
export LC_ALL

usage() {
cat <<'EOF'
Usage:
  vless_capacity.sh iperf  -h <host> [-p <port>] [-P <parallel>] [-t <sec>] [--ipv4|--ipv6]
  vless_capacity.sh curl   [-u <url>]
  vless_capacity.sh manual -m <mbps>
Options:
  -h, --host        iperf3 сервер (обязательно для режима iperf)
  -p, --port        порт iperф3 (по умолчанию 5201)
  -P, --parallel    число потоков iperf3 (по умолчанию 4)
  -t, --time        длительность iperf3, сек (по умолчанию 10)
      --ipv4        принудительно IPv4 для iperf3
      --ipv6        принудительно IPv6 для iperf3
  -u, --url         URL для curl (по умолчанию https://proof.ovh.net/files/1Gb.dat)
  -m, --mbps        готовое значение скорости в Мбит/с (для режима manual)
Env:
  OVERHEAD_FACTOR   доля полезной нагрузки после накладных расходов (def 0.90)
  CURL_URL          URL большого файла для curl (def указан выше)
Examples:
  ./vless_capacity.sh iperf -h spd-rudp.hostkey.ru -p 5201 -P 10 --ipv4
  ./vless_capacity.sh curl
  OVERHEAD_FACTOR=0.85 ./vless_capacity.sh manual -m 2000
EOF
  exit 1
}

install_pkg() {
  # $1 = пакет
  PKG="$1"
  if command -v apt-get >/dev/null 2>&1; then
    # Debian/Ubuntu
    if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get update -y >/dev/null 2>&1 || true
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$PKG"
  elif command -v dnf >/dev/null 2>&1; then
    # RHEL8+/Fedora
    if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
    $SUDO dnf install -y "$PKG"
  elif command -v yum >/dev/null 2>&1; then
    # RHEL/CentOS
    if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
    $SUDO yum install -y "$PKG"
  elif command -v apk >/dev/null 2>&1; then
    # Alpine
    if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi
    $SUDO apk add --no-cache "$PKG"
  else
    echo "Не удалось определить пакетный менеджер. Установи пакет $PKG вручную." >&2
    exit 3
  fi
}

ensure_bin() {
  # $1 = бинарь, $2 = пакет(ы) для установки (через пробел)
  BIN="$1"
  PKGS="$2"
  if ! command -v "$BIN" >/dev/null 2>&1; then
    echo "$BIN not found. Installing..."
    # попробуем установить все пакеты из списка
    for P in $PKGS; do
      install_pkg "$P" || true
      if command -v "$BIN" >/dev/null 2>&1; then
        break
      fi
    done
    if ! command -v "$BIN" >/dev/null 2>&1; then
      echo "Не удалось установить $BIN. Установи вручную." >&2
      exit 3
    fi
  fi
}

to_int() { awk 'BEGIN{printf "%.0f\n",'$1'}'; }

calc_and_print() {
  RAW_MBPS="$1"
  OVER_MBPS=$(awk 'BEGIN{printf "%.2f",'$RAW_MBPS'*'${OVERHEAD_FACTOR}'}')

  echo "Измеренная скорость (RAW): ${RAW_MBPS} Мбит/с"
  echo "Коэффициент полезной нагрузки (OVERHEAD_FACTOR): ${OVERHEAD_FACTOR}"
  echo "Полезная полоса для VLESS (EFF): ${OVER_MBPS} Мбит/с"
  echo

  profiles="3 Лёгкий сёрфинг/IM
5 Смешанный (веб+720/1080p)
8 Частый HD-стриминг/облака
25 4K-видео/тяжёлый стриминг
50 Очень тяжёлая нагрузка (торренты/заливы)"

  printf "%-36s %12s %12s\n" "Профиль нагрузки" "N (без запаса)" "N (-30% запас)"
  echo "-----------------------------------------------------------------------"
  echo "$profiles" | while read -r rate desc; do
    [ -z "${rate:-}" ] && continue
    n_raw=$(awk 'BEGIN{printf "%.0f",'$OVER_MBPS'/'$rate'}')
    n_safe=$(awk 'BEGIN{printf "%.0f",('$OVER_MBPS'*0.70)/'$rate'}')
    printf "%-36s %12s %12s\n" "$desc" "$n_raw" "$n_safe"
  done
}

# ===== Parse args =====
[ $# -lt 1 ] && usage
MODE="$1"; shift || true

case "$MODE" in
  iperf)
    HOST=""
    IPVER_FLAG=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -h|--host) HOST="$2"; shift 2 ;;
        -p|--port) IPERF_PORT="$2"; shift 2 ;;
        -P|--parallel) IPERF_PARALLEL="$2"; shift 2 ;;
        -t|--time) IPERF_TIME="$2"; shift 2 ;;
        --ipv4) IPVER_FLAG="-4"; shift ;;
        --ipv6) IPVER_FLAG="-6"; shift ;;
        *) echo "Unknown arg: $1"; usage ;;
      esac
    done
    [ -z "${HOST}" ] && { echo "Error: --host required for iperf mode"; exit 2; }

    # Автоустановка iperf3
    ensure_bin iperf3 "iperf3"

    # Запуск iperf3 (клиент), собираем суммарную скорость receiver (fallback: sender)
    OUT=$(iperf3 -c "$HOST" -p "$IPERF_PORT" -P "$IPERF_PARALLEL" -t "$IPERF_TIME" $IPVER_FLAG 2>/dev/null || true)

    SUM_LINE=$(echo "$OUT" | awk '/\[SUM\].*receiver/ {print $0}' | tail -n1)
    if [ -z "$SUM_LINE" ]; then
      SUM_LINE=$(echo "$OUT" | awk '/\[SUM\].*sender/ {print $0}' | tail -n1)
    fi
    if [ -z "$SUM_LINE" ]; then
      echo "Не удалось извлечь суммарную скорость из iperf3."
      echo "Вывод iperf3:"
      echo "$OUT"
      exit 4
    fi

    NUM=$(echo "$SUM_LINE" | awk '{for(i=1;i<=NF;i++){if($i~/Mbits\/sec|Gbits\/sec/){print $(i-1),$i; exit}}}')
    VAL=$(echo "$NUM" | awk '{print $1}')
    UNIT=$(echo "$NUM" | awk '{print $2}')
    case "$UNIT" in
      Mbits/sec) RAW_MBPS="$VAL" ;;
      Gbits/sec) RAW_MBPS=$(awk 'BEGIN{printf "%.2f",'$VAL'*1000}') ;;
      *) echo "Неизвестные единицы: $UNIT"; exit 5 ;;
    esac

    # Доп. информация о Retr (если есть sender-строка)
    RETR=$(echo "$OUT" | awk '/\[SUM\].*sender/ {for(i=1;i<=NF;i++) if($i=="Retr") {print $(i+1); exit}}' | tail -n1 || true)
    [ -n "${RETR:-}" ] && echo "TCP Retransmissions (SUM sender): $RETR"

    calc_and_print "$RAW_MBPS"
    ;;

  curl)
    while [ $# -gt 0 ]; do
      case "$1" in
        -u|--url) CURL_URL="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; usage ;;
      esac
    done

    # Автоустановка curl
    ensure_bin curl "curl"

    SPD_BPS=$(curl -o /dev/null -s -w '%{speed_download}\n' "$CURL_URL" || echo "0")
    RAW_MBPS=$(awk 'BEGIN{printf "%.2f",('$SPD_BPS'*8)/1000000}')
    calc_and_print "$RAW_MBPS"
    ;;

  manual)
    RAW_MBPS=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -m|--mbps) RAW_MBPS="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; usage ;;
      esac
    done
    [ -z "$RAW_MBPS" ] && { echo "Error: --mbps required for manual mode"; exit 2; }
    calc_and_print "$RAW_MBPS"
    ;;

  *)
    usage
    ;;
esac
