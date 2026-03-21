# Strapi v5 Code Patterns

## Content Type Schema (schema.json)
```json
{
  "kind": "collectionType",
  "collectionName": "events",
  "info": {
    "singularName": "event",
    "pluralName": "events",
    "displayName": "Event"
  },
  "options": { "draftAndPublish": false },
  "pluginOptions": {},
  "attributes": {
    "title": { "type": "string", "required": true },
    "startDate": { "type": "datetime" },
    "owner": {
      "type": "relation",
      "relation": "manyToOne",
      "target": "plugin::users-permissions.user",
      "inversedBy": "events"
    }
  }
}
```

**Important**: `schema.json` MUST be in `dist/src/api/<name>/content-types/<name>/schema.json` at runtime. The compiler patch (scripts/fix-compiler.js) handles this.

---

## Route Config (Strapi v5)

```typescript
// src/api/event/routes/event.ts
export default {
  routes: [
    {
      method: 'GET',
      path: '/events',
      handler: 'event.find',
      config: {
        auth: false,           // Public route
        middlewares: [],
      },
    },
    {
      method: 'POST',
      path: '/events',
      handler: 'event.create',
      config: {
        auth: { scope: [] },   // Authenticated — NOT auth: true
        middlewares: [],
      },
    },
  ],
};
```

**Rule**: `auth: true` is INVALID in Strapi v5. Use `auth: { scope: [] }` for authenticated routes.

---

## Custom Controller

```typescript
// src/api/event/controllers/event.ts
import { factories } from '@strapi/strapi';

export default factories.createCoreController('api::event.event', ({ strapi }) => ({
  async find(ctx) {
    const userId = ctx.state.user?.id;
    const { data, meta } = await super.find(ctx);
    return { data, meta };
  },

  async create(ctx) {
    const userId = ctx.state.user?.id;
    ctx.request.body.data = {
      ...ctx.request.body.data,
      owner: userId,
    };
    return super.create(ctx);
  },
}));
```

---

## Custom Service

```typescript
// src/api/event/services/event.ts
import { factories } from '@strapi/strapi';

export default factories.createCoreService('api::event.event', ({ strapi }) => ({
  async findByUser(userId: number) {
    return strapi.entityService.findMany('api::event.event', {
      filters: { owner: { id: userId } },
      populate: ['owner'],
      sort: { startDate: 'desc' },
    });
  },
}));
```

---

## Users-Permissions Route Extension

```typescript
// src/extensions/users-permissions/routes/auth-custom.ts
export default {
  routes: [
    {
      method: 'POST',
      path: '/auth/google/callback',
      handler: 'auth.callback',
      config: {
        auth: false,      // OAuth callbacks are always public
        middlewares: [],
      },
    },
    {
      method: 'POST',
      path: '/auth/refresh-token',
      handler: 'auth.refreshToken',
      config: {
        auth: { scope: [] },   // Requires valid JWT — NOT auth: true
        middlewares: [],
      },
    },
  ],
};
```

---

## Strapi v5 Key Directories

```
src/
  api/
    <name>/
      content-types/<name>/schema.json   ← MUST exist in dist/ too
      controllers/<name>.ts
      routes/<name>.ts
      services/<name>.ts
  extensions/
    users-permissions/
      routes/
      controllers/
      services/
config/
  admin.ts     ← ({ env }: { env: any }) =>
  database.ts  ← ({ env }: { env: any }) =>
  plugins.ts   ← ({ env }: { env: any }) =>
  server.ts    ← ({ env }: { env: any }) =>
public/
  uploads/     ← MUST exist (mkdir -p public/uploads)
```

---

## entityService vs db (Strapi v5)

```typescript
// Prefer entityService for full ORM support
await strapi.entityService.findMany('api::event.event', {
  filters: { owner: { id: userId } },
  populate: ['owner', 'groups'],
  sort: { startDate: 'asc' },
  limit: 100,
});

// db.query for raw queries only
await strapi.db.query('api::event.event').findMany({
  where: { owner: { id: userId } },
});
```

---

## Strapi v5 Internal Architecture Notes

- **Cluster mode**: `strapi develop` spawns a primary (cleans dist, compiles TS) and a worker (runs server)
- **Content type loading**: Worker loads `dist/src/api/*/content-types/*/schema.json` — if missing → `undefined` → crash
- **Link tables**: ORM creates `<entity>_owner_lnk`, `<entity>_<relation>_lnk` with INTEGER FK — must match Strapi's integer IDs
- **JWT plugin**: Configured via `config/plugins.ts` under `'users-permissions'.config.jwt`
