Perfect! Now that you have `apt` working, we can turn your minimal Debian server into a **full dev + portfolio hosting setup**. Let’s go **step by step**. I’ll explain the concepts, what commands to run, and why.

---

# 1️⃣ Set up a static IP

### What it is

A **static IP** is an IP address that **never changes** for your server.

Why it’s important:

* If you want to **access your server remotely** (SSH, VS Code, web apps)
* If you want to **forward ports on your router** for your portfolio
* So your domain (e.g., `stevenene.com`) points to the right machine consistently

Dynamic IP (default) changes whenever DHCP assigns a new address → bad for servers.

---

### How to set it up on Debian

1. Edit the network config:

```bash
sudo nano /etc/network/interfaces
```

Example for **Ethernet**:

```text
auto enp0s25
iface enp0s25 inet static
    address 192.168.1.50
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 1.1.1.1
```

> Replace:
>
> * `enp0s25` with your interface (`ip link show` to check)
> * `192.168.1.50` with desired static IP
> * `192.168.1.1` with your router

2. Restart networking:

```bash
sudo systemctl restart networking
```

3. Check IP:

```bash
ip a
```

---

# 2️⃣ Firewall setup

For a developer server:

* Only allow what you need (SSH, HTTP/HTTPS, maybe database)
* Block everything else

Debian’s simplest option: **ufw**

```bash
sudo apt update
sudo apt install ufw
```

Enable:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp   # HTTP for your portfolio
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
sudo ufw status
```

> Now your server is protected by default.

---

# 3️⃣ Connect to the internet wirelessly

Yes — you **can use Wi-Fi instead of Ethernet**.

Check your interfaces:

```bash
ip link
```

Look for something like `wlp2s0` — that’s Wi-Fi.

Install Wi-Fi tools:

```bash
sudo apt install wireless-tools wpasupplicant net-tools
```

Example config for `/etc/network/interfaces`:

```text
auto wlp2s0
iface wlp2s0 inet dhcp
    wpa-ssid "YourWiFiSSID"
    wpa-psk "YourWiFiPassword"
```

Then restart networking:

```bash
sudo systemctl restart networking
```

Check:

```bash
ping 8.8.8.8
```

✅ If it works, your server is online over Wi-Fi.

> **Tip**: Wi-Fi can be less stable than Ethernet for servers — if your portfolio is public, Ethernet is safer.

---

# 4️⃣ Install developer stack

Since you want **React + Python**, here’s a minimal setup:

### Python

```bash
sudo apt install python3 python3-pip python3-venv
```

### Node.js (for React)

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs
```

### Git

```bash
sudo apt install git
```

---

# 5️⃣ Portfolio hosting

You have options:

### Option A: Simple static React build

1. Build React app:

```bash
cd /home/steve/portfolio
npm run build
```

2. Serve with Nginx:

```bash
sudo apt install nginx
sudo cp -r build/* /var/www/html/
sudo systemctl restart nginx
```

Visit `http://<server-ip>` — your portfolio is live.

---

### Option B: React + Python backend

* React → served via Nginx
* Python → Flask / Django API on a port (e.g., 5000)
* Use **reverse proxy** with Nginx:

```nginx
server {
    listen 80;
    server_name stevenene.com;

    location / {
        root /var/www/html;
        index index.html index.htm;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Then:

```bash
sudo nginx -t
sudo systemctl restart nginx
```

---

# 6️⃣ Extra developer tools

* Docker + Docker Compose
* VS Code Remote SSH
* Postgres / MySQL if needed
* Certbot for HTTPS (`sudo apt install certbot python3-certbot-nginx`)

---

# ✅ Recommended sequence for your server

1. Set static IP → consistent network
2. Enable firewall → secure your ports
3. Ensure Wi-Fi works if you don’t want Ethernet
4. Install dev stack → Python, Node, Git
5. Serve your React portfolio → Nginx
6. Add optional backend → Python Flask/Django
7. Add Docker → containerize apps

---
