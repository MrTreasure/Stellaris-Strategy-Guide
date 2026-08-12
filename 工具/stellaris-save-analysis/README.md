# Stellaris 存档分析工具

当前规则库版本：**4.4.6 Pegasus**。

## 建立游戏元数据 SQLite

元数据数据库不是某个存档的快照，而是从本地游戏安装中抽取的可复用规则索引，包含：

- `definitions`：建筑、岗位、科技、起源、理念、传统、飞升、政策、特质及其他 `common` 定义
- `localization`：简体中文名称和文本
- `source_files`：来源文件、大小、修改时间
- `database_info`：数据库版本、游戏版本、游戏安装路径、索引时间

首次建立或游戏更新后重建：

```powershell
& .\scripts\build_stellaris_metadata.ps1 `
  -GameRoot 'E:\SteamLibrary\steamapps\common\Stellaris' `
  -DatabasePath '.\sqlite\stellaris_game_metadata.sqlite' `
  -GameVersion '4.4.6' `
  -Language 'simp_chinese'
```

本机索引结果约包含2016个规则文件、29269个定义和148694条简体中文本地化记录。

## 使用元数据解析任意存档

```powershell
& 'C:\Users\Treasure\.codex\skills\stellaris-save-analysis\scripts\parse_stellaris_save.ps1' `
  -MetadataDbPath '.\sqlite\stellaris_game_metadata.sqlite' `
  -OutputPath '.\latest_stellaris_analysis.md'
```

解析器仍然只读 `.sav`；元数据数据库只用于把岗位和殖民地定位等内部 key 映射为本地化名称。
