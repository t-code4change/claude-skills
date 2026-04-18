---
name: docs-remote
description: Tạo trang tài liệu kỹ thuật VitePress bằng tiếng Việt và deploy lên Vercel với password protection. Phân tích codebase tự động, viết đầy đủ docs (tổng quan, frontend, backend, API, database, deploy), tạo project Vercel mới. Dùng khi user nói "tạo tài liệu", "docs", "/docs-remote".
triggers:
  - "tạo tài liệu"
  - "docs-remote"
  - "viết docs"
  - "tạo docs"
  - "documentation"
references:
  - references/vitepress-config-template.md
  - references/login-page-template.md
  - references/deploy-steps.md
---

# docs-remote — Tạo Tài Liệu Kỹ Thuật & Deploy Vercel

Tự động phân tích codebase, tạo docs VitePress tiếng Việt, và deploy lên Vercel với password protection.

## Khi nào dùng

- User muốn tạo tài liệu kỹ thuật cho một project
- Command `/docs-remote` được gọi
- User nói "tạo docs", "viết tài liệu", "documentation"

## Quy trình thực hiện

### Bước 1 — Thu thập thông tin codebase

Dùng `Explore` agent hoặc đọc trực tiếp:

```
1. package.json (web + backend) → tech stack, version
2. src/app/ → routes, pages
3. src/components/ → components chính
4. prisma/schema.prisma hoặc db schema → database models
5. docker-compose.yml → deploy architecture
6. src/lib/ → key libs (auth, i18n, api)
7. README.md (nếu có)
```

**Output cần có:**
- Tên app, mô tả ngắn gọn
- Tech stack đầy đủ (FE + BE + DB + Deploy)
- Tất cả routes/pages
- Tính năng chính
- Cấu trúc database
- Auth flow
- Deploy architecture

### Bước 2 — Tạo thư mục docs

```bash
mkdir -p {project-name}-docs/docs/.vitepress
mkdir -p {project-name}-docs/docs/{tong-quan,bat-dau,frontend,backend,api,database,tinh-nang,deploy}
```

**Tham chiếu template:** `/Users/tuanpham/MyLife/travelwithme/travelwithme-docs/`

### Bước 3 — Tạo package.json

```json
{
  "name": "{project-name}-docs",
  "version": "1.0.0",
  "description": "Tài liệu kỹ thuật cho {App Name}",
  "scripts": {
    "docs:dev": "vitepress dev docs",
    "docs:build": "vitepress build docs",
    "docs:preview": "vitepress preview docs"
  },
  "devDependencies": {
    "vitepress": "^1.6.3"
  }
}
```

### Bước 4 — Tạo VitePress config

Đọc `references/vitepress-config-template.md` để lấy cấu trúc config chuẩn.

Các section sidebar cần có:
- 🎵/🗺️/[icon phù hợp] **Tổng quan** — gioi-thieu, tinh-nang, flow-su-dung, kien-truc-tong-quat
- 🚀 **Bắt đầu** — cai-dat, cau-truc-du-an, env-vars
- 🎨 **Frontend** — tong-quan, pages-routing, components, state-management, auth, i18n
- ⚙️ **Backend** — tong-quan, kien-truc, auth-jwt, websocket (nếu có), email
- 📡 **API Reference** — tong-quan + từng module API chính
- 🗄️ **Database** — schema, cac-bang, migrations
- 🎮 **Tính năng** — các feature đặc thù của app
- ☁️ **Deploy** — tong-quan, frontend, backend, blue-green (nếu có), nginx

### Bước 5 — Viết nội dung docs (tiếng Việt)

**QUAN TRỌNG:** Viết THẬT SỰ, không placeholder. Mỗi trang phải có:
- Giải thích rõ mục đích
- Code example cụ thể (copy từ codebase thật)
- Sơ đồ ASCII nếu cần
- Hướng dẫn step-by-step khi cần

Nội dung tối thiểu mỗi trang: 30-100 dòng markdown thực chất.

Tổng cộng: 35-50 trang docs.

### Bước 6 — Tạo login page & vercel.json

Đọc `references/login-page-template.md` để lấy HTML login page.

Password mặc định: `{project-name}2025` (ví dụ: `listenwithme2025`)

```bash
mkdir -p {project-name}-docs/docs/public
# Tạo login.html tại docs/public/login.html
# Tạo vercel.json với routes config
```

### Bước 7 — Build & Deploy

Đọc `references/deploy-steps.md` để xem đầy đủ các lệnh.

```bash
cd {project-name}-docs
npm install
npm run docs:build    # verify build thành công trước
vercel --yes          # tạo project mới nếu chưa có
vercel --prod         # deploy production
```

**Vercel project name:** `{project-name}-docs`

### Bước 8 — Report kết quả

Báo cáo cuối:
```
✅ Docs đã deploy:
URL: https://{project-name}-docs.vercel.app
🔑 Mật khẩu: {project-name}2025
📄 Số trang: XX trang tiếng Việt
```

## Rules quan trọng

1. **Luôn viết tiếng Việt** — toàn bộ nội dung docs
2. **Không placeholder** — mọi trang phải có nội dung thật
3. **Build trước khi deploy** — `npm run docs:build` phải pass
4. **Password = `{project-name}2025`** — nhất quán, dễ nhớ
5. **Vercel SSO không available trên free plan** — dùng cookie-based login page
6. **Tham chiếu travelwithme-docs** tại `/Users/tuanpham/MyLife/travelwithme/travelwithme-docs/` nếu cần xem format cụ thể

## Parallel agents

Khi viết docs, dùng nhiều agents song song để nhanh:
- Agent 1: tong-quan/ + bat-dau/
- Agent 2: frontend/ 
- Agent 3: backend/ + api/
- Agent 4: database/ + deploy/ + tinh-nang/
