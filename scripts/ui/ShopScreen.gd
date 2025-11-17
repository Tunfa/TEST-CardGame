# ShopScreen.gd
# 商店界面控制器 - 模組化版本
extends Control

# ==================== 節點引用 ====================
@onready var back_button = $VBoxContainer/TopBar/HBoxContainer/BackButton
@onready var gold_label = $VBoxContainer/TopBar/HBoxContainer/CurrencyContainer/GoldLabel
@onready var gem_label = $VBoxContainer/TopBar/HBoxContainer/CurrencyContainer/GemLabel
@onready var tab_container = $VBoxContainer/TabContainer
@onready var shop_items_grid = $VBoxContainer/ScrollContainer/ShopItemsGrid

# 當前選中的標籤
var current_tab: String = ""

# 從JSON載入的配置
var shop_tabs: Array = []  # 商城按鈕配置
var tab_buttons: Dictionary = {}  # 按鈕ID -> Button節點
var shop_items: Array = []
var items_by_category: Dictionary = {}

# JSON配置文件路徑
const SHOP_CONFIG_PATH = "res://data/config/shop_config.json"
const SHOP_ITEMS_PATH = "res://data/config/shop_items.json"

# ==================== 初始化 ====================
func _ready():
	print("🏪 商店界面載入（模組化版本）")

	# 載入配置
	load_shop_tab_config()
	load_shop_items_config()

	# 連接按鈕信號
	back_button.pressed.connect(_on_back_pressed)

	# 創建商城按鈕
	create_tab_buttons()

	# 更新貨幣顯示
	update_currency_display()

	# 顯示第一個標籤的內容
	if shop_tabs.size() > 0:
		switch_to_tab(shop_tabs[0]["id"])

# ==================== JSON配置載入 ====================
func load_shop_tab_config():
	"""從JSON文件載入商城按鈕配置"""
	if not FileAccess.file_exists(SHOP_CONFIG_PATH):
		push_error("⚠️ 找不到商城配置文件: " + SHOP_CONFIG_PATH)
		return

	var file = FileAccess.open(SHOP_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("⚠️ 無法打開商城配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("⚠️ 解析商城配置JSON失敗: " + json.get_error_message())
		return

	var data = json.data
	if not data.has("tabs"):
		push_error("⚠️ 商城配置格式錯誤：缺少tabs字段")
		return

	shop_tabs = data["tabs"]
	print("✅ 成功載入 %d 個商城按鈕配置" % shop_tabs.size())

func load_shop_items_config():
	"""從JSON文件載入商店物品配置"""
	if not FileAccess.file_exists(SHOP_ITEMS_PATH):
		push_error("⚠️ 找不到商店物品配置文件: " + SHOP_ITEMS_PATH)
		return

	var file = FileAccess.open(SHOP_ITEMS_PATH, FileAccess.READ)
	if file == null:
		push_error("⚠️ 無法打開商店物品配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("⚠️ 解析商店物品配置JSON失敗: " + json.get_error_message())
		return

	var data = json.data
	if not data.has("items"):
		push_error("⚠️ 商店物品配置格式錯誤：缺少items字段")
		return

	shop_items = data["items"]

	# 按分類組織物品
	items_by_category.clear()
	for item in shop_items:
		var category = item.get("category", "items")
		if not items_by_category.has(category):
			items_by_category[category] = []
		items_by_category[category].append(item)

	print("✅ 成功載入 %d 個商店物品配置" % shop_items.size())

# ==================== 更新顯示 ====================
func update_currency_display():
	"""更新玩家貨幣顯示"""
	var gold = PlayerDataManager.get_gold()
	var gems = PlayerDataManager.get_diamond()

	gold_label.text = "💰 金幣: %d" % gold
	gem_label.text = "💎 寶石: %d" % gems

# ==================== 動態創建商城按鈕 ====================
func create_tab_buttons():
	"""動態創建商城按鈕"""
	# 清空現有按鈕
	for child in tab_container.get_children():
		child.queue_free()

	tab_buttons.clear()

	# 根據配置創建按鈕
	for tab_config in shop_tabs:
		var button = Button.new()
		button.custom_minimum_size = Vector2(150, 50)
		button.theme_type_variation = "Button"
		button.add_theme_font_size_override("font_size", 20)
		button.toggle_mode = true

		# 設置按鈕文字（包含圖標）
		var icon = tab_config.get("icon", "")
		var tab_name = tab_config.get("name", "")
		button.text = "%s %s" % [icon, tab_name]

		# 連接信號
		var tab_id = tab_config.get("id", "")
		button.pressed.connect(_on_tab_pressed.bind(tab_id, tab_config))

		# 添加到容器
		tab_container.add_child(button)
		tab_buttons[tab_id] = button

	print("✅ 成功創建 %d 個商城按鈕" % tab_buttons.size())

func _on_tab_pressed(tab_id: String, tab_config: Dictionary):
	"""處理按鈕點擊"""
	var tab_type = tab_config.get("type", "")

	match tab_type:
		"navigate":
			# 導航到其他場景
			var action = tab_config.get("action", "")
			handle_navigation(action)
		"shop_items":
			# 顯示商品列表
			switch_to_tab(tab_id)

func handle_navigation(action: String):
	"""處理場景導航"""
	match action:
		"goto_gacha":
			print("🎰 前往抽卡系統")
			GameManager.goto_gacha()
		_:
			print("⚠️ 未知的導航動作: " + action)

# ==================== 禮包懸停提示 ====================
var hover_tooltip: PanelContainer = null

func _on_gift_pack_hover(_panel: PanelContainer, item_data: Dictionary):
	"""禮包懸停時顯示詳細內容"""
	if hover_tooltip:
		hover_tooltip.queue_free()

	# 創建懸停提示框
	hover_tooltip = PanelContainer.new()
	hover_tooltip.z_index = 100

	# 設置樣式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.6, 0.8, 1)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	hover_tooltip.add_theme_stylebox_override("panel", style_box)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	hover_tooltip.add_child(vbox)

	# 標題
	var title_label = Label.new()
	title_label.text = "📦 禮包內容"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	vbox.add_child(title_label)

	# 獎勵列表
	var reward_config = item_data.get("reward_config", {})
	var rewards = reward_config.get("rewards", [])

	for reward in rewards:
		var reward_label = Label.new()
		var reward_text = get_reward_display_text(reward)
		reward_label.text = "  • " + reward_text
		reward_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(reward_label)

	# 購買限制
	var purchase_limit = item_data.get("purchase_limit", 0)
	if purchase_limit > 0:
		var limit_label = Label.new()
		limit_label.text = "\n限購: %d 次" % purchase_limit
		limit_label.add_theme_font_size_override("font_size", 14)
		limit_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5, 1))
		vbox.add_child(limit_label)

	# 添加到場景
	add_child(hover_tooltip)

	# 計算位置（在滑鼠旁邊）
	await get_tree().process_frame
	var mouse_pos = get_viewport().get_mouse_position()
	hover_tooltip.global_position = mouse_pos + Vector2(20, 20)

func _on_gift_pack_hover_end(_panel: PanelContainer):
	"""禮包懸停結束"""
	if hover_tooltip:
		hover_tooltip.queue_free()
		hover_tooltip = null

func get_reward_display_text(reward: Dictionary) -> String:
	"""獲取獎勵顯示文字"""
	var reward_type = reward.get("type", "")

	match reward_type:
		"currency":
			var currency_type = reward.get("currency_type", "gold")
			var amount = reward.get("amount", 0)
			if currency_type == "gold":
				return "💰 金幣 x%d" % amount
			elif currency_type == "gem":
				return "💎 鑽石 x%d" % amount

		"bag_expansion":
			var slots = reward.get("slots", 5)
			return "🎒 背包擴充 +%d 格" % slots

		"specific_card":
			var card_id = reward.get("card_id", "")
			var count = reward.get("count", 1)
			return "🃏 卡片 %s x%d" % [card_id, count]

		_:
			return "❓ 未知獎勵"

	return ""

func switch_to_tab(tab_id: String):
	"""切換到指定標籤"""
	current_tab = tab_id
	update_tab_buttons()
	create_shop_items()

func update_tab_buttons():
	"""更新標籤按鈕狀態"""
	for tab_id in tab_buttons:
		var button = tab_buttons[tab_id]
		button.button_pressed = (tab_id == current_tab)

# ==================== 創建商店物品 ====================
func create_shop_items():
	"""根據當前標籤創建商店物品"""
	# 清空現有物品
	for child in shop_items_grid.get_children():
		child.queue_free()

	# 獲取當前分類的物品
	var current_items = items_by_category.get(current_tab, [])

	if current_items.size() == 0:
		# 顯示空提示
		var empty_label = Label.new()
		empty_label.text = "此分類暫無商品"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		shop_items_grid.add_child(empty_label)
		return

	# 動態調整列數（根據可用寬度）
	# 每個商品卡片寬度約 250，間距 30
	await get_tree().process_frame  # 等待佈局更新
	var available_width = shop_items_grid.size.x
	if available_width > 0:
		var item_width = 250
		var spacing = 15
		var columns = max(1, int(available_width / (item_width + spacing)))
		shop_items_grid.columns = columns
		print("🔧 調整商店列數為: %d (可用寬度: %d)" % [columns, available_width])

	# 動態創建商店物品UI
	for item_data in current_items:
		var item_node = create_shop_item_ui(item_data)
		shop_items_grid.add_child(item_node)

func create_shop_item_ui(item_data: Dictionary) -> Control:
	"""創建單個商店物品的UI"""
	var item_panel = PanelContainer.new()
	item_panel.custom_minimum_size = Vector2(230, 300)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	item_panel.add_child(vbox)

	# 物品圖標（佔位符）
	var icon_rect = ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(210, 150)
	icon_rect.color = Color(0.3, 0.3, 0.4, 0.5)
	vbox.add_child(icon_rect)

	# 物品名稱
	var item_name_label = Label.new()
	item_name_label.text = item_data.get("name", "未命名物品")
	item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(item_name_label)

	# 檢查是否為禮包
	var is_gift_pack = item_data.get("category", "") == "gift_packs"

	# 物品描述（禮包不顯示，其他商品顯示）
	if not is_gift_pack:
		var desc_label = Label.new()
		desc_label.text = item_data.get("description", "")
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(210, 40)
		desc_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(desc_label)

	# 價格標籤
	var price_label = Label.new()
	var price = item_data.get("price", 0)
	var currency = item_data.get("currency", "gold")
	var currency_icon = "💰" if currency == "gold" else "💎"
	price_label.text = "%s %d" % [currency_icon, price]
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(price_label)

	# ✅ 檢查購買限制
	var purchase_limit = item_data.get("purchase_limit", 0)
	var item_id = item_data.get("id", "")
	var purchase_count = PlayerDataManager.get_shop_purchase_count(item_id)
	var can_purchase = PlayerDataManager.can_purchase_item(item_id, purchase_limit)

	# 購買按鈕
	var buy_button = Button.new()
	buy_button.custom_minimum_size = Vector2(0, 40)

	# ✅ 根據購買限制更新按鈕狀態
	if purchase_limit > 0:
		# 有購買限制的商品
		if can_purchase:
			buy_button.text = "購買 (%d/%d)" % [purchase_count, purchase_limit]
			buy_button.disabled = false
			buy_button.pressed.connect(_on_buy_item.bind(item_data))
		else:
			buy_button.text = "已達上限"
			buy_button.disabled = true
			buy_button.modulate = Color(0.6, 0.6, 0.6)
	else:
		# 無限購買的商品
		buy_button.text = "購買"
		buy_button.disabled = false
		buy_button.pressed.connect(_on_buy_item.bind(item_data))

	vbox.add_child(buy_button)

	# 禮包特殊處理：添加懸停提示
	if is_gift_pack:
		item_panel.mouse_entered.connect(_on_gift_pack_hover.bind(item_panel, item_data))
		item_panel.mouse_exited.connect(_on_gift_pack_hover_end.bind(item_panel))
		item_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	return item_panel

# ==================== 購買邏輯 ====================
func _on_buy_item(item_data: Dictionary):
	"""處理購買物品"""
	var item_id = item_data.get("id", "")
	var price = item_data.get("price", 0)
	var currency = item_data.get("currency", "gold")
	var item_name = item_data.get("name", "物品")
	var purchase_limit = item_data.get("purchase_limit", 0)

	print("購買物品: %s, 價格: %d %s" % [item_id, price, currency])

	# ✅ 檢查購買限制
	if not PlayerDataManager.can_purchase_item(item_id, purchase_limit):
		show_notification("❌ 已達購買上限！")
		return

	# 檢查並扣除貨幣
	var success = false
	if currency == "gold":
		if PlayerDataManager.get_gold() >= price:
			success = PlayerDataManager.spend_gold(price)
		else:
			show_notification("❌ 金幣不足！")
			return
	elif currency == "gem":
		if PlayerDataManager.get_diamond() >= price:
			success = PlayerDataManager.spend_diamond(price)
		else:
			show_notification("❌ 寶石不足！")
			return

	if success:
		# ✅ 記錄購買
		PlayerDataManager.record_shop_purchase(item_id)

		# 發放物品
		give_item(item_data)

		# ✅ 刷新商店UI（更新購買次數顯示）
		create_shop_items()

		# 更新顯示
		update_currency_display()

		# 顯示成功訊息
		var purchase_count = PlayerDataManager.get_shop_purchase_count(item_id)
		if purchase_limit > 0:
			show_notification("✅ 購買成功：%s (%d/%d)" % [item_name, purchase_count, purchase_limit])
		else:
			show_notification("✅ 購買成功：%s" % item_name)
	else:
		show_notification("❌ 購買失敗！")

func give_item(item_data: Dictionary):
	"""發放購買的物品"""
	var reward_type = item_data.get("reward_type", "")
	var reward_config = item_data.get("reward_config", {})
	var item_name = item_data.get("name", "物品")

	match reward_type:
		"random_cards":
			# 給予隨機卡片
			var count = reward_config.get("count", 1)
			var rarities = reward_config.get("rarities", [])
			var rarity_enums = convert_rarity_strings_to_enums(rarities)

			for i in range(count):
				var card_id = get_random_card_by_rarity(rarity_enums)
				PlayerDataManager.add_card(card_id)
			print("✅ 獲得 %s x%d" % [item_name, count])

		"guaranteed_legendary":
			# 給予保底傳說的卡包
			var count = reward_config.get("count", 10)
			var guaranteed = reward_config.get("guaranteed_legendary", 1)
			var other_rarities = reward_config.get("other_rarities", [])
			var rarity_enums = convert_rarity_strings_to_enums(other_rarities)

			# 先給非保底的卡片
			for i in range(count - guaranteed):
				var card_id = get_random_card_by_rarity(rarity_enums)
				PlayerDataManager.add_card(card_id)

			# 給保底傳說卡片
			for i in range(guaranteed):
				var legendary_card = get_random_card_by_rarity([Constants.CardRarity.LEGENDARY])
				PlayerDataManager.add_card(legendary_card)

			print("✅ 獲得 %s x%d（含%d張傳說）" % [item_name, count, guaranteed])

		"specific_card":
			# 給予指定卡片
			var card_id = reward_config.get("card_id", "")
			var count = reward_config.get("count", 1)
			for i in range(count):
				PlayerDataManager.add_card(card_id)
			print("✅ 獲得指定卡片: %s x%d" % [card_id, count])

		"item":
			# 給予道具（TODO: 需要實現道具系統）
			var item_type = reward_config.get("item_type", "")
			var count = reward_config.get("count", 1)
			print("✅ 獲得道具: %s x%d（暫未實現）" % [item_type, count])

		"currency":
			# 給予貨幣
			var currency_type = reward_config.get("currency_type", "gold")
			var amount = reward_config.get("amount", 0)
			if currency_type == "gold":
				PlayerDataManager.add_gold(amount)
				print("✅ 獲得金幣: %d" % amount)
			elif currency_type == "gem":
				PlayerDataManager.add_diamond(amount)
				print("✅ 獲得寶石: %d" % amount)

		"bundle":
			# 給予禮包（包含多種獎勵）
			var rewards = reward_config.get("rewards", [])
			print("🎁 開啟禮包: %s" % item_name)
			for reward in rewards:
				give_bundle_reward(reward)
			print("✅ 禮包 %s 發放完成！" % item_name)

	PlayerDataManager.save_data()

func convert_rarity_strings_to_enums(rarity_strings: Array) -> Array:
	"""將稀有度字符串數組轉換為枚舉數組"""
	var result = []
	for rarity_str in rarity_strings:
		match rarity_str:
			"LEGENDARY":
				result.append(Constants.CardRarity.LEGENDARY)
			"EPIC":
				result.append(Constants.CardRarity.EPIC)
			"RARE":
				result.append(Constants.CardRarity.RARE)
			"COMMON":
				result.append(Constants.CardRarity.COMMON)
	return result

func get_random_card_by_rarity(_rarities: Array) -> String:
	"""根據稀有度獲取隨機卡片ID"""
	# TODO: 實際從 DataManager 獲取指定稀有度的卡片
	# 暫時返回預設卡片
	var card_ids = ["002", "002", "002", "002", "002"]
	return card_ids[randi() % card_ids.size()]

func give_bundle_reward(reward: Dictionary):
	"""發放禮包中的單個獎勵"""
	var reward_type = reward.get("type", "")

	match reward_type:
		"currency":
			# 貨幣獎勵
			var currency_type = reward.get("currency_type", "gold")
			var amount = reward.get("amount", 0)
			if currency_type == "gold":
				PlayerDataManager.add_gold(amount)
				print("  💰 獲得金幣: %d" % amount)
			elif currency_type == "gem":
				PlayerDataManager.add_diamond(amount)
				print("  💎 獲得鑽石: %d" % amount)

		"bag_expansion":
			# 背包擴充（免費）
			var slots = reward.get("slots", 5)
			PlayerDataManager.expand_bag(slots, 0)  # 免費擴充
			print("  🎒 背包擴充: +%d 格" % slots)

		"specific_card":
			# 指定卡片
			var card_id = reward.get("card_id", "")
			var count = reward.get("count", 1)
			for i in range(count):
				PlayerDataManager.add_card(card_id)
			print("  🃏 獲得卡片: %s x%d" % [card_id, count])

		_:
			print("  ⚠️ 未知的獎勵類型: %s" % reward_type)

func show_notification(message: String):
	"""顯示通知訊息"""
	# TODO: 創建更好的通知UI
	print(message)

# ==================== 輸入處理 ====================

func _input(event: InputEvent):
	"""處理 ESC 鍵返回"""
	if event.is_action_pressed("ui_cancel"):  # ESC 鍵
		_on_back_pressed()

# ==================== 按鈕回調 ====================
func _on_back_pressed():
	"""返回主選單"""
	print("← 返回主選單")
	GameManager.goto_main_menu()
