# VFXManager 視覺特效系統

這是一個模組化的視覺特效系統，類似於 `AudioManager` 的設計模式，用於統一管理遊戲中的粒子特效。

## 特效列表

目前可用的特效：

1. **hit** - 打擊特效（白色→橙色→紅色）
2. **explosion** - 爆炸特效（黃色→紅色→黑色）
3. **heal** - 治療特效（綠色→青色→藍色）
4. **critical** - 暴擊特效（金色閃爍）
5. **shield** - 護盾特效（藍色環繞）

## 基本使用方法

### 方法 1：使用位置播放

```gdscript
# 在指定位置播放特效
VFXManager.play_effect("hit", Vector2(100, 100))
VFXManager.play_effect("explosion", enemy.global_position)
```

### 方法 2：在節點上播放

```gdscript
# 在節點的位置播放特效
VFXManager.play_effect_at_node("heal", player_card)
VFXManager.play_effect_at_node("critical", enemy)
```

### 方法 3：使用便捷方法

```gdscript
# 直接使用快捷方法
VFXManager.hit(enemy.global_position)
VFXManager.explosion(Vector2(200, 200))
VFXManager.heal(player.global_position)
VFXManager.critical(target.global_position)
VFXManager.shield(player.global_position)
```

## 進階使用

### 批量播放特效

```gdscript
# 在多個位置同時播放
var enemy_positions = [enemy1.position, enemy2.position, enemy3.position]
VFXManager.play_multiple_effects("explosion", enemy_positions)
```

### 自定義特效

```gdscript
# 創建不自動播放的特效，可自定義屬性
var my_effect = VFXManager.create_custom_effect("shield")
my_effect.scale = Vector2(2, 2)  # 放大 2 倍
my_effect.modulate = Color(1, 0, 0)  # 改成紅色
add_child(my_effect)
my_effect.trigger(position)
```

### 獲取特效引用

```gdscript
# play_effect 會返回創建的特效節點
var effect = VFXManager.play_effect("explosion", pos)
if effect:
    # 可以進一步操作特效
    effect.scale = Vector2(1.5, 1.5)
```

## 實際範例

### 在戰鬥系統中使用

```gdscript
# BattleScene.gd 或 Enemy.gd

func take_damage(damage: int, is_critical: bool = false):
    # 扣血邏輯
    health -= damage

    # 播放對應特效
    if is_critical:
        VFXManager.critical(global_position)
    else:
        VFXManager.hit(global_position)

    # 死亡時播放爆炸
    if health <= 0:
        VFXManager.explosion(global_position)

func heal(amount: int):
    health += amount
    VFXManager.heal(global_position)

func activate_shield():
    shield_active = true
    VFXManager.shield(global_position)
```

### 在技能系統中使用

```gdscript
# SkillEffectHandler.gd

func apply_skill_effect(skill_name: String, target: Node2D):
    match skill_name:
        "fire_ball":
            VFXManager.explosion(target.global_position)
        "healing_light":
            VFXManager.heal(target.global_position)
        "iron_wall":
            VFXManager.shield(target.global_position)
        "critical_strike":
            VFXManager.critical(target.global_position)
```

## 如何添加新特效

### 1. 創建特效腳本

在 `scripts/effects/` 目錄下創建新的特效腳本：

```gdscript
# MyNewEffect.gd
extends BaseEffect

func _init():
    effect_lifetime = 0.8  # 持續時間
    particle_amount = 40   # 粒子數量

func setup_material():
    var mat = ParticleProcessMaterial.new()
    process_material = mat

    # 設定你的粒子屬性...
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    mat.emission_sphere_radius = 10.0

    # 設定顏色
    var gradient_tex = _create_gradient([
        Color(1, 0, 0, 1),  # 紅色
        Color(0, 0, 0, 0)   # 透明
    ], [0.0, 1.0])
    mat.color_ramp = gradient_tex
```

### 2. 註冊到 VFXManager

在 `VFXManager.gd` 的 `vfx_library` 中添加：

```gdscript
var vfx_library = {
    # ... 現有特效 ...
    "my_new_effect": preload("res://scripts/effects/MyNewEffect.gd"),
}
```

### 3. 添加便捷方法（可選）

```gdscript
func my_new_effect(pos: Vector2) -> GPUParticles2D:
    return play_effect("my_new_effect", pos)
```

## 技術細節

### 節點池管理

- VFXManager 會自動管理特效節點
- 最多同時播放 20 個特效（可調整 `max_active_effects`）
- 自動清理已完成的特效
- 避免記憶體洩漏

### 效能考量

- 所有特效使用 GPU 粒子（GPUParticles2D）
- 特效完成後自動刪除
- 使用預載（preload）減少運行時加載

### BaseEffect 類

所有特效都繼承自 `BaseEffect`，提供：

- `trigger(pos)` - 觸發特效
- `_create_gradient(colors, positions)` - 創建顏色漸變
- 自動清理機制

## 常見問題

### Q: 特效不顯示？

1. 確保已將 VFXManager 註冊為 autoload
2. 檢查特效位置是否在可見範圍內
3. 檢查父節點是否正確

### Q: 如何調整特效大小？

```gdscript
var effect = VFXManager.play_effect("explosion", pos)
effect.scale = Vector2(2, 2)  # 放大 2 倍
```

### Q: 如何改變特效顏色？

```gdscript
var effect = VFXManager.play_effect("hit", pos)
effect.modulate = Color(0, 1, 0)  # 改成綠色
```

### Q: 特效太多會影響效能嗎？

VFXManager 有自動限制，超過 20 個會自動清理最舊的特效。可調整：

```gdscript
# 在任何地方設定
VFXManager.max_active_effects = 30
```

## 與 AudioManager 配合使用

```gdscript
# 同時播放音效和特效
func attack_enemy(enemy):
    AudioManager.play_sfx("player_attack")  # 音效
    VFXManager.hit(enemy.global_position)   # 視覺特效
```

---

**版本**: 1.0
**最後更新**: 2024
