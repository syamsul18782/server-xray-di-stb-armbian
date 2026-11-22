#!/bin/bash
# ==============================================================================
# xray-auto-expired.sh — Cronjob Hapus Akun Xray Expired Otomatis (Tanpa Lisensi IP)
# ==============================================================================

XRAY_CONF="/usr/local/etc/xray/config.json"
EXP_FILE="/usr/local/etc/xray/expiry.txt"

[ ! -f "$EXP_FILE" ] && exit 0
[ ! -f "$XRAY_CONF" ] && exit 0

now_sec=$(date +%s)
need_restart=0

while read -r proto user uuid exp_date exp_time; do
  [ -z "$user" ] && continue
  if [ "$exp_date" = "Lifetime" ] || [ -z "$exp_date" ]; then
    continue
  fi
  exp_sec=$(date -d "$exp_date $exp_time" +%s 2>/dev/null || echo "")
  if [ -n "$exp_sec" ] && [ "$now_sec" -ge "$exp_sec" ]; then
    jq '(.inbounds[] | select(.protocol == "vmess" or .protocol == "vless" or .protocol == "trojan") | .settings.clients) |= map(select(.email != "'"$user"'"))' "$XRAY_CONF" > /tmp/xray_cfg_tmp.json
    if [ -s /tmp/xray_cfg_tmp.json ]; then
      mv /tmp/xray_cfg_tmp.json "$XRAY_CONF"
      sed -i "/^$proto $user /d" "$EXP_FILE"
      need_restart=1
    fi
  fi
done < "$EXP_FILE"

if [ "$need_restart" -eq 1 ]; then
  systemctl restart xray
fi
