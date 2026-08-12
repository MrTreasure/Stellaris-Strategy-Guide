---
name: stellaris-save-analysis
description: Read-only analysis of Stellaris PC save files (.sav), especially 4.4.x Pegasus saves. Use when Codex needs to locate the newest save, identify the player empire, inspect technologies, traditions, ascension perks, colonies, populations, jobs, buildings, fleets, resources, diplomacy, or run a requested playstyle-specific diagnosis such as Experimental Sentencing.
---

# Stellaris 存档解析

## 使用脚本

优先运行同目录的 `scripts/parse_stellaris_save.ps1`，不要手写一次性解析命令。默认执行通用存档分析；只有用户明确要求专项诊断或存档检测到对应理念时，才加载对应专项规则。

```powershell
.\scripts\parse_stellaris_save.ps1
```

脚本默认从这些位置按 `LastWriteTime` 找最新 `.sav`：

- `Documents\Paradox Interactive\Stellaris\save games`
- `OneDrive\Documents\Paradox Interactive\Stellaris\save games`
- `Saved Games\Paradox Interactive\Stellaris`

常用参数：

```powershell
# 列出所有找到的存档，不解析
.\scripts\parse_stellaris_save.ps1 -ListOnly

# 指定存档
.\scripts\parse_stellaris_save.ps1 -SavePath 'C:\path\save.sav'

# 指定存档根目录
.\scripts\parse_stellaris_save.ps1 -SaveRoot 'C:\path\save games'

# 指定报告位置
.\scripts\parse_stellaris_save.ps1 -OutputPath 'C:\path\report.md'

# 强制输出实验审判专项，即使存档没有自动检测到该理念
.\scripts\parse_stellaris_save.ps1 -ExperimentalSentencing
```

## 游戏元数据 SQLite

解析前优先复用本地游戏元数据索引。该数据库保存通用游戏定义和本地化，
不是任何一个存档的状态；当前数据库记录的游戏版本为 Pegasus **4.4.6**。

首次建立或游戏文件更新后重建：

```powershell
.\scripts\build_stellaris_metadata.ps1 `
    -GameRoot 'E:\SteamLibrary\steamapps\common\Stellaris' `
    -DatabasePath '.\sqlite\stellaris_game_metadata.sqlite' `
    -GameVersion '4.4.6' `
    -Language 'simp_chinese'
```

解析任意存档时，`parse_stellaris_save.ps1` 会自动读取项目目录下的
`sqlite\stellaris_game_metadata.sqlite`；也可以显式传入 `-MetadataDbPath`。SQLite
只用于快速映射建筑、岗位、科技、起源、理念、传统、飞升和本地化名称，
不会修改 `.sav`。

脚本只读 `.sav`：它把存档 ZIP 临时解压到随机临时目录，读取 `meta` 和 `gamestate`，写出 Markdown 报告，最后删除该随机临时目录。不会覆盖、修改或保存游戏存档。

一次运行会同时生成殖民地/岗位、帝国规模、月度收支与库存、主要舰队、当前战争和已拥有巨构等栏目。优先直接使用这一份报告回答后续问题，不要为了查询不同栏目反复解析同一存档。脚本只为玩家实际拥有的殖民地、岗位、建筑、舰队和巨构建立定向索引，避免逐项重复扫描整个 `gamestate`。

## 解析顺序

1. 从 `meta` 确认版本、存档日期、帝国名和 DLC；优先确认是 4.4.6 Pegasus，不要把 4.5 测试分支的攻略套进来。
2. 从 `player` 找玩家国家 ID，再进入 `country` 区块；不要假设玩家永远是国家 ID 0。
3. 从玩家国家的 `owned_planets` 读取殖民地 ID。它们是殖民地记录 ID，不一定等于实际行星 ID。
4. 在 `colony` 区块中读取每颗殖民地的 `carrier.reference`，再到 `planets -> planet` 区块映射实际星球。
5. 用殖民地的 `pop_jobs` ID 去 `pop_jobs` 区块查岗位类型、实际 workforce、岗位上限和 bonus workforce。
6. 用 `buildings_cache` ID 去 `buildings` 区块查建筑类型；不要只看 `last_building_changed` 判断整颗星球的建筑。
7. 通用分析至少汇总：殖民地定位、人口、住房、稳定度、犯罪、建筑、主要岗位、帝国规模、资源收支、主要舰队、战争和巨构；再结合原始国家区块检查科技、传统和飞升天赋。
8. 只有用户要求实验审判，或检测到 `civic_twisted_experimenters` / `civic_twisted_experimenters_hive_mind` 时，才额外汇总：`experiment_engineer`、`experiment_engineer_drone`、`test_subject`、`slave_orderly`、`criminal`、`enforcer`。
9. 将专项岗位和星球经济放在同一张表里，再判断效率问题；不要把实验审判的判读规则套用到普通帝国。

## 可选专项：实验审判

- `experiment_engineer` 是主要科研岗位；`test_subject` 是附带岗位，不能把测试对象数量直接当作实验工程师倍率。
- 犯罪修正是实验审判的重要倍率来源。实验星通常应减少执法岗位，并检查是否已经触发犯罪相关修正。
- `slave_orderly` 是另一项核心倍率来源。没有杂勤奴隶时，即使实验工程师和测试对象很多，效率也可能明显低。
- 4.4.x 的实验研究所升级主要增加测试对象岗位，实验工程师岗位不是按普通研究所逻辑成倍增加；升级前检查战略资源维护和测试对象是否真的需要。
- 不要把实验建筑分散到所有星球。先集中一颗主实验星，再建立第二、第三实验星；其他星球负责合金、消费品、能源和食物。
- 稳定度不能为了犯罪无限压低。犯罪高但稳定度低于 50、出现叛乱或经济崩溃时，先恢复基础经济。

## 输出诊断

通用存档分析先回答：

1. 玩家国家实际使用什么起源、思潮、理念、科技、传统和飞升天赋？
2. 哪些星球是首都、资源、工业、科研、贸易或军工定位？
3. 哪些星球存在人口不足、岗位错配、建筑空置、稳定度/犯罪异常或资源赤字？
4. 舰队、星港、外交和帝国规模是否支持当前扩张节奏？

启用实验审判专项后，再回答：

1. 哪些星球有实验工程师但犯罪为 0？这些星球没有吃到犯罪修正。
2. 哪些星球有实验工程师但 `slave_orderly=0`？这些星球缺少杂勤倍率。
3. 哪些星球实验研究所很多但实验工程师没有增加？检查是否只是升级了建筑、增加了测试对象。
4. 哪些实验星同时有高犯罪、杂勤和稳定度？把它们作为主实验星，不要继续平均铺建筑。

报告只提供存档事实和操作建议；不要修改原存档。需要验证改法时，复制存档后在游戏内暂停操作，再重新保存并运行脚本比较两份报告。
