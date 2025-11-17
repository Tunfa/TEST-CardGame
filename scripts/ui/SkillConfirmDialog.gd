# SkillConfirmDialog.gd
# 技能確認對話框
extends AcceptDialog

# ==================== 信號 ====================
signal skill_confirmed(card: CardData, target: EnemyData)
signal skill_cancelled()

# ==================== 引用 ====================
@onready var skill_name_label = $VBoxContainer/SkillNameLabel
@onready var skill_desc_label = $VBoxContainer/SkillDescLabel
@onready var confirm_button = $VBoxContainer/ButtonContainer/ConfirmButton
@onready var cancel_button = $VBoxContainer/ButtonContainer/CancelButton

# ==================== 資料 ====================
var current_card: CardData = null
var current_target: EnemyData = null

# ==================== 初始化 ====================

func _ready():
	hide()
	
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm)
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel)

# ==================== 顯示對話框 ====================

func show_skill_dialog(card: CardData, target: EnemyData = null, p_battle_manager = null):
	"""顯示技能確認對話框 (新版：會計算動態數值)"""
	print("\n🔍 [SkillConfirmDialog] show_skill_dialog 被調用")
	print("  - 卡片: %s" % (card.card_name if card else "null"))

	current_card = card
	current_target = target

	if not card or not card.active_skill:
		print("  ❌ 卡片或技能為 null，取消顯示")
		return

	var skill = card.active_skill
	print("  - 技能: %s" % skill.skill_name)

	# 1. 設置技能名稱 (安全訪問)
	var skill_name = ""
	if "skill_name" in skill:
		skill_name = skill.skill_name
	else:
		skill_name = "未知技能"
	skill_name_label.text = skill_name

	# 2. 設置技能描述
	var base_description = ""
	if "skill_description" in skill:
		base_description = skill.skill_description
	else:
		base_description = "無描述"
	var final_description = base_description
	var calculated_value_str = ""

	# 3. 計算動態數值
	var skill_id = ""
	if "skill_id" in skill:
		skill_id = skill.skill_id
	match skill_id:	
		"active_heavy_strike":
			if "multiplier" in skill:
				var damage = int(card.current_atk * skill.multiplier)
				calculated_value_str = str(damage)
		"active_aoe_damage":
			if "multiplier" in skill:
				var damage = int(card.current_atk * skill.multiplier)
				calculated_value_str = str(damage)

		"active_heal":
			if p_battle_manager:
				# 需要 battle_manager 來獲取全隊回復力
				var heal_amount = p_battle_manager.total_recovery
				calculated_value_str = str(heal_amount)
			else:
				calculated_value_str = "?" # 預防 battle_manager 未傳入

		_:
			# 其他沒有 {value} 的技能會保持原樣
			pass

	# 4. 替換佔位符
	if not calculated_value_str.is_empty():
		final_description = base_description.replace("{value}", calculated_value_str)

	# 5. 設置最終的技能描述
	skill_desc_label.text = final_description

	# 6. 檢查 CD 和 END_TURN_DAMAGE 限制
	var can_use = card.can_use_active_skill()

	# ✅ 檢查 END_TURN_DAMAGE 技能使用限制
	# 只有在「刚斩击结束」AND「已有主动技能 END_TURN_DAMAGE Buff」时才阻止
	if can_use and p_battle_manager and p_battle_manager.slash_ended:
		if card.active_skill and "effects" in card.active_skill:
			for effect in card.active_skill.effects:
				if effect.get("effect_type", "") == "END_TURN_DAMAGE":
					# 检查是否已经有 END_TURN_DAMAGE Buff 在生效
					if p_battle_manager.has_active_buff("END_TURN_DAMAGE"):
						can_use = false
					break

	if can_use:
		confirm_button.disabled = false
		confirm_button.text = "確定"
	else:
		confirm_button.disabled = true

		if card.is_stunned:
			confirm_button.text = "眩暈中"
		elif card.active_skill_current_cd > 0:
			confirm_button.text = "CD: %d" % card.active_skill_current_cd
		elif p_battle_manager and p_battle_manager.slash_ended:
			# ✅ 新增：顯示斬擊剛結束的提示
			var has_end_turn_damage = false
			if card.active_skill and "effects" in card.active_skill:
				for effect in card.active_skill.effects:
					if effect.get("effect_type", "") == "END_TURN_DAMAGE":
						has_end_turn_damage = true
						break
			# 只有当有现存的 Buff 时才显示"請先斬擊"
			if has_end_turn_damage and p_battle_manager.has_active_buff("END_TURN_DAMAGE"):
				confirm_button.text = "請先斬擊"
			else:
				confirm_button.text = "無法使用"
		else:
			confirm_button.text = "無法使用"

	print("  ✓ 準備顯示對話框...")
	print("    - 技能名稱: %s" % skill_name_label.text)
	print("    - 技能描述: %s" % skill_desc_label.text)
	print("    - 按鈕文字: %s" % confirm_button.text)
	popup_centered()
	print("  ✓ popup_centered() 已調用")

# ==================== 按鈕回調 ====================

func _on_confirm():
	"""確認使用技能"""
	skill_confirmed.emit(current_card, current_target)
	hide()

func _on_cancel():
	"""取消使用技能"""
	skill_cancelled.emit()
	hide()
