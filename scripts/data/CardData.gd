# CardData.gd
# 卡片資料結構
class_name CardData
extends Resource

# ==================== 基礎資訊 ====================
@export var card_id: String = ""
@export var card_name: String = ""
@export var card_image_path: String = ""
@export var rarity: Constants.CardRarity = Constants.CardRarity.COMMON
@export var card_race: Constants.CardRace = Constants.CardRace.HUMAN
@export var element: Constants.Element = Constants.Element.FIRE

# 實例ID（每張卡片的唯一識別碼）
var instance_id: String = ""

# ==================== 等級系統 ====================
@export var max_level: int = 99  # 最高等級
@export var max_exp: int = 900   # 滿級所需經驗值
var current_level: int = 1        # 當前等級（存檔數據）
var current_exp: int = 0          # 當前經驗值（存檔數據）

# ==================== 升星系統 ====================
@export var rank: int = 1               # 星等（例如 2 代表2星）
@export var evoland: Array[String] = []  # 可進化成的卡片ID列表（例如 ["C001"]）
@export var material: Array[String] = [] # 進化所需素材卡片列表（例如 ["AT1","AT1","AT2"]）

# ==================== 三圍屬性 ====================
# 注意：base_hp/atk/recovery 代表滿級時的數值
@export var base_hp: int = 10
@export var base_atk: int = 5
@export var base_recovery: int = 3

# 實際屬性（會被技能修正）
var current_hp: int = 10
var current_atk: int = 5
var current_recovery: int = 3

# 屬性倍率（用於技能加成）
var hp_multiplier: float = 1.0
var atk_multiplier: float = 1.0
var recovery_multiplier: float = 1.0

# ==================== SP 系統 ====================
@export var max_sp: int = 3
@export var initial_sp: int = 1
var current_sp: int = 1

# ==================== 技能系統 ====================
@export var passive_skill_ids: Array = []  # ✅ 修改：改為 "個人被動" (例如：迴避)
@export var leader_skill_ids: Array = []   # ✅ 新增："隊長技能"
@export var active_skill_id: String = ""           # 主动技能ID
@export var active_skill_cd: int = 5               # ⚠️ 已廢棄：技能CD應該從技能定義讀取，不應在卡片上設置

var active_skill_current_cd: int = 0  # 當前CD計數

# 技能實例（戰鬥時由 SkillRegistry 創建）
var passive_skills: Array = []  # Array[SkillBase]
var active_skill = null  # SkillBase

# ==================== 戰鬥狀態 ====================
var is_alive: bool = true
var is_stunned: bool = false  # 是否被眩暈

# ==================== 方法 ====================

func _init():
	"""初始化"""
	# 初始化等級為1級
	current_level = 1
	current_exp = 0

	# 計算1級時的屬性（基礎數值 * 等級係數）
	var level_stats = calculate_level_stats()
	current_hp = level_stats.hp
	current_atk = level_stats.atk
	current_recovery = level_stats.recovery
	current_sp = initial_sp

func reset_for_battle():
	"""戰鬥開始時重置"""
	# 重置屬性倍率
	hp_multiplier = 1.0
	atk_multiplier = 1.0
	recovery_multiplier = 1.0

	# 重置SP
	current_sp = initial_sp

	# 重置技能CD（從技能定義讀取）
	active_skill_current_cd = get_active_skill_max_cd()

	# 重置狀態
	is_alive = true
	is_stunned = false

	# 清空技能實例（會重新創建）
	passive_skills.clear()
	active_skill = null

func calculate_level_stats() -> Dictionary:
	"""根據當前等級計算屬性
	1級 = 10% 基礎屬性
	滿級 = 100% 基礎屬性
	線性成長
	"""
	# 計算等級係數 (10% - 100%)
	var level_percent = 0.1 + (0.9 * (current_level - 1) / float(max_level - 1))

	return {
		"hp": int(base_hp * level_percent),
		"atk": int(base_atk * level_percent),
		"recovery": int(base_recovery * level_percent)
	}

func calculate_final_stats():
	"""計算最終屬性（先套用等級，再套用技能倍率）"""
	var level_stats = calculate_level_stats()
	current_hp = int(level_stats.hp * hp_multiplier)
	current_atk = int(level_stats.atk * atk_multiplier)
	current_recovery = int(level_stats.recovery * recovery_multiplier)

func use_sp(amount: int = 1) -> bool:
	"""使用SP，返回是否成功"""
	if current_sp >= amount:
		current_sp -= amount
		return true
	return false

func recover_sp(amount: int = 1):
	"""恢復SP"""
	current_sp = min(current_sp + amount, max_sp)

func get_active_skill_max_cd() -> int:
	"""獲取主動技能的最大CD（從技能定義讀取）"""
	if active_skill_id.is_empty():
		return 0

	# 嘗試從 SkillRegistry 讀取技能定義的 skill_cost
	# Resources 不能使用 get_node_or_null()，但可以直接訪問 autoload
	if SkillRegistry != null and SkillRegistry.skill_system != null:
		var skill_data = SkillRegistry.skill_system.get_active_skill(active_skill_id)
		if skill_data:
			return skill_data.get("skill_cost", 5)

	# 向後兼容：如果無法從技能讀取，使用卡片的 active_skill_cd
	return active_skill_cd

func can_use_active_skill() -> bool:
	"""檢查是否能使用主動技能"""
	return active_skill_current_cd == 0 and not is_stunned

func use_active_skill():
	"""使用主動技能（重置CD）"""
	if can_use_active_skill():
		active_skill_current_cd = get_active_skill_max_cd()

func reduce_skill_cd():
	"""減少技能CD（每回合調用）"""
	if active_skill_current_cd > 0:
		active_skill_current_cd -= 1

func apply_multiplier(stat_type: String, multiplier: float):
	"""應用屬性倍率（可疊加）"""
	match stat_type:
		"hp":
			hp_multiplier *= multiplier
		"atk":
			atk_multiplier *= multiplier
		"recovery":
			recovery_multiplier *= multiplier

func add_exp(exp_amount: int) -> Dictionary:
	"""增加經驗值並處理升級
	返回: {
		"leveled_up": bool,  # 是否升級了
		"new_level": int,    # 新等級
		"overflow_exp": int  # 溢出的經驗值（滿級後無法獲得的經驗）
	}
	"""
	var result = {
		"leveled_up": false,
		"new_level": current_level,
		"overflow_exp": 0
	}

	# 已滿級，不再獲得經驗
	if current_level >= max_level:
		result.overflow_exp = exp_amount
		return result

	# 增加經驗值
	current_exp += exp_amount

	# 處理升級（可能連續升級多次）
	while current_exp >= get_exp_for_next_level() and current_level < max_level:
		current_exp -= get_exp_for_next_level()
		current_level += 1
		result.leveled_up = true

	# 滿級時，溢出的經驗值
	if current_level >= max_level:
		result.overflow_exp = current_exp
		current_exp = 0

	result.new_level = current_level

	# 如果升級了，重新計算屬性
	if result.leveled_up:
		calculate_final_stats()

	return result

func get_exp_for_next_level() -> int:
	"""獲取升到下一級所需的經驗值（線性成長）"""
	if current_level >= max_level:
		return 0
	# 每級需要的經驗值 = 總經驗 / (最高等級 - 1)
	return int(max_exp / float(max_level - 1))

func get_level_progress() -> float:
	"""獲取當前等級的進度百分比 (0.0 - 1.0)"""
	if current_level >= max_level:
		return 1.0
	var exp_needed = get_exp_for_next_level()
	if exp_needed == 0:
		return 0.0
	return current_exp / float(exp_needed)

func get_display_info() -> Dictionary:
	"""獲取顯示資訊"""
	var level_stats = calculate_level_stats()
	return {
		"card_name": card_name,
		"level": current_level,
		"max_level": max_level,
		"exp": current_exp,
		"exp_for_next_level": get_exp_for_next_level(),
		"level_progress": get_level_progress(),
		"hp": level_stats.hp,
		"atk": level_stats.atk,
		"recovery": level_stats.recovery,
		"sp": "%d/%d" % [current_sp, max_sp],
		"skill_cd": str(active_skill_current_cd) if active_skill_current_cd > 0 else "就緒"
	}
