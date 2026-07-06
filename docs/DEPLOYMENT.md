# Deployment Guide

## Server Deployment

### Prerequisites
- Node.js 18+ or Docker 20+
- Domain name (for HTTPS)
- Minimum 1 CPU, 512MB RAM

### Option 1: Docker Compose (Recommended)

```bash
# Clone and configure
cd server
cp .env.example .env
nano .env  # Edit configuration

# Start with Caddy reverse proxy
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f chat-server
```

### Option 2: Direct Node.js

```bash
cd server
npm install
cp .env.example .env
# Edit .env with your settings

# Development
npm run dev

# Production
npm start
```

### Option 3: PM2 Process Manager

```bash
npm install -g pm2
pm2 start src/server.ts --name enc-chat --interpreter ts-node
pm2 save
pm2 startup
```

### Caddy Reverse Proxy (Production)

Edit `docker/Caddyfile`:
```
your-domain.com {
    reverse_proxy chat-server:3000
    auto_https on
    
    header {
        Strict-Transport-Security "max-age=31536000"
        X-Content-Type-Options nosniff
    }
}
```

## Server Configuration (.env)

```env
NODE_ENV=production
PORT=3000
MESSAGE_TTL_DAYS=7
MAX_FILE_SIZE=104857600
RATE_LIMIT_MAX_REQUESTS=100
CLEANUP_INTERVAL_MINUTES=60
LOG_LEVEL=warn
UPLOAD_DIR=./uploads
```

## Flutter App Configuration

### Update Server URL in App

Edit `app/lib/services/ws_service.dart`:
```dart
// Replace with your server URL
const String serverUrl = 'wss://your-domain.com/ws';
```

### Build Android APK

```bash
cd app
flutter build apk --release
flutter build appbundle --release
```

### Build iOS IPA

```bash
cd app
flutter build ios --release
```

### Build Windows Desktop

```bash
cd app
flutter build windows --release
```

## SSL/TLS Configuration

### Required
- TLS 1.2 minimum, 1.3 preferred
- Valid certificate from trusted CA
- HSTS enabled

### Certificate Options
1. **Let's Encrypt** (free): Auto-renew via Certbot
2. **Cloudflare Origin CA**: Free, integrated with CDN
3. **Commercial CA**: Paid, extended validation

## Monitoring

### Health Check Endpoint
```
GET https://your-domain.com/health
```

Response:
```json
{
  "status": "ok",
  "uptime": 3600,
  "rooms_active": 5,
  "clients_connected": 12
}
```

### Recommended Monitoring
- Uptime monitoring (UptimeRobot, Pingdom)
- Log aggregation (ELK, Loki)
- Error tracking (Sentry)
- Resource usage (Prometheus + Grafana)
