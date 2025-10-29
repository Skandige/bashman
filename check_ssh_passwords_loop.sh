#!/usr/bin/env bash
# check_ssh_list_big.sh — не прерывается даже при большом списке хостов

set -u

HOSTS_FILE=""
USER=""
PASSWORD=""
OUTFILE="results.csv"
CONNECT_TIMEOUT=5
SSH_CMD_TIMEOUT=8

while getopts ":f:u:p:o:" opt; do
  case $opt in
    f) HOSTS_FILE="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    o) OUTFILE="$OPTARG" ;;
  esac
done

if [[ -z "$HOSTS_FILE" || -z "$USER" ]]; then
  echo "Использование: $0 -f hosts.txt -u user [-p password] [-o results.csv]"
  exit 1
fi

if [[ -z "$PASSWORD" ]]; then
  read -s -p "Введите пароль для $USER: " PASSWORD
  echo
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "Установите sshpass: sudo apt install sshpass"
  exit 1
fi

echo "host,user,success,detail,timestamp" > "$OUTFILE"

# ---- основной цикл ----
# ключевой момент: < <(cat "$HOSTS_FILE") вместо ... < "$HOSTS_FILE"
while IFS= read -r host; do
  host="${host%%#*}"
  host="$(echo "$host" | xargs)"
  [[ -z "$host" ]] && continue

  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  # проверяем порт
  if ! nc -z -w $CONNECT_TIMEOUT "$host" 22 >/dev/null 2>&1; then
    echo "$host,$USER,false,unreachable,$timestamp" >> "$OUTFILE"
    echo "[FAIL] $host — порт 22 недоступен"
    continue
  fi

  # пытаемся подключиться (отключаем stdin для sshpass!)
  result=$(timeout $SSH_CMD_TIMEOUT sshpass -p "$PASSWORD" \
    ssh -n \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=$CONNECT_TIMEOUT \
      -o BatchMode=no \
      "$USER@$host" "echo OK" 2>&1)
  rc=$?

  if [[ $rc -eq 0 && "$result" == "OK" ]]; then
    echo "$host,$USER,true,auth_ok,$timestamp" >> "$OUTFILE"
    echo "[ OK ] $host — авторизация успешна"
  else
    reason="auth_failed"
    if echo "$result" | grep -qi "Permission denied"; then reason="permission_denied"; fi
    if echo "$result" | grep -qi "Connection refused"; then reason="connection_refused"; fi
    if echo "$result" | grep -qi "timed out"; then reason="timeout"; fi
    echo "$host,$USER,false,$reason,$timestamp" >> "$OUTFILE"
    echo "[FAIL] $host — $reason"
  fi

done < <(cat "$HOSTS_FILE")  # <<<--- ключевой момент

echo
echo "Результаты записаны в $OUTFILE"
