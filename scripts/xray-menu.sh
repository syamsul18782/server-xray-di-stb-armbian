#!/bin/bash
# ==============================================================================
# xray-menu.sh — CLI Ringan Manajemen Akun Xray WS untuk STB Armbian
# Repo: https://github.com/syamsul18782/server-xray-di-stb-armbian
# ==============================================================================

ENV_FILE="/usr/local/etc/srpcom/env.conf"
XRAY_CONF="/usr/local/etc/xray/config.json"
EXP_FILE="/usr/local/etc/xray/expiry.txt"

[ -f "$ENV_FILE" ] && source "$ENV_FILE"
DOMAIN="${DOMAIN:-aw.srpcom.cloud}"
BUG_HOST="${BUG_HOST:-support.zoom.us}"
mkdir -p /usr/local/etc/srpcom /usr/local/etc/xray
touch "$EXP_FILE"

show_account_info() {
  local proto="$1"
  local user="$2"
  local uuid="$3"
  local exp_date="$4"
  local exp_time="$5"
  local ws_path="/${proto}ws"
  local wc_host="${BUG_HOST}.${DOMAIN}"

  echo "=============================================================="
  echo "  DETAIL AKUN XRAY ${proto^^} WS"
  echo "=============================================================="
  echo "Remarks        : $user"
  echo "Domain         : $DOMAIN"
  echo "Wildcard SNI   : $wc_host"
  echo "Port TLS       : 443"
  echo "UUID / Pass    : $uuid"
  echo "Network        : WebSocket (ws)"
  echo "Path           : $ws_path"
  echo "Expired On     : $exp_date $exp_time"
  echo "--------------------------------------------------------------"

  if [ "$proto" = "trojan" ]; then
    echo "LINK TROJAN TLS (Direct CDN):"
    echo "trojan://${uuid}@${DOMAIN}:443?path=%2Ftrojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    echo ""
    echo "LINK TROJAN TLS (Wildcard Bug ${BUG_HOST}):"
    echo "trojan://${uuid}@${BUG_HOST}:443?path=%2Ftrojanws&security=tls&host=${wc_host}&type=ws&sni=${wc_host}#${user}_wc"
    echo "--------------------------------------------------------------"
    echo "YAML OPENCLASH (Wildcard Bug ${BUG_HOST}):"
    cat << YAMLEOF
proxies:
- name: "${user}_stb"
  type: trojan
  server: ${BUG_HOST}
  port: 443
  password: "${uuid}"
  tls: true
  sni: ${wc_host}
  skip-cert-verify: true
  network: ws
  ws-opts:
    path: "/trojanws"
    headers:
      Host: ${wc_host}
  udp: true
YAMLEOF
  elif [ "$proto" = "vless" ]; then
    echo "LINK VLESS TLS (Direct CDN):"
    echo "vless://${uuid}@${DOMAIN}:443?path=%2Fvlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    echo ""
    echo "LINK VLESS TLS (Wildcard Bug ${BUG_HOST}):"
    echo "vless://${uuid}@${BUG_HOST}:443?path=%2Fvlessws&security=tls&encryption=none&host=${wc_host}&type=ws&sni=${wc_host}#${user}_wc"
    echo "--------------------------------------------------------------"
    echo "YAML OPENCLASH (Wildcard Bug ${BUG_HOST}):"
    cat << YAMLEOF
proxies:
- name: "${user}_stb"
  type: vless
  server: ${BUG_HOST}
  port: 443
  uuid: "${uuid}"
  tls: true
  servername: ${wc_host}
  skip-cert-verify: true
  network: ws
  ws-opts:
    path: "/vlessws"
    headers:
      Host: ${wc_host}
  udp: true
YAMLEOF
  elif [ "$proto" = "vmess" ]; then
    local json_direct="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    local json_wc="{\"v\":\"2\",\"ps\":\"${user}_wc\",\"add\":\"${BUG_HOST}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${wc_host}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${wc_host}\"}"
    echo "LINK VMESS TLS (Direct CDN):"
    echo "vmess://$(echo -n "$json_direct" | base64 -w 0)"
    echo ""
    echo "LINK VMESS TLS (Wildcard Bug ${BUG_HOST}):"
    echo "vmess://$(echo -n "$json_wc" | base64 -w 0)"
    echo "--------------------------------------------------------------"
    echo "YAML OPENCLASH (Wildcard Bug ${BUG_HOST}):"
    cat << YAMLEOF
proxies:
- name: "${user}_stb"
  type: vmess
  server: ${BUG_HOST}
  port: 443
  uuid: "${uuid}"
  alterId: 0
  cipher: auto
  tls: true
  servername: ${wc_host}
  skip-cert-verify: true
  network: ws
  ws-opts:
    path: "/vmessws"
    headers:
      Host: ${wc_host}
  udp: true
YAMLEOF
  fi
  echo "=============================================================="
}

create_account() {
  local proto="$1"
  local user="$2"
  local days="$3"
  local custom_uuid="$4"

  if [ -z "$proto" ]; then
    echo "Pilih Protokol: 1) Trojan WS  2) VLESS WS  3) VMess WS"
    read -p "Pilihan [1-3]: " p_choice
    case "$p_choice" in
      1) proto="trojan" ;;
      2) proto="vless" ;;
      3) proto="vmess" ;;
      *) echo "Pilihan tidak valid."; return 1 ;;
    esac
  fi

  if [ -z "$user" ]; then
    read -p "Username: " user
  fi
  [ -z "$user" ] && { echo "Username tidak boleh kosong."; return 1; }

  local orig="$user"
  local cnt=2
  while grep -q "\"email\": \"$user\"" "$XRAY_CONF" 2>/dev/null; do
    user="${orig}${cnt}"
    ((cnt++))
  done

  if [ -z "$days" ]; then
    read -p "Masa Aktif (hari, ketik 0 untuk Lifetime): " days
  fi

  local uuid="${custom_uuid:-$(uuidgen)}"
  local exp_date="Lifetime"
  local exp_time="-"
  if [ -n "$days" ] && [ "$days" != "0" ] && [ "$days" != "Lifetime" ]; then
    exp_date=$(date -d "$days days" +"%Y-%m-%d")
    exp_time=$(date -d "$days days" +"%H:%M:%S")
  fi

  if [ "$proto" = "trojan" ]; then
    jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'"$uuid"'", "email": "'"$user"'"}]' "$XRAY_CONF" > /tmp/xray_cfg_tmp.json
  elif [ "$proto" = "vless" ]; then
    jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'"$uuid"'", "email": "'"$user"'"}]' "$XRAY_CONF" > /tmp/xray_cfg_tmp.json
  elif [ "$proto" = "vmess" ]; then
    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'"$uuid"'", "alterId": 0, "email": "'"$user"'"}]' "$XRAY_CONF" > /tmp/xray_cfg_tmp.json
  else
    echo "Protokol tidak dikenal: $proto (gunakan trojan, vless, atau vmess)"
    return 1
  fi

  if [ -s /tmp/xray_cfg_tmp.json ]; then
    mv /tmp/xray_cfg_tmp.json "$XRAY_CONF"
    sed -i "/ $user /d" "$EXP_FILE" 2>/dev/null || true
    echo "$proto $user $uuid $exp_date $exp_time" >> "$EXP_FILE"
    systemctl restart xray
    show_account_info "$proto" "$user" "$uuid" "$exp_date" "$exp_time"
  fi
}

list_accounts() {
  echo "================================================================"
  printf " %-4s | %-8s | %-18s | %-20s\n" "No" "Proto" "Username" "Expired"
  echo "----------------------------------------------------------------"
  if [ ! -s "$EXP_FILE" ]; then
    echo " (Belum ada akun terdaftar)"
  else
    local i=1
    while read -r proto user uuid exp_date exp_time; do
      [ -z "$user" ] && continue
      printf " %-4s | %-8s | %-18s | %-20s\n" "$i" "${proto^^}" "$user" "$exp_date $exp_time"
      ((i++))
    done < "$EXP_FILE"
  fi
  echo "================================================================"
}

delete_account() {
  local user="$1"
  if [ -z "$user" ]; then
    list_accounts
    read -p "Masukkan Username yang ingin dihapus: " user
  fi
  [ -z "$user" ] && return
  jq '(.inbounds[] | select(.protocol=="vmess" or .protocol=="vless" or .protocol=="trojan") | .settings.clients) |= map(select(.email != "'"$user"'"))' "$XRAY_CONF" > /tmp/xray_cfg_tmp.json
  if [ -s /tmp/xray_cfg_tmp.json ]; then
    mv /tmp/xray_cfg_tmp.json "$XRAY_CONF"
    sed -i "/ $user /d" "$EXP_FILE"
    systemctl restart xray
    echo "Akun '$user' berhasil dihapus."
  fi
}

renew_account() {
  list_accounts
  read -p "Masukkan Username yang ingin diperpanjang: " user
  [ -z "$user" ] && return
  if ! grep -q " $user " "$EXP_FILE"; then
    echo "User tidak ditemukan."
    return
  fi
  read -p "Set Masa Aktif Baru (hari dari sekarang, 0 = Lifetime): " days
  local line=$(grep " $user " "$EXP_FILE" | head -n 1)
  local proto=$(echo "$line" | awk '{print $1}')
  local uuid=$(echo "$line" | awk '{print $3}')
  local exp_date="Lifetime"
  local exp_time="-"
  if [ "$days" != "0" ]; then
    exp_date=$(date -d "$days days" +"%Y-%m-%d")
    exp_time=$(date -d "$days days" +"%H:%M:%S")
  fi
  sed -i "/ $user /d" "$EXP_FILE"
  echo "$proto $user $uuid $exp_date $exp_time" >> "$EXP_FILE"
  echo "Masa aktif '$user' diperbarui menjadi: $exp_date $exp_time"
}

change_domain() {
  echo "Domain saat ini : $DOMAIN"
  echo "Bug saat ini    : $BUG_HOST"
  read -p "Domain baru (Enter untuk tetap): " new_dom
  read -p "Bug Host baru (Enter untuk tetap): " new_bug
  [ -n "$new_dom" ] && DOMAIN="$new_dom"
  [ -n "$new_bug" ] && BUG_HOST="$new_bug"
  cat > "$ENV_FILE" << EOF
DOMAIN="${DOMAIN}"
BUG_HOST="${BUG_HOST}"
EOF
  echo "Konfigurasi disimpan: DOMAIN=${DOMAIN}, BUG_HOST=${BUG_HOST}"
}

show_cf_template() {
  echo "=== TEMPLATE INGRESS CLOUDFLARE TUNNEL ==="
  cat << EOF
ingress:
  - hostname: ${BUG_HOST}.${DOMAIN}
    path: ^/vmessws.*
    service: http://127.0.0.1:10001
  - hostname: ${BUG_HOST}.${DOMAIN}
    path: ^/vlessws.*
    service: http://127.0.0.1:10002
  - hostname: ${BUG_HOST}.${DOMAIN}
    path: ^/trojanws.*
    service: http://127.0.0.1:10003
  - hostname: ${DOMAIN}
    path: ^/vmessws.*
    service: http://127.0.0.1:10001
  - hostname: ${DOMAIN}
    path: ^/vlessws.*
    service: http://127.0.0.1:10002
  - hostname: ${DOMAIN}
    path: ^/trojanws.*
    service: http://127.0.0.1:10003
  - service: http_status:404
EOF
}

# Mode CLI Non-Interaktif
case "$1" in
  add)  create_account "$2" "$3" "$4" "$5"; exit 0 ;;
  del)  delete_account "$2"; exit 0 ;;
  list) list_accounts; exit 0 ;;
esac

# Mode Menu Interaktif
while true; do
  clear
  echo "=============================================================="
  echo "      SERVER XRAY STB ARMBIAN — CLI RINGAN (WS ONLY)          "
  echo "=============================================================="
  echo " Domain      : $DOMAIN"
  echo " Bug Default : $BUG_HOST"
  echo " Xray Core   : $(systemctl is-active xray 2>/dev/null || echo inactive)"
  echo " Cloudflared : $(systemctl is-active cloudflared 2>/dev/null || echo not-installed)"
  echo "=============================================================="
  echo " 1. Buat Akun Xray Baru (Trojan / VLESS / VMess WS)"
  echo " 2. Hapus Akun Xray"
  echo " 3. Perpanjang Masa Aktif Akun (Renew)"
  echo " 4. Lihat Daftar Akun & Detail YAML OpenClash"
  echo " 5. Ubah Domain / Bug Default"
  echo " 6. Lihat Template Ingress Cloudflare Tunnel"
  echo " 7. Restart Xray & Cloudflared"
  echo " 0. Keluar"
  echo "=============================================================="
  read -p "Pilih menu [0-7]: " opt
  case "$opt" in
    1) create_account; read -p "Tekan Enter untuk kembali..." ;;
    2) delete_account; read -p "Tekan Enter untuk kembali..." ;;
    3) renew_account; read -p "Tekan Enter untuk kembali..." ;;
    4)
      list_accounts
      read -p "Ketik Username untuk lihat Link/YAML (atau Enter untuk kembali): " u_detail
      if [ -n "$u_detail" ] && grep -q " $u_detail " "$EXP_FILE"; then
        line=$(grep " $u_detail " "$EXP_FILE" | head -n 1)
        show_account_info $(echo "$line" | awk '{print $1, $2, $3, $4, $5}')
        read -p "Tekan Enter untuk kembali..."
      fi
      ;;
    5) change_domain; read -p "Tekan Enter untuk kembali..." ;;
    6) show_cf_template; read -p "Tekan Enter untuk kembali..." ;;
    7)
      systemctl restart xray
      systemctl is-active --quiet cloudflared 2>/dev/null && systemctl restart cloudflared
      echo "Layanan berhasil di-restart!"
      sleep 2
      ;;
    0|x|X) exit 0 ;;
  esac
done
