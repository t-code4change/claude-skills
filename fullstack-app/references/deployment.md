# Deployment Guide

## docker-compose.yml

```yaml
x-app-common: &app-common
  build: .
  restart: always
  environment:
    - NODE_ENV=production
    - PORT=3000
    - DATABASE_URL=postgresql://myapp:${DB_PASSWORD}@postgres:5432/myapp?connection_limit=25&pool_timeout=10&connect_timeout=10
    - REDIS_URL=redis://redis:6379
    - JWT_SECRET=${JWT_SECRET}
    - FRONTEND_URL=${FRONTEND_URL}
    - APP_URL=${APP_URL}
    - AWS_REGION=${AWS_REGION:-ap-southeast-2}
    - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    - EMAIL_FROM=${EMAIL_FROM}
    - FIREBASE_SERVICE_ACCOUNT=${FIREBASE_SERVICE_ACCOUNT}
    - DISCORD_ERROR_WEBHOOK=${DISCORD_ERROR_WEBHOOK}
    - DISCORD_DEPLOY_WEBHOOK=${DISCORD_DEPLOY_WEBHOOK}
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy
  networks:
    - app

services:
  api-blue:
    <<: *app-common
    ports: ["127.0.0.1:3001:3000"]
    deploy:
      resources:
        limits: { memory: 1.5G, cpus: '1.5' }

  api-green:
    <<: *app-common
    ports: ["127.0.0.1:3002:3000"]
    deploy:
      resources:
        limits: { memory: 1.5G, cpus: '1.5' }

  ws-blue:
    <<: *app-common
    ports: ["127.0.0.1:3004:3003"]
    environment:
      - NODE_ENV=production
      - PORT=3003
      - DATABASE_URL=postgresql://myapp:${DB_PASSWORD}@postgres:5432/myapp?connection_limit=10
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    command: ["./startup-ws.sh"]
    deploy:
      resources:
        limits: { memory: 1G, cpus: '1.0' }

  ws-green:
    <<: *app-common
    ports: ["127.0.0.1:3005:3003"]
    environment:
      - NODE_ENV=production
      - PORT=3003
      - DATABASE_URL=postgresql://myapp:${DB_PASSWORD}@postgres:5432/myapp?connection_limit=10
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    command: ["./startup-ws.sh"]
    deploy:
      resources:
        limits: { memory: 1G, cpus: '1.0' }

  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=myapp
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myapp"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks: [app]
    deploy:
      resources:
        limits: { memory: 1G, cpus: '0.5' }

  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --maxmemory 200mb --maxmemory-policy allkeys-lru
    volumes: [redis_data:/data]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks: [app]
    deploy:
      resources:
        limits: { memory: 256M, cpus: '0.25' }

volumes:
  postgres_data:
  redis_data:

networks:
  app:
    driver: bridge
```

## Dockerfile

```dockerfile
FROM node:20-alpine
RUN apk add --no-cache openssl libc6-compat
WORKDIR /app
COPY package*.json ./
RUN npm ci --legacy-peer-deps
COPY . .
RUN npx prisma generate && npm run build
EXPOSE 3000
COPY startup.sh startup-ws.sh ./
RUN chmod +x startup.sh startup-ws.sh
CMD ["./startup.sh"]
```

## startup.sh

```bash
#!/bin/sh
set -e
echo "[startup] Running Prisma migrations..."
npx prisma migrate deploy
echo "[startup] Starting API server..."
exec node dist/app.js
```

## startup-ws.sh

```bash
#!/bin/sh
set -e
echo "[startup-ws] Starting WebSocket server..."
exec node dist/ws-server.js
```

## deploy.sh (Blue-green API — zero-downtime)

```bash
#!/bin/bash
set -e
REPO_DIR="/home/ubuntu/my-app"
UPSTREAM_FILE="/etc/nginx/my-app-upstream.conf"
echo "=== Deploy API $(date) ==="
cd "$REPO_DIR"

if grep -q "3001" "$UPSTREAM_FILE" 2>/dev/null; then
  ACTIVE=blue; ACTIVE_PORT=3001; NEW=green; NEW_PORT=3002
else
  ACTIVE=green; ACTIVE_PORT=3002; NEW=blue; NEW_PORT=3001
fi

echo "--- $ACTIVE(:$ACTIVE_PORT) → $NEW(:$NEW_PORT)"
git pull origin main
docker compose build "api-$NEW"
docker compose up -d "api-$NEW"

for i in $(seq 1 60); do
  curl -sf "http://127.0.0.1:$NEW_PORT/health" > /dev/null && echo "Healthy (${i}s)" && break
  [ "$i" -eq 60 ] && echo "FAIL — rolling back" && docker compose stop "api-$NEW" && docker compose rm -f "api-$NEW" && exit 1
  sleep 1
done

echo "server 127.0.0.1:$NEW_PORT;" > "$UPSTREAM_FILE"
sudo nginx -s reload
sleep 3
docker compose stop "api-$ACTIVE" && docker compose rm -f "api-$ACTIVE"
echo "=== Done: api-$NEW(:$NEW_PORT) ==="
```

## deploy-ws.sh (Blue-green WS — 30s graceful drain)

```bash
#!/bin/bash
set -e
REPO_DIR="/home/ubuntu/my-app"
WS_UPSTREAM_FILE="/etc/nginx/my-app-ws-upstream.conf"
echo "=== Deploy WS $(date) ==="
cd "$REPO_DIR"

if grep -q "3004" "$WS_UPSTREAM_FILE" 2>/dev/null; then
  ACTIVE=blue; ACTIVE_PORT=3004; NEW=green; NEW_PORT=3005
else
  ACTIVE=green; ACTIVE_PORT=3005; NEW=blue; NEW_PORT=3004
fi

git pull origin main
docker compose build "ws-$NEW"
docker compose up -d "ws-$NEW"

for i in $(seq 1 30); do
  curl -sf "http://127.0.0.1:$NEW_PORT/health" > /dev/null && echo "Healthy (${i}s)" && break
  [ "$i" -eq 30 ] && docker compose stop "ws-$NEW" && docker compose rm -f "ws-$NEW" && exit 1
  sleep 1
done

echo "server 127.0.0.1:$NEW_PORT;" > "$WS_UPSTREAM_FILE"
sudo nginx -s reload
echo "--- Draining ws-$ACTIVE (30s graceful)..."
sleep 30
docker compose stop "ws-$ACTIVE" && docker compose rm -f "ws-$ACTIVE"
echo "=== Done: ws-$NEW(:$NEW_PORT) ==="
```

## Nginx Site Config (`/etc/nginx/sites-enabled/api.example.com`)

```nginx
upstream my_app {
  include /etc/nginx/my-app-upstream.conf;
  keepalive 32;
}
upstream my_app_ws {
  include /etc/nginx/my-app-ws-upstream.conf;
}

server {
  listen 443 ssl;
  server_name api.example.com;
  ssl_certificate /etc/letsencrypt/live/api.example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/api.example.com/privkey.pem;

  location /ws {
    proxy_pass http://my_app_ws;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 3600s;
  }

  location / {
    proxy_pass http://my_app;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}

server {
  listen 80;
  server_name api.example.com;
  return 301 https://$host$request_uri;
}
```

Init upstream files:
```bash
sudo bash -c 'echo "server 127.0.0.1:3001;" > /etc/nginx/my-app-upstream.conf'
sudo bash -c 'echo "server 127.0.0.1:3004;" > /etc/nginx/my-app-ws-upstream.conf'
```

## GitHub Actions deploy.yml

```yaml
name: Deploy
on:
  push:
    branches: [main]
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.2.0
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          command_timeout: 8m
          script: bash /home/ubuntu/my-app/deploy.sh

      - name: Notify Discord
        if: always()
        env:
          STATUS: ${{ job.status }}
          MSG: ${{ github.event.head_commit.message }}
          SHA: ${{ github.sha }}
          WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}
        run: |
          TITLE=$( [ "$STATUS" = "success" ] && echo "✅ Deploy succeeded" || echo "❌ Deploy failed" )
          COLOR=$( [ "$STATUS" = "success" ] && echo 3066993 || echo 15158332 )
          curl -s -X POST -H "Content-Type: application/json" \
            -d "{\"embeds\":[{\"title\":\"$TITLE\",\"color\":$COLOR,\"fields\":[{\"name\":\"Commit\",\"value\":\"${SHA:0:7}: $MSG\"}]}]}" \
            "$WEBHOOK"
```

## EC2 Initial Setup Checklist

```bash
# 1. Install dependencies
sudo apt update && sudo apt install -y docker.io docker-compose-v2 nginx certbot python3-certbot-nginx
sudo usermod -aG docker ubuntu && sudo systemctl enable --now docker

# 2. Clone repo
git clone git@github.com:YOUR_ORG/my-app-backend.git ~/my-app
cd ~/my-app && cp .env.example .env && nano .env

# 3. Init nginx upstream files
sudo bash -c 'echo "server 127.0.0.1:3001;" > /etc/nginx/my-app-upstream.conf'
sudo bash -c 'echo "server 127.0.0.1:3004;" > /etc/nginx/my-app-ws-upstream.conf'

# 4. Copy nginx site config, get SSL cert
sudo certbot --nginx -d api.example.com

# 5. Allow deploy.sh to reload nginx without sudo password prompt
echo "ubuntu ALL=(ALL) NOPASSWD: /usr/sbin/nginx" | sudo tee /etc/sudoers.d/ubuntu-nginx

# 6. First deploy
docker compose build && docker compose up -d api-blue ws-blue postgres redis
```

## GitHub Secrets Required

| Secret | Value |
|--------|-------|
| `EC2_HOST` | EC2 public IP |
| `EC2_USER` | `ubuntu` |
| `EC2_SSH_KEY` | Private SSH key (PEM) |
| `DISCORD_WEBHOOK` | Discord webhook URL (optional) |
