#!/bin/bash
# ==============================================================================
# Server Xray di STB Armbian (Xray-Only + Cloudflare Tunnel Ready)
# Repo: https://github.com/syamsul18782/server-xray-di-stb-armbian
# Protokol: VMess WS (/vmessws), VLESS WS (/vlessws), Trojan WS (/trojanws)
# ==============================================================================

set -e

REPO_RAW="https://raw.githubusercontent.com/syamsul18782/server-xray-di-stb-armbian/main"
XRAY_CONF="/usr/local/etc/xray/config.json"
ENV_FILE="/usr/local/etc/srpcom/env.conf"
EXP_FILE="/usr/local/etc/xray/expiry.txt"

# Warna output
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

# Cek root
if [ "${EUID}" -ne 0 ]; then
  echo -e "${RED}[ERROR]${NC} Jalankan script ini sebagai root (sudo -i / root)."
  exit 1
fi

# Parsing argumen opsional (--domain dan --bug)
DOMAIN=""
BUG_HOST=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --bug) BUG_HOST="$2"; shift 2 ;;
    *) shift ;;
  esac
done

clear
echo -e "${CYAN}==============================================================${NC}"
echo -e "${CYAN}   INSTALLER SERVER XRAY DI STB ARMBIAN (CLI RINGAN EDITION)  ${NC}"
echo -e "${CYAN}   Protokol : VMess WS | VLESS WS | Trojan WS (Cloudflare)    ${NC}"
echo -e "${CYAN}==============================================================${NC}"
echo ""

ARCH=$(uname -m)
echo -e "${GREEN}[INFO]${NC} Arsitektur terdeteksi: ${ARCH}"

# Input Domain & Bug jika belum diberikan via argumen
if [ -z "$DOMAIN" ]; then
  read -p "Masukkan Domain/Subdomain Xray (contoh: aw.srpcom.cloud): " DOMAIN < /dev/tty
  while [ -z "$DOMAIN" ]; do
    echo -e "${RED}[ERROR]${NC} Domain tidak boleh kosong!"
    read -p "Masukkan Domain/Subdomain Xray (contoh: aw.srpcom.cloud): " DOMAIN < /dev/tty
  done
fi

if [ -z "$BUG_HOST" ]; then
  read -p "Masukkan Bug Host default untuk YAML OpenClash [Enter = support.zoom.us]: " BUG_HOST < /dev/tty
  BUG_HOST="${BUG_HOST:-support.zoom.us}"
fi

echo ""
echo -e "${YELLOW}[1/6] Memasang dependensi ringan (jq, uuid-runtime, curl, unzip, cron)...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -qq
apt-get install -y -qq jq uuid-runtime curl unzip cron

echo -e "${YELLOW}[2/6] Menginstal Xray-core resmi (${ARCH})...${NC}"
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
/usr/local/bin/xray version | head -n 2

echo -e "${YELLOW}[3/6] Membuat konfigurasi Xray WebSocket (Tanpa acceptProxyProtocol)...${NC}"
mkdir -p /usr/local/etc/xray /usr/local/etc/srpcom /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log "$EXP_FILE"
chown -R nobody:nogroup /var/log/xray 2>/dev/null || true
chmod -R 777 /var/log/xray

cat > "$ENV_FILE" << EOF
DOMAIN="${DOMAIN}"
BUG_HOST="${BUG_HOST}"
EOF

# Backup config lama jika sudah ada akun
if [ -f "$XRAY_CONF" ] && grep -q '"clients": \[' "$XRAY_CONF" 2>/dev/null && [ -s "$EXP_FILE" ]; then
  cp "$XRAY_CONF" "${XRAY_CONF}.bak.$(date +%s)"
  echo -e "${GREEN}[INFO]${NC} Backup config Xray lama dibuat."
fi

cat > "$XRAY_CONF" << 'EOF'
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "api": {
    "services": ["StatsService", "LoggerService"],
    "tag": "api"
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },
  "inbounds": [
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmessws"
        }
      }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vlessws"
        }
      }
    },
    {
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojanws"
        }
      }
    },
    {
      "port": 10085,
      "listen": "127.0.0.1",
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ],
  "routing": {
    "rules": [
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      }
    ]
  }
}
EOF

echo -e "${YELLOW}[4/6] Mengunduh CLI xray-menu & cron auto-expired dari GitHub...${NC}"
curl -fsSL "${REPO_RAW}/scripts/xray-menu.sh" -o /usr/local/bin/xray-menu
curl -fsSL "${REPO_RAW}/scripts/xray-auto-expired.sh" -o /usr/local/bin/xray-auto-expired
sed -i 's/\r$//' /usr/local/bin/xray-menu /usr/local/bin/xray-auto-expired
chmod +x /usr/local/bin/xray-menu /usr/local/bin/xray-auto-expired
ln -sf /usr/local/bin/xray-menu /usr/local/bin/menu

echo "0 * * * * root /usr/local/bin/xray-auto-expired >/dev/null 2>&1" > /etc/cron.d/xray_auto_expired
chmod 644 /etc/cron.d/xray_auto_expired

echo -e "${YELLOW}[5/6] Mengaktifkan service Xray...${NC}"
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

echo -e "${YELLOW}[6/6] Memeriksa Cloudflare Tunnel (cloudflared)...${NC}"
if ! command -v cloudflared >/dev/null 2>&1; then
  echo -e "${YELLOW}[INFO]${NC} cloudflared belum terinstal di STB ini."
  read -p "Apakah ingin menginstal binary cloudflared sekarang? (y/n) [y]: " inst_cf < /dev/tty
  inst_cf="${inst_cf:-y}"
  if [[ "$inst_cf" =~ ^[Yy]$ ]]; then
    CF_ARCH="arm64"
    [ "$ARCH" = "x86_64" ] && CF_ARCH="amd64"
    [ "$ARCH" = "armv7l" ] && CF_ARCH="arm"
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    echo -e "${GREEN}[OK]${NC} cloudflared berhasil dipasang: $(cloudflared --version | head -n 1)"
  fi
else
  echo -e "${GREEN}[OK]${NC} cloudflared sudah terinstal ($(cloudflared --version | head -n 1))."
fi

echo ""
echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}   INSTALASI SERVER XRAY DI STB ARMBIAN SELESAI!              ${NC}"
echo -e "${GREEN}==============================================================${NC}"
echo -e " Status Xray   : $(systemctl is-active xray)"
echo -e " Domain        : ${DOMAIN}"
echo -e " Bug Default   : ${BUG_HOST}"
echo -e " Port Lokal    : 10001 (/vmessws) | 10002 (/vlessws) | 10003 (/trojanws)"
echo -e "--------------------------------------------------------------"
echo -e " ${CYAN}LANGKAH SELANJUTNYA (CLOUDFLARE TUNNEL):${NC}"
echo -e " Arahkan Public Hostname / Ingress Cloudflare Tunnel Anda:"
echo -e "   * ${DOMAIN} (atau ${BUG_HOST}.${DOMAIN}):"
echo -e "     - Path /vmessws  -> http://127.0.0.1:10001"
echo -e "     - Path /vlessws  -> http://127.0.0.1:10002"
echo -e "     - Path /trojanws -> http://127.0.0.1:10003"
echo -e "--------------------------------------------------------------"
echo -e " ${CYAN}CARA KELOLA AKUN:${NC}"
echo -e "   Ketik 'menu' atau 'xray-menu' di terminal."
echo -e "   Atau cepat: xray-menu add trojan user1 30"
echo -e "${GREEN}==============================================================${NC}"
echo ""

read -p "Ingin langsung buat 1 akun Trojan WS pertama sekarang? (y/n) [y]: " make_first < /dev/tty
make_first="${make_first:-y}"
if [[ "$make_first" =~ ^[Yy]$ ]]; then
  /usr/local/bin/xray-menu add trojan admin_stb 0
fi
