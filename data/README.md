# 模組化數據系統使用說明

本系統提供了一個簡單易用的 JSON 配置方式，讓你可以快速新增、修改和刪除卡片、敵人和關卡。

## 目錄結構

```
data/
├── cards.json      # 卡片配置文件
├── enemies.json    # 敵人配置文件
├── stages.json     # 關卡配置文件
└── README.md       # 本文件
```

---

## 📋 卡片配置 (cards.json)

### 卡片屬性說明

```json
{
  "card_id": "001",              // 卡片ID（唯一識別碼）
  "card_name": "劍士",            // 卡片名稱
  "card_image_path": "res://assets/cards/sword_fighter.png",  // 圖片路徑
  "rarity": "COMMON",            // 稀有度: COMMON, RARE, EPIC, LEGENDARY
  "card_class": "WARRIOR",       // 職業: WARRIOR, MAGE, RANGER, HEALER, ASSASSIN
  "base_hp": 30,                 // 基礎HP
  "base_atk": 8,                 // 基礎攻擊力
  "base_recovery": 5,            // 基礎回復力
  "max_sp": 3,                   // 最大SP（技能點數）
  "initial_sp": 1,               // 初始SP
  "passive_skill_ids": ["hp_boost_10"],  // 被動技能ID列表
  "active_skill_id": "slash_attack",      // 主動技能ID
  "active_skill_cd": 3           // 主動技能冷卻時間
}
```

### 新增卡片範例

在 `cards.json` 的 `cards` 陣列中新增：

```json
{
  "card_id": "006",
  "card_name": "暗影刺客",
  "card_image_path": "res://assets/cards/assassin.png",
  "rarity": "EPIC",
  "card_class": "ASSASSIN",
  "base_hp": 18,
  "base_atk": 15,
  "base_recovery": 2,
  "max_sp": 4,
  "initial_sp": 2,
  "passive_skill_ids": ["critical_boost"],
  "active_skill_id": "backstab",
  "active_skill_cd": 3
}
```

---

## 👹 敵人配置 (enemies.json)

### 敵人屬性說明

```json
{
  "enemy_id": "E001",            // 敵人ID（唯一識別碼）
  "enemy_name": "史萊姆",         // 敵人名稱
  "sprite_path": "res://assets/enemies/slime.png",  // 圖片路徑
  "max_hp": 15,                  // 最大HP
  "base_atk": 3,                 // 基礎攻擊力
  "attack_cd": 1,                // 攻擊冷卻（1=每回合攻擊）
  "passive_skill_ids": [],       // 被動技能ID列表
  "attack_skill_ids": ["slime_bounce"]  // 攻擊技能ID列表
}
```

### 新增敵人範例

在 `enemies.json` 的 `enemies` 陣列中新增：

```json
{
  "enemy_id": "E005",
  "enemy_name": "火焰巨龍",
  "sprite_path": "res://assets/enemies/fire_dragon.png",
  "max_hp": 200,
  "base_atk": 25,
  "attack_cd": 2,
  "passive_skill_ids": ["flame_aura"],
  "attack_skill_ids": ["dragon_breath", "tail_sweep"]
}
```

---

## 🗺️ 關卡配置 (stages.json)

### 關卡屬性說明

```json
{
  "stage_id": "1-1",             // 關卡ID（唯一識別碼）
  "stage_name": "森林入口",       // 關卡名稱
  "description": "新手關卡，遇見了幾隻史萊姆",  // 關卡描述
  "difficulty": 1,               // 難度等級（1-10）
  "is_boss_stage": false,        // 是否為BOSS關卡
  "enemies": [                   // 敵人配置
    {
      "enemy_id": "E001",        // 敵人ID
      "count": 3                 // 數量
    }
  ],
  "rewards": {                   // 獎勵配置
    "gold": 50,                  // 金幣獎勵
    "exp": 10,                   // 經驗值獎勵
    "card_drops": [              // 卡片掉落
      {
        "card_id": "001",        // 卡片ID
        "drop_rate": 0.1         // 掉落機率（0.0-1.0）
      }
    ]
  },
  "unlock_requirements": {       // 解鎖條件
    "required_stages": []        // 需要完成的前置關卡ID列表
  }
}
```

### 新增關卡範例

在 `stages.json` 的 `stages` 陣列中新增：

```json
{
  "stage_id": "2-1",
  "stage_name": "火山入口",
  "description": "炎熱的火山區域，小心火焰敵人！",
  "difficulty": 5,
  "is_boss_stage": false,
  "enemies": [
    {
      "enemy_id": "E002",
      "count": 2
    },
    {
      "enemy_id": "E003",
      "count": 2
    }
  ],
  "rewards": {
    "gold": 150,
    "exp": 40,
    "card_drops": [
      {
        "card_id": "002",
        "drop_rate": 0.2
      },
      {
        "card_id": "005",
        "drop_rate": 0.05
      }
    ]
  },
  "unlock_requirements": {
    "required_stages": ["1-4"]
  }
}
```

---

## 🎮 如何在遊戲中使用

### 1. 通過代碼獲取數據

```gdscript
# 獲取卡片數據
var card = DataManager.get_card("001")
print(card.card_name)  # 輸出: "劍士"

# 獲取敵人數據
var enemy = DataManager.get_enemy("E001")
print(enemy.enemy_name)  # 輸出: "史萊姆"

# 獲取關卡數據
var stage = DataManager.get_stage("1-1")
print(stage.stage_name)  # 輸出: "森林入口"

# 獲取關卡的敵人列表
var enemy_list = stage.get_enemy_list()
# enemy_list = ["E001", "E001", "E001"]
```

### 2. 檢查數據是否存在

```gdscript
if DataManager.card_exists("001"):
    print("卡片存在")

if DataManager.enemy_exists("E001"):
    print("敵人存在")

if DataManager.stage_exists("1-1"):
    print("關卡存在")
```

### 3. 獲取所有ID列表

```gdscript
var all_cards = DataManager.get_all_cards()
var all_enemies = DataManager.get_all_enemies()
var all_stages = DataManager.get_all_stages()
```

---

## ⚠️ 注意事項

1. **ID 必須唯一**：卡片ID、敵人ID、關卡ID 都必須保持唯一
2. **圖片路徑**：確保圖片資源存在於指定路徑
3. **技能ID**：確保技能ID 在 SkillRegistry 中已註冊
4. **關卡解鎖**：關卡的 `required_stages` 必須是已存在的關卡ID
5. **數值平衡**：注意平衡性，避免過強或過弱的設定

---

## 🔧 常見問題

### Q: 修改 JSON 後需要重啟遊戲嗎？
**A:** 是的，JSON 數據在遊戲啟動時載入，修改後需要重新運行遊戲。

### Q: 如何刪除卡片/敵人/關卡？
**A:** 直接從 JSON 文件中刪除對應的條目即可，但要注意不要刪除其他地方引用的數據。

### Q: 如何新增技能？
**A:** 技能系統使用腳本而非 JSON。需要在 `scripts/skills/` 目錄下創建新的技能腳本。

### Q: 掉落機率怎麼設定？
**A:** `drop_rate` 是 0.0 到 1.0 的數值，例如 0.1 = 10%，0.5 = 50%。

---

## 📝 快速開始檢查清單

- [ ] 打開對應的 JSON 文件
- [ ] 複製現有條目作為模板
- [ ] 修改 ID（確保唯一）
- [ ] 修改名稱和描述
- [ ] 調整數值（HP、攻擊、難度等）
- [ ] 確認技能ID存在
- [ ] 確認圖片路徑正確
- [ ] 保存文件
- [ ] 重啟遊戲測試

---

## 🎯 範例：創建完整的新關卡流程

### 1. 創建新敵人 (enemies.json)
```json
{
  "enemy_id": "E006",
  "enemy_name": "冰霜魔像",
  "sprite_path": "res://assets/enemies/ice_golem.png",
  "max_hp": 50,
  "base_atk": 12,
  "attack_cd": 2,
  "passive_skill_ids": ["ice_armor"],
  "attack_skill_ids": ["ice_punch"]
}
```

### 2. 創建新卡片獎勵 (cards.json)
```json
{
  "card_id": "007",
  "card_name": "冰法師",
  "card_image_path": "res://assets/cards/ice_mage.png",
  "rarity": "RARE",
  "card_class": "MAGE",
  "base_hp": 22,
  "base_atk": 13,
  "base_recovery": 4,
  "max_sp": 4,
  "initial_sp": 2,
  "passive_skill_ids": [],
  "active_skill_id": "ice_storm",
  "active_skill_cd": 4
}
```

### 3. 創建新關卡 (stages.json)
```json
{
  "stage_id": "3-1",
  "stage_name": "冰雪洞窟",
  "description": "寒冷的洞窟，冰霜魔像守護著這裡",
  "difficulty": 6,
  "is_boss_stage": false,
  "enemies": [
    {
      "enemy_id": "E006",
      "count": 3
    }
  ],
  "rewards": {
    "gold": 200,
    "exp": 60,
    "card_drops": [
      {
        "card_id": "007",
        "drop_rate": 0.25
      }
    ]
  },
  "unlock_requirements": {
    "required_stages": ["2-1"]
  }
}
```

完成！重新啟動遊戲即可看到新的關卡。

---

## 💡 提示

- 使用 JSON 格式化工具確保文件格式正確
- 定期備份 JSON 文件
- 可以使用註解記錄設計思路（但 JSON 標準不支持註解，需要移除後才能使用）
- 建議使用版本控制（如 Git）追蹤修改

---

**祝你設計出精彩的遊戲內容！** 🎮
