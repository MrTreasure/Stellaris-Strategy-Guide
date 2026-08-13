# 任务：为 Stellaris 攻略站添加第 16 篇攻略「居住站」

项目目录：/vol1/picoclaw/home/workspace/stellaris-strategy-guide

## 背景

攻略站已有 16 篇开局攻略（guide-00 ~ guide-15），新加一篇居住站玩法攻略，编号 16。

攻略 Markdown 已写好，位于：
`content/开局攻略/16_居住站_轨道殖民与虚空经济.md`

## 需要做的事

### 1. 注册 metadata
编辑 `lib/guides.ts`，在 `metadata` 字典中**新增一行**：

```ts
'16': { difficulty: '中', dlc: '乌托邦', image: '/images/guide-16.jpg' },
```

插在 `'15'` 那行后面（保持顺序）。

### 2. 配图
- 从 Google 图片搜索一张《群星》(Stellaris) 游戏本身的**居住站（Habitat）相关截图/图**（虚空居者起源、居住站空间站外观、居住站界面截图均可，必须与居住站主题相关，不要 Unsplash 通用太空图，不要 AI 生图）。
- 下载保存为 `public/images/guide-16.jpg`
- 要求：单张 ≤300KB，宽度 ≥1600px，深色系（与现有 guide-*.jpg 风格一致）
- 若 Google 图片直连失败，可尝试 Bing 图片，或从 stellaris wiki / gamepedia 等站点抓取居住站配图

### 3. 构建
```bash
cd /vol1/picoclaw/home/workspace/stellaris-strategy-guide
npm run build
```
构建成功应产出 `out/` 目录，包含 `guides/guide-16/` 相关静态文件。

### 4. 部署
将 `out/` 内容同步到部署目录：
```bash
rsync -a --delete /vol1/picoclaw/home/workspace/stellaris-strategy-guide/out/ /vol1/1000/nginx/public/stellaris-guide/
```
（注意 --delete 会清掉旧文件，确保 out/ 构建完整再同步）

### 5. 验证
- 本机验证：`curl -s -H "Host: stellaris-guide.mrtreasure.cc" http://127.0.0.1:8080/guides/guide-16 | grep -o "居住站" | head -3` 应输出内容
- 图片验证：`curl -sI -H "Host: stellaris-guide.mrtreasure.cc" http://127.0.0.1:8080/images/guide-16.jpg | head -5` 应 200

### 6. Git 提交
```bash
cd /vol1/picoclaw/home/workspace/stellaris-strategy-guide
git add -A
git commit -m "Add habitat guide (guide-16)"
git push origin main
```

## 注意
- 不要动其他 16 篇攻略内容
- 不要修改 next.config.mjs / package.json
- 构建日志输出到 /vol1/log/codex-stellaris-guide16.log（用 nohup 或重定向）
- 完成后用一句话总结：新攻略 URL、图片大小、构建部署是否成功
