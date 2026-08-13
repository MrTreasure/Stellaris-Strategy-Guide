# 修复 Stellaris 攻略站两个 bug

项目: /vol1/picoclaw/home/workspace/stellaris-strategy-guide (Next.js 16.3.0, output: export)
线上: https://stellaris-guide.mrtreasure.cc/
部署目录: /vol1/1000/nginx/public/stellaris-guide/ (构建后 cp out/* 过去)
GitHub: 已推 main, 提交 8fce570

## Bug 1: 客户端点击详情页 404 (CRITICAL)
现象: 首页点攻略链接, Next.js 客户端路由渲染 "404: This page could not be found."
已确认: 直接访问 URL/刷新返回 200 (nginx try_files $uri $uri.html 兜底), 只有 SPA 客户端导航失败。
根因: Next 16 静态导出把每个动态路由生成:
  - guides/guide-00_xxx.html (HTML)
  - guides/guide-00_xxx/ 目录, 里面只有 __next.*.txt (RSC payload), 没有 index.html
客户端 router 导航时找不到 index.html → 内部 404。

修复要求 (任选最稳方案):
1. 推荐: 列表页/详情页的 <Link> 改成普通 <a href>, 或给 Link 加属性强制整页导航 (如 <a> 代替 <Link>, 避免客户端路由) — 简单可靠
2. 或改 next.config: 试试 trailingSlash: true 让导出变成 /guides/xxx/index.html 标准结构 (注意 nginx 配置已支持 $uri/)
3. 或降级 Next 到 15.x 稳定版重新构建 (最后手段)
修完必须用 Playwright 实测点击导航不再 404 (可参考 /home/Treasure/.picoclaw/workspace/playwright/test_stellaris_click.mjs)

## Bug 2: 每篇攻略配图都一样
现象: 20 篇文章的封面全是同一张 deep-space.jpg (19篇) + voidfarer-arkship.jpg (1篇)。
根因: lib/guides.ts 的 metadata 写死 image 字段。
要求:
- 为 20 篇攻略各找 1 张**不同**的《群星》游戏图片, 共 20 张
- 图源必须是《群星》(Stellaris) 游戏本身的图: 优先 Stellaris 官方 Wiki (https://stellaris.paradoxwikis.com/), Steam 商店页截图, 或 Google 图片搜索 stellaris + 对应主题
- 每篇攻略按主题找对应的游戏图: 先读该篇攻略开头「核心优势/起源」部分, 搞清楚这篇玩的什么起源/玩法, 再找对应图
  - 例如: 01 协同进化 → 起源「协同进化」/ 基因改造相关游戏图; 02 克隆大军 → 克隆起源/基因; 03 演化猎手 → 变异掠食; 05 虚空航行者 → 方舟/贸易; 12 降世灾星 → 陨石/灾星; 14 资源统合 → 机械智能/监护矩阵 等
- 下载到 public/images/, 命名 guide-00.jpg ~ guide-15.jpg, review-01.jpg ~ review-04.jpg (或按 slug)
- 更新 lib/guides.ts metadata, 每篇配不同图
- 注意: 图片别太大 (建议 ≤300KB/张, 宽度≥1600px 更好), 深色系为主, 要和文字对比度够
- 禁止 AI 生图; 不需要考虑版权合规 (个人自用)

## 完成后
1. npm run build 成功
2. 部署: cp -r out/* /vol1/1000/nginx/public/stellaris-guide/ (覆盖旧的)
3. 本机验证: curl -H "Host: stellaris-guide.mrtreasure.cc" http://127.0.0.1:8080/ 200; 用 Playwright 点链接验证详情页 200 且标题不是 404
4. git add + commit + push main
5. 汇报: 改了哪些文件、图片列表、验证结果
