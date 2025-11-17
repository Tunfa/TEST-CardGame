# DataManager.gd
# 數據管理器（Autoload）
# 負責載入和管理所有 JSON 數據（卡片、敵人、關卡）
extends Node

# ==================== 數據字典 ====================
var cards_database: Dictionary = {}  # {card_id: CardData}
var enemies_database: Dictionary = {}  # {enemy_id: EnemyData}
var stages_database: Dictionary = {}  # {stage_id: StageData}
var gacha_pools_database: Dictionary = {} # ✅ 新增： {pool_id: Dictionary}
var shop_items_database: Dictionary = {} # ✅ 新增： {item_id: Dictionary}
var card_textures: Dictionary = {} # ✅ 1. 新增：圖片快取字典
var enemy_textures: Dictionary = {} # ✅ 新增：敵人圖片快取字典
# ==================== 常量定義 ====================
const CARDS_JSON_PATH = "res://data/cards.json"
const ENEMIES_JSON_PATH = "res://data/enemies.json"
const STAGES_JSON_PATH = "res://data/stages.json"
const GACHA_JSON_PATH = "res://data/config/gacha_pools.json"
const SHOP_JSON_PATH = "res://data/config/shop_items.json"

# 稀有度映射
const RARITY_MAP = {
	"COMMON": Constants.CardRarity.COMMON,
	"RARE": Constants.CardRarity.RARE,
	"EPIC": Constants.CardRarity.EPIC,
	"LEGENDARY": Constants.CardRarity.LEGENDARY
}

# 種族映射
const RACE_MAP = {
	"HUMAN": Constants.CardRace.HUMAN,
	"ELF": Constants.CardRace.ELF,
	"DWARF": Constants.CardRace.DWARF,
	"ORC": Constants.CardRace.ORC,
	"DEMON": Constants.CardRace.DEMON,
	"UNDEAD": Constants.CardRace.UNDEAD,
	"DRAGON": Constants.CardRace.DRAGON,
	"ELEMENTAL": Constants.CardRace.ELEMENTAL
}

# 元素映射（五行）
const ELEMENT_MAP = {
	"METAL": Constants.Element.METAL,
	"WOOD": Constants.Element.WOOD,
	"WATER": Constants.Element.WATER,
	"FIRE": Constants.Element.FIRE,
	"EARTH": Constants.Element.EARTH
}

# ==================== 初始化 ====================

func _ready():
	print("📦 DataManager 初始化中...")
	load_all_data()
	print("✅ DataManager 初始化完成")

# ==================== 載入所有數據 ====================

func load_all_data():
	"""載入所有 JSON 數據"""
	load_cards()
	load_enemies()
	load_stages()
	load_gacha_pools() # ✅ 新增
	load_shop_items()  # ✅ 新增

# ==================== 載入卡片數據 ====================

func load_cards():
	"""從 JSON 載入卡片數據"""
	var json_data = load_json_file(CARDS_JSON_PATH)
	if json_data == null:
		push_error("❌ 無法載入卡片數據: " + CARDS_JSON_PATH)
		return

	var cards_array = json_data.get("cards", [])
	print("開始載入卡片數據，共 %d 張卡片..." % cards_array.size())

	for card_json in cards_array:
		var card_data = create_card_from_json(card_json)
		if card_data:
			cards_database[card_data.card_id] = card_data
			print("  ✓ 載入卡片: %s - %s" % [card_data.card_id, card_data.card_name])

	print("✅ 卡片數據載入完成，共 %d 張" % cards_database.size())

func create_card_from_json(json_dict: Dictionary) -> CardData:
	"""從 JSON 創建 CardData"""
	var card = CardData.new()

	# 基礎資訊
	card.card_id = json_dict.get("card_id", "")
	card.card_name = json_dict.get("card_name", "")
	card.card_image_path = json_dict.get("card_image_path", "")
	
	if not card.card_image_path.is_empty() and FileAccess.file_exists(card.card_image_path):
		# 載入圖片並存到快取中
		card_textures[card.card_id] = load(card.card_image_path)
	else:
		# 如果圖片不存在，存一個 null
		card_textures[card.card_id] = null

	# 稀有度、種族、元素
	var rarity_str = json_dict.get("rarity", "COMMON")
	card.rarity = RARITY_MAP.get(rarity_str, Constants.CardRarity.COMMON)

	var race_str = json_dict.get("card_race", "HUMAN")
	card.card_race = RACE_MAP.get(race_str, Constants.CardRace.HUMAN)

	var element_str = json_dict.get("element", "FIRE")
	card.element = ELEMENT_MAP.get(element_str, Constants.Element.FIRE)

	# 三圍屬性
	card.base_hp = json_dict.get("base_hp", 10)
	card.base_atk = json_dict.get("base_atk", 5)
	card.base_recovery = json_dict.get("base_recovery", 3)

	# 等級系統
	card.max_level = json_dict.get("max_level", 99)
	card.max_exp = json_dict.get("max_exp", 900)

	# 升星系統
	card.rank = json_dict.get("rank", 1)
	# 需要轉換為 Array[String] 類型
	var evoland_array: Array[String] = []
	for item in json_dict.get("evoland", []):
		evoland_array.append(str(item))
	card.evoland = evoland_array

	var material_array: Array[String] = []
	for item in json_dict.get("material", []):
		material_array.append(str(item))
	card.material = material_array

	# SP 系統
	card.max_sp = json_dict.get("max_sp", 3)
	card.initial_sp = json_dict.get("initial_sp", 1)

	# 技能系統
	card.passive_skill_ids = json_dict.get("passive_skill_ids", [])
	card.leader_skill_ids = json_dict.get("leader_skill_ids", []) # ✅ 新增這一行
	card.active_skill_id = json_dict.get("active_skill_id", "")
	# ⚠️ 已廢棄：active_skill_cd 現在從技能定義讀取，不再需要在卡片上設置
	# card.active_skill_cd = json_dict.get("active_skill_cd", 5)

	# 初始化當前屬性
	card.current_hp = card.base_hp
	card.current_atk = card.base_atk
	card.current_recovery = card.base_recovery
	card.current_sp = card.initial_sp

	return card

# ==================== 載入卡池數據 (Gacha) (新) ====================

func load_gacha_pools():
	"""從 JSON 載入卡池數據"""
	var json_data = load_json_file(GACHA_JSON_PATH)
	if json_data == null:
		push_error("❌ 無法載入卡池數據: " + GACHA_JSON_PATH)
		return

	var pools_array = json_data.get("pools", [])
	print("開始載入卡池數據，共 %d 個卡池..." % pools_array.size())

	for pool_json in pools_array:
		var pool_id = pool_json.get("pool_id", "")
		if not pool_id.is_empty():
			gacha_pools_database[pool_id] = pool_json
			print("  ✓ 載入卡池: %s - %s" % [pool_id, pool_json.get("pool_name", "")])
	
	print("✅ 卡池數據載入完成，共 %d 個" % gacha_pools_database.size())

# ==================== 載入商店數據 (Shop) (新) ====================

func load_shop_items():
	"""從 JSON 載入商店數據"""
	var json_data = load_json_file(SHOP_JSON_PATH)
	if json_data == null:
		push_error("❌ 無法載入商店數據: " + SHOP_JSON_PATH)
		return

	var items_array = json_data.get("items", [])
	print("開始載入商店數據，共 %d 個商品..." % items_array.size())

	for item_json in items_array:
		var item_id = item_json.get("item_id", "")
		if not item_id.is_empty():
			shop_items_database[item_id] = item_json
			print("  ✓ 載入商品: %s - %s" % [item_id, item_json.get("item_name", "")])

	print("✅ 商店數據載入完成，共 %d 個" % shop_items_database.size())

# ... (現有 JSON 工具函數) ...

# ==================== 載入敵人數據 ====================

func load_enemies():
	"""從 JSON 載入敵人數據"""
	var json_data = load_json_file(ENEMIES_JSON_PATH)
	if json_data == null:
		push_error("❌ 無法載入敵人數據: " + ENEMIES_JSON_PATH)
		return

	var enemies_array = json_data.get("enemies", [])
	print("開始載入敵人數據，共 %d 個敵人..." % enemies_array.size())

	for enemy_json in enemies_array:
		var enemy_data = create_enemy_from_json(enemy_json)
		if enemy_data:
			enemies_database[enemy_data.enemy_id] = enemy_data
			print("  ✓ 載入敵人: %s - %s (元素: %s)" % [enemy_data.enemy_id, enemy_data.enemy_name, Constants.Element.keys()[enemy_data.element]])

	print("✅ 敵人數據載入完成，共 %d 個" % enemies_database.size())

func create_enemy_from_json(json_dict: Dictionary) -> EnemyData:
	"""從 JSON 創建 EnemyData"""
	var enemy = EnemyData.new()

	# 基礎資訊
	enemy.enemy_id = json_dict.get("enemy_id", "")
	enemy.enemy_name = json_dict.get("enemy_name", "")
	enemy.sprite_path = json_dict.get("sprite_path", "")
	
	# ✅ 載入敵人圖片並存到快取中
	if not enemy.sprite_path.is_empty() and FileAccess.file_exists(enemy.sprite_path):
		enemy_textures[enemy.enemy_id] = load(enemy.sprite_path)
	else:
		enemy_textures[enemy.enemy_id] = null

	# 元素屬性
	var element_str = json_dict.get("element", "FIRE")
	enemy.element = ELEMENT_MAP.get(element_str, Constants.Element.FIRE)

	# 屬性
	enemy.max_hp = json_dict.get("max_hp", 20)
	enemy.base_atk = json_dict.get("base_atk", 5)
	enemy.attack_cd = json_dict.get("attack_cd", 1)

	# 技能系統
	enemy.passive_skill_ids = json_dict.get("passive_skill_ids", [])
	enemy.attack_skill_ids = json_dict.get("attack_skill_ids", [])

	# 初始化當前屬性
	enemy.current_hp = enemy.max_hp
	enemy.current_atk = enemy.base_atk
	enemy.current_cd = enemy.attack_cd

	return enemy

# ==================== 載入關卡數據 ====================

func load_stages():
	"""從 JSON 載入關卡數據"""
	var json_data = load_json_file(STAGES_JSON_PATH)
	if json_data == null:
		push_error("❌ 無法載入關卡數據: " + STAGES_JSON_PATH)
		return

	var stages_array = json_data.get("stages", [])
	print("開始載入關卡數據，共 %d 個關卡..." % stages_array.size())

	for stage_json in stages_array:
		var stage_data = create_stage_from_json(stage_json)
		if stage_data:
			stages_database[stage_data.stage_id] = stage_data
			print("  ✓ 載入關卡: %s - %s" % [stage_data.stage_id, stage_data.stage_name])

	print("✅ 關卡數據載入完成，共 %d 個" % stages_database.size())

func create_stage_from_json(json_dict: Dictionary) -> StageData:
	"""從 JSON 創建 StageData"""
	var stage = StageData.new()

	# 基礎資訊
	stage.stage_id = json_dict.get("stage_id", "")
	stage.stage_name = json_dict.get("stage_name", "")
	stage.stage_description = json_dict.get("description", "")
	stage.difficulty = json_dict.get("difficulty", 1)
	stage.is_boss_stage = json_dict.get("is_boss_stage", false)

	# ✅ 敵人配置（優先使用 waves，兼容舊格式 enemies）
	stage.waves = json_dict.get("waves", [])
	stage.enemies = json_dict.get("enemies", [])

	# ✅ 計算總波次數
	if not stage.waves.is_empty():
		stage.total_waves = stage.waves.size()
	else:
		stage.total_waves = 1

	# 獎勵
	stage.rewards = json_dict.get("rewards", {})

	# 解鎖條件
	stage.unlock_requirements = json_dict.get("unlock_requirements", {})

	return stage

# ==================== JSON 工具函數 ====================

func load_json_file(file_path: String) -> Dictionary:
	"""載入 JSON 文件"""
	if not FileAccess.file_exists(file_path):
		push_error("❌ JSON 文件不存在: " + file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("❌ 無法打開 JSON 文件: " + file_path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		push_error("❌ JSON 解析失敗: " + file_path + " (錯誤: " + str(parse_result) + ")")
		return {}

	return json.data

# ==================== 獲取數據 ====================
func get_gacha_pool(pool_id: String) -> Dictionary: # ✅ 新增
	"""獲取卡池數據（返回副本）"""
	if pool_id not in gacha_pools_database:
		push_error("❌ 卡池不存在: " + pool_id)
		return {}
	return gacha_pools_database[pool_id].duplicate()

func get_all_gacha_pools() -> Dictionary: # ✅ 新增
	"""獲取所有卡池"""
	return gacha_pools_database

func get_shop_item(item_id: String) -> Dictionary: # ✅ 新增
	"""獲取商店商品（返回副本）"""
	if item_id not in shop_items_database:
		push_error("❌ 商品不存在: " + item_id)
		return {}
	return shop_items_database[item_id].duplicate()

func get_all_shop_items() -> Dictionary: # ✅ 新增
	"""獲取所有商品"""
	return shop_items_database
	
func get_card(card_id: String) -> CardData:
	"""獲取卡片數據（返回副本）"""
	if card_id not in cards_database:
		push_error("❌ 卡片不存在: " + card_id)
		return null

	# 返回副本，避免修改原始數據
	var original = cards_database[card_id]
	var card_copy = CardData.new()

	# 複製所有屬性
	card_copy.card_id = original.card_id
	card_copy.card_name = original.card_name
	card_copy.card_image_path = original.card_image_path
	card_copy.rarity = original.rarity
	card_copy.card_race = original.card_race
	card_copy.element = original.element
	card_copy.base_hp = original.base_hp
	card_copy.base_atk = original.base_atk
	card_copy.base_recovery = original.base_recovery
	card_copy.max_level = original.max_level
	card_copy.max_exp = original.max_exp
	card_copy.max_sp = original.max_sp
	card_copy.initial_sp = original.initial_sp
	card_copy.passive_skill_ids = original.passive_skill_ids.duplicate()
	card_copy.leader_skill_ids = original.leader_skill_ids.duplicate()
	card_copy.active_skill_id = original.active_skill_id
	# ✅ 升星系統屬性
	card_copy.rank = original.rank
	card_copy.evoland = original.evoland.duplicate()
	card_copy.material = original.material.duplicate()
	# ⚠️ 已廢棄：active_skill_cd 現在從技能定義讀取
	# card_copy.active_skill_cd = original.active_skill_cd

	# 重置當前屬性
	card_copy.current_hp = card_copy.base_hp
	card_copy.current_atk = card_copy.base_atk
	card_copy.current_recovery = card_copy.base_recovery
	card_copy.current_sp = card_copy.initial_sp

	return card_copy

func get_enemy(enemy_id: String) -> EnemyData:
	"""獲取敵人數據（返回副本）"""
	if enemy_id not in enemies_database:
		push_error("❌ 敵人不存在: " + enemy_id)
		return null

	var original = enemies_database[enemy_id]
	var enemy_copy = EnemyData.new()

	# 複製所有屬性
	enemy_copy.enemy_id = original.enemy_id
	enemy_copy.enemy_name = original.enemy_name
	enemy_copy.sprite_path = original.sprite_path
	enemy_copy.element = original.element  # 複製元素屬性
	enemy_copy.max_hp = original.max_hp
	enemy_copy.base_atk = original.base_atk
	enemy_copy.attack_cd = original.attack_cd
	enemy_copy.passive_skill_ids = original.passive_skill_ids.duplicate()
	enemy_copy.attack_skill_ids = original.attack_skill_ids.duplicate()

	# 重置當前屬性
	enemy_copy.current_hp = enemy_copy.max_hp
	enemy_copy.current_atk = enemy_copy.base_atk
	enemy_copy.current_cd = enemy_copy.attack_cd

	return enemy_copy

func get_stage(stage_id: String) -> StageData:
	"""獲取關卡數據"""
	if stage_id not in stages_database:
		push_error("❌ 關卡不存在: " + stage_id)
		return null

	return stages_database[stage_id]

func get_all_cards() -> Array:
	"""獲取所有卡片ID"""
	return cards_database.keys()

func get_all_enemies() -> Array:
	"""獲取所有敵人ID"""
	return enemies_database.keys()

func get_all_stages() -> Array:
	"""獲取所有關卡ID"""
	return stages_database.keys()

# ==================== 驗證數據 ====================

func card_exists(card_id: String) -> bool:
	"""檢查卡片是否存在"""
	return card_id in cards_database

func enemy_exists(enemy_id: String) -> bool:
	"""檢查敵人是否存在"""
	return enemy_id in enemies_database

func stage_exists(stage_id: String) -> bool:
	"""檢查關卡是否存在"""
	return stage_id in stages_database

func get_card_texture(card_id: String) -> Texture:
	"""從快取中獲取卡片圖片"""
	if card_id in card_textures:
		return card_textures[card_id]
	return null
	
func get_enemy_texture(enemy_id: String) -> Texture:
	"""從快取中獲取敵人圖片"""
	if enemy_id in enemy_textures:
		return enemy_textures[enemy_id]
	return null
