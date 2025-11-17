# GachaScreen.gd
# 抽卡界面控制器（完整版）
extends Control

# ==================== 節點引用 ====================
@onready var back_button = $VBoxContainer/TopBar/HBoxContainer/BackButton
@onready var gold_label = $VBoxContainer/TopBar/HBoxContainer/CurrencyContainer/GoldLabel
@onready var gem_label = $VBoxContainer/TopBar/HBoxContainer/CurrencyContainer/GemLabel
@onready var ticket_label = $VBoxContainer/TopBar/HBoxContainer/CurrencyContainer/TicketLabel

# 卡池選擇容器
@onready var pools_container = $VBoxContainer/MainContent/LeftPanel/MarginContainer/VBox/PoolsScroll/PoolsContainer

# 中央顯示區
@onready var pool_title = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/DisplayArea/CenterContainer/PreviewContainer/PoolTitle
@onready var pool_description = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/DisplayArea/CenterContainer/PreviewContainer/PoolDescription
@onready var showcase_cards_container = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/DisplayArea/CenterContainer/PreviewContainer/ShowcaseCards

@onready var current_pity = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/PityCounter/HBox/CurrentPity
@onready var total_pulls = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/PityCounter/HBox/TotalPulls
@onready var last_legendary = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/PityCounter/HBox/LastLegendary

# 抽卡按鈕
@onready var single_pull_button = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/ButtonsContainer/SinglePullButton
@onready var ten_pull_button = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/ButtonsContainer/TenPullButton
@onready var details_button = $VBoxContainer/MainContent/CenterPanel/VBoxContainer/ButtonsContainer/DetailsButton

# 抽卡記錄
@onready var history_list = $VBoxContainer/MainContent/RightPanel/MarginContainer/VBox/HistoryScroll/HistoryList

# 結果顯示
@onready var result_overlay = $ResultOverlay
@onready var result_cards_container = $ResultOverlay/ResultPanel/VBox/ScrollContainer/CardsContainer
@onready var result_confirm_button = $ResultOverlay/ResultPanel/VBox/ConfirmButton

# 詳情面板
@onready var details_overlay = $DetailsOverlay
@onready var details_pool_name = $DetailsOverlay/DetailsPanel/VBox/PoolName
@onready var details_rates = $DetailsOverlay/DetailsPanel/VBox/RatesContainer
@onready var details_card_list = $DetailsOverlay/DetailsPanel/VBox/ScrollContainer/CardList
@onready var details_close_button = $DetailsOverlay/DetailsPanel/VBox/CloseButton

# 卡片詳情面板
@onready var card_detail_panel = $CardDetailPanel

# ==================== 變量 ====================
var current_pool: String = "standard"
var pity_counter: int = 0
var total_pull_count: int = 0
var pulls_since_last_legendary: int = 0

var gacha_pools: Dictionary = {}
var current_pool_config: Dictionary = {}

# 卡池按鈕引用
var pool_buttons: Dictionary = {}

const GACHA_CONFIG_PATH = "res://data/config/gacha_pools.json"

# 動畫相關
var is_pulling: bool = false

# ==================== 初始化 ====================
func _ready():
	print("🎰 抽卡界面載入")

	load_gacha_config()
	create_pool_buttons()

	back_button.pressed.connect(_on_back_pressed)
	single_pull_button.pressed.connect(_on_single_pull)
	ten_pull_button.pressed.connect(_on_ten_pull)
	details_button.pressed.connect(_on_details_pressed)
	result_confirm_button.pressed.connect(_on_result_confirmed)
	details_close_button.pressed.connect(_on_details_closed)

	update_currency_display()
	select_pool("standard")
	update_pity_display()

	result_overlay.visible = false
	details_overlay.visible = false

# ==================== 卡池按鈕動態生成 ====================
func create_pool_buttons():
	"""根據 JSON 動態創建卡池選擇按鈕"""
	# 清空現有按鈕
	for child in pools_container.get_children():
		child.queue_free()

	pool_buttons.clear()

	# 為每個卡池創建按鈕
	for pool_id in gacha_pools.keys():
		var pool_data = gacha_pools[pool_id]
		var button = create_pool_button(pool_id, pool_data)
		pools_container.add_child(button)
		pool_buttons[pool_id] = button

func create_pool_button(pool_id: String, pool_data: Dictionary) -> Button:
	"""創建單個卡池按鈕"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(220, 100)
	button.toggle_mode = true

	# 創建按鈕內容容器
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(vbox)

	# 卡池名稱
	var name_label = Label.new()
	name_label.text = pool_data.get("name", "未命名卡池")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# 卡池描述
	var desc_label = Label.new()
	desc_label.text = pool_data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.custom_minimum_size = Vector2(200, 0)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	# 設置顏色
	var icon_color_str = pool_data.get("icon_color", "#4A90E2")
	var icon_color = Color(icon_color_str)
	
	# 使用 StyleBox 設置背景顏色
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = icon_color.darkened(0.3)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = icon_color
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = icon_color.darkened(0.1)
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = icon_color.lightened(0.3)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = icon_color
	pressed_style.border_width_left = 4
	pressed_style.border_width_top = 4
	pressed_style.border_width_right = 4
	pressed_style.border_width_bottom = 4
	pressed_style.border_color = Color.WHITE
	pressed_style.corner_radius_top_left = 8
	pressed_style.corner_radius_top_right = 8
	pressed_style.corner_radius_bottom_left = 8
	pressed_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("pressed", pressed_style)

	# 連接信號
	button.pressed.connect(_on_pool_button_pressed.bind(pool_id))

	return button

func _on_pool_button_pressed(pool_id: String):
	"""卡池按鈕被按下"""
	select_pool(pool_id)

func select_pool(pool_id: String):
	"""選擇卡池"""
	current_pool = pool_id

	# 更新按鈕狀態
	for pid in pool_buttons.keys():
		var btn = pool_buttons[pid]
		btn.button_pressed = (pid == pool_id)

	# 載入卡池配置
	if gacha_pools.has(pool_id):
		current_pool_config = gacha_pools[pool_id]

	update_pool_display()
	update_pity_display()
	update_button_costs()

# ==================== JSON配置載入 ====================
func load_gacha_config():
	"""從JSON文件載入抽卡池配置"""
	if not FileAccess.file_exists(GACHA_CONFIG_PATH):
		push_error("⚠️ 找不到抽卡配置文件: " + GACHA_CONFIG_PATH)
		return

	var file = FileAccess.open(GACHA_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("⚠️ 無法打開抽卡配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("⚠️ 解析抽卡配置JSON失敗: " + json.get_error_message())
		return

	var data = json.data
	if not data.has("pools"):
		push_error("⚠️ 抽卡配置格式錯誤：缺少pools字段")
		return

	for pool in data["pools"]:
		if pool.has("id"):
			gacha_pools[pool["id"]] = pool

	print("✅ 成功載入 %d 個抽卡池配置" % gacha_pools.size())

# ==================== 更新顯示 ====================
func update_currency_display():
	"""更新玩家貨幣顯示"""
	var gold = PlayerDataManager.get_gold()
	var gems = PlayerDataManager.get_diamond()

	gold_label.text = "💰 %d" % gold
	gem_label.text = "💎 %d" % gems
	ticket_label.text = "🎫 10"

func update_pool_display():
	"""更新卡池顯示"""
	pool_title.text = current_pool_config.get("name", "未知卡池")
	pool_description.text = current_pool_config.get("description", "")

	# 更新展示卡片
	update_showcase_cards()

func update_showcase_cards():
	"""更新展示卡片"""
	# 清空現有展示
	for child in showcase_cards_container.get_children():
		child.queue_free()

	var showcase_ids = current_pool_config.get("showcase_cards", [])
	
	for card_id in showcase_ids:
		var card_data = DataManager.get_card(card_id)
		if card_data:
			var card_preview = create_mini_card_preview(card_data)
			showcase_cards_container.add_child(card_preview)

func create_mini_card_preview(card_data: CardData) -> Control:
	"""創建迷你卡片預覽"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(100, 120)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 讓事件穿透到 panel
	panel.add_child(vbox)

	# 卡片圖片區域
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(90, 90)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 讓事件穿透到 panel

	var card_texture = DataManager.get_card_texture(card_data.card_id)
	if card_texture:
		texture_rect.texture = card_texture

	vbox.add_child(texture_rect)

	# 卡片名稱
	var name_label = Label.new()
	name_label.text = card_data.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 讓事件穿透到 panel
	vbox.add_child(name_label)

	# 設置稀有度背景色
	var style_box = StyleBoxFlat.new()
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	match card_data.rarity:
		Constants.CardRarity.LEGENDARY:
			style_box.bg_color = Color(1, 0.85, 0, 0.2)
			style_box.border_color = Color(1, 0.85, 0)
		Constants.CardRarity.EPIC:
			style_box.bg_color = Color(0.8, 0.5, 1, 0.2)
			style_box.border_color = Color(0.8, 0.5, 1)
		Constants.CardRarity.RARE:
			style_box.bg_color = Color(0.3, 0.6, 1, 0.2)
			style_box.border_color = Color(0.3, 0.6, 1)
		_:
			style_box.bg_color = Color(0.6, 0.6, 0.6, 0.2)
			style_box.border_color = Color(0.6, 0.6, 0.6)

	panel.add_theme_stylebox_override("panel", style_box)

	# ✅ 添加右鍵點擊顯示卡片詳情
	panel.gui_input.connect(_on_showcase_card_gui_input.bind(card_data.card_id))

	return panel

func update_button_costs():
	"""更新抽卡按鈕的消費顯示"""
	var single_cost = current_pool_config.get("single_pull_cost", 1)
	var ten_cost = current_pool_config.get("ten_pull_cost", 10)
	var currency = current_pool_config.get("currency", "gem")
	var currency_icon = "💰" if currency == "gold" else "💎"

	single_pull_button.text = "單抽 %s%d" % [currency_icon, single_cost]
	ten_pull_button.text = "十連 %s%d" % [currency_icon, ten_cost]

func update_pity_display():
	"""更新保底計數器顯示"""
	var pity_threshold = current_pool_config.get("pity_threshold", 90)
	var remaining = max(0, pity_threshold - pulls_since_last_legendary)
	current_pity.text = "距離保底: %d抽" % remaining
	total_pulls.text = "累計: %d次" % total_pull_count
	last_legendary.text = "上次傳說: %d抽前" % pulls_since_last_legendary

# ==================== 抽卡邏輯 ====================
func _on_single_pull():
	"""單抽"""
	if is_pulling:
		return

	# ✅ 檢查背包是否已滿（不允許臨時突破）
	if PlayerDataManager.is_bag_over_capacity():
		show_notification("❌ 背包已滿！請先前往背包整理")
		return

	var cost = current_pool_config.get("single_pull_cost", 1)
	var currency = current_pool_config.get("currency", "gem")

	if not check_and_spend_currency(currency, cost):
		return

	is_pulling = true
	var results = perform_gacha(1)
	await show_gacha_animation(results)
	show_gacha_results(results)
	is_pulling = false

	update_currency_display()
	update_pity_display()

func _on_ten_pull():
	"""十連抽"""
	if is_pulling:
		return

	# ✅ 檢查背包是否已滿（不允許臨時突破）
	if PlayerDataManager.is_bag_over_capacity():
		show_notification("❌ 背包已滿！請先前往背包整理")
		return

	var cost = current_pool_config.get("ten_pull_cost", 10)
	var currency = current_pool_config.get("currency", "gem")

	if not check_and_spend_currency(currency, cost):
		return

	is_pulling = true
	var results = perform_gacha(10)
	await show_gacha_animation(results)
	show_gacha_results(results)
	is_pulling = false

	update_currency_display()
	update_pity_display()

func check_and_spend_currency(currency: String, cost: int) -> bool:
	"""檢查並扣除貨幣"""
	if currency == "gem":
		if PlayerDataManager.get_diamond() < cost:
			show_notification("❌ 寶石不足！需要 %d 💎" % cost)
			return false
		PlayerDataManager.spend_diamond(cost)
	else:
		if PlayerDataManager.get_gold() < cost:
			show_notification("❌ 金幣不足！需要 %d 💰" % cost)
			return false
		PlayerDataManager.spend_gold(cost)
	
	return true

func perform_gacha(count: int) -> Array:
	"""執行抽卡並返回結果"""
	var results = []

	for i in range(count):
		var card_data = draw_single_card()
		results.append(card_data)

		total_pull_count += 1
		pulls_since_last_legendary += 1

		if card_data.rarity == Constants.CardRarity.LEGENDARY:
			pulls_since_last_legendary = 0

		PlayerDataManager.add_card(card_data.card_id)
		add_to_history(card_data)

	PlayerDataManager.save_data()
	return results

func draw_single_card() -> CardData:
	"""抽取單張卡片"""
	var legendary_rate = current_pool_config.get("legendary_rate", 0.01)
	var epic_rate = current_pool_config.get("epic_rate", 0.05)
	var rare_rate = current_pool_config.get("rare_rate", 0.20)
	var pity_threshold = current_pool_config.get("pity_threshold", 90)

	if pulls_since_last_legendary >= pity_threshold:
		return get_random_card_by_rarity(Constants.CardRarity.LEGENDARY)

	var rand_val = randf()

	if rand_val < legendary_rate:
		return get_random_card_by_rarity(Constants.CardRarity.LEGENDARY)
	elif rand_val < legendary_rate + epic_rate:
		return get_random_card_by_rarity(Constants.CardRarity.EPIC)
	elif rand_val < legendary_rate + epic_rate + rare_rate:
		return get_random_card_by_rarity(Constants.CardRarity.RARE)
	else:
		return get_random_card_by_rarity(Constants.CardRarity.COMMON)

func get_random_card_by_rarity(rarity: Constants.CardRarity) -> CardData:
	"""根據稀有度獲取隨機卡片"""
	var card_pool = current_pool_config.get("card_pool", {})
	var card_ids = []

	match rarity:
		Constants.CardRarity.LEGENDARY:
			card_ids = card_pool.get("legendary", [])
		Constants.CardRarity.EPIC:
			card_ids = card_pool.get("epic", [])
		Constants.CardRarity.RARE:
			card_ids = card_pool.get("rare", [])
		Constants.CardRarity.COMMON:
			card_ids = card_pool.get("common", [])

	if card_ids.is_empty():
		card_ids = ["C001", "C002", "C003"]

	var random_id = card_ids[randi() % card_ids.size()]
	var card = DataManager.get_card(random_id)

	if card:
		# ✅ 不覆蓋卡片原本的稀有度，使用卡片定義中的稀有度
		return card
	else:
		var temp_card = CardData.new()
		temp_card.card_id = random_id
		temp_card.card_name = "測試卡片 " + random_id
		temp_card.rarity = rarity
		return temp_card

# ==================== 抽卡動畫 ====================
func show_gacha_animation(results: Array):
	"""播放抽卡動畫"""
	if results.size() == 1:
		# 單抽動畫
		await play_single_pull_animation(results[0])
	else:
		# 十連抽動畫
		await play_multi_pull_animation(results)

	print("✨ 抽卡動畫播放完成")

func play_single_pull_animation(card_data: CardData):
	"""單抽動畫：卡背從上方掉落，點擊翻牌顯示結果"""
	# 創建動畫層（黑色背景）
	var anim_layer = ColorRect.new()
	anim_layer.color = Color(0, 0, 0, 0.9)
	anim_layer.size = get_viewport_rect().size
	anim_layer.position = Vector2.ZERO
	anim_layer.z_index = 150
	add_child(anim_layer)

	var viewport_size = get_viewport_rect().size

	# 創建卡背顯示
	var card_back = create_card_back_display()
	anim_layer.add_child(card_back)

	# 設置初始位置（螢幕上方）
	var start_pos = Vector2(viewport_size.x / 2 - 75, -200)
	var end_pos = Vector2(viewport_size.x / 2 - 75, viewport_size.y / 2 - 125)

	card_back.position = start_pos
	card_back.modulate.a = 0.5

	# 創建提示文字
	var hint_label = Label.new()
	hint_label.text = "點擊翻牌"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hint_label.position = Vector2(viewport_size.x / 2 - 100, viewport_size.y - 100)
	hint_label.custom_minimum_size = Vector2(200, 40)
	anim_layer.add_child(hint_label)

	# 動畫序列
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 1. 卡背掉落（帶彈跳效果）
	tween.tween_property(card_back, "position", end_pos, 0.8)
	tween.parallel().tween_property(card_back, "modulate:a", 1.0, 0.8)

	# 2. 小幅彈跳
	tween.tween_property(card_back, "position:y", end_pos.y + 20, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_back, "position:y", end_pos.y, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	# ✅ 使用字典存儲可變狀態（避免 lambda 捕獲變量錯誤）
	var click_state = {"clicked": false}

	# 處理點擊事件
	var on_click = func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			click_state["clicked"] = true

	# ✅ 連接點擊事件到卡背（只有點擊卡片才能翻牌）
	card_back.gui_input.connect(on_click)

	# 等待玩家點擊翻牌
	while not click_state["clicked"]:
		await get_tree().create_timer(0.1).timeout

	# 翻牌動畫
	hint_label.visible = false
	await play_card_flip_animation(anim_layer, card_back, card_data, viewport_size)

	# 停留顯示
	await get_tree().create_timer(1.0).timeout

	# 清理動畫層
	anim_layer.queue_free()
	
	

func play_multi_pull_animation(results: Array):
	"""十連抽動畫：依次顯示所有卡片（帶翻牌效果）"""
	# 創建動畫層（黑色背景）
	var anim_layer = ColorRect.new()
	anim_layer.color = Color(0, 0, 0, 0.9)
	anim_layer.size = get_viewport_rect().size
	anim_layer.position = Vector2.ZERO
	anim_layer.z_index = 150
	add_child(anim_layer)

	var viewport_size = get_viewport_rect().size
	var current_index = 0
	var current_card_front = null  # 當前顯示的卡片正面（用於清理）

	# 創建提示文字
	var hint_label = Label.new()
	hint_label.text = "點擊翻牌 (%d/%d)" % [current_index + 1, results.size()]
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hint_label.position = Vector2(viewport_size.x / 2 - 200, viewport_size.y - 100)
	hint_label.custom_minimum_size = Vector2(400, 40)
	anim_layer.add_child(hint_label)

	# ✅ 創建跳過按鈕
	var skip_button = Button.new()
	skip_button.text = "跳過"
	skip_button.custom_minimum_size = Vector2(100, 50)
	#skip_button.position = Vector2(viewport_size.x / 2 - 200, viewport_size.y - 200)
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.88, 0.75, 0.28, 1.0) # 深色底 (R, G, B, Alpha)
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.88, 0.75, 0.28, 1.0) # 懸停
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.1, 0.12, 0.15, 0.7) # 按下
	skip_button.add_theme_stylebox_override("normal", style_normal)
	skip_button.add_theme_stylebox_override("hover", style_hover)
	skip_button.add_theme_stylebox_override("pressed", style_pressed)
	skip_button.add_theme_color_override("font_color", Color.WHITE)
	skip_button.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9))
	anim_layer.add_child(skip_button)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skip_button.position.y -= 200
	skip_button.position.x -= 35

	# ✅ 使用字典存儲可變狀態（避免 lambda 捕獲變量錯誤）
	var click_state = {"clicked": false, "skip": false}

	# 處理點擊事件
	var on_click = func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			click_state["clicked"] = true

	# 處理跳過按鈕
	var on_skip = func():
		click_state["skip"] = true

	# 連接跳過按鈕
	skip_button.pressed.connect(on_skip)

	# 循環顯示所有卡片
	while current_index < results.size():
		# ✅ 檢查是否按下跳過按鈕
		if click_state["skip"]:
			break

		var card_data = results[current_index]
		hint_label.text = "點擊翻牌 (%d/%d)" % [current_index + 1, results.size()]

		# ✅ 清理上一張卡片（避免圖層重疊）
		if current_card_front != null:
			current_card_front.queue_free()
			current_card_front = null

		# 創建卡背（從上方掉落）
		var card_back_display = create_card_back_display()
		var start_pos = Vector2(viewport_size.x / 2 - 75, -200)
		var end_pos = Vector2(viewport_size.x / 2 - 75, viewport_size.y / 2 - 125)
		card_back_display.position = start_pos
		card_back_display.modulate.a = 0.5
		anim_layer.add_child(card_back_display)

		# ✅ 卡背掉落動畫（帶彈跳效果）
		var drop_tween = create_tween()
		drop_tween.set_trans(Tween.TRANS_CUBIC)
		drop_tween.set_ease(Tween.EASE_OUT)
		drop_tween.tween_property(card_back_display, "position", end_pos, 0.6)
		drop_tween.parallel().tween_property(card_back_display, "modulate:a", 1.0, 0.6)

		# 小幅彈跳
		drop_tween.tween_property(card_back_display, "position:y", end_pos.y + 15, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		drop_tween.tween_property(card_back_display, "position:y", end_pos.y, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

		await drop_tween.finished

		# ✅ 檢查是否按下跳過按鈕
		if click_state["skip"]:
			break

		# ✅ 連接點擊事件到卡背（只有點擊卡片才能翻牌）
		card_back_display.gui_input.connect(on_click)

		# 等待玩家點擊翻牌
		click_state["clicked"] = false
		while not click_state["clicked"] and not click_state["skip"]:
			await get_tree().create_timer(0.1).timeout

		# ✅ 檢查是否按下跳過按鈕
		if click_state["skip"]:
			break

		# 翻牌動畫（卡背 -> 卡片正面）
		current_card_front = await play_card_flip_animation(anim_layer, card_back_display, card_data, viewport_size)

		# ✅ 檢查是否按下跳過按鈕
		if click_state["skip"]:
			break

		# 如果不是最後一張，等待點擊切換下一張
		if current_index < results.size() - 1:
			# ✅ 連接點擊事件到卡片正面（點擊卡片切換下一張）
			current_card_front.gui_input.connect(on_click)

			hint_label.text = "點擊顯示下一張 (%d/%d)" % [current_index + 2, results.size()]
			click_state["clicked"] = false
			while not click_state["clicked"] and not click_state["skip"]:
				await get_tree().create_timer(0.1).timeout

		current_index += 1

	# ✅ 如果不是跳過，所有卡片顯示完畢，等待點擊關閉
	if not click_state["skip"]:
		# ✅ 連接點擊事件到最後一張卡片（點擊卡片關閉動畫）
		if current_card_front != null:
			current_card_front.gui_input.connect(on_click)

		hint_label.text = "點擊關閉"
		click_state["clicked"] = false
		while not click_state["clicked"]:
			await get_tree().create_timer(0.1).timeout

	# 清理動畫層
	anim_layer.queue_free()

func create_card_back_display() -> PanelContainer:
	"""創建卡背顯示"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 250)

	# 創建一個簡單的卡背樣式（深藍色背景 + 裝飾）
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# 卡背圖案（使用文字代替，你可以之後換成圖片）
	var back_label = Label.new()
	back_label.text = "🎴"
	back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_label.add_theme_font_size_override("font_size", 64)
	vbox.add_child(back_label)

	var text_label = Label.new()
	text_label.text = "點擊翻牌"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(text_label)

	# 卡背樣式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.3, 0.5, 1.0)
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style_box)

	return panel

func play_card_flip_animation(parent: Node, card_back: Control, card_data: CardData, viewport_size: Vector2) -> Control:
	"""播放翻牌動畫，返回創建的卡片正面"""
	# 翻牌動畫：縮小（翻轉效果）-> 切換卡片 -> 放大
	var flip_tween = create_tween()
	flip_tween.set_trans(Tween.TRANS_CUBIC)
	flip_tween.set_ease(Tween.EASE_IN_OUT)

	# 1. 卡背縮小到 0 寬度（翻轉到側面）
	flip_tween.tween_property(card_back, "scale:x", 0.0, 0.2)

	await flip_tween.finished

	# 2. 隱藏卡背，顯示卡片正面
	card_back.queue_free()

	# 創建卡片正面
	var card_front = create_animated_card_display(card_data)
	card_front.position = Vector2(viewport_size.x / 2 - 75, viewport_size.y / 2 - 125)
	card_front.scale.x = 0.0  # 從側面開始
	parent.add_child(card_front)

	# 3. 卡片正面從側面放大
	var show_tween = create_tween()
	show_tween.set_trans(Tween.TRANS_CUBIC)
	show_tween.set_ease(Tween.EASE_OUT)
	show_tween.tween_property(card_front, "scale:x", 1.0, 0.2)

	# 4. 閃光效果
	show_tween.tween_interval(0.1)
	for i in range(2):
		show_tween.tween_property(card_front, "scale", Vector2(1.05, 1.05), 0.1)
		show_tween.parallel().tween_property(card_front, "modulate", Color(1.3, 1.3, 1.3, 1), 0.1)
		show_tween.tween_property(card_front, "scale", Vector2(1.0, 1.0), 0.1)
		show_tween.parallel().tween_property(card_front, "modulate", Color(1, 1, 1, 1), 0.1)

	await show_tween.finished

	return card_front

func create_animated_card_display(card_data: CardData) -> PanelContainer:
	"""創建用於動畫的卡片顯示"""
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(150, 250)

	var vbox = VBoxContainer.new()
	card_panel.add_child(vbox)

	# 卡片圖片
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(140, 180)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var card_texture = DataManager.get_card_texture(card_data.card_id)
	if card_texture:
		texture_rect.texture = card_texture

	vbox.add_child(texture_rect)

	# 稀有度標籤
	var rarity_label = Label.new()
	rarity_label.text = get_rarity_name(card_data.rarity)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.add_theme_color_override("font_color", get_rarity_color(card_data.rarity))
	vbox.add_child(rarity_label)

	# 卡片名稱
	var name_label = Label.new()
	name_label.text = card_data.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# 稀有度背景
	var style_box = StyleBoxFlat.new()
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10

	match card_data.rarity:
		Constants.CardRarity.LEGENDARY:
			style_box.bg_color = Color(1, 0.85, 0, 0.4)
			style_box.border_color = Color(1, 0.85, 0, 1)
		Constants.CardRarity.EPIC:
			style_box.bg_color = Color(0.8, 0.5, 1, 0.4)
			style_box.border_color = Color(0.8, 0.5, 1, 1)
		Constants.CardRarity.RARE:
			style_box.bg_color = Color(0.3, 0.6, 1, 0.4)
			style_box.border_color = Color(0.3, 0.6, 1, 1)
		_:
			style_box.bg_color = Color(0.6, 0.6, 0.6, 0.4)
			style_box.border_color = Color(0.6, 0.6, 0.6, 1)

	card_panel.add_theme_stylebox_override("panel", style_box)

	return card_panel

# ==================== 結果顯示 ====================
func show_gacha_results(results: Array):
	"""顯示抽卡結果"""
	for child in result_cards_container.get_children():
		child.queue_free()

	for card_data in results:
		var card_display = create_result_card_display(card_data)
		result_cards_container.add_child(card_display)

	result_overlay.visible = true

func create_result_card_display(card_data: CardData) -> Control:
	"""創建結果卡片顯示"""
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(130, 180)

	var vbox = VBoxContainer.new()
	card_panel.add_child(vbox)

	# 卡片圖片
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(110, 120)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var card_texture = DataManager.get_card_texture(card_data.card_id)
	if card_texture:
		texture_rect.texture = card_texture
	
	vbox.add_child(texture_rect)

	# 稀有度標籤
	var rarity_label = Label.new()
	rarity_label.text = get_rarity_name(card_data.rarity)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", get_rarity_color(card_data.rarity))
	vbox.add_child(rarity_label)

	# 卡片名稱
	var label = Label.new()
	label.text = card_data.card_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(label)

	# 稀有度背景
	var style_box = StyleBoxFlat.new()
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	match card_data.rarity:
		Constants.CardRarity.LEGENDARY:
			style_box.bg_color = Color(1, 0.85, 0, 0.4)
			style_box.border_color = Color(1, 0.85, 0, 1)
		Constants.CardRarity.EPIC:
			style_box.bg_color = Color(0.8, 0.5, 1, 0.4)
			style_box.border_color = Color(0.8, 0.5, 1, 1)
		Constants.CardRarity.RARE:
			style_box.bg_color = Color(0.3, 0.6, 1, 0.4)
			style_box.border_color = Color(0.3, 0.6, 1, 1)
		_:
			style_box.bg_color = Color(0.6, 0.6, 0.6, 0.4)
			style_box.border_color = Color(0.6, 0.6, 0.6, 1)
	
	card_panel.add_theme_stylebox_override("panel", style_box)

	return card_panel

func _on_result_confirmed():
	"""確認結果"""
	result_overlay.visible = false

# ==================== 詳情面板 ====================
func _on_details_pressed():
	"""顯示卡池詳情"""
	show_pool_details()

func show_pool_details():
	"""顯示卡池詳細資訊"""
	details_pool_name.text = current_pool_config.get("name", "未知卡池")

	# 顯示機率
	for child in details_rates.get_children():
		child.queue_free()

	var rates_info = [
		"傳說: %.2f%%" % (current_pool_config.get("legendary_rate", 0.01) * 100),
		"史詩: %.2f%%" % (current_pool_config.get("epic_rate", 0.05) * 100),
		"稀有: %.2f%%" % (current_pool_config.get("rare_rate", 0.20) * 100),
		"保底: %d 抽" % current_pool_config.get("pity_threshold", 90)
	]

	for info in rates_info:
		var label = Label.new()
		label.text = "• " + info
		details_rates.add_child(label)

	# 顯示所有可抽卡片
	for child in details_card_list.get_children():
		child.queue_free()

	var card_pool = current_pool_config.get("card_pool", {})
	
	for rarity_key in ["legendary", "epic", "rare", "common"]:
		var card_ids = card_pool.get(rarity_key, [])
		
		for card_id in card_ids:
			var card_data = DataManager.get_card(card_id)
			if card_data:
				var card_item = create_details_card_item(card_data)
				details_card_list.add_child(card_item)

	details_overlay.visible = true

func create_details_card_item(card_data: CardData) -> Control:
	"""創建詳情中的卡片項目"""
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 60)
	
	# 卡片圖示
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(50, 50)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var card_texture = DataManager.get_card_texture(card_data.card_id)
	if card_texture:
		texture_rect.texture = card_texture
	
	hbox.add_child(texture_rect)

	# 卡片資訊
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label = Label.new()
	name_label.text = card_data.card_name
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var rarity_label = Label.new()
	rarity_label.text = get_rarity_name(card_data.rarity)
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", get_rarity_color(card_data.rarity))
	vbox.add_child(rarity_label)

	hbox.add_child(vbox)

	return hbox

func get_rarity_name(rarity: Constants.CardRarity) -> String:
	"""獲取稀有度名稱"""
	match rarity:
		Constants.CardRarity.LEGENDARY:
			return "⭐ 傳說"
		Constants.CardRarity.EPIC:
			return "💜 史詩"
		Constants.CardRarity.RARE:
			return "💙 稀有"
		_:
			return "⚪ 普通"

func get_rarity_color(rarity: Constants.CardRarity) -> Color:
	"""獲取稀有度顏色"""
	match rarity:
		Constants.CardRarity.LEGENDARY:
			return Color(1, 0.85, 0)
		Constants.CardRarity.EPIC:
			return Color(0.8, 0.5, 1)
		Constants.CardRarity.RARE:
			return Color(0.3, 0.6, 1)
		_:
			return Color(0.7, 0.7, 0.7)

func _on_details_closed():
	"""關閉詳情面板"""
	details_overlay.visible = false

# ==================== 抽卡記錄 ====================
func add_to_history(card_data: CardData):
	"""添加到抽卡記錄"""
	var history_item = HBoxContainer.new()
	
	# 時間標籤
	var time_label = Label.new()
	time_label.text = Time.get_time_string_from_system()
	time_label.custom_minimum_size = Vector2(80, 0)
	history_item.add_child(time_label)
	
	# 卡片名稱
	var name_label = Label.new()
	name_label.text = card_data.card_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_item.add_child(name_label)
	
	# 稀有度
	var rarity_label = Label.new()
	rarity_label.text = get_rarity_name(card_data.rarity)
	rarity_label.add_theme_color_override("font_color", get_rarity_color(card_data.rarity))
	history_item.add_child(rarity_label)
	
	# 添加到列表頂部
	history_list.add_child(history_item)
	history_list.move_child(history_item, 0)
	
	# 限制記錄數量
	while history_list.get_child_count() > 20:
		var last_child = history_list.get_child(history_list.get_child_count() - 1)
		last_child.queue_free()

# ==================== 輔助函數 ====================
func show_notification(message: String):
	"""顯示通知訊息"""
	print(message)

	# 使用統一對話框顯示通知
	var CustomDialog = load("res://scripts/ui/CustomDialog.gd")
	var dialog = CustomDialog.new()
	dialog.setup_info_dialog("提示", message)
	get_tree().root.add_child(dialog)
	dialog.show_dialog()

func _on_showcase_card_gui_input(event: InputEvent, card_id: String):
	"""處理展示卡片的輸入事件（右鍵顯示詳情）"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 顯示卡片詳情（使用卡片ID，不含等級資訊）
			var mouse_position = get_global_mouse_position()
			card_detail_panel.show_card_details(card_id, mouse_position)

func _input(event: InputEvent):
	"""處理 ESC 鍵返回"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		if result_overlay.visible:
			# 如果結果面板打開，關閉它
			_on_result_confirmed()
		elif details_overlay.visible:
			# 如果詳情面板打開，關閉它
			_on_details_closed()
		else:
			# 正常返回
			_on_back_pressed()

func _on_back_pressed():
	"""返回主選單"""
	print("← 返回主選單")
	GameManager.goto_main_menu()
