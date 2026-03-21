# Strapi v5 Known Issues & Fixes

## Issue 1: JSON Schema Files Not Copied to dist/ (CRITICAL)

**Error**: `TypeError: Cannot read properties of undefined (reading 'kind')`
**Root cause**: Strapi TypeScript compiler (`@strapi/typescript-utils/lib/compilers/basic.js`) calls `program.emit()` which only outputs `.js` files. JSON schema files (`schema.json`) are never copied to `dist/src/api/`. Strapi loads content types from `dist/src/api/*/content-types/*/schema.json` — if missing, `strapi.contentType('api::event.event')` returns `undefined`, crashing on `.kind`.

**Fix**: Run `scripts/fix-compiler.js` before `npm run develop`. See that script for the patch.

Manual patch location: `node_modules/@strapi/typescript-utils/lib/compilers/basic.js`
After `program.emit()`, add:
```javascript
const path = require('path');
const fse = require('fs-extra');
const rootDir = compilerOptions.rootDir || path.dirname(tsConfigPath);
const outDir = compilerOptions.outDir;
if (rootDir && outDir) {
  const srcApiDir = path.join(rootDir, 'src');
  const distSrcDir = path.join(outDir, 'src');
  if (fse.existsSync(srcApiDir)) {
    fse.copySync(srcApiDir, distSrcDir, {
      filter: (src) => fse.statSync(src).isDirectory() || src.endsWith('.json'),
      overwrite: true,
    });
  }
}
```

---

## Issue 2: Route Auth Config Invalid

**Error**: `Error: Invalid route config config.auth must be a 'object' type, but the final value was: 'true'`
**Root cause**: Strapi v5 schema validator rejects `auth: true` (boolean). Must be `false` or an object.

**Fix**:
```typescript
// WRONG
config: { auth: true, middlewares: [] }

// CORRECT
config: { auth: { scope: [] }, middlewares: [] }
// Or for public routes:
config: { auth: false, middlewares: [] }
```

---

## Issue 3: TypeScript Strict Mode in Config Files

**Error**: `TS7031: Binding element 'env' implicitly has an 'any' type`
**Root cause**: `tsconfig.json` has `"strict": true`. Config files use `({ env }) =>` without explicit types.

**Fix**: Add `: { env: any }` to all 4 config files:
```typescript
// config/server.ts, database.ts, plugins.ts, admin.ts
export default ({ env }: { env: any }) => ({
  // ...
});
```

---

## Issue 4: Missing uploads Directory

**Error**: `Error: The upload folder doesn't exist or is not accessible`
**Root cause**: Strapi checks for `public/uploads/` on startup.

**Fix**:
```bash
mkdir -p public/uploads
```

---

## Issue 5: Raw SQL Migrations with UUID IDs

**Error**: `error: foreign key constraint "events_owner_lnk_fk" cannot be implemented`
**Root cause**: Custom SQL migrations created tables with `id uuid` (UUID primary key). Strapi ORM expects `id integer` (serial/bigint) and creates link tables (e.g., `events_owner_lnk`) with `event_id integer` FK — type mismatch causes FK constraint error.

**Fix**: Drop all custom tables and enum types, clear Strapi's schema cache, let ORM recreate:
```sql
DROP TABLE IF EXISTS event_groups CASCADE;
DROP TABLE IF EXISTS events CASCADE;
-- ... all other custom tables
DROP TYPE IF EXISTS event_category CASCADE;
-- ... all other custom types
DELETE FROM strapi_database_schema WHERE TRUE;
DELETE FROM strapi_migrations_internal WHERE TRUE;
```

**Rule**: Never use raw SQL migrations with UUID IDs. Let Strapi ORM manage schema entirely.

---

## Issue 6: Missing .dockerignore

**Symptom**: Docker build hangs, sends 879MB build context
**Root cause**: No `.dockerignore` → `node_modules` included in build context.

**Fix**: Create `.dockerignore`:
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

---

## Issue 7: esbuild Missing

**Error**: `Cannot find module 'esbuild'`
**Root cause**: Stale or incomplete `node_modules` install.

**Fix**:
```bash
npm install
```

---

## Issue 8: Build OOM on 2GB Lightsail / Low-RAM Server

**Symptom**: `v8::internal::V8::FatalProcessOutOfMemory` during `npm run build` (admin panel webpack crash)
**Root cause**: Strapi admin panel webpack build requires ~2GB+ RAM. Lightsail small_2_0 (2GB) + swap still not enough.

**Fix**: Build locally on Mac, rsync `dist/` to server. Never build on server.
```bash
# Local Mac
NODE_ENV=production npm run build

# Deploy dist to server
rsync -avz --exclude=node_modules --exclude=.env \
  -e "ssh -i ~/.ssh/lightsail-lichnha.pem" \
  ./dist/ ubuntu@18.142.220.104:/srv/lichnha/dist/

# Restart PM2
ssh -i ~/.ssh/lightsail-lichnha.pem ubuntu@18.142.220.104 "pm2 restart lichnha-backend"
```

---

## Issue 9: `claims` Scoping Error in try-catch

**Error**: `TS2304: Cannot find name 'claims'`
**Root cause**: Variable declared as `const claims = ...` inside `try {}` block, then referenced after the block.

**Fix**: Extract specific values inside try, declare outer vars before try:
```typescript
// WRONG
try { const claims = await verifyToken(t); }
if (claims.nonce) { ... }  // ❌ claims not in scope

// CORRECT
let tokenNonce: string | undefined;
try {
  const claims = await verifyToken(t);
  tokenNonce = claims.nonce;  // extract inside try
}
if (tokenNonce) { ... }  // ✅
```

---

## Issue 10: Missing firebase-admin import after user edits

**Error**: `TS2304: Cannot find name 'admin'`
**Root cause**: `import * as admin from 'firebase-admin'` was removed during user file edit.

**Fix**: Always keep this import in `auth-custom.ts` when `googleSignIn` handler is present:
```typescript
import * as admin from 'firebase-admin';
```
**Rule**: After any user edit to auth-custom.ts, run `npx tsc --noEmit` to catch missing imports.

---

## Issue 11: Extension Schema Overwrites Plugin Default Attributes (CRITICAL)

**Error**: `Undefined attribute level operator id` on `GET /users-permissions/advanced` → admin settings page crashes with "Cannot read properties of undefined (reading 'settings')"
**Root cause**: Strapi v5 loads plugin extension schemas using shallow spread:
```javascript
plugin.contentTypes[ctName].schema = {
  ...plugin.contentTypes[ctName].schema,  // default (has role, username, email, etc.)
  ...extendedSchema                         // extension (has custom fields)
};
```
The `attributes` key in the extension schema **completely overwrites** the default `attributes`. All default attributes (including `role`, the manyToOne relation to roles) are removed from ORM metadata.

Result: `meta.attributes['role']` is undefined → `count({ where: { role: { id: X } } })` fails because the object `{ id: X }` is passed to `processAttributeWhere(null, ...)` which then iterates its keys and rejects `id` as "not an operator".

**Fix**: Re-declare the `role` relation in `src/extensions/users-permissions/content-types/user/schema.json`:
```json
"role": {
  "type": "relation",
  "relation": "manyToOne",
  "target": "plugin::users-permissions.role",
  "inversedBy": "users",
  "configurable": false
}
```

**Rule**: When extending a plugin's content type schema, always include any relations from the original schema that you need to query by. The extension schema `attributes` key replaces (not merges with) the plugin's `attributes`.

---

## Issue 12: Plain SQL Tables Missing from Production DB

**Error**: `relation "refresh_tokens" does not exist`
**Root cause**: SQL migrations in `database/migrations/` are NOT automatically run by Strapi. They must be applied manually to the production database.

**Fix**: Run migrations manually via psql:
```bash
# Install psql on server
sudo apt-get install -y postgresql-client

# Run migration
PGPASSWORD=$DB_PASS psql "host=$DB_HOST dbname=$DB_NAME user=$DB_USER sslmode=require" \
  -f database/migrations/016_create_refresh_tokens.sql
```

**Rule**: After adding new SQL migration files, always apply them to production before deploying the code that uses them.
