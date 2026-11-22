#!/bin/bash
# ==============================================================================
# uninstall.sh — Hapus Bersih Server Xray dari STB Armbian
# (Tidak menyentuh Nginx, Cockpit, WA Gateway, maupun Cloudflared)
# ==============================================================================

set -e

if [ "${EUID}" -ne 0 ]; then
  echo "[ERROR] Jalankan sebagai root."
  exit 1
fi

echo "Menghentikan dan menghapus service Xray..."
systemctl stop xray 2>/dev/null || true
systemctl disable xray 2>/dev/null || true

rm -rf /etc/systemd/system/xray.service \
       /etc/systemd/system/xray.service.d \
       /etc/systemd/system/xray@.service \
       /etc/systemd/system/xray@.service.d \
       /usr/local/bin/xray \
       /usr/local/bin/xray-menu \
       /usr/local/bin/menu \
       /usr/local/bin/xray-auto-expired \
       /usr/local/etc/xray \
       /usr/local/share/xray \
       /var/log/xray \
       /etc/cron.d/xray_auto_expired

systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

echo "[OK] Server Xray berhasil dihapus bersih dari STB Armbian."
echo "Catatan: Layanan lain (Cloudflared, Nginx, Cockpit, dll.) tetap aman."
