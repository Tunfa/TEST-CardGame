# 任務系統 UI 高亮指南

## 概述

任務系統的 UI 高亮功能支援智能查找節點，無需為每個按鈕硬編碼路徑。

## 支援的查找策略（優先級從高到低）

### 策略 1: 元數據查找（推薦） ⭐

為需要高亮的節點設置元數據 `highlight_id`：

```gdscript
# 在任何 UI 腳本中
var my_button = Button.new()
my_button.set_meta("highlight_id", "my_special_button")
add_child(my_button)
```

在任務配置中使用：
```json
{
  "type": "highlight_ui",
  "target": "my_special_button",
  "highlight_type": "red_flash"
}
```

**優點**：
- ✅ 最靈活，不依賴節點名稱或位置
- ✅ 可以在不改變節點名稱的情況下設置高亮 ID
- ✅ 支持動態創建的節點

### 策略 2: 組查找

將節點加入特定組：

```gdscript
# 在 UI 腳本中
var my_button = Button.new()
add_child(my_button)
my_button.add_to_group("highlight_my_special_button")
```

在任務配置中使用：
```json
{
  "type": "highlight_ui",
  "target": "my_special_button",
  "highlight_type": "red_flash"
}
```

**注意**: 組名會自動加上前綴 `highlight_`，所以 target `"my_special_button"` 會查找組 `"highlight_my_special_button"`。

### 策略 3: 節點名稱查找

直接使用節點名稱（遞歸查找）：

```gdscript
# 在 UI 腳本中
var my_button = Button.new()
my_button.name = "my_special_button"
add_child(my_button)
```

在任務配置中使用：
```json
{
  "type": "highlight_ui",
  "target": "my_special_button",
  "highlight_type": "red_flash"
}
```

**優點**：
- ✅ 簡單直接，無需額外設置
- ✅ 支持場景樹任意深度的遞歸查找

**缺點**：
- ❌ 如果有多個同名節點，只會返回第一個找到的
- ❌ 修改節點名稱會破壞高亮功能

### 策略 4: 硬編碼路徑（舊版兼容）

僅用於向後兼容，**不推薦新代碼使用**。

```gdscript
# 在 TaskManager.gd 中硬編碼
"my_button":
    if current_scene.has_node("MarginContainer/VBoxContainer/MyButton"):
        return current_scene.get_node("MarginContainer/VBoxContainer/MyButton")
```

## 實際範例

### 範例 1: 訓練室按鈕

```gdscript
# TrainingRoomSelect.gd
func create_room_button(room_data: Dictionary):
    var room_id = room_data.get("room_id", "")
    var button_container = PanelContainer.new()

    # 使用策略 1 + 策略 3（雙保險）
    button_container.name = "training_room_" + room_id
    button_container.set_meta("highlight_id", "training_room_" + room_id)

    add_child(button_container)
```

任務配置：
```json
{
  "type": "highlight_ui",
  "target": "training_room_TR_001",
  "highlight_type": "red_flash"
}
```

### 範例 2: 通用返回按鈕

在場景的 `_ready()` 中設置：
```gdscript
func _ready():
    # 如果按鈕已經在場景樹中
    if back_button:
        back_button.set_meta("highlight_id", "back_button")
```

或在創建按鈕時：
```gdscript
back_button = Button.new()
back_button.name = "BackButton"
back_button.set_meta("highlight_id", "back_button")
```

## 最佳實踐

1. **優先使用元數據**：為所有可能需要高亮的 UI 元素設置 `highlight_id` 元數據
2. **使用有意義的 ID**：使用清晰的命名，如 `"training_room_TR_001"` 而不是 `"btn1"`
3. **雙保險**：同時設置元數據和節點名稱，確保查找成功
4. **文檔記錄**：在代碼註釋中說明該節點可被任務系統高亮

## 調試

查找過程會在控制台輸出詳細日誌：

```
🔍 開始查找高亮目標: training_room_TR_001
✅ 透過元數據找到節點: training_room_TR_001
```

如果找不到節點：
```
🔍 開始查找高亮目標: my_button
❌ 找不到高亮目標: my_button
```

檢查清單：
- [ ] 節點是否已經創建並加入場景樹？
- [ ] 元數據 `highlight_id` 是否正確設置？
- [ ] 節點名稱是否匹配 target？
- [ ] 是否在正確的場景中查找？

## 性能考量

- **元數據查找**：需要遞歸遍歷場景樹，但通常很快（< 1ms）
- **組查找**：O(1) 查找，最快
- **節點名稱查找**：需要遞歸遍歷，與元數據查找相同性能
- **硬編碼路徑**：O(1) 查找，但不靈活

對於大型場景（>1000 節點），建議優先使用組查找。
