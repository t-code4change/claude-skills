# WebSocket & SSE Patterns

## Socket.io — Room-based Chat

```typescript
// src/socket/namespaces/chat.ts
import { Namespace, Socket } from 'socket.io';

interface ServerToClient {
  'message:new': (msg: Message) => void;
  'user:typing': (data: { userId: string }) => void;
  'room:joined': (data: { roomId: string; members: string[] }) => void;
}

interface ClientToServer {
  'join:room': (roomId: string, ack: (err?: string) => void) => void;
  'send:message': (data: { roomId: string; text: string }) => void;
  'start:typing': (roomId: string) => void;
}

export function registerChatHandlers(ns: Namespace<ClientToServer, ServerToClient>) {
  ns.on('connection', (socket) => {
    const userId = socket.data.userId; // set by auth middleware

    socket.on('join:room', async (roomId, ack) => {
      // Validate access
      const hasAccess = await checkRoomAccess(userId, roomId);
      if (!hasAccess) return ack('FORBIDDEN');

      await socket.join(roomId);
      const members = await getRoomMembers(roomId);
      socket.emit('room:joined', { roomId, members });
      ack(); // success
    });

    socket.on('send:message', async ({ roomId, text }) => {
      // Validate + save to DB
      const msg = await createMessage({ userId, roomId, text });
      // Broadcast to room (including sender)
      ns.to(roomId).emit('message:new', msg);
    });

    socket.on('start:typing', (roomId) => {
      // Broadcast to room except sender
      socket.to(roomId).emit('user:typing', { userId });
    });

    socket.on('disconnect', async () => {
      // Cleanup if needed
    });
  });
}
```

## Socket.io — Notification Broadcast

```typescript
// Send to specific user (user can have multiple sockets/tabs)
// Pattern: join personal room on connect
socket.on('connection', (socket) => {
  const userId = socket.data.userId;
  socket.join(`user:${userId}`); // personal room
});

// From anywhere in app:
io.to(`user:${userId}`).emit('notification:new', payload);

// From a queue worker:
appEvents.on('notification:send', ({ userId, payload }) => {
  io.to(`user:${userId}`).emit('notification:new', payload);
});
```

## SSE — Live Dashboard / Feed

```typescript
// src/sse/router.ts
import { Router } from 'express';
import { authMiddleware } from '../middleware/auth';
import { appEvents } from '../events/emitter';

const router = Router();

router.get('/events', authMiddleware, (req, res) => {
  const userId = (req as any).userId;

  // SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no'); // Nginx: disable buffering
  res.flushHeaders();

  // Send initial data
  res.write(`data: ${JSON.stringify({ type: 'connected', userId })}\n\n`);

  // Heartbeat (keep connection alive through proxies)
  const heartbeat = setInterval(() => {
    res.write(': heartbeat\n\n');
  }, 30_000);

  // Listen for events
  const onNotification = (data: any) => {
    if (data.userId === userId) {
      res.write(`event: notification\n`);
      res.write(`data: ${JSON.stringify(data.payload)}\n\n`);
    }
  };
  appEvents.on('notification:send', onNotification);

  // Cleanup on client disconnect
  req.on('close', () => {
    clearInterval(heartbeat);
    appEvents.off('notification:send', onNotification);
    res.end();
  });
});

export default router;
```

## Native WebSocket (ws library) — Simple cases

```typescript
import { WebSocketServer, WebSocket } from 'ws';

const wss = new WebSocketServer({ server: httpServer, path: '/ws' });

// Track clients by userId
const clients = new Map<string, Set<WebSocket>>();

wss.on('connection', (ws, req) => {
  const userId = validateToken(req); // parse from query or header
  if (!userId) return ws.close(4001, 'Unauthorized');

  if (!clients.has(userId)) clients.set(userId, new Set());
  clients.get(userId)!.add(ws);

  // Ping-pong to detect dead connections
  (ws as any).isAlive = true;
  ws.on('pong', () => { (ws as any).isAlive = true; });

  ws.on('close', () => {
    clients.get(userId)?.delete(ws);
  });
});

// Heartbeat check every 30s
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!(ws as any).isAlive) return ws.terminate();
    (ws as any).isAlive = false;
    ws.ping();
  });
}, 30_000);

// Send to user from anywhere
function sendToUser(userId: string, data: object) {
  clients.get(userId)?.forEach((ws) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(data));
    }
  });
}
```

## Dependencies

```json
{
  "dependencies": {
    "socket.io": "^4.7.0",
    "@socket.io/redis-adapter": "^8.3.0",
    "ws": "^8.17.0",
    "ioredis": "^5.3.2",
    "bullmq": "^5.7.0",
    "express": "^4.19.0",
    "jsonwebtoken": "^9.0.2"
  },
  "devDependencies": {
    "@types/ws": "^8.5.0",
    "@types/jsonwebtoken": "^9.0.0"
  }
}
```
