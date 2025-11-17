# 訓練室任務引導示例

## 需求場景

進入訓練室後的引導流程：
1. 高亮"編輯隊伍"按鈕 → 等待玩家選完角色
2. 高亮"開始訓練"按鈕 → 等待玩家點擊開始
3. 等待訓練完成（倒計時結束）
4. 高亮"領取獎勵"按鈕（此時按鈕文字已變）

---

## 步驟 1: 為 UI 元素設置高亮 ID

### 1.1 修改 TrainingScene.gd

在 `_ready()` 函數中為按鈕設置元數據：

```gdscript
func _ready():
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	confirm_button.pressed.connect(_on_selector_confirm_pressed)
	cancel_button.pressed.connect(_on_selector_cancel_pressed)

	# ✅ 為按鈕設置高亮 ID（策略1 - 元數據）
	if start_button:
		start_button.set_meta("highlight_id", "start_training_button")
	if back_button:
		back_button.set_meta("highlight_id", "back_button")

	# 創建計時器...
	timer = Timer.new()
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)
	timer.start(1.0)

	# 其餘初始化代碼...
```

### 1.2 修改 TrainingTeamRow.gd

在 `_ready()` 函數中為編輯按鈕設置元數據：

```gdscript
func _ready():
	edit_button.pressed.connect(_on_edit_pressed)
	clear_button.pressed.connect(_on_clear_pressed)

	# ✅ 為編輯按鈕設置高亮 ID
	if edit_button:
		# 使用 team_index 區分不同隊伍的編輯按鈕
		edit_button.set_meta("highlight_id", "edit_team_button_%d" % team_index)

	# 連接所有槽位按鈕...
```

**或者**，如果只想高亮第一個隊伍的編輯按鈕：

```gdscript
func setup(index: int, cards: Array = []):
	"""設定隊伍數據"""
	team_index = index
	team_cards = cards.duplicate()
	team_label.text = "訓練隊伍 %d" % (team_index + 1)

	# ✅ 只為第一個隊伍設置高亮 ID
	if team_index == 0 and edit_button:
		edit_button.set_meta("highlight_id", "edit_first_team_button")

	update_display()
```

---

## 步驟 2: 配置任務 JSON

在 `data/config/quests.json` 中創建訓練教學任務：

```json
{
  "quest_id": "training_tutorial_001",
  "quest_name": "訓練室新手教學",
  "quest_description": "學習如何使用訓練室訓練你的道侶",
  "is_mandatory": true,
  "steps": [
    {
      "step_id": "enter_training_room",
      "description": "進入訓練室",
      "dialog_id": "training_tutorial_enter",
      "condition": {
        "type": "scene_entered",
        "scene_name": "training_scene"
      },
      "actions": [
        {
          "type": "highlight_ui",
          "target": "edit_first_team_button",
          "highlight_type": "red_flash"
        }
      ],
      "allowed_actions": {
        "type": "specific_ui",
        "allowed_targets": ["edit_first_team_button"]
      }
    },
    {
      "step_id": "edit_team",
      "description": "組建訓練隊伍",
      "dialog_id": "training_tutorial_edit_team",
      "condition": {
        "type": "custom",
        "event": "team_edited",
        "data": {
          "team_index": 0,
          "cards_count_min": 1
        }
      },
      "actions": [
        {
          "type": "highlight_ui",
          "target": "start_training_button",
          "highlight_type": "red_flash"
        }
      ],
      "allowed_actions": {
        "type": "specific_ui",
        "allowed_targets": ["start_training_button"]
      }
    },
    {
      "step_id": "start_training",
      "description": "開始訓練",
      "dialog_id": "training_tutorial_start",
      "condition": {
        "type": "custom",
        "event": "training_started"
      },
      "actions": [],
      "allowed_actions": {
        "type": "all"
      }
    },
    {
      "step_id": "wait_training_complete",
      "description": "等待訓練完成",
      "condition": {
        "type": "custom",
        "event": "training_completed"
      },
      "actions": [
        {
          "type": "highlight_ui",
          "target": "start_training_button",
          "highlight_type": "red_flash"
        }
      ],
      "allowed_actions": {
        "type": "specific_ui",
        "allowed_targets": ["start_training_button"]
      }
    },
    {
      "step_id": "claim_reward",
      "description": "領取訓練獎勵",
      "condition": {
        "type": "custom",
        "event": "training_reward_claimed"
      },
      "actions": [],
      "allowed_actions": {
        "type": "all"
      }
    }
  ]
}
```

---

## 步驟 3: 在 TrainingScene.gd 中觸發任務事件

在適當的時機通知任務系統：

```gdscript
# 當玩家編輯隊伍後
func _on_selector_confirm_pressed():
	"""確認選擇"""
	if current_editing_team_index >= 0 and current_editing_team_index < training_teams.size():
		training_teams[current_editing_team_index] = selected_cards_for_edit.duplicate()

	card_selector_modal.visible = false
	update_training_teams()

	# ✅ 通知任務系統：隊伍已編輯
	TaskManager.notify_event("team_edited", {
		"team_index": current_editing_team_index,
		"cards_count": selected_cards_for_edit.size()
	})

# 當玩家開始訓練時
func _on_start_button_pressed():
	"""開始訓練按鈕被按下"""
	if current_state == TrainingState.IDLE:
		# 開始訓練
		start_training()

		# ✅ 通知任務系統：訓練已開始
		TaskManager.notify_event("training_started", {
			"room_id": room_data.get("room_id", "")
		})

	elif current_state == TrainingState.COMPLETED:
		# 領取獎勵
		claim_rewards()

		# ✅ 通知任務系統：獎勵已領取
		TaskManager.notify_event("training_reward_claimed", {
			"exp": exp_reward
		})

# 當訓練完成時
func check_training_status():
	"""檢查訓練狀態（每秒調用）"""
	if PlayerDataManager.is_training_active():
		var training_data = PlayerDataManager.get_training_data()
		remaining_time = training_data.get("remaining_time", 0)

		if remaining_time <= 0:
			# 訓練完成
			current_state = TrainingState.COMPLETED
			update_start_button_text()

			# ✅ 通知任務系統：訓練完成
			TaskManager.notify_event("training_completed", {
				"room_id": room_data.get("room_id", "")
			})

func update_start_button_text():
	"""更新開始訓練按鈕文字"""
	match current_state:
		TrainingState.IDLE:
			start_button.text = "開始訓練"
		TrainingState.TRAINING:
			start_button.text = "訓練中..."
			start_button.disabled = true
		TrainingState.COMPLETED:
			start_button.text = "領取獎勵"  # ⭐ 按鈕文字變更
			start_button.disabled = false
```

---

## 步驟 4: 配置對話框

在 `data/config/dialogs.json` 中添加對應的對話：

```json
[
  {
    "dialog_id": "training_tutorial_enter",
    "speaker": "系統",
    "speaker_avatar": "system",
    "content": "歡迎來到訓練室！\n\n點擊「編輯隊伍」按鈕組建你的訓練隊伍。",
    "choices": [
      {
        "text": "我知道了",
        "action": "next"
      }
    ]
  },
  {
    "dialog_id": "training_tutorial_edit_team",
    "speaker": "系統",
    "speaker_avatar": "system",
    "content": "很好！你已經組建了訓練隊伍。\n\n現在點擊「開始訓練」按鈕開始訓練。",
    "choices": [
      {
        "text": "開始訓練！",
        "action": "next"
      }
    ]
  },
  {
    "dialog_id": "training_tutorial_start",
    "speaker": "系統",
    "speaker_avatar": "system",
    "content": "訓練已開始！\n\n請耐心等待訓練完成。你可以先去做其他事情，訓練會在後台進行。",
    "choices": [
      {
        "text": "了解",
        "action": "next"
      }
    ]
  }
]
```

---

## 工作流程圖

```
進入訓練室場景
    ↓
[高亮: edit_first_team_button]  ← 紅色閃爍
    ↓
玩家點擊編輯隊伍 → 選擇卡片 → 確認
    ↓
觸發事件: team_edited
    ↓
[高亮: start_training_button]   ← 紅色閃爍
    ↓
玩家點擊開始訓練
    ↓
觸發事件: training_started
    ↓
倒計時進行中... (按鈕文字: "訓練中...")
    ↓
倒計時結束
    ↓
觸發事件: training_completed
    ↓
按鈕文字變為: "領取獎勵"
    ↓
[高亮: start_training_button]   ← 紅色閃爍（同一個按鈕）
    ↓
玩家點擊領取獎勵
    ↓
觸發事件: training_reward_claimed
    ↓
任務完成！
```

---

## 關鍵點總結

1. **元數據設置**：為所有需要高亮的按鈕設置 `highlight_id`
2. **事件觸發**：在關鍵操作後調用 `TaskManager.notify_event()`
3. **條件檢查**：任務系統會自動檢查條件並進入下一步
4. **動態按鈕**：即使按鈕文字改變，高亮 ID 不變，仍能正確高亮
5. **限制操作**：使用 `allowed_actions` 確保玩家只能點擊高亮的按鈕

---

## 測試檢查清單

- [ ] 進入訓練室後，"編輯隊伍"按鈕是否紅色閃爍？
- [ ] 編輯隊伍後，"開始訓練"按鈕是否紅色閃爍？
- [ ] 開始訓練後，高亮是否消失？
- [ ] 訓練完成後，"領取獎勵"按鈕是否紅色閃爍？
- [ ] 領取獎勵後，任務是否完成？
- [ ] 整個過程中，是否顯示了對應的對話框？

---

## 進階用法：多隊伍支持

如果訓練室支持多個隊伍同時訓練，可以這樣設置：

```gdscript
# TrainingTeamRow.gd
func setup(index: int, cards: Array = []):
	team_index = index
	team_cards = cards.duplicate()
	team_label.text = "訓練隊伍 %d" % (team_index + 1)

	# 為每個隊伍的編輯按鈕設置唯一 ID
	if edit_button:
		edit_button.set_meta("highlight_id", "edit_team_button_%d" % team_index)

	update_display()
```

然後在任務配置中：

```json
{
  "type": "highlight_ui",
  "target": "edit_team_button_0",  // 高亮第1個隊伍
  "highlight_type": "red_flash"
}
```

或者高亮所有未編輯的隊伍：

```json
{
  "type": "highlight_ui",
  "targets": [
    "edit_team_button_0",
    "edit_team_button_1",
    "edit_team_button_2"
  ],
  "highlight_type": "red_flash"
}
```

（注意：這需要擴展 TaskManager 支持 `targets` 數組）
