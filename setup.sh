#!/bin/bash
set -e

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Extract base domain from wildcard (e.g., "*.example.com" -> "example.com")
BASE_DOMAIN=$(echo "$DOMAIN" | sed 's/^\*\.\(.*\)$/\1/')

# Update & upgrade system
sudo apt update && sudo apt upgrade -y
sudo apt update

# Install Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# Install Nginx
sudo apt install -y nginx

# Configure Nginx for HTTP + WebSocket reverse proxy
sudo tee /etc/nginx/sites-available/proxy-server <<EOF
server {
    listen 80;
    server_name *.${BASE_DOMAIN};

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/proxy-server /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Install Certbot & Cloudflare plugin
sudo apt install -y certbot python3-certbot-nginx python3-certbot-dns-cloudflare

# Prepare Cloudflare credentials file
CF_CREDS="/etc/letsencrypt/cloudflare.ini"
sudo tee $CF_CREDS <<EOF
dns_cloudflare_api_token = ${CF_API_TOKEN}
EOF
sudo chmod 600 $CF_CREDS

# Obtain wildcard SSL certificate (only *.example.com)
if [ -n "$BASE_DOMAIN" ] && [ -n "$CF_API_TOKEN" ]; then
  sudo certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials $CF_CREDS \
    -d "*.${BASE_DOMAIN}" \
    --non-interactive --agree-tos --email "${EMAIL:-admin@$BASE_DOMAIN}"
  # Configure Nginx to use SSL
  sudo tee /etc/nginx/sites-available/proxy-server <<EOF
server {
    listen 443 ssl;
    server_name *.${BASE_DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${BASE_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${BASE_DOMAIN}/privkey.pem;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
server {
    listen 80;
    server_name *.${BASE_DOMAIN};
    return 301 https://\$host\$request_uri;
}
EOF
  sudo nginx -t && sudo systemctl reload nginx
fi

# Setup auto-renewal
sudo systemctl enable certbot.timer

# Install PM2 globally
sudo npm install -g pm2

# Install project dependencies
npm install

# Build source code if build script exists
if [ -f package.json ] && grep -q '"build"' package.json; then
  npm run build
fi

# Start app with PM2 (non-blocking, non-interactive)
pm2 start npm --name "proxy-server" -- start
pm2 save
pm2 startup systemd -u $USER --hp $HOME --no-daemon

echo "Setup complete!"