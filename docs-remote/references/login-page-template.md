# Login Page Template

## vercel.json

```json
{
  "buildCommand": "npm run docs:build",
  "outputDirectory": "docs/.vitepress/dist",
  "installCommand": "npm install",
  "routes": [
    { "src": "/login", "dest": "/login.html" },
    { "src": "/(.*)", "dest": "/$1" }
  ]
}
```

## docs/public/login.html

Password mặc định: `{project-name}2025`

```html
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Đăng nhập — {App Name} Docs</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #0f0f1a;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      color: #e2e8f0;
    }
    .card {
      background: #1a1a2e;
      border: 1px solid #2d2d4e;
      border-radius: 16px;
      padding: 40px;
      width: 100%;
      max-width: 380px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.5);
    }
    .logo { font-size: 2rem; text-align: center; margin-bottom: 8px; }
    h1 { text-align: center; font-size: 1.25rem; font-weight: 700; margin-bottom: 4px; }
    .sub { text-align: center; font-size: 0.8rem; color: #64748b; margin-bottom: 28px; }
    label { display: block; font-size: 0.8rem; color: #94a3b8; margin-bottom: 6px; }
    input[type="password"] {
      width: 100%;
      padding: 10px 14px;
      background: #0f0f1a;
      border: 1px solid #2d2d4e;
      border-radius: 8px;
      color: #e2e8f0;
      font-size: 0.95rem;
      outline: none;
      transition: border-color 0.2s;
    }
    input[type="password"]:focus { border-color: #8b5cf6; }
    .error { font-size: 0.8rem; color: #f87171; margin-top: 8px; }
    button {
      width: 100%;
      margin-top: 20px;
      padding: 11px;
      background: #8b5cf6;
      border: none;
      border-radius: 8px;
      color: #fff;
      font-size: 0.95rem;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }
    button:hover { background: #7c3aed; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">{emoji}</div>
    <h1>{App Name} Docs</h1>
    <p class="sub">Tài liệu kỹ thuật nội bộ</p>
    <form id="form">
      <label for="pwd">Mật khẩu truy cập</label>
      <input type="password" id="pwd" name="password" placeholder="Nhập mật khẩu..." autofocus required>
      <div class="error" id="err" style="display:none">Mật khẩu không đúng. Thử lại.</div>
      <button type="submit">Truy cập tài liệu →</button>
    </form>
  </div>
  <script>
    const PASSWORD = '{project-name}2025'
    const COOKIE_NAME = 'docs-auth'
    const params = new URLSearchParams(location.search)
    if (params.get('error')) document.getElementById('err').style.display = 'block'
    document.getElementById('form').addEventListener('submit', function(e) {
      e.preventDefault()
      const pwd = document.getElementById('pwd').value
      if (pwd === PASSWORD) {
        document.cookie = COOKIE_NAME + '=' + PASSWORD + '; path=/; max-age=2592000; samesite=strict'
        location.href = params.get('next') || '/'
      } else {
        document.getElementById('err').style.display = 'block'
      }
    })
    if (document.cookie.includes(COOKIE_NAME + '=' + PASSWORD)) {
      location.href = params.get('next') || '/'
    }
  </script>
</body>
</html>
```

## middleware.js (Edge Middleware — optional, only if Vercel Pro)

Nếu account Vercel là Pro, có thể dùng Edge Middleware thay login page:

```js
export const config = {
  matcher: ['/((?!_vercel|login|favicon.ico).*)'],
}

export default function middleware(request) {
  const url = new URL(request.url)
  const cookie = request.cookies.get('docs-auth')
  const PASSWORD = '{project-name}2025'

  if (cookie?.value === PASSWORD) return

  const loginUrl = new URL('/login', request.url)
  loginUrl.searchParams.set('next', url.pathname)
  return Response.redirect(loginUrl, 302)
}
```

> **Note:** Vercel SSO & Password Protection yêu cầu Pro plan. Free plan dùng JavaScript cookie-based login ở trên.
