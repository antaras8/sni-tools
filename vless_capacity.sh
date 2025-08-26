#!/usr/bin/env sh
set -eu

# ===== Defaults =====
OVERHEAD_FACTOR="${OVERHEAD_FACTOR:-0.90}"   # полезная доля после накладных расходов (0.85–0.95)
IPERF_PARALLEL="${IPERF_PARALLEL:-4}"        # количество потоков для iperf3
IPERF_TIME="${IPERF_TIME:-10}"               # длительность теста, сек
IPERF_PORT="${IPERF_PORT:-5201}"
CURL_URL="${CURL_URL:-https://proof.ovh.net/files/1Gb.dat}"  # большой файл для curl

usage() {
  cat <<EOF
Usage:
  $0 iperf  -h <host> [-p <port>] [-P <parallel>] [-t <sec>] [--ipv4|--ipv6]
  $0 curl   [-u <url>]
  $0 manual -m <mbps>
Options:
  -h, --host        iperf3 сервер (обязательно для режима iperf)
  -p, --port        порт iperf3 (по умолчанию ${IPERF_PORT})
  -P, --parallel    число потоков iperf3 (по умолчанию ${IPERF_PARALLEL})
  -t, --time        длительность iperf3, сек (по умолчанию ${IPERF_TIME})
      --ipv4        принудительно IPv4 для iperf3
      --ipv6        принудительно IPv6 для iperf3
  -u, --url         URL для curl (по умолчанию ${CURL_URL})
  -m, --mbps        готовое значение скорости в Мбит/с (для режима manual)
Env:
  OVERHEAD_FACTOR   доля полезной нагрузки после накладных расходов (def ${OVERHEAD_FACTOR})
  CURL_URL          URL большого файла для curl (def ${CURL_URL})
Examples:
  $0 iperf -h spd-rudp.hostkey.ru -p 5201 -P 10 --ipv4
  $0 curl
  $0 manual -m 2000
EOF
  exit 1
}

to_int() { awk 'BEGIN{printf "%.0f\n",'$1'}'; }

calc_and_print() {
  RAW_MBPS="$1"
  OVER_MBPS=$(awk 'BEGIN{printf "%.2f",'$RAW_MBPS'*'${OVERHEAD_FACTOR}'}')

  echo "Измеренная скорость (RAW): ${RAW_MBPS} Мбит/с"
  echo "Коэффициент полезной нагрузки (OVERHEAD_FACTOR): ${OVERHEAD_FACTOR}"
  echo "Полезная полоса для VLESS (EFF): ${OVER_MBPS} Мбит/с"
  echo

  # Профили (Мбит/с на активного пользователя)
  # Можно изменить по своим реалиям.
  profiles="3 Лёгкий сёрфинг/IM
5 Смешанный (веб+720/1080p)
8 Частый HD-стриминг/облака
25 4K-видео/тяжёлый стриминг
50 Очень тяжёлая нагрузка (торренты/заливы)"

  printf "%-36s %12s %12s\n" "Профиль нагрузки" "N (без запаса)" "N (-30% запас)"
  echo "-----------------------------------------------------------------------"
  echo "$profiles" | while read -r rate desc; do
    [ -z "$rate" ] && continue
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

    # Проверяем наличие iperf3 и устанавливаем при необходимости
    if ! command -v iperf3 >/dev/null 2>&1; then
      echo "iperf3 not found. Installing..."
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -y && sudo apt-get install -y iperf3
      elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y iperf3
      else
        echo "Не удалось определить пакетный менеджер, установи iperf3 вручную."
        exit 3
      fi
    fi

    # Запуск iperf3 (клиент)
    OUT=$(iperf3 -c "$HOST" -p "$IPERF_PORT" -P "$IPERF_PARALLEL" -t "$IPERF_TIME" $IPVER_FLAG 2>/dev/null || true)

    # Парсим строку [SUM] ... receiver
    SUM_LINE=$(echo "$OUT" | awk '/\[SUM\].*receiver/ {print $0}' | tail -n1)
    if [ -z "$SUM_LINE" ]; then
      # fallback: берём sender
      SUM_LINE=$(echo "$OUT" | awk '/\[SUM\].*sender/ {print $0}' | tail -n1)
    fi
    if [ -z "$SUM_LINE" ]; then
      echo "Не удалось извлечь суммарную скорость из iperf3."
      echo "Вывод iperf3:"
      echo "$OUT"
      exit 4
    fi

    # Извлекаем число и единицы (Mbits/sec|Gbits/sec)
    NUM=$(echo "$SUM_LINE" | awk '{for(i=1;i<=NF;i++){if($i~/Mbits\/sec|Gbits\/sec/){print $(i-1),$i; exit}}}')
    VAL=$(echo "$NUM" | awk '{print $1}')
    UNIT=$(echo "$NUM" | awk '{print $2}')
    case "$UNIT" in
      Mbits/sec) RAW_MBPS="$VAL" ;;
      Gbits/sec) RAW_MBPS=$(awk 'BEGIN{printf "%.2f",'$VAL'*1000}') ;;
      *) echo "Неизвестные единицы: $UNIT"; exit 5 ;;
    esac

    calc_and_print "$RAW_MBPS"
    ;;

  curl)
    while [ $# -gt 0 ]; do
      case "$1" in
        -u|--url) CURL_URL="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; usage ;;
      esac
    done
    command -v curl >/dev/null 2>&1 || { echo "Error: curl not found"; exit 3; }
    # Средняя скорость скачивания в байтах/с; переведём в Мбит/с
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
