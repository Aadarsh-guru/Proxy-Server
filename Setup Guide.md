# Proxy Server Setup Guide

This guide will help you set up the Proxy Server on an Ubuntu 24.04 environment, including Node.js, PM2, Nginx, SSL via Certbot with Cloudflare DNS, and auto-renewal.

## Prerequisites

- Ubuntu 24.04 server (or compatible)
- Git installed (`sudo apt install git`)
- Cloudflare API Token with DNS edit permissions
- Your wildcard domain (e.g., `*.workspaces.example.com`)
- SSH access to your server

## Steps

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd Proxy-Server
```

### 2. Configure Environment Variables

Copy `.env.sample` to `.env` and fill in your details:

```bash
cp .env.sample .env
```

Edit `.env`:

- `REDIS_URL`: Your Redis connection string
- `DOMAIN`: Your wildcard domain (e.g., `*.workspaces.example.com`)
- `CF_API_TOKEN`: Your Cloudflare API token
- `EMAIL`: Your email for SSL notifications

### 3. Make the Setup Script Executable

```bash
chmod +x setup.sh
```

### 4. Run the Setup Script

```bash
./setup.sh
```

> **Note:** You may be prompted for your password for `sudo` commands.

### 5. Verify Services

- **Proxy Server:** Should be running on port 8000 (managed by PM2)
- **Nginx:** Reverse proxy for HTTP and WebSocket traffic
- **SSL:** Wildcard certificate installed and auto-renewal enabled

### 6. Open Your App

Visit your subdomain (e.g., `https://abc.workspaces.example.com`) in your browser.

Or, from the terminal:

```bash
"$BROWSER" https://abc.workspaces.example.com
```

## Troubleshooting

- Check logs: `pm2 logs proxy-server`
- Nginx status: `sudo systemctl status nginx`
- Certbot renewal: `sudo certbot renew --dry-run`

## Updating

To update your app:

```bash
git pull
npm install
pm2 restart proxy-server
```

---