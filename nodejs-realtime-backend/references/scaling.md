# Horizontal Scaling — Redis Pub/Sub

## Problem Without Redis Adapter

```
Instance A: user connected → socket in memory
Instance B: io.emit('notification') → only reaches Instance B's sockets
Result: User on Instance A never receives the event ❌
```

## Socket.io Redis Adapter (Required for Multi-Instance)

```typescript
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';

const pubClient = createClient({ url: process.env.REDIS_URL });
const subClient = pubClient.duplicate();

await Promise.all([pubClient.connect(), subClient.connect()]);
io.adapter(createAdapter(pubClient, subClient));
// Now io.to(room).emit() works across all instances ✅
```

## Raw Redis Pub/Sub (Cross-Service)

```typescript
// Publisher (any service)
import { createClient } from 'redis';
const pub = createClient({ url: process.env.REDIS_URL });
await pub.connect();

await pub.publish('notifications', JSON.stringify({
  userId: '123',
  payload: { title: 'New message', body: 'You have mail' }
}));

// Subscriber (realtime service)
const sub = createClient({ url: process.env.REDIS_URL });
await sub.connect();

sub.subscribe('notifications', (message) => {
  const { userId, payload } = JSON.parse(message);
  io.to(`user:${userId}`).emit('notification:new', payload);
});
```

## BullMQ — Async Job Queue

```typescript
import { Queue, Worker, QueueEvents } from 'bullmq';

const connection = { host: process.env.REDIS_HOST!, port: 6379 };

// Producer (add job)
const emailQueue = new Queue('emails', { connection });
await emailQueue.add('send-welcome', { userId, email }, {
  attempts: 3,
  backoff: { type: 'exponential', delay: 1000 },
  removeOnComplete: 100, // keep last 100
  removeOnFail: 500,
});

// Consumer (worker)
new Worker('emails', async (job) => {
  if (job.name === 'send-welcome') {
    await sendEmail(job.data.email, 'Welcome!');
  }
}, { connection, concurrency: 10 });

// Monitor events
const queueEvents = new QueueEvents('emails', { connection });
queueEvents.on('completed', ({ jobId }) => {
  console.log(`Job ${jobId} done`);
});
queueEvents.on('failed', ({ jobId, failedReason }) => {
  console.error(`Job ${jobId} failed: ${failedReason}`);
});
```

## Docker Compose (Dev)

```yaml
# docker-compose.yml
services:
  app:
    build: .
    ports: ['3000:3000']
    environment:
      REDIS_URL: redis://redis:6379
    depends_on: [redis]
    deploy:
      replicas: 2  # Test multi-instance locally

  redis:
    image: redis:7-alpine
    ports: ['6379:6379']
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data

volumes:
  redis-data:
```

## Load Balancer (Nginx) — Sticky Sessions for WebSocket

```nginx
upstream realtime_backend {
  # Sticky sessions: same client → same instance (needed for polling fallback)
  ip_hash;
  server app1:3000;
  server app2:3000;
}

server {
  listen 80;

  location /socket.io/ {
    proxy_pass http://realtime_backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
    proxy_read_timeout 86400s; # Keep WS alive
  }

  location /events {
    proxy_pass http://realtime_backend;
    proxy_buffering off;           # SSE: disable buffering
    proxy_set_header X-Accel-Buffering no;
    proxy_cache off;
    proxy_read_timeout 3600s;      # SSE: long-lived connection
  }
}
```

## Redis Best Practices

- Use `ioredis` (not `redis` package) for clustering + sentinel support
- Separate pub/sub clients from data clients (blocking subscribe)
- Set `maxmemory-policy allkeys-lru` for cache use cases
- Monitor with `redis-cli monitor` or RedisInsight
