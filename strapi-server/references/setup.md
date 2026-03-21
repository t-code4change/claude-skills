# Strapi v5 Setup Guide (Zero to Running)

## Prerequisites
- Node.js 18+, npm
- PostgreSQL instance (local or AWS RDS)
- AWS CLI (if using RDS)

---

## Step 1: AWS RDS PostgreSQL Setup (skip if using local DB)

```bash
# Create security group allowing port 5432
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' --output text --region ap-southeast-1)

SG_ID=$(aws ec2 create-security-group \
  --group-name strapi-db-sg \
  --description "Allow PostgreSQL access" \
  --vpc-id $VPC_ID \
  --region ap-southeast-1 \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 5432 --cidr 0.0.0.0/0 \
  --region ap-southeast-1

# Create RDS instance (db.t4g.micro ~$13/month in ap-southeast-1)
aws rds create-db-instance \
  --db-instance-identifier myapp-db \
  --db-instance-class db.t4g.micro \
  --engine postgres \
  --engine-version 16.6 \
  --master-username myapp \
  --master-user-password "MyPassword123!" \
  --allocated-storage 20 \
  --storage-type gp2 \
  --vpc-security-group-ids $SG_ID \
  --no-multi-az \
  --publicly-accessible \
  --region ap-southeast-1

# Wait for it to be available (~5-10 min)
aws rds wait db-instance-available \
  --db-instance-identifier myapp-db \
  --region ap-southeast-1

# Get endpoint
aws rds describe-db-instances \
  --db-instance-identifier myapp-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text --region ap-southeast-1

# Create database
psql "host=<ENDPOINT> user=myapp password=MyPassword123!" \
  -c "CREATE DATABASE myapp;"
```

### RDS Notes
- db.t4g.micro = ARM Graviton2, ~$13/month in ap-southeast-1, no free tier
- db.t3.micro = x86, same price range, free tier eligible
- One RDS instance can host multiple databases for different projects (cost-efficient)
- Always enable `DATABASE_SSL=true` with RDS

---

## Step 2: Configure .env

```bash
HOST=0.0.0.0
PORT=1337
APP_KEYS=key1,key2,key3,key4
API_TOKEN_SALT=your-salt
ADMIN_JWT_SECRET=your-secret
TRANSFER_TOKEN_SALT=your-transfer-salt
JWT_SECRET=your-jwt-secret
ACCESS_TOKEN_EXPIRY_MINUTES=15

DATABASE_HOST=<RDS_ENDPOINT_OR_LOCALHOST>
DATABASE_PORT=5432
DATABASE_NAME=myapp
DATABASE_USERNAME=myapp
DATABASE_PASSWORD=MyPassword123!
DATABASE_SSL=true   # true for RDS, false for local
```

Generate random secrets:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

---

## Step 3: Pre-flight Fixes (ALWAYS run before first `npm run develop`)

```bash
# Install deps
npm install

# Create required directory
mkdir -p public/uploads

# Apply JSON schema compiler patch (CRITICAL — see known-issues.md #1)
node ~/.claude/skills/strapi-server/scripts/fix-compiler.js
```

---

## Step 4: Fix Config Files

Add `: { env: any }` type to all `config/*.ts` files:

```typescript
// config/server.ts
export default ({ env }: { env: any }) => ({
  host: env('HOST', '0.0.0.0'),
  port: env.int('PORT', 1337),
  app: { keys: env.array('APP_KEYS') },
});

// config/database.ts
export default ({ env }: { env: any }) => ({
  connection: {
    client: 'postgres',
    connection: {
      host: env('DATABASE_HOST', '127.0.0.1'),
      port: env.int('DATABASE_PORT', 5432),
      database: env('DATABASE_NAME', 'myapp'),
      user: env('DATABASE_USERNAME', 'myapp'),
      password: env('DATABASE_PASSWORD', ''),
      ssl: env.bool('DATABASE_SSL', false) ? { rejectUnauthorized: false } : false,
    },
    pool: { min: 2, max: 10 },
  },
});

// config/admin.ts
export default ({ env }: { env: any }) => ({
  auth: { secret: env('ADMIN_JWT_SECRET') },
  apiToken: { salt: env('API_TOKEN_SALT') },
  transfer: { token: { salt: env('TRANSFER_TOKEN_SALT') } },
});

// config/plugins.ts
export default ({ env }: { env: any }) => ({
  'users-permissions': {
    config: {
      jwt: { expiresIn: `${env.int('ACCESS_TOKEN_EXPIRY_MINUTES', 15)}m` },
    },
  },
});
```

---

## Step 5: Run

```bash
npm run develop
```

Expected: Server starts at `http://localhost:1337`, admin at `http://localhost:1337/admin`

Verify API works:
```bash
curl http://localhost:1337/api/events
# Should return 401/403 (auth required) — NOT 500
```

---

## Docker Setup

Create `.dockerignore` (REQUIRED):
```
node_modules
dist
.cache
build
*.log
.DS_Store
.env
exports/
```

`Dockerfile` example:
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 1337
CMD ["npm", "start"]
```

---

## Documentation Plugin (Swagger UI)

```bash
npm install @strapi/plugin-documentation
```

Add to `config/plugins.ts`:
```typescript
documentation: {
  enabled: true,
  config: {
    openapi: '3.0.0',
    info: {
      version: '1.0.0',
      title: 'My API',
      description: 'API description',
    },
    'x-strapi-config': {
      mutateDocumentation: (draft: any) => {
        draft.components.securitySchemes = {
          bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
        };
        draft.security = [{ bearerAuth: [] }];
        return draft;
      },
    },
  },
},
```

Access at: `http://localhost:1337/documentation`

---

## Google OAuth config in plugins.ts (built-in web flow)

```typescript
google: {
  enabled: true,
  key: env('GOOGLE_CLIENT_ID', ''),
  secret: env('GOOGLE_CLIENT_SECRET', ''),
  callback: env('GOOGLE_CALLBACK_URL', 'lichnha://auth/callback'),
  scope: ['email', 'profile'],
},
```

Required in Google Cloud Console:
- Authorized redirect URI: `https://your-domain.com/api/connect/google/callback`
- Authorized JS origin: `https://your-domain.com`

---

## Lightsail Production Deploy (deploy.sh)

Script at `HomeCalendarBackend/deploy.sh`. SSH key: `~/.ssh/lightsail-lichnha.pem`

Key rule: **Always build locally, never on server** (OOM on 2GB RAM).

PM2 app name: `lichnha-backend`, app dir: `/srv/lichnha/`
