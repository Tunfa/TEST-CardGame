# EvolutionHall.gd
# 升仙台 - 卡片進化系統
extends Control

# ==================== 場景預載 ====================
const EvolutionCardSlot = preload("res://scenes/evolution/EvolutionCardSlot.tscn")

# ==================== 節點引用 ====================
@onready var back_button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var card_list_panel = $MarginContainer/VBoxContainer/MainContent/LeftPanel/CardListPanel
@onready var card_list = $MarginContainer/VBoxContainer/MainContent/LeftPanel/CardListPanel/ScrollContainer/CardList

# 進化區域
@onready var evolution_area = $MarginContainer/VBoxContainer/MainContent/RightPanel/EvolutionArea
@onready var target_card_slot_container = $MarginContainer/VBoxContainer/MainContent/RightPanel/EvolutionArea/TargetCardSlotContainer
@onready var material_slots_container = $MarginContainer/VBoxContainer/MainContent/RightPanel/EvolutionArea/MaterialSlotsContainer

# 按鈕
@onready var auto_fill_button = $MarginContainer/VBoxContainer/BottomBar/AutoFillButton
@onready var evolve_button = $MarginContainer/VBoxContainer/BottomBar/EvolveButton

# 信息顯示
@onready var info_label = $MarginContainer/VBoxContainer/MainContent/RightPanel/InfoLabel
@onready var cost_label = $MarginContainer/VBoxContainer/BottomBar/CostLabel

# 進化預覽
@onready var preview_card_slot_container = $MarginContainer/VBoxContainer/MainContent/RightPanel/PreviewContainer/PreviewCardSlotContainer

# 卡片詳情面板
@onready var card_detail_panel = $CardDetailPanel

# ==================== 數據 ====================
var player_cards: Array = []  # 玩家擁有的所有卡片 (Array[CardData])
var card_database: Dictionary = {}  # 卡片定義數據庫 {card_id: card_data}

var target_card: CardData = null  # 放入中間的目標卡片
var target_card_slot_node = null  # 目標卡槽UI節點
var material_cards: Array = []  # 放入的素材卡片（最多5張，CardData或null）
var material_slots: Array = []  # 素材槽位UI節點

var preview_card_slot_node = null  # 進化預覽卡槽UI節點

const MAX_MATERIAL_SLOTS = 5
const EVOLUTION_GOLD_COST = 100

# ==================== 初始化 ====================
func _ready():
	back_button.pressed.connect(_on_back_pressed)
	auto_fill_button.pressed.connect(_on_auto_fill_pressed)
	evolve_button.pressed.connect(_on_evolve_pressed)

	# 初始化目標卡槽
	_create_target_card_slot()

	# 初始化素材槽位
	_create_material_slots()

	# 初始化進化預覽槽
	_create_preview_card_slot()

	# 載入卡片數據庫
	_load_card_database()

	# 載入玩家卡片
	_load_player_cards()

	# 更新UI
	_update_ui()
	update_evolution_info()

	# 檢查是否有從背包選中要進化的卡片
	_check_auto_select_card()

func _create_target_card_slot():
	"""創建目標卡槽"""
	target_card_slot_node = EvolutionCardSlot.instantiate()
	target_card_slot_node.custom_minimum_size = Vector2(150, 210)
	target_card_slot_node.slot_clicked.connect(_on_target_slot_clicked)
	target_card_slot_container.add_child(target_card_slot_node)
	target_card_slot_node.show_empty()

func _create_material_slots():
	"""創建5個素材槽位"""
	for i in range(MAX_MATERIAL_SLOTS):
		var slot = EvolutionCardSlot.instantiate()
		slot.custom_minimum_size = Vector2(90, 135)
		slot.slot_clicked.connect(_on_material_slot_pressed.bind(i))
		material_slots_container.add_child(slot)
		material_slots.append(slot)
		material_cards.append(null)
		slot.show_empty()

func _create_preview_card_slot():
	"""創建進化預覽卡槽"""
	preview_card_slot_node = EvolutionCardSlot.instantiate()
	preview_card_slot_node.custom_minimum_size = Vector2(150, 210)
	preview_card_slot_container.add_child(preview_card_slot_node)
	preview_card_slot_node.show_empty()
	# 連接點擊事件以顯示進化後卡片的詳情
	preview_card_slot_node.slot_clicked.connect(_on_preview_card_clicked)

func _load_card_database():
	"""從 JSON 載入卡片定義數據庫"""
	var file_path = "res://data/cards.json"
	if not FileAccess.file_exists(file_path):
		push_error("❌ 找不到卡片數據庫: " + file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("❌ 無法打開卡片數據庫")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("❌ JSON 解析錯誤: " + json.get_error_message())
		return

	var data = json.get_data()
	var cards_array = data.get("cards", [])

	# 建立 card_id -> card_data 的映射
	for card in cards_array:
		var card_id = card.get("card_id", "")
		if card_id != "":
			card_database[card_id] = card

	print("✅ 成功載入 %d 張卡片定義" % card_database.size())

func _load_player_cards():
	"""載入玩家卡片"""
	player_cards = PlayerDataManager.get_all_card_instances()
	print("✅ 玩家擁有 %d 張卡片" % player_cards.size())

	# 調試：列出所有卡片的進化信息
	for card in player_cards:
		if card.evoland.size() > 0:
			print("  📋 %s (Lv.%d/%d) evoland=%s material=%s 可進化=%s" % [
				card.card_name,
				card.current_level,
				card.max_level,
				card.evoland,
				card.material,
				_can_card_evolve(card)
			])

func _check_auto_select_card():
	"""檢查是否有從背包選中的卡片需要自動放入"""
	var selected_instance_id = GameManager.selected_card_for_evolution
	if selected_instance_id.is_empty():
		return

	# 清空選中的卡片（避免下次進入時重複選中）
	GameManager.selected_card_for_evolution = ""

	# 找到該卡片
	for card in player_cards:
		if card.instance_id == selected_instance_id:
			# 自動放入目標槽
			target_card = card

			# 清空素材槽
			for i in range(MAX_MATERIAL_SLOTS):
				material_cards[i] = null

			_update_target_card_display()
			_update_material_slots_display()
			update_evolution_info()

			print("✅ 自動選中卡片：%s" % card.card_name)
			break

# ==================== UI 更新 ====================
func _update_ui():
	"""更新卡片列表UI"""
	# 清空現有列表
	for child in card_list.get_children():
		child.queue_free()

	# 創建卡片按鈕
	for card in player_cards:
		_create_card_button(card)

func _create_card_button(card: CardData):
	"""創建卡片槽"""
	var slot = EvolutionCardSlot.instantiate()
	slot.custom_minimum_size = Vector2(0, 140)

	# 必須先 add_child，讓 @onready 變數初始化
	card_list.add_child(slot)

	# 然後才能調用 setup
	slot.setup(card, "list")

	# 檢查是否可進化
	var can_evolve = _can_card_evolve(card)
	var evoland = card.evoland
	var has_evolution = evoland.size() > 0

	if has_evolution and can_evolve:
		slot.set_status_text("✨可進化", Color(1, 0.85, 0))
	elif has_evolution:
		slot.set_status_text("🔒未滿等", Color(0.7, 0.7, 0.7))

	# 信號已經會傳遞 instance_id，不需要 bind
	slot.slot_clicked.connect(_on_card_selected)

	# 添加右鍵點擊顯示詳情（鼠標進入時啟用右鍵菜單）
	slot.gui_input.connect(_on_card_slot_gui_input.bind(card.instance_id))

func _update_target_card_display():
	"""更新目標卡片槽顯示"""
	if target_card == null:
		target_card_slot_node.show_empty()
		return

	target_card_slot_node.setup(target_card, "target")

func _update_material_slots_display():
	"""更新素材槽顯示"""
	for i in range(MAX_MATERIAL_SLOTS):
		var slot = material_slots[i]
		var mat_card = material_cards[i]

		if mat_card == null:
			slot.show_empty()
		else:
			slot.setup(mat_card, "material")

func _update_preview_card_display():
	"""更新進化預覽卡槽顯示"""
	if target_card == null or target_card.evoland.size() == 0:
		preview_card_slot_node.show_empty()
		return

	# 獲取進化後的卡片ID
	var evolved_card_id = target_card.evoland[0]

	# 創建一個臨時的 CardData 來顯示預覽
	var preview_card = DataManager.get_card(evolved_card_id)
	if preview_card:
		preview_card.instance_id = "preview_" + evolved_card_id  # 臨時ID用於預覽
		preview_card_slot_node.setup(preview_card, "preview")
		preview_card_slot_node.set_status_text("點擊查看詳情", Color(0.8, 0.8, 1.0))
	else:
		preview_card_slot_node.show_empty()

func update_evolution_info():
	"""更新進化信息顯示"""
	if target_card == null:
		info_label.text = "請選擇要進化的卡片"
		cost_label.text = ""
		evolve_button.disabled = true
		auto_fill_button.disabled = true
		preview_card_slot_node.show_empty()
		return

	auto_fill_button.disabled = false

	var evoland = target_card.evoland
	var materials_needed = target_card.material

	# 檢查是否有進化路線
	if evoland.size() == 0:
		info_label.text = "此卡尚無進化方向"
		cost_label.text = ""
		evolve_button.disabled = true
		preview_card_slot_node.show_empty()
		return

	# 檢查是否滿等
	var level = target_card.current_level
	var max_level = target_card.max_level
	if level < max_level:
		info_label.text = "需達到 Lv.%d 才能進化" % max_level
		cost_label.text = ""
		evolve_button.disabled = true
		preview_card_slot_node.show_empty()
		return

	var info_text = "消耗代價如下：\n"

	# 統計所需素材
	var material_count = {}
	for mat_id in materials_needed:
		material_count[mat_id] = material_count.get(mat_id, 0) + 1

	# 顯示素材需求
	for mat_id in material_count.keys():
		var mat_def = card_database.get(mat_id, {})
		var mat_name = mat_def.get("card_name", mat_id)
		var needed = material_count[mat_id]
		var owned = _count_available_material(mat_id)
		info_text += "%s x%d (持有%d個)\n" % [mat_name, needed, owned]

	info_label.text = info_text
	cost_label.text = "進化費用：%d 金幣" % EVOLUTION_GOLD_COST

	# 更新進化預覽卡槽
	_update_preview_card_display()

	# 按鈕總是可以點擊，點擊時檢查條件
	evolve_button.disabled = false

# ==================== 進化邏輯 ====================
func _can_card_evolve(card: CardData) -> bool:
	"""檢查卡片是否可以進化"""
	var evoland = card.evoland

	if evoland.size() == 0:
		return false

	var level = card.current_level
	var max_level = card.max_level

	return level >= max_level

func _check_evolution_requirements() -> bool:
	"""檢查進化條件是否滿足"""
	if target_card == null:
		return false

	var evoland = target_card.evoland
	var materials_needed = target_card.material

	# 檢查進化路線
	if evoland.size() == 0:
		return false

	# 檢查等級
	if not _can_card_evolve(target_card):
		return false

	# 檢查素材是否放入
	var placed_materials = []
	for mat in material_cards:
		if mat != null:
			placed_materials.append(mat.card_id)

	# 複製需求列表
	var needed = materials_needed.duplicate()
	for placed_id in placed_materials:
		var idx = needed.find(placed_id)
		if idx != -1:
			needed.remove_at(idx)

	if needed.size() > 0:
		return false

	# 檢查金幣
	if PlayerDataManager.get_gold() < EVOLUTION_GOLD_COST:
		return false

	return true

func _count_available_material(mat_id: String) -> int:
	"""統計可用的素材卡片數量（排除組隊中的）"""
	var count = 0
	for card in player_cards:
		if card.card_id == mat_id:
			# 檢查是否在組隊中
			if not PlayerDataManager.is_card_in_team(card.instance_id):
				count += 1
	return count

func _get_available_material_cards(mat_id: String) -> Array:
	"""獲取可用的素材卡片實例"""
	var cards = []
	for card in player_cards:
		if card.card_id == mat_id:
			if not PlayerDataManager.is_card_in_team(card.instance_id):
				cards.append(card)
	return cards

func _get_evolution_error_message() -> String:
	"""獲取進化失敗的具體原因"""
	if target_card == null:
		return "尚未選擇要進化的卡片"

	var evoland = target_card.evoland
	var materials_needed = target_card.material

	# 檢查進化路線
	if evoland.size() == 0:
		return "此卡片無法進化"

	# 檢查等級
	if not _can_card_evolve(target_card):
		return "卡片未達到滿等（需要 Lv.%d）" % target_card.max_level

	# 檢查素材是否放入
	var placed_materials = []
	for mat in material_cards:
		if mat != null:
			placed_materials.append(mat.card_id)

	# 檢查素材是否足夠
	var needed = materials_needed.duplicate()
	for placed_id in placed_materials:
		var idx = needed.find(placed_id)
		if idx != -1:
			needed.remove_at(idx)

	if needed.size() > 0:
		return "進化素材尚未放入完整"

	# 檢查金幣
	if PlayerDataManager.get_gold() < EVOLUTION_GOLD_COST:
		return "金幣不足！需要 %d 金幣，當前 %d 金幣" % [EVOLUTION_GOLD_COST, PlayerDataManager.get_gold()]

	return ""  # 沒有錯誤

# ==================== 事件處理 ====================
func _on_target_slot_clicked(_instance_id: String):
	"""點擊目標卡槽（清空）"""
	if target_card != null:
		target_card = null
		# 清空素材槽
		for i in range(MAX_MATERIAL_SLOTS):
			material_cards[i] = null

		_update_target_card_display()
		_update_material_slots_display()
		update_evolution_info()

func _on_card_selected(instance_id: String):
	"""選擇卡片作為進化目標"""
	# 找到卡片
	var card = null
	for c in player_cards:
		if c.instance_id == instance_id:
			card = c
			break

	if card == null:
		return

	# 檢查是否在組隊中
	if PlayerDataManager.is_card_in_team(instance_id):
		GameManager.show_message("無法進化", "此卡片正在組隊中，無法作為進化素材")
		return

	# 放入目標槽
	target_card = card

	# 清空素材槽
	for i in range(MAX_MATERIAL_SLOTS):
		material_cards[i] = null

	_update_target_card_display()
	_update_material_slots_display()
	update_evolution_info()

func _on_material_slot_pressed(_instance_id: String, slot_index: int):
	"""點擊素材槽（移除素材）"""
	if material_cards[slot_index] != null:
		material_cards[slot_index] = null
		_update_material_slots_display()
		update_evolution_info()

func _on_auto_fill_pressed():
	"""自動放入素材"""
	if target_card == null:
		return

	var materials_needed = target_card.material

	if materials_needed.size() == 0:
		GameManager.show_message("提示", "此卡片不需要素材")
		return

	# 清空現有素材
	for i in range(MAX_MATERIAL_SLOTS):
		material_cards[i] = null

	# 統計需求
	var needed_list = materials_needed.duplicate()
	var slot_idx = 0

	# 按需求放入素材
	while needed_list.size() > 0 and slot_idx < MAX_MATERIAL_SLOTS:
		var mat_id = needed_list[0]
		var available = _get_available_material_cards(mat_id)

		if available.size() > 0:
			# 找一張未被放入的
			var found = false
			for mat_card in available:
				var already_used = false
				for i in range(slot_idx):
					if material_cards[i] != null and material_cards[i].instance_id == mat_card.instance_id:
						already_used = true
						break

				if not already_used:
					material_cards[slot_idx] = mat_card
					slot_idx += 1
					needed_list.remove_at(0)
					found = true
					break

			if not found:
				break
		else:
			break

	if needed_list.size() > 0:
		GameManager.show_message("素材不足", "部分素材不足，請手動補充或獲取更多素材")

	_update_material_slots_display()
	update_evolution_info()

func _on_evolve_pressed():
	"""執行進化"""
	# 檢查進化條件並給出具體提示
	var error_msg = _get_evolution_error_message()
	if error_msg != "":
		GameManager.show_message("無法進化", error_msg)
		return

	var evoland = target_card.evoland
	var target_id = evoland[0]
	var target_def = card_database.get(target_id, {})
	var target_name = target_def.get("card_name", target_id)

	# 確認對話框
	var CustomDialog = load("res://scripts/ui/CustomDialog.gd")
	var dialog = CustomDialog.new()

	var message = "確定要進化成 %s 嗎？\n\n" % target_name
	message += "• 消耗素材將被移除\n"
	message += "• 原卡片將被取代\n"
	message += "• 新卡片從 Lv.1 開始\n"
	message += "• 消耗 %d 金幣\n\n" % EVOLUTION_GOLD_COST
	message += "此操作無法撤銷！"

	var buttons = [
		{"text": "取消", "action": "cancel"},
		{"text": "確認進化", "action": "evolve"}
	]
	dialog.setup_choice_dialog("確認進化", message, buttons)

	dialog.button_pressed.connect(func(action):
		if action == "evolve":
			await get_tree().create_timer(0.1).timeout
			_execute_evolution()
	)

	get_tree().root.add_child(dialog)
	dialog.show_dialog()

func _execute_evolution():
	"""執行進化（實際邏輯）"""
	var target_instance_id = target_card.instance_id
	var evoland = target_card.evoland
	var new_card_id = evoland[0]

	# 收集素材實例ID
	var material_instance_ids = []
	for mat in material_cards:
		if mat != null:
			material_instance_ids.append(mat.instance_id)

	# 播放進化動畫
	await _play_evolution_animation()

	# 調用 PlayerDataManager 進行進化
	var result = PlayerDataManager.evolve_card(target_instance_id, new_card_id, material_instance_ids, EVOLUTION_GOLD_COST)

	if result:
		# 進化成功
		var target_def = card_database.get(new_card_id, {})
		var target_name = target_def.get("card_name", new_card_id)

		GameManager.show_message("進化成功", "成功進化成 %s！" % target_name)

		# 清空選擇
		target_card = null
		for i in range(MAX_MATERIAL_SLOTS):
			material_cards[i] = null

		# 重新載入玩家卡片
		_load_player_cards()
		_update_ui()
		_update_target_card_display()
		_update_material_slots_display()
		update_evolution_info()
	else:
		GameManager.show_message("進化失敗", "進化過程出錯，請檢查日誌")

func _input(event: InputEvent):
	"""處理 ESC 鍵返回"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		_on_back_pressed()

func _on_back_pressed():
	"""返回主選單"""
	print("🔙 返回主選單")
	GameManager.goto_main_menu()

func _on_card_slot_gui_input(event: InputEvent, instance_id: String):
	"""處理卡片槽的輸入事件（右鍵顯示詳情）"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 顯示卡片詳情
			var slot_position = get_global_mouse_position()
			card_detail_panel.show_card_details_with_instance(instance_id, slot_position)

func _on_preview_card_clicked(_instance_id: String):
	"""點擊進化預覽卡槽（顯示進化後卡片的詳情）"""
	if target_card == null or target_card.evoland.size() == 0:
		return

	# 獲取進化後的卡片ID
	var evolved_card_id = target_card.evoland[0]

	# 顯示進化後卡片的詳情（使用模板ID，不含等級信息）
	var slot_position = get_global_mouse_position()
	card_detail_panel.show_card_details(evolved_card_id, slot_position)

# ==================== 進化動畫 ====================

func _play_evolution_animation():
	"""播放進化動畫效果"""
	# 1. 素材卡片飛入動畫
	await _animate_materials_flying()

	# 2. 閃光效果
	await _animate_flash_effect()

	# 3. 新卡片出現動畫
	await _animate_new_card_reveal()

func _animate_materials_flying():
	"""素材卡片飛入動畫"""
	var target_global_pos = target_card_slot_node.global_position
	var target_size = target_card_slot_node.size
	var target_center = target_global_pos + target_size / 2

	# 為每個素材創建飛行動畫
	var tweens = []
	for i in range(MAX_MATERIAL_SLOTS):
		var mat_slot = material_slots[i]
		var mat_card = material_cards[i]

		if mat_card == null:
			continue

		# 創建素材卡片的視覺副本
		var material_clone = ColorRect.new()
		material_clone.custom_minimum_size = mat_slot.size
		material_clone.size = mat_slot.size

		# 獲取素材卡片的顏色（根據元素）
		var ELEMENT_COLORS = {
			Constants.Element.METAL: Color("FFD700"),
			Constants.Element.WOOD: Color("33CC33"),
			Constants.Element.WATER: Color("3388FF"),
			Constants.Element.FIRE: Color("FF3333"),
			Constants.Element.EARTH: Color("CC9933"),
			Constants.Element.HEART: Color("FF66CC")
		}
		var mat_color = ELEMENT_COLORS.get(mat_card.element, Color.WHITE)
		material_clone.color = mat_color

		# 添加到場景（在最上層）
		add_child(material_clone)
		material_clone.global_position = mat_slot.global_position

		# 創建飛行動畫
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_IN)

		# 飛向目標中心
		tween.tween_property(material_clone, "global_position", target_center - material_clone.size / 2, 0.5).set_delay(i * 0.1)
		# 縮小
		tween.tween_property(material_clone, "scale", Vector2(0.3, 0.3), 0.5).set_delay(i * 0.1)
		# 淡出
		tween.tween_property(material_clone, "modulate:a", 0.0, 0.5).set_delay(i * 0.1)

		# 動畫結束後刪除副本
		tween.finished.connect(func(): material_clone.queue_free())

		tweens.append(tween)

	# 等待所有動畫完成
	if tweens.size() > 0:
		await tweens[-1].finished
	else:
		await get_tree().create_timer(0.1).timeout

func _animate_flash_effect():
	"""閃光效果"""
	# 創建白色閃光覆蓋
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = get_viewport_rect().size
	flash.position = Vector2.ZERO
	flash.z_index = 100
	add_child(flash)

	# 閃光動畫：淡入 -> 淡出
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.8, 0.2)
	tween.tween_property(flash, "color:a", 0.0, 0.3)

	await tween.finished
	flash.queue_free()

	# 目標卡片放大縮小效果
	var target_tween = create_tween()
	target_tween.set_trans(Tween.TRANS_ELASTIC)
	target_tween.set_ease(Tween.EASE_OUT)
	target_tween.tween_property(target_card_slot_node, "scale", Vector2(1.2, 1.2), 0.3)
	target_tween.tween_property(target_card_slot_node, "scale", Vector2(1.0, 1.0), 0.4)

	await target_tween.finished

func _animate_new_card_reveal():
	"""新卡片顯示動畫"""
	# 這裡暫時只是一個簡單的等待
	# 實際的卡片更新會在 _execute_evolution 中的 PlayerDataManager.evolve_card 之後進行
	await get_tree().create_timer(0.2).timeout
