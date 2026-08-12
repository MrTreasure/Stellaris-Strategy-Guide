# Stellaris 银河战略档案

《Stellaris》4.4.6 Pegasus 的纯静态攻略阅读站。站点在构建时自动扫描 `content/开局攻略/` 与 `content/存档复盘/` 中的 Markdown，生成攻略列表、详情页、章节目录与浏览器端全文搜索。

## 内容与结构

- `content/开局攻略/`：16 篇开局攻略原文
- `content/存档复盘/`：实战复盘原文
- `app/`：Next.js App Router 路由
- `components/`：阅读卡片、Markdown 渲染、搜索组件
- `lib/guides.ts`：构建期内容扫描和元数据提取
- `public/images/`：深空背景和方舟主题图

Markdown 原文保留不改。新增攻略时，将 `.md` 放入上述任一内容目录，重新构建即可被发现并导出；开局攻略若文件以前导两位编号命名，会自动关联 README 中整理的难度和 DLC 标签。

## 本地开发

要求 Node.js 20.9 或更高版本。

```bash
npm install
npm run dev
```

打开 `http://localhost:3000`。生产静态构建：

```bash
npm run build
```

`next.config.mjs` 使用 `output: 'export'`，产物位于 `out/`，可由任意静态 Web 服务器托管，无需 Node.js 服务端。

## 部署到本机 nginx

```bash
npm run build
rsync -a --delete out/ /vol1/1000/nginx/public/stellaris-guide/
curl -H "Host: stellaris-guide.mrtreasure.cc" http://127.0.0.1:8080/
```

站点使用独立域名 `https://stellaris-guide.mrtreasure.cc/`，不部署到 `/resume/muse/` 路径。
