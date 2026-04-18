---
description: ⚡⚡⚡ Tạo tài liệu kỹ thuật VitePress tiếng Việt + deploy Vercel với password protection
argument-hint: "[project-path] [--password custom_pass] [--name project-name]"
---

Tạo tài liệu kỹ thuật hoàn chỉnh từ codebase và deploy lên Vercel.
<arguments>$ARGUMENTS</arguments>

## Parse Arguments

Từ arguments:
- `project-path`: đường dẫn tới project cần viết docs (mặc định: thư mục hiện tại)
- `--password`: mật khẩu bảo vệ docs (mặc định: `{project-name}2025`)
- `--name`: tên project docs (mặc định: tự detect từ package.json hoặc folder name)

## Kích hoạt skill docs-remote

Đọc và thực hiện đầy đủ theo skill `docs-remote` tại `.claude/skills/docs-remote/SKILL.md`.

## Quy trình nhanh

### 1. Phân tích codebase
Dùng `Explore` subagent để thu thập:
- Tech stack (package.json cả web lẫn backend)
- Routes và pages
- Components chính
- Database schema
- Deploy architecture
- Tính năng chính

### 2. Tạo cấu trúc docs song song
Spawn nhiều agents viết docs song song:
- **Agent 1**: `tong-quan/` + `bat-dau/` + `index.md` + config
- **Agent 2**: `frontend/` (tất cả pages)
- **Agent 3**: `backend/` + `api/`
- **Agent 4**: `database/` + `tinh-nang/` + `deploy/`

### 3. Tạo login page
- Đọc `docs-remote/references/login-page-template.md`
- Tạo `docs/public/login.html` với password `{project-name}2025`
- Tạo `vercel.json` với route `/login → /login.html`

### 4. Build & Deploy
```bash
cd {project-name}-docs
npm install
npm run docs:build   # verify trước
vercel --yes         # tạo project mới
vercel --prod        # deploy production
```

### 5. Report

Cuối cùng báo:
```
✅ Docs deployed!
🌐 URL: https://{project-name}-docs.vercel.app
🔑 Password: {project-name}2025
📄 XX trang tài liệu tiếng Việt
```

## Tham chiếu

- Skill: `docs-remote/SKILL.md`
- Config template: `docs-remote/references/vitepress-config-template.md`
- Login template: `docs-remote/references/login-page-template.md`
- Deploy guide: `docs-remote/references/deploy-steps.md`
- Ví dụ thực tế: `/Users/tuanpham/MyLife/me/listenwithme/listenwithme-docs/`
- Template tham chiếu: `/Users/tuanpham/MyLife/travelwithme/travelwithme-docs/`
