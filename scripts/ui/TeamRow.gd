# scripts/ui/TeamRow.gd
# 單一隊伍橫排的控制器
extends PanelContainer

# ==================== 信號 ====================
signal edit_requested(team_id: String)
signal clear_requested(team_id: String)
signal battle_requested(team_id: String)
signal remove_member_requested(team_id: String, slot_index: int)

# ==================== 引用 ====================
@onready var team_name_label = $MarginContainer/HBoxContainer/ButtonVBox/TeamNameLabel
@onready var edit_button = $MarginContainer/HBoxContainer/ButtonVBox/EditButton
@onready var action_button = $MarginContainer/HBoxContainer/ButtonVBox/ActionButton
@onready var leader_skill_panel = $MarginContainer/HBoxContainer/LeaderSkillPanel
@onready var leader_skill_title = $MarginContainer/HBoxContainer/LeaderSkillPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var leader_skill_desc = $MarginContainer/HBoxContainer/LeaderSkillPanel/MarginContainer/VBoxContainer/DescScrollContainer/DescLabel
@onready var slots_container = $MarginContainer/HBoxContainer/TeamSlotsContainer

# ==================== 資料 ====================
var team_id: String = ""
var team_slots: Array = []
var is_selection_mode: bool = false

# ==================== 初始化 ====================
func _ready():
	# 獲取所有格子
	team_slots = slots_container.get_children()

	# 連接按鈕
	edit_button.pressed.connect(_on_edit_pressed)
	action_button.pressed.connect(_on_action_button_pressed)

	# 初始化格子索引 (用於辨識)
	for i in range(team_slots.size()):
		var slot = team_slots[i]
		if slot.has_method("setup_slot"): # 確保是 TeamSlot
			slot.setup_slot(i)
			# ✅ 連接移除按鈕信號
			slot.remove_clicked.connect(_on_slot_remove_clicked)
			
func set_selection_mode(is_selection: bool, team_is_empty: bool):
	is_selection_mode = is_selection
	if is_selection_mode:
		action_button.text = "⚔️ 戰鬥"
		# 如果是選擇模式，但隊伍是空的，則禁用戰鬥按鈕
		action_button.disabled = team_is_empty 
	else:
		action_button.text = "清空"
		# 如果是管理模式，隊伍是空的，則禁用清空按鈕 (維持您現有邏輯)
		action_button.disabled = team_is_empty

func setup(p_team_id: String, team_data: TeamData):
	"""
	設定此隊伍欄位的資料
	team_data 可以是 TeamData 物件，也可以是 null
	"""
	team_id = p_team_id
	team_name_label.text = "隊伍 %s" % team_id.replace("team_", "")

	if team_data == null or team_data.leader_card_id.is_empty():
		# 這是空隊伍
		for slot in team_slots:
			slot.show_empty()
		action_button.disabled = true
		set_selection_mode(is_selection_mode, true)
		# 隱藏隊長技能面板
		leader_skill_panel.visible = false
	else:
		# 這是有資料的隊伍
		action_button.disabled = false
		set_selection_mode(is_selection_mode, false)

		# 1. 設定隊長 (L1)
		var leader_slot = team_slots[0]
		leader_slot.set_card(team_data.leader_card_id)
		leader_slot.set_as_leader(true)

		# 2. 設定隊員 (A1 ~ A4)
		for i in range(1, team_slots.size()):
			var member_index = i - 1
			var slot = team_slots[i]

			if member_index < team_data.member_card_ids.size():
				# 有隊員
				var member_card_id = team_data.member_card_ids[member_index]
				slot.set_card(member_card_id)
				slot.set_as_leader(false)
			else:
				# 隊員欄位為空
				slot.show_empty()

		# 3. 更新隊長技能顯示
		update_leader_skill_display(team_data.leader_card_id)

func update_leader_skill_display(leader_instance_or_card_id: String):
	"""更新隊長技能顯示"""
	if leader_instance_or_card_id.is_empty():
		leader_skill_panel.visible = false
		return

	# ✅ 先嘗試將 instance_id 轉換為 card_id
	var card_id = PlayerDataManager.get_card_id_from_instance(leader_instance_or_card_id)

	# 如果轉換失敗，可能本身就是 card_id，直接使用
	if card_id.is_empty():
		card_id = leader_instance_or_card_id

	# 獲取隊長卡片數據
	var card = DataManager.get_card(card_id)
	if not card:
		leader_skill_panel.visible = false
		return

	# 檢查是否有隊長技能
	if card.leader_skill_ids.is_empty():
		leader_skill_panel.visible = false
		return

	# 顯示面板
	leader_skill_panel.visible = true

	# 組合所有隊長技能描述
	var desc_text = ""
	for skill_id in card.leader_skill_ids:
		var skill = SkillRegistry.get_skill_info(skill_id)
		if skill and not skill.is_empty():
			if not desc_text.is_empty():
				desc_text += "\n\n"
			desc_text += "◆ " + skill.skill_name + "\n"
			desc_text += skill.skill_description

	leader_skill_desc.text = desc_text

# ==================== 按鈕回調 ====================
func _on_edit_pressed():
	"""點擊編輯按鈕"""
	print("請求編輯隊伍: %s" % team_id)
	edit_requested.emit(team_id)
	
func _on_action_button_pressed():
	"""點擊了「清空」或「戰鬥」按鈕"""
	if is_selection_mode:
		print("請求戰鬥，隊伍: %s" % team_id)
		battle_requested.emit(team_id)
	else:
		print("請求清空隊伍: %s" % team_id)
		clear_requested.emit(team_id)

func _on_slot_remove_clicked(slot_index: int):
	"""TeamSlot 的移除按鈕被點擊"""
	print("請求移除格子 %d 的卡片，隊伍: %s" % [slot_index, team_id])
	remove_member_requested.emit(team_id, slot_index)
