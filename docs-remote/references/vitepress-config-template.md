# VitePress Config Template

Dùng template này cho `docs/.vitepress/config.mts`:

```typescript
import { defineConfig } from 'vitepress'

export default defineConfig({
  title: '{App Name} Docs',
  description: 'Tài liệu kỹ thuật cho {App Name} — dành cho dev mới onboard',
  lang: 'vi-VN',
  ignoreDeadLinks: true,

  themeConfig: {
    logo: '{emoji}',
    siteTitle: '{App Name}',

    nav: [
      { text: 'Tổng quan', link: '/tong-quan/gioi-thieu' },
      { text: 'Bắt đầu', link: '/bat-dau/cai-dat' },
      { text: 'Frontend', link: '/frontend/tong-quan' },
      { text: 'Backend', link: '/backend/tong-quan' },
      { text: 'API', link: '/api/tong-quan' },
      { text: 'Database', link: '/database/schema' },
      { text: 'Deploy', link: '/deploy/tong-quan' },
    ],

    sidebar: [
      {
        text: '{icon} Tổng quan',
        items: [
          { text: 'Giới thiệu dự án', link: '/tong-quan/gioi-thieu' },
          { text: 'Tính năng chính', link: '/tong-quan/tinh-nang' },
          { text: 'Flow sử dụng', link: '/tong-quan/flow-su-dung' },
          { text: 'Kiến trúc tổng quát', link: '/tong-quan/kien-truc-tong-quat' },
        ],
      },
      {
        text: '🚀 Bắt đầu',
        items: [
          { text: 'Cài đặt môi trường', link: '/bat-dau/cai-dat' },
          { text: 'Cấu trúc dự án', link: '/bat-dau/cau-truc-du-an' },
          { text: 'Biến môi trường', link: '/bat-dau/env-vars' },
        ],
      },
      {
        text: '🎨 Frontend',
        items: [
          { text: 'Tổng quan', link: '/frontend/tong-quan' },
          { text: 'Pages & Routing', link: '/frontend/pages-routing' },
          { text: 'Components', link: '/frontend/components' },
          { text: 'State Management', link: '/frontend/state-management' },
          { text: 'Xác thực (Auth)', link: '/frontend/auth' },
          { text: 'Đa ngôn ngữ (i18n)', link: '/frontend/i18n' },
        ],
      },
      {
        text: '⚙️ Backend',
        items: [
          { text: 'Tổng quan', link: '/backend/tong-quan' },
          { text: 'Kiến trúc', link: '/backend/kien-truc' },
          { text: 'Xác thực & JWT', link: '/backend/auth-jwt' },
          { text: 'WebSocket', link: '/backend/websocket' },
          { text: 'Email', link: '/backend/email' },
        ],
      },
      {
        text: '📡 API Reference',
        items: [
          { text: 'Tổng quan', link: '/api/tong-quan' },
          // Thêm từng module API theo app cụ thể
        ],
      },
      {
        text: '🗄️ Database',
        items: [
          { text: 'Schema tổng quan', link: '/database/schema' },
          { text: 'Các bảng dữ liệu', link: '/database/cac-bang' },
          { text: 'Migrations', link: '/database/migrations' },
        ],
      },
      {
        text: '☁️ Deploy',
        items: [
          { text: 'Tổng quan hạ tầng', link: '/deploy/tong-quan' },
          { text: 'Frontend (Vercel)', link: '/deploy/frontend-vercel' },
          { text: 'Backend (EC2 + Docker)', link: '/deploy/backend-ec2-docker' },
          { text: 'Blue/Green Deploy', link: '/deploy/blue-green' },
          { text: 'Nginx', link: '/deploy/nginx' },
        ],
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/t-code4change/{project-name}' },
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: '{App Name} — {tagline}',
    },
  },
})
```

## index.md homepage template

```markdown
---
layout: home

hero:
  name: "{App Name}"
  text: "Tài liệu kỹ thuật"
  tagline: Hướng dẫn dành cho dev mới onboard — từ tổng quan đến deploy production
  actions:
    - theme: brand
      text: Bắt đầu ngay
      link: /tong-quan/gioi-thieu
    - theme: alt
      text: API Reference
      link: /api/tong-quan
    - theme: alt
      text: Hướng dẫn cài đặt
      link: /bat-dau/cai-dat

features:
  - icon: {emoji}
    title: Tổng quan dự án
    details: Hiểu về {App Name} — {mô tả ngắn}, các tính năng cốt lõi và luồng sử dụng.
    link: /tong-quan/gioi-thieu

  - icon: 🎨
    title: Frontend ({framework})
    details: Kiến trúc, routing, components, state management, auth, i18n.
    link: /frontend/tong-quan

  - icon: ⚙️
    title: Backend ({framework})
    details: REST API + WebSocket, ORM, authentication, email, real-time.
    link: /backend/tong-quan

  - icon: 📡
    title: API Reference
    details: Toàn bộ endpoint với request/response format chi tiết.
    link: /api/tong-quan

  - icon: 🗄️
    title: Database Schema
    details: Sơ đồ ORM — các bảng, quan hệ, và migrations.
    link: /database/schema

  - icon: ☁️
    title: Deploy & Hạ tầng
    details: Deployment trên EC2, Docker Compose, Nginx, Vercel cho frontend.
    link: /deploy/tong-quan
---
```
