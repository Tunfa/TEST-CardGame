# 模組化技能系統使用指南

## 📋 概述

本系統提供完全模組化的技能配置，通過JSON文件配置各種技能效果，無需修改代碼即可創建新技能。

## 🎯 技能類型

### 1. 隊長技能（Leader Skills）
配置文件：`data/config/leader_skills.json`

#### 可用效果類型：

**傷害倍率類：**
- `DAMAGE_MULTIPLIER` - X屬性傷害 X 倍
- `BASE_DAMAGE_BOOST` - X屬性基礎傷害提升 X%
- `ALL_DAMAGE_BOOST` - X屬性所有傷害提升 X%（包含主動技能）
- `IGNORE_RESISTANCE` - X屬性傷害無視屬性克制

**靈珠相關：**
- `FORCE_ORB_SPAWN` - 前X粒固定出現X屬性靈珠
- `ORB_DROP_ON_SLASH` - 斬裂X屬性X次掉落X個靈珠
- `SLASH_ORB_SPAWN` - 斬裂X屬性X次立刻出現X個斬擊珠
- `ORB_SPAWN_RATE_BOOST` - X屬性靈珠出現機率額外 X%
- `ORB_CAPACITY_BOOST` - X屬性靈珠最高容量額外增加X個
- `ORB_DUAL_EFFECT` - X屬性靈珠兼具X屬性靈珠 X% 效果
- `ORB_DROP_END_TURN` - 回合結束掉落X粒X屬性靈珠

**數值動態倍率類：**
- `ORB_COUNT_MULTIPLIER` - X屬性靈珠越多X屬性傷害越高 最高X倍
- `TEAM_ELEMENT_MULTIPLIER` - 隊伍中越多X屬性成員 X屬性傷害越高 最高X倍
- `TEAM_DIVERSITY_MULTIPLIER` - 隊伍中越多不同屬性成員 全隊攻擊力越高 最高X倍

**屬性倍率類：**
- `HP_MULTIPLIER` - X屬性生命力 X 倍
- `RECOVERY_MULTIPLIER` - X屬性回復力 X 倍

**時間延長：**
- `EXTEND_SLASH_TIME` - 額外延長X秒斬擊時間

**回合結束效果：**
- `END_TURN_DAMAGE` - 每回合結束對敵方造成X屬性X傷害

### 2. 敵人技能（Enemy Skills）
配置文件：`data/config/enemy_skills.json`

#### 可用效果類型：

**條件限制類：**
- `REQUIRE_COMBO` - 需斬擊累積 X 連擊才可對敵人造成傷害
- `REQUIRE_ORB_TOTAL` - 需斬擊累積 X 粒X屬性靈珠才可對敵人造成傷害
- `REQUIRE_ORB_CONTINUOUS` - 需連續斬擊X粒X屬性靈珠才可對敵人造成傷害
- `REQUIRE_ORB_SEQUENCE` - 需先斬擊X粒X屬性靈珠再斬擊X粒X屬性靈珠才能造成傷害
- `REQUIRE_ENEMY_ATTACK` - 敵人必須先攻擊否則無法造成傷害
- `REQUIRE_ELEMENTS` - 需斬擊X種屬性靈珠才能造成傷害

**傷害減免類：**
- `DAMAGE_REDUCTION_PERCENT` - 降低所受X%傷害
- `DAMAGE_REDUCTION_FLAT` - 降低所受X傷害（固定值）

**封鎖類：**
- `SEAL_ACTIVE_SKILL` - 封鎖X回合主動技能
- `SEAL_ORB_SWAP` - 封鎖X回合靈珠使用（排版）
- `DISABLE_ELEMENT_SLASH` - X回合內X屬性靈珠斬擊無效
- `ZERO_RECOVERY` - X回合內回復力歸零

**敵人強化類：**
- `ENEMY_DAMAGE_BY_PLAYER_ORBS` - 玩家靈珠越多敵人傷害越高
- `ENEMY_DAMAGE_BY_PLAYER_LOW_ORBS` - 玩家靈珠越少敵人傷害越高

**靈珠移除類：**
- `REMOVE_RANDOM_ORBS` - 每回合隨機減少玩家X粒X屬性靈珠

**干擾類：**
- `REDUCE_SLASH_TIME` - 斬擊時間減少X秒
- `SPAWN_INVALID_ORBS` - 斬擊途中隨機出現無效珠
- `REDUCE_DAMAGE_TURNS` - X回合內傷害降低X%

**特殊類：**
- `ENTER_HP_TO_ONE` - 進場時生命力扣至1
- `DEATH_DAMAGE` - 自身死亡時對玩家造成X點傷害
- `REVIVE_ONCE` - 自身可以復活一次

## 📝 配置示例

### 隊長技能示例

```json
{
  "skill_id": "LS_FIRE_DAMAGE_2X",
  "skill_name": "火屬性強化",
  "description": "火屬性傷害2倍",
  "effects": [
	{
	  "effect_type": "DAMAGE_MULTIPLIER",
	  "target_element": "FIRE",
	  "multiplier": 2.0
	}
  ]
}
```

### 複合效果示例

```json
{
  "skill_id": "LS_COMBO_FIRE_WOOD",
  "skill_name": "火木雙修",
  "description": "火屬性與木屬性傷害各1.5倍，生命力1.5倍",
  "effects": [
	{
	  "effect_type": "DAMAGE_MULTIPLIER",
	  "target_element": "FIRE",
	  "multiplier": 1.5
	},
	{
	  "effect_type": "DAMAGE_MULTIPLIER",
	  "target_element": "WOOD",
	  "multiplier": 1.5
	},
	{
	  "effect_type": "HP_MULTIPLIER",
	  "target_element": "ALL",
	  "multiplier": 1.5
	}
  ]
}
```

### 敵人技能示例

```json
{
  "skill_id": "ES_COMBO_SHIELD_DAMAGE_REDUCTION",
  "skill_name": "複合防禦",
  "description": "需10連擊才能造成傷害，並降低30%傷害",
  "effects": [
	{
	  "effect_type": "REQUIRE_COMBO",
	  "required_combo": 10
	},
	{
	  "effect_type": "DAMAGE_REDUCTION_PERCENT",
	  "reduction_percent": 30.0
	}
  ]
}
```

## 🔧 如何添加新技能

### 步驟1：在JSON文件中添加配置

編輯 `leader_skills.json` 或 `enemy_skills.json`：

```json
{
  "skill_id": "LS_MY_NEW_SKILL",
  "skill_name": "我的新技能",
  "description": "技能描述",
  "effects": [
	{
	  "effect_type": "DAMAGE_MULTIPLIER",
	  "target_element": "WATER",
	  "multiplier": 2.5
	}
  ]
}
```

### 步驟2：在卡片數據中引用技能

在 `data/cards.json` 中：

```json
{
  "card_id": "C001",
  "card_name": "我的卡片",
  "leader_skill_ids": ["LS_MY_NEW_SKILL"],
  ...
}
```

### 步驟3：遊戲自動載入

技能系統會在遊戲啟動時自動載入所有配置，無需重新編譯！

## 🎮 技能組合建議

### 新手推薦組合
- 火屬性強化 + 生命力提升
- 前5粒固定火珠 + 火屬性傷害2倍

### 進階組合
- 火木雙修 + 隊伍多樣性加成
- 靈珠數量倍率 + 靈珠出現率提升

### 極限組合
- 全傷害提升 + 無視屬性克制 + 隊伍元素倍率
- 延長時間 + 靈珠容量提升 + 回合結束掉落

## ⚠️ 注意事項

1. **不影響遊戲規則**：所有技能效果都不會改變基本遊戲規則（如斬3掉1）
2. **獨立計算**：所有效果都是獨立計算並疊加的
3. **性能優化**：使用JSON配置大幅減少載入時間
4. **易於擴展**：添加新效果類型只需在Constants.gd中添加枚舉

## 📊 元素代碼

- `FIRE` - 火
- `WATER` - 水
- `WOOD` - 木
- `METAL` - 金
- `EARTH` - 土
- `HEART` - 心
- `ALL` - 全屬性（僅用於某些效果）

## 🔍 調試技巧

在控制台中查看技能載入日誌：
```
✅ SkillSystem: 技能系統初始化完成
  - 隊長技能: 15 個
  - 敵人技能: 15 個
```

應用技能時的日誌：
```
🔮 [SkillEffectHandler] 應用隊長技能: 火屬性強化
  ✓ 傷害倍率: FIRE x2.0 (總計: x2.0)
```

## 🚀 未來擴展

可輕鬆添加的新效果類型：
- 暴擊率提升
- 連擊加成
- 特定條件觸發效果
- 隊友協同效果
- 更多...

---

**提示**：所有配置立即生效，無需重啟遊戲！只需重新載入關卡即可。
