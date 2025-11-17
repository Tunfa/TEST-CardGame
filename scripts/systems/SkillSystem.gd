# SkillSystem.gd
# 技能系統核心 - 負責加載、解析和應用技能效果
class_name SkillSystem
extends Node

# ==================== 信號 ====================
signal skill_effect_applied(skill_name: String, effect_type: String)
# signal skill_condition_checked(skill_name: String, passed: bool)  # Reserved for future use

# ==================== 技能數據庫 ====================
var leader_skills: Dictionary = {}  # skill_id -> skill_data
var enemy_skills: Dictionary = {}   # skill_id -> skill_data
var active_skills: Dictionary = {}  # skill_id -> skill_data

# ==================== 配置文件路徑 ====================
const LEADER_SKILLS_PATH = "res://data/config/leader_skills.json"
const ENEMY_SKILLS_PATH = "res://data/config/enemy_skills.json"
const ACTIVE_SKILLS_PATH = "res://data/config/active_skills.json"

# ==================== 初始化 ====================
func _ready():
	load_all_skills()

func load_all_skills():
	"""載入所有技能配置"""
	load_leader_skills()
	load_enemy_skills()
	load_active_skills()
	print("✅ SkillSystem: 技能系統初始化完成")
	print("  - 隊長技能: %d 個" % leader_skills.size())
	print("  - 敵人技能: %d 個" % enemy_skills.size())
	print("  - 主動技能: %d 個" % active_skills.size())

# ==================== 載入技能配置 ====================
func load_leader_skills():
	"""載入隊長技能配置"""
	if not FileAccess.file_exists(LEADER_SKILLS_PATH):
		push_error("⚠️ 找不到隊長技能配置: " + LEADER_SKILLS_PATH)
		return

	var file = FileAccess.open(LEADER_SKILLS_PATH, FileAccess.READ)
	if file == null:
		push_error("⚠️ 無法打開隊長技能配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("⚠️ 解析隊長技能JSON失敗: " + json.get_error_message())
		return

	var data = json.data
	if data.has("leader_skills"):
		for skill in data["leader_skills"]:
			leader_skills[skill["skill_id"]] = skill

func load_enemy_skills():
	"""載入敵人技能配置"""
	if not FileAccess.file_exists(ENEMY_SKILLS_PATH):
		push_error("⚠️ 找不到敵人技能配置: " + ENEMY_SKILLS_PATH)
		return

	var file = FileAccess.open(ENEMY_SKILLS_PATH, FileAccess.READ)
	if file == null:
		push_error("⚠️ 無法打開敵人技能配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("⚠️ 解析敵人技能JSON失敗: " + json.get_error_message())
		return

	var data = json.data
	if data.has("enemy_skills"):
		for skill in data["enemy_skills"]:
			enemy_skills[skill["skill_id"]] = skill

func load_active_skills():
	"""載入主動技能配置"""
	if not FileAccess.file_exists(ACTIVE_SKILLS_PATH):
		push_error("⚠️ 找不到主動技能配置: " + ACTIVE_SKILLS_PATH)
		return

	var file = FileAccess.open(ACTIVE_SKILLS_PATH, FileAccess.READ)
	if file == null:
		push_error("⚠️ 無法打開主動技能配置文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("⚠️ 解析主動技能JSON失敗: " + json.get_error_message())
		return

	var data = json.data
	if data.has("active_skills"):
		for skill in data["active_skills"]:
			active_skills[skill["skill_id"]] = skill

# ==================== 獲取技能數據 ====================
func get_leader_skill(skill_id: String) -> Dictionary:
	"""獲取隊長技能數據"""
	if leader_skills.has(skill_id):
		return leader_skills[skill_id]
	else:
		push_warning("⚠️ 找不到隊長技能: " + skill_id)
		return {}

func get_enemy_skill(skill_id: String) -> Dictionary:
	"""獲取敵人技能數據"""
	if enemy_skills.has(skill_id):
		return enemy_skills[skill_id]
	else:
		push_warning("⚠️ 找不到敵人技能: " + skill_id)
		return {}

func get_active_skill(skill_id: String) -> Dictionary:
	"""獲取主動技能數據"""
	if active_skills.has(skill_id):
		return active_skills[skill_id]
	else:
		push_warning("⚠️ 找不到主動技能: " + skill_id)
		return {}

# ==================== 技能效果解析 ====================
func parse_element(element_string: String) -> Constants.Element:
	"""將字符串轉換為元素枚舉"""
	match element_string.to_upper():
		"FIRE":
			return Constants.Element.FIRE
		"WATER":
			return Constants.Element.WATER
		"WOOD":
			return Constants.Element.WOOD
		"METAL":
			return Constants.Element.METAL
		"EARTH":
			return Constants.Element.EARTH
		"HEART":
			return Constants.Element.HEART
		_:
			push_warning("⚠️ 未知元素類型: " + element_string)
			return Constants.Element.FIRE

func parse_leader_skill_effect_type(effect_type_str: String) -> Constants.LeaderSkillEffectType:
	"""將字符串轉換為隊長技能效果類型枚舉"""
	match effect_type_str.to_upper():
		"DAMAGE_MULTIPLIER":
			return Constants.LeaderSkillEffectType.DAMAGE_MULTIPLIER
		"BASE_DAMAGE_BOOST":
			return Constants.LeaderSkillEffectType.BASE_DAMAGE_BOOST
		"ALL_DAMAGE_BOOST":
			return Constants.LeaderSkillEffectType.ALL_DAMAGE_BOOST
		"IGNORE_RESISTANCE":
			return Constants.LeaderSkillEffectType.IGNORE_RESISTANCE
		"FORCE_ORB_SPAWN":
			return Constants.LeaderSkillEffectType.FORCE_ORB_SPAWN
		"ORB_DROP_ON_SLASH":
			return Constants.LeaderSkillEffectType.ORB_DROP_ON_SLASH
		"SLASH_ORB_SPAWN":
			return Constants.LeaderSkillEffectType.SLASH_ORB_SPAWN
		"ORB_SPAWN_RATE_BOOST":
			return Constants.LeaderSkillEffectType.ORB_SPAWN_RATE_BOOST
		"ORB_CAPACITY_BOOST":
			return Constants.LeaderSkillEffectType.ORB_CAPACITY_BOOST
		"ORB_DUAL_EFFECT":
			return Constants.LeaderSkillEffectType.ORB_DUAL_EFFECT
		"ORB_DROP_END_TURN":
			return Constants.LeaderSkillEffectType.ORB_DROP_END_TURN
		"ORB_COUNT_MULTIPLIER":
			return Constants.LeaderSkillEffectType.ORB_COUNT_MULTIPLIER
		"TEAM_ELEMENT_MULTIPLIER":
			return Constants.LeaderSkillEffectType.TEAM_ELEMENT_MULTIPLIER
		"TEAM_DIVERSITY_MULTIPLIER":
			return Constants.LeaderSkillEffectType.TEAM_DIVERSITY_MULTIPLIER
		"HP_MULTIPLIER":
			return Constants.LeaderSkillEffectType.HP_MULTIPLIER
		"RECOVERY_MULTIPLIER":
			return Constants.LeaderSkillEffectType.RECOVERY_MULTIPLIER
		"EXTEND_SLASH_TIME":
			return Constants.LeaderSkillEffectType.EXTEND_SLASH_TIME
		"END_TURN_DAMAGE":
			return Constants.LeaderSkillEffectType.END_TURN_DAMAGE
		_:
			push_warning("⚠️ 未知隊長技能效果類型: " + effect_type_str)
			return Constants.LeaderSkillEffectType.DAMAGE_MULTIPLIER

func parse_enemy_skill_effect_type(effect_type_str: String) -> Constants.EnemySkillEffectType:
	"""將字符串轉換為敵人技能效果類型枚舉"""
	match effect_type_str.to_upper():
		"REQUIRE_COMBO":
			return Constants.EnemySkillEffectType.REQUIRE_COMBO
		"REQUIRE_COMBO_EXACT":
			return Constants.EnemySkillEffectType.REQUIRE_COMBO_EXACT
		"REQUIRE_COMBO_MAX":
			return Constants.EnemySkillEffectType.REQUIRE_COMBO_MAX
		"REQUIRE_ORB_TOTAL":
			return Constants.EnemySkillEffectType.REQUIRE_ORB_TOTAL
		"REQUIRE_ORB_CONTINUOUS":
			return Constants.EnemySkillEffectType.REQUIRE_ORB_CONTINUOUS
		"REQUIRE_ORB_SEQUENCE":
			return Constants.EnemySkillEffectType.REQUIRE_ORB_SEQUENCE
		"REQUIRE_ENEMY_ATTACK":
			return Constants.EnemySkillEffectType.REQUIRE_ENEMY_ATTACK
		"REQUIRE_ELEMENTS":
			return Constants.EnemySkillEffectType.REQUIRE_ELEMENTS
		"REQUIRE_STORED_ORB_MIN":
			return Constants.EnemySkillEffectType.REQUIRE_STORED_ORB_MIN
		"REQUIRE_STORED_ORB_EXACT":
			return Constants.EnemySkillEffectType.REQUIRE_STORED_ORB_EXACT
		"DAMAGE_REDUCTION_PERCENT":
			return Constants.EnemySkillEffectType.DAMAGE_REDUCTION_PERCENT
		"DAMAGE_REDUCTION_FLAT":
			return Constants.EnemySkillEffectType.DAMAGE_REDUCTION_FLAT
		"DAMAGE_ONCE_ONLY":
			return Constants.EnemySkillEffectType.DAMAGE_ONCE_ONLY
		"SEAL_ACTIVE_SKILL":
			return Constants.EnemySkillEffectType.SEAL_ACTIVE_SKILL
		"SEAL_ORB_SWAP":
			return Constants.EnemySkillEffectType.SEAL_ORB_SWAP
		"DISABLE_ELEMENT_SLASH":
			return Constants.EnemySkillEffectType.DISABLE_ELEMENT_SLASH
		"ZERO_RECOVERY":
			return Constants.EnemySkillEffectType.ZERO_RECOVERY
		"ENEMY_DAMAGE_BY_PLAYER_ORBS":
			return Constants.EnemySkillEffectType.ENEMY_DAMAGE_BY_PLAYER_ORBS
		"ENEMY_DAMAGE_BY_PLAYER_LOW_ORBS":
			return Constants.EnemySkillEffectType.ENEMY_DAMAGE_BY_PLAYER_LOW_ORBS
		"REMOVE_RANDOM_ORBS":
			return Constants.EnemySkillEffectType.REMOVE_RANDOM_ORBS
		"REDUCE_SLASH_TIME":
			return Constants.EnemySkillEffectType.REDUCE_SLASH_TIME
		"SPAWN_INVALID_ORBS":
			return Constants.EnemySkillEffectType.SPAWN_INVALID_ORBS
		"REDUCE_DAMAGE_TURNS":
			return Constants.EnemySkillEffectType.REDUCE_DAMAGE_TURNS
		"ENTER_HP_TO_ONE":
			return Constants.EnemySkillEffectType.ENTER_HP_TO_ONE
		"DEATH_DAMAGE":
			return Constants.EnemySkillEffectType.DEATH_DAMAGE
		"REVIVE_ONCE":
			return Constants.EnemySkillEffectType.REVIVE_ONCE
		_:
			push_warning("⚠️ 未知敵人技能效果類型: " + effect_type_str)
			return Constants.EnemySkillEffectType.DAMAGE_REDUCTION_PERCENT

# ==================== 技能效果應用 ====================
func apply_leader_skill_to_battle(skill_id: String, battle_manager: BattleManager):
	"""應用隊長技能到戰鬥管理器"""
	var skill_data = get_leader_skill(skill_id)
	if skill_data.is_empty():
		return

	print("🔮 應用隊長技能: %s" % skill_data.get("skill_name", "未知"))

	# 遍歷所有效果
	for effect in skill_data.get("effects", []):
		var effect_type_str = effect.get("effect_type", "")
		var effect_type = parse_leader_skill_effect_type(effect_type_str)

		# 根據效果類型應用效果
		_apply_leader_skill_effect(effect_type, effect, battle_manager)

		skill_effect_applied.emit(skill_data.get("skill_name", ""), effect_type_str)

func _apply_leader_skill_effect(effect_type: Constants.LeaderSkillEffectType, effect_data: Dictionary, _battle_manager: BattleManager):
	"""應用單個隊長技能效果"""
	# 這裡暫時只打印，實際邏輯會在SkillEffectHandler中實現
	match effect_type:
		Constants.LeaderSkillEffectType.DAMAGE_MULTIPLIER:
			print("  - 傷害倍率: %s x%.1f" % [
				effect_data.get("target_element", "ALL"),
				effect_data.get("multiplier", 1.0)
			])

		Constants.LeaderSkillEffectType.HP_MULTIPLIER:
			print("  - 生命力倍率: %s x%.1f" % [
				effect_data.get("target_element", "ALL"),
				effect_data.get("multiplier", 1.0)
			])

		Constants.LeaderSkillEffectType.FORCE_ORB_SPAWN:
			print("  - 固定出現: %s x%d" % [
				effect_data.get("target_element", "FIRE"),
				effect_data.get("count", 0)
			])

		_:
			print("  - 效果類型: %s (尚未實現)" % effect_type)

# ==================== 輔助函數 ====================
func get_all_leader_skill_ids() -> Array:
	"""獲取所有隊長技能ID"""
	return leader_skills.keys()

func get_all_enemy_skill_ids() -> Array:
	"""獲取所有敵人技能ID"""
	return enemy_skills.keys()
