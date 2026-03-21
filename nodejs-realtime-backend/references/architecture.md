# Realtime Backend Architecture

## Project Structure

```
src/
├── index.ts              # App entry, attach socket server to HTTP
├── socket/
│   ├── index.ts          # Socket.io init, middleware, namespaces
│   ├── namespaces/
│   │   ├── chat.ts       # /chat namespace handlers
│   │   ├── notifications.ts
│   │   └── dashboard.ts
│   └── middleware/
│       └── auth.ts       # JWT validation on handshake
├── sse/
│   └── router.ts         # SSE endpoints (Express routes)
├── events/
│   ├── emitter.ts        # Internal EventEmitter (typed)
│   └── handlers/         # Business logic, separated from transport
├── queues/
│   ├── index.ts          # BullMQ setup
│   └── workers/          # Job processors
└── redis/
    └── client.ts         # Shared Redis connection
```

## Entry Point Pattern

```typescript
// src/index.ts
import express from 'express';
import { createServer } from 'http';
import { initSocket } from './socket';
import { redis } from './redis/client';

const app = express();
const httpServer = createServer(app);

// Attach Socket.io to same HTTP server (shares port)
initSocket(httpServer);

const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`Server listening on :${PORT}`);
});

// Graceful shutdown
const shutdown = async () => {
  httpServer.close();
  await redis.quit();
  process.exit(0);
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
```

## Socket.io Init

```typescript
// src/socket/index.ts
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';
import { authMiddleware } from './middleware/auth';
import { registerChatHandlers } from './namespaces/chat';

export function initSocket(httpServer: any) {
  const io = new Server(httpServer, {
    cors: { origin: process.env.ALLOWED_ORIGINS?.split(','), credentials: true },
    pingTimeout: 5000,
    pingInterval: 30000,
    transports: ['websocket', 'polling'], // websocket first
  });

  // Redis adapter (required for multi-instance)
  const pubClient = createClient({ url: process.env.REDIS_URL });
  const subClient = pubClient.duplicate();
  Promise.all([pubClient.connect(), subClient.connect()]).then(() => {
    io.adapter(createAdapter(pubClient, subClient));
  });

  // Global auth middleware
  io.use(authMiddleware);

  // Namespaces
  const chatNS = io.of('/chat');
  chatNS.use(authMiddleware);
  registerChatHandlers(chatNS);

  return io;
}
```

## Event-Driven Pattern

```typescript
// src/events/emitter.ts
import { EventEmitter } from 'events';

interface AppEvents {
  'user:joined': { userId: string; roomId: string };
  'message:created': { messageId: string; roomId: string };
  'notification:send': { userId: string; payload: object };
}

class TypedEmitter extends EventEmitter {
  emit<K extends keyof AppEvents>(event: K, data: AppEvents[K]): boolean {
    return super.emit(event as string, data);
  }
  on<K extends keyof AppEvents>(event: K, listener: (data: AppEvents[K]) => void): this {
    return super.on(event as string, listener);
  }
}

export const appEvents = new TypedEmitter();
```

## BullMQ Queue Pattern

```typescript
// src/queues/index.ts
import { Queue, Worker } from 'bullmq';
import { redis } from '../redis/client';

const connection = { host: process.env.REDIS_HOST, port: Number(process.env.REDIS_PORT) };

export const notificationQueue = new Queue('notifications', { connection });

// Worker
new Worker('notifications', async (job) => {
  const { userId, payload } = job.data;
  // Send push, email, etc.
  console.log(`Processing notification for ${userId}`);
}, { connection, concurrency: 5 });
```
