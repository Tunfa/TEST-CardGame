# VFXManager 戰鬥整合指南

本文檔說明如何在戰鬥系統中使用 VFXManager 視覺特效系統。

## 已整合的特效

### 1. 攻擊特效

**位置**: `BattleScene.gd:_on_damage_dealt()` (1166行)

#### 玩家受傷
```gdscript
# 當敵人攻擊玩家時
VFXManager.play_effect("hit", spawn_pos)
```

#### 敵人受傷
```gdscript
# 根據傷害大小自動選擇特效
if damage >= target_node.get_enemy_data().max_hp * 0.3:
    # 大傷害（超過30%最大HP）- 暴擊特效
    VFXManager.play_effect("critical", spawn_pos)
else:
    # 普通傷害 - 打擊特效
    VFXManager.play_effect("hit", spawn_pos)
```

**觸發時機**：
- 玩家拖曳卡片攻擊敵人
- 使用主動技能造成傷害
- 敵人攻擊玩家

---

### 2. 敵人死亡特效

**位置**: `BattleScene.gd:_on_enemy_died()` (1143行)

```gdscript
# 敵人死亡時播放爆炸特效
var death_pos = node_to_remove.global_position + (node_to_remove.size / 2)
VFXManager.play_effect("explosion", death_pos)
```

**觸發時機**：
- 敵人HP歸零時

---

### 3. 治療特效

**位置**: `BattleScene.gd:_on_healing_phase_finished()` (1242行)

```gdscript
# 治療結算時播放治療特效
if player_hp_bar:
    var heal_pos = player_hp_bar.global_position + (player_hp_bar.size / 2)
    VFXManager.play_effect("heal", heal_pos)
```

**觸發時機**：
- 消除心珠（Heart）回復生命值時
- 使用治療技能時

---

## 如何添加更多特效

### 範例 1：在技能確認時添加特效

```gdscript
# BattleScene.gd 中的 _on_skill_confirmed() 函數

func _on_skill_confirmed(card: CardData, _target: EnemyData):
    var skill = card.active_skill
    if not skill: return

    # ✨ 添加技能啟動特效
    var card_pos = Vector2.ZERO
    for card_node in card_nodes:
        if card_node.card_data == card:
            card_pos = card_node.global_position + (card_node.size / 2)
            break

    # 根據技能類型選擇特效
    match skill.target_type:
        Constants.TargetType.ALL_ENEMIES:
            VFXManager.play_effect("explosion", card_pos)
        Constants.TargetType.SELF:
            VFXManager.play_effect("shield", card_pos)
        _:
            VFXManager.play_effect("critical", card_pos)
```

### 範例 2：在特定元素攻擊時添加自定義特效

```gdscript
# BattleScene.gd 中的 _on_damage_dealt() 函數

# 可以根據攻擊者的元素選擇不同特效
var attacker_element = get_attacker_element()  # 假設有這個函數

match attacker_element:
    Constants.Element.FIRE:
        VFXManager.play_effect("explosion", spawn_pos)
    Constants.Element.WATER:
        VFXManager.play_effect("heal", spawn_pos)  # 水屬性用藍色特效
    Constants.Element.WOOD:
        VFXManager.play_effect("heal", spawn_pos)  # 木屬性用綠色特效
    _:
        VFXManager.play_effect("hit", spawn_pos)
```

### 範例 3：在護盾技能時添加特效

```gdscript
# 如果你有護盾技能系統
func apply_shield(card: CardData, shield_amount: int):
    # ... 護盾邏輯 ...

    # ✨ 播放護盾特效
    var card_pos = get_card_position(card)
    VFXManager.play_effect("shield", card_pos)
```

---

## 可用特效列表

| 特效名稱 | 使用場景 | 顏色 | 動畫特點 |
|---------|---------|------|---------|
| `hit` | 一般攻擊、受傷 | 白→橙→紅 | 向四周飛濺 |
| `critical` | 暴擊、大傷害 | 金色閃爍 | 爆發式擴散 |
| `explosion` | 範圍攻擊、死亡 | 黃→紅→黑 | 環形爆炸 |
| `heal` | 治療、回復 | 綠→青→藍 | 向上飄散 |
| `shield` | 防禦、護盾 | 藍色 | 環繞效果 |

---

## 進階用法

### 1. 批量播放特效

```gdscript
# 對多個敵人同時造成傷害時
var enemy_positions = []
for enemy in damaged_enemies:
    enemy_positions.append(enemy.global_position)

VFXManager.play_multiple_effects("explosion", enemy_positions)
```

### 2. 自定義特效屬性

```gdscript
# 創建特效後進行自定義
var my_effect = VFXManager.play_effect("critical", position)
if my_effect:
    my_effect.scale = Vector2(2, 2)  # 放大2倍
    my_effect.modulate = Color(0, 1, 0)  # 改成綠色
```

### 3. 組合多種特效

```gdscript
# 超強攻擊時疊加多種特效
VFXManager.play_effect("critical", target_pos)
await get_tree().create_timer(0.1).timeout
VFXManager.play_effect("explosion", target_pos)
```

---

## 特效與音效配合

在戰鬥中，視覺特效通常與音效一起使用：

```gdscript
# BattleScene.gd 中已有的音效系統
func _on_card_dragged_to_enemy(card_node: Control, enemy_node: Control):
    # ... 攻擊邏輯 ...

    if battle_manager.attack_with_card(card_data, enemy_data):
        # 音效
        AudioManager.play_sfx("player_attack")

        # 視覺特效（已自動在 _on_damage_dealt 中播放）
        # VFXManager 會自動處理
```

---

## 效能建議

### 同時顯示特效數量限制

VFXManager 預設最多同時顯示 20 個特效，超過會自動清理最舊的特效。

如果需要調整：
```gdscript
# 在 BattleScene._ready() 中
VFXManager.max_active_effects = 30  # 增加到30個
```

### 檢查活躍特效數量

```gdscript
# 在播放大量特效前檢查
if VFXManager.get_active_effect_count() < 15:
    VFXManager.play_effect("explosion", pos)
```

---

## 除錯技巧

### 1. 檢查特效是否正確播放

```gdscript
var effect = VFXManager.play_effect("hit", position)
if effect:
    print("特效已成功創建: ", effect.name)
else:
    print("特效創建失敗！")
```

### 2. 視覺化特效位置

```gdscript
# 在播放特效前繪製一個臨時標記
var marker = ColorRect.new()
marker.size = Vector2(10, 10)
marker.color = Color.RED
marker.global_position = spawn_pos - Vector2(5, 5)
add_child(marker)
await get_tree().create_timer(1.0).timeout
marker.queue_free()

VFXManager.play_effect("hit", spawn_pos)
```

---

## 常見問題

### Q: 為什麼特效沒有顯示？

1. 檢查 VFXManager 是否已在 `project.godot` 中註冊為 autoload
2. 確認位置是否在畫面可見範圍內
3. 檢查是否有錯誤訊息在控制台

### Q: 特效位置不正確？

確保使用 `global_position` 而不是 `position`：
```gdscript
# ✅ 正確
VFXManager.play_effect("hit", enemy.global_position)

# ❌ 錯誤
VFXManager.play_effect("hit", enemy.position)
```

### Q: 如何讓特效跟隨移動的目標？

目前特效是獨立節點，不會自動跟隨。如需跟隨效果：
```gdscript
var effect = VFXManager.create_custom_effect("shield")
target_node.add_child(effect)  # 作為子節點會跟隨移動
effect.trigger(Vector2.ZERO)  # 使用相對位置
```

---

## 版本資訊

- **建立日期**: 2024-11-16
- **系統版本**: 1.0
- **相關文件**: `scripts/effects/README.md`
