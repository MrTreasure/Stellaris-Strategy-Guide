# Codex 任务：Stellaris 攻略站点生成

## 项目背景

本地已克隆仓库：`/vol1/picoclaw/home/workspace/stellaris-strategy-guide/`
这是一个《群星》（Stellaris）4.4.6 版本的策略攻略库，包含：

- `开局攻略/` — 16 篇 Markdown 攻略（00-15，每篇 10-15KB，有固定章节结构：核心优势/成型理论/前三个生产中心/凝聚力预算/传统树/飞升槽/阶段转型/翻车条件/检查表）
- `存档复盘/` — 4 篇实战存档复盘（Markdown）
- `游戏预设/` — 帝国设计文本备份（txt）
- `工具/` — 存档解析技能与脚本
- `图片/` — 已有 1 张配图（4.4配船_结果.webp）
- `sqlite/` — 游戏元数据数据库

## 核心需求

做一个**纯静态攻略阅读站点**（不需要后端数据库），让玩家能通过浏览器阅读所有攻略。

### 功能要求

1. **Markdown 渲染阅读**：将 `开局攻略/`、`存档复盘/` 下的 .md 文件渲染为可读页面
   - 支持目录/章节导航（TOC）
   - 代码块、表格、引用、加粗等 Markdown 特性完整渲染
   - 移动端自适应
2. **攻略列表页**：展示所有攻略的标题 + 摘要 + 难度标签（README.md 中有每篇的难度/玩法/DLC 信息，可参考）
3. **搜索**：站内关键词搜索（纯前端实现，如 lunr.js / flexsearch，内容量不大）
4. **阅读体验**：深色太空主题，符合《群星》游戏美学

### 风格要求（重要）

- 整体风格必须和《群星》游戏一致：**太空/科幻/深色主题**
- 参考元素：
  - 深空蓝黑背景（#0a0e1a 附近色系）
  - 群星游戏内的金色/青色强调色（帝国金色 #c9a86a、科技青色 #4fd1c5 之类）
  - 群星游戏标题字体气质（可以用 Google Fonts 的 Cinzel / Rajdhani 之类的科幻衬线字体，或本地字体）
  - 星系/星云装饰元素（CSS 或 SVG，可以用星空粒子背景）
- 标题、按钮、卡片要有"银河帝国档案"的感觉

### 配图要求

**两类图，两个来源：**

1. **攻略主题配图**（每篇攻略详情页顶部/卡片的主题图）— **优先 Google 图片搜索**
   - 先阅读每篇攻略的标题和内容（尤其开头「核心优势/起源」部分），搞清楚这篇玩的什么起源/玩法主题，再搜对应主题的配图
   - 例如：01 协同进化·实验审判 → 实验室/基因改造主题图；02 克隆大军 → 克隆/基因主题；03 演化猎手 → 变异生物/猎手主题；05 虚空航行者 → 太空方舟/商贸主题；12 降世灾星 → 陨石/灾难题材等
   - 找到可用的图源 URL 直接用，或下载到本地 `public/` 目录引用
2. **氛围图/背景图**（首页大背景、页面氛围背景、装饰性星空/星云）— **用 Unsplash 找**
   - 关键词：galaxy, nebula, space, starfield, exoplanet, black hole, deep space, cosmic
   - 用 Unsplash 搜索 API 或直接浏览 unsplash.com 找合适的深空/星系大图做背景

**通用规则：**
- **禁止 AI 生图**（不要调用任何生图工具）
- 不需要考虑版权合规（个人自用，不商用），怎么方便怎么来

### 技术选型（限定）

- **必须使用 React + Next.js**（App Router），版本用最新的稳定版
- Markdown 渲染：next-mdx-remote / react-markdown + remark-gfm（表格/代码块/引用支持）+ 自定义 TOC 组件
- 搜索：flexsearch 或 minisearch（纯前端索引）
- 样式：Tailwind CSS（快速实现深色太空主题）+ 可选 framer-motion 做动效
- 构建产物 `next build` 后 `next export` / `output: 'export'` 纯静态导出，必须能通过静态服务器直接部署（无 Node 服务端依赖）
- 如果 Next.js 版本不支持纯静态导出（如中间件/SSR），用静态生成（SSG）保证产物是纯静态文件

### 源码结构调整

**允许你更改仓库源码结构**以更适合应用开发，但注意：

- 攻略 md 文件保留在仓库内（`开局攻略/`、`存档复盘/` 等目录可移动/重命名，但要保持内容不变）
- 建议结构（可自行调整）：
  ```
  stellaris-strategy-guide/
    app/              # Next.js App Router 页面
    components/       # React 组件
    lib/              # 数据加载/搜索索引构建
    content/          # 攻略 md 迁移到这里（原开局攻略/存档复盘/）
    public/           # 图片等静态资源
    package.json
    next.config.mjs
  ```
- md 内容**不要改写**，保留原文（包括中文、表格、链接）
- 构建时自动扫描 `content/` 目录生成导航和搜索索引，不硬编码文件列表

### 输出要求

1. 按上述结构调整仓库源码
2. `npm run build`（或 pnpm build）跑通，产出静态产物
3. **构建成功后 push 到 GitHub 仓库 main 分支**（仓库：`https://github.com/MrTreasure/Stellaris-Strategy-Guide.git`，使用 gh CLI 或配置好的 git credential）
4. 写 README 说明如何本地开发/构建/部署
5. 推送前确认：能跑通 build、页面正常、md 内容完整

### 部署要求（最后一步）

1. 构建产物部署到本机独立目录：`/vol1/1000/nginx/public/stellaris-guide/`（独立应用，不挂在 resume/muse 下）
2. 部署后本机验证：`curl -H "Host: stellaris-guide.mrtreasure.cc" http://127.0.0.1:8080/` 能返回页面（nginx 的 stellaris-guide server block 已配好）
3. **不要**走 `/resume/muse/` 静态路径，这是独立应用，有独立域名
4. 最终公网域名：`https://stellaris-guide.mrtreasure.cc/`（Cloudflare DNS + Tunnel ingress 已配好，你只需要把产物放对目录）

## 后续维护机制（了解即可，不用实现）

用户会定期从另一台电脑修改 md 攻略内容并 push 到 GitHub 仓库，我们会拉取更新后重新构建部署。因此：
- 站点应能**增量式**引用 md（攻略放 `content/` 目录）
- 新增/修改 md 后重新构建即可生效
- 避免硬编码文件列表，自动扫描目录生成导航

## 当前目录文件清单

```
开局攻略/
  00_通用构筑_前三球与凝聚力.md
  01_协同进化_杂勤实验室.md
  ... 共 16 篇
存档复盘/
  存档复盘_人类联邦_实验审判_2340.md
  ... 共 4 篇
游戏预设/
  新增多形态帝国预设_独立备份.txt
工具/
  stellaris-save-analysis/ (README.md, SKILL.md, scripts/...)
图片/
  4.4配船_结果.webp
sqlite/
  stellaris_game_metadata.sqlite
  stellaris_metadata_probe.sqlite
README.md
```

## 验收标准

- [ ] `开局攻略/` 全部 16 篇 md 都能渲染成页面，无乱码/格式丢失
- [ ] 深色太空主题，风格贴合群星
- [ ] 首页有攻略列表 + 难度/DLC 标签 + 配图
- [ ] 搜索可用
- [ ] 移动端浏览正常
- [ ] `npm run build` 构建成功，产物纯静态可部署
- [ ] **已 push 到 GitHub main 分支**
- [ ] **已部署到 `/vol1/1000/nginx/public/stellaris-guide/`，公网 `https://stellaris-guide.mrtreasure.cc/` 可访问**
