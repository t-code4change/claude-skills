# Deploy Steps

## Quy trình deploy đầy đủ

```bash
cd {project-name}-docs

# 1. Cài dependencies
npm install

# 2. Build (phải pass không lỗi)
npm run docs:build

# 3. Deploy preview (test trước)
vercel --yes

# 4. Deploy production
vercel --prod
```

## Vercel CLI output mong đợi

```
Linked to tf-reelancer/{project-name}-docs (created .vercel)
Production: https://{project-name}-docs.vercel.app
Aliased: https://{project-name}-docs.vercel.app
```

## Nếu project đã tồn tại trên Vercel

```bash
# Xóa project cũ qua dashboard hoặc CLI:
vercel remove {old-project-name} --yes

# Deploy mới
vercel --yes --name {project-name}-docs
vercel --prod
```

## Kiểm tra deploy

```bash
# Xem logs
vercel logs {project-name}-docs.vercel.app

# List deployments
vercel list

# Redeploy nếu cần
vercel --prod
```

## Cấu trúc output directory

VitePress build output tại: `docs/.vitepress/dist/`

vercel.json phải có:
```json
{
  "outputDirectory": "docs/.vitepress/dist"
}
```

## Thêm custom domain (optional)

```bash
vercel domains add docs.{app-domain}.com
vercel alias {project-name}-docs.vercel.app docs.{app-domain}.com
```

## Gitignore cho docs project

```
node_modules/
docs/.vitepress/dist/
docs/.vitepress/cache/
.vercel/
```
