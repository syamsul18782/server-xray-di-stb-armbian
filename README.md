# Server Xray di STB Armbian (CLI Ringan + Cloudflare Tunnel)

Installer **Xray-Only (WebSocket)** yang sangat ringan dan aman untuk **STB Armbian (`aarch64` / ARM64 maupun `x86_64`)** menggunakan koneksi **Cloudflare Tunnel (`cloudflared`)** — **tanpa perlu IP Publik statis, tanpa Port Forwarding, tanpa Caddy/Nginx bentrok, dan tanpa UFW agresif.**

## Arsitektur
```text
Client / OpenClash ──(TLS 443 + Bug/SNI)──▶ Cloudflare CDN ──▶ Cloudflare Tunnel (STB Armbian)
                                                                       │
                                              ┌────────────────────────┼────────────────────────┐
                                              ▼                        ▼                        ▼
                                        127.0.0.1:10001          127.0.0.1:10002          127.0.0.1:10003
                                        (VMess /vmessws)         (VLESS /vlessws)         (Trojan /trojanws)
                                                                       │
                                                                       ▼
                                                                Internet STB
```

---

## Instalasi Cepat (1 Baris Perintah)

Login sebagai `root` di terminal STB Armbian baru, lalu jalankan perintah berikut:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/syamsul18782/server-xray-di-stb-armbian/main/install.sh)
```

Atau mode cepat langsung isi domain & bug tanpa ditanya:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/syamsul18782/server-xray-di-stb-armbian/main/install.sh) --domain aw.srpcom.cloud --bug support.zoom.us
```

---

## Fitur Utama
* **Ringan & Aman untuk STB Existing:** Tidak memasang Caddy, OpenVPN, L2TP, Dropbear, ataupun mengaktifkan UFW sehingga aman dijalankan berdampingan dengan layanan lain (WA Gateway, Cockpit, Nginx, dll.).
* **Kompatibel Penuh dengan Cloudflare Tunnel:** Konfigurasi inbound Xray tidak menggunakan `acceptProxyProtocol` agar langsung terhubung dengan `cloudflared`.
* **3 Protokol WebSocket Siap Pakai:**
  * `127.0.0.1:10001` → **VMess WS** (`/vmessws`)
  * `127.0.0.1:10002` → **VLESS WS** (`/vlessws`)
  * `127.0.0.1:10003` → **Trojan WS** (`/trojanws`)
* **CLI Manajemen Akun (`menu` / `xray-menu`):**
  * Tambah / Hapus / Perpanjang / List akun.
  * Otomatis menghasilkan **Link URI** dan **Format YAML OpenClash** (termasuk mode Bug Wildcard).
* **Auto-Expired Cron:** Otomatis menghapus akun yang sudah habis masa aktifnya setiap 1 jam.

---

## Konfigurasi Cloudflare Tunnel & DNS

Setelah instalasi selesai di STB baru:
1. Buat Tunnel di **Cloudflare Zero Trust → Networks → Tunnels** dan jalankan token `cloudflared` di STB.
2. Tambahkan **Public Hostname** di tunnel (atau edit `/etc/cloudflared/config.yml`, lihat [`templates/cloudflared-ingress.example.yml`](templates/cloudflared-ingress.example.yml)):
   * Hostname: `aw.srpcom.cloud` *(dan/atau `support.zoom.us.aw.srpcom.cloud` untuk mode Wildcard Bug)*
   * Path `/vmessws` → `HTTP` → `127.0.0.1:10001`
   * Path `/vlessws` → `HTTP` → `127.0.0.1:10002`
   * Path `/trojanws` → `HTTP` → `127.0.0.1:10003`
3. Pastikan record DNS CNAME di Cloudflare berstatus **Proxied (Awan Oranye)**.

---

## Cara Menggunakan CLI (`menu`)

Buka menu interaktif:
```bash
menu
# atau
xray-menu
```

Perintah cepat 1 baris:
```bash
# Tambah akun (isi 0 untuk Lifetime)
xray-menu add trojan user1 30
xray-menu add vless user2 0
xray-menu add vmess user3 30

# Lihat daftar akun
xray-menu list

# Hapus akun
xray-menu del user1
```

---

## Uninstall (Hapus Bersih)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/syamsul18782/server-xray-di-stb-armbian/main/uninstall.sh)
```
