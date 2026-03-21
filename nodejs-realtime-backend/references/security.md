# Realtime Backend Security

## JWT Auth on WebSocket Handshake

```typescript
// src/socket/middleware/auth.ts
import { Socket } from 'socket.io';
import jwt from 'jsonwebtoken';

export function authMiddleware(socket: Socket, next: (err?: Error) => void) {
  // Option A: Token in handshake.auth (recommended for Socket.io)
  const token = socket.handshake.auth.token
    // Option B: Bearer in headers (HTTP upgrade headers)
    ?? socket.handshake.headers.authorization?.split(' ')[1]
    // Option C: Query param (less secure, shows in logs)
    ?? socket.handshake.query.token as string;

  if (!token) return next(new Error('AUTH_MISSING'));

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as { sub: string };
    socket.data.userId = payload.sub; // attach to socket
    next();
  } catch {
    next(new Error('AUTH_INVALID'));
  }
}
```

```typescript
// Client side (Socket.io)
const socket = io('https://api.example.com/chat', {
  auth: { token: localStorage.getItem('jwt') },
});
```

## SSE Auth (Express Middleware)

```typescript
// src/middleware/auth.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'AUTH_MISSING' });

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as { sub: string };
    (req as any).userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: 'AUTH_INVALID' });
  }
}
```

## Rate Limiting

```typescript
// Socket.io: limit events per socket
const rateLimits = new Map<string, { count: number; reset: number }>();

socket.use(([event, ...args], next) => {
  const key = `${socket.id}:${event}`;
  const now = Date.now();
  const limit = rateLimits.get(key) ?? { count: 0, reset: now + 1000 };

  if (now > limit.reset) { limit.count = 0; limit.reset = now + 1000; }
  limit.count++;
  rateLimits.set(key, limit);

  if (limit.count > 20) return next(new Error('RATE_LIMIT')); // 20 events/sec
  next();
});

// SSE / HTTP: use express-rate-limit
import rateLimit from 'express-rate-limit';
app.use('/events', rateLimit({ windowMs: 60_000, max: 5 })); // 5 SSE connections/min
```

## Input Validation

```typescript
import { z } from 'zod';

const MessageSchema = z.object({
  roomId: z.string().uuid(),
  text: z.string().min(1).max(2000),
});

socket.on('send:message', (data) => {
  const result = MessageSchema.safeParse(data);
  if (!result.success) return socket.emit('error', { code: 'INVALID_INPUT' });

  const { roomId, text } = result.data;
  // safe to use
});
```

## Room Authorization

```typescript
// Check DB before joining a room — never trust client-provided roomId
socket.on('join:room', async (roomId, ack) => {
  const userId = socket.data.userId;
  const member = await db.groupMember.findFirst({
    where: { groupId: roomId, userId },
  });
  if (!member) return ack('FORBIDDEN');
  await socket.join(roomId);
  ack();
});
```

## Connection Limits

```typescript
// Limit concurrent sockets per user
const userSocketCount = new Map<string, number>();

io.on('connection', (socket) => {
  const userId = socket.data.userId;
  const count = (userSocketCount.get(userId) ?? 0) + 1;

  if (count > 5) { // max 5 tabs/devices
    socket.emit('error', { code: 'TOO_MANY_CONNECTIONS' });
    return socket.disconnect();
  }

  userSocketCount.set(userId, count);
  socket.on('disconnect', () => {
    const n = (userSocketCount.get(userId) ?? 1) - 1;
    if (n <= 0) userSocketCount.delete(userId);
    else userSocketCount.set(userId, n);
  });
});
```

## CORS

```typescript
const io = new Server(httpServer, {
  cors: {
    origin: (origin, callback) => {
      const allowed = process.env.ALLOWED_ORIGINS!.split(',');
      if (!origin || allowed.includes(origin)) callback(null, true);
      else callback(new Error('CORS_BLOCKED'));
    },
    credentials: true,
  },
});
```
