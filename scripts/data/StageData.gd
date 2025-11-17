# StageData.gd
# 關卡資料結構
class_name StageData
extends Resource

# ==================== 基礎資訊 ====================
@export var stage_id: String = ""
@export var stage_name: String = ""
@export var stage_description: String = ""
@export var difficulty: int = 1
@export var is_boss_stage: bool = false

# ==================== 敵人配置 ====================
# 簡單模式（舊版相容）
@export var enemy_ids: Array = []  # 敵人ID列表
@export var member_card_ids: Array = []
# 進階模式（支援數量配置）
var enemies: Array = []  # [{enemy_id: "E001", count: 3}, ...]
var waves: Array = []  # 多波敵人配置
# ==================== 獎勵 ====================
# 簡單模式（舊版相容）
@export var reward_gold: int = 100
@export var reward_exp: int = 50
@export var drop_card_ids: Array[String] = []  # 可能掉落的卡片ID
@export var drop_rate: float = 0.3  # 掉落機率

# 進階模式
var rewards: Dictionary = {}  # {gold: 100, exp: 50, card_drops: [...]}
var current_wave: int = 0
var total_waves: int = 1
# ==================== 解鎖條件 ====================
@export var required_stage_id: String = ""  # 需要先通關的關卡ID（舊版）
var unlock_requirements: Dictionary = {}  # {required_stages: [...]}

# ==================== 狀態 ====================
var unlocked: bool = false
var completed: bool = false
var best_score: int = 0

# ==================== 方法 ====================

func is_unlocked(completed_stages: Array) -> bool:  # ✅ 普通陣列
	"""檢查關卡是否解鎖（兼容舊版和新版）"""
	# 新版檢查
	if not unlock_requirements.is_empty():
		var required_stages = unlock_requirements.get("required_stages", [])
		if required_stages.is_empty():
			return true
		for req_stage in required_stages:
			if req_stage not in completed_stages:
				return false
		return true

	# 舊版檢查
	if required_stage_id.is_empty():
		return true
	return required_stage_id in completed_stages

func get_enemy_list() -> Array:
	"""獲取敵人列表（展開count）- 僅用於兼容性，優先使用 waves"""
	# ✅ 優先使用 waves（僅返回第一波的敵人）
	if not waves.is_empty():
		var enemy_list = []
		var first_wave = waves[0]
		for enemy_config in first_wave.get("enemies", []):
			var enemy_id = enemy_config.get("enemy_id", "")
			var count = enemy_config.get("count", 1)
			for i in range(count):
				enemy_list.append(enemy_id)
		return enemy_list

	# 新版：使用 enemies 陣列（舊格式兼容）
	if not enemies.is_empty():
		var enemy_list = []
		for enemy_config in enemies:
			var enemy_id = enemy_config.get("enemy_id", "")
			var count = enemy_config.get("count", 1)
			for i in range(count):
				enemy_list.append(enemy_id)
		return enemy_list

	# 舊版：直接返回 enemy_ids
	return enemy_ids.duplicate()

func get_random_drop() -> String:
	"""隨機掉落卡片（舊版方法）"""
	if drop_card_ids.is_empty():
		return ""

	if randf() > drop_rate:
		return ""

	return drop_card_ids[randi() % drop_card_ids.size()]

func calculate_rewards(performance_score: int = 100) -> Dictionary:
	"""計算獎勵（新版方法）"""
	var final_rewards = {
		"gold": 0,
		"exp": 0,
		"cards": []
	}

	# 使用新版 rewards
	if not rewards.is_empty():
		final_rewards["gold"] = int(rewards.get("gold", 0) * performance_score / 100.0)
		final_rewards["exp"] = int(rewards.get("exp", 0) * performance_score / 100.0)

		# 卡片掉落
		for card_drop in rewards.get("card_drops", []):
			var roll = randf()
			if roll < card_drop.get("drop_rate", 0):
				final_rewards["cards"].append(card_drop.get("card_id", ""))
	else:
		# 使用舊版獎勵
		final_rewards["gold"] = int(reward_gold * performance_score / 100.0)
		final_rewards["exp"] = int(reward_exp * performance_score / 100.0)

		var dropped_card = get_random_drop()
		if not dropped_card.is_empty():
			final_rewards["cards"].append(dropped_card)

	return final_rewards

func complete_stage(score: int):
	"""完成關卡"""
	completed = true
	if score > best_score:
		best_score = score
