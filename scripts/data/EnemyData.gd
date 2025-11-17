# EnemyData.gd
# 敵人資料結構
class_name EnemyData
extends Resource

# ==================== 基礎資訊 ====================
@export var enemy_id: String = ""
@export var enemy_name: String = ""
@export var sprite_path: String = ""
@export var element: Constants.Element = Constants.Element.FIRE  # 敵人元素屬性

# ==================== 屬性 ====================
@export var max_hp: int = 20
var current_hp: int = 20

@export var base_atk: int = 5
var current_atk: int = 5

# 屬性倍率
var atk_multiplier: float = 1.0
var defense_multiplier: float = 0.0  # 防禦倍率（減傷）

# ==================== 攻擊系統 ====================
@export var attack_cd: int = 1  # 攻擊CD（1=每回合攻擊）
var current_cd: int = 1  # 當前CD計數

# ==================== 技能系統 ====================
@export var passive_skill_ids: Array = []  # 被动技能ID列表
@export var attack_skill_ids: Array = []   # 攻击技能ID列表

# 技能實例
var passive_skills: Array = []  # Array[SkillBase]
var attack_skills: Array = []   # Array[SkillBase]

# ==================== 戰鬥狀態 ====================
var is_alive: bool = true
var is_stunned: bool = false

# ==================== 方法 ====================

func _init():
	"""初始化"""
	current_hp = max_hp
	current_atk = base_atk
	current_cd = attack_cd

func reset_for_battle():
	"""戰鬥開始時重置"""
	current_hp = max_hp
	current_atk = base_atk
	current_cd = attack_cd
	
	atk_multiplier = 1.0
	defense_multiplier = 0.0
	
	is_alive = true
	is_stunned = false
	
	passive_skills.clear()
	attack_skills.clear()

func calculate_final_stats():
	"""計算最終屬性"""
	current_atk = int(base_atk * atk_multiplier)

func tick_cd():
	"""更新CD（每回合調用）"""
	if current_cd > 0:
		current_cd -= 1

func should_attack() -> bool:
	"""檢查是否該攻擊"""
	return current_cd <= 0 and not is_stunned and is_alive

func reset_cd():
	"""重置CD"""
	current_cd = attack_cd

func take_damage(damage: int) -> int:
	"""受到傷害，返回實際傷害值"""
	var actual_damage = int(damage * (1.0 - defense_multiplier))
	actual_damage = max(actual_damage, 0)  # 不能是負數

	current_hp -= actual_damage

	if current_hp <= 0:
		current_hp = 0
		is_alive = false

	return actual_damage

func apply_multiplier(stat_type: String, multiplier: float):
	"""應用屬性倍率"""
	match stat_type:
		"atk":
			atk_multiplier *= multiplier
		"defense":
			defense_multiplier *= multiplier

func get_display_info() -> Dictionary:
	"""獲取顯示資訊"""
	return {
		"enemy_name": enemy_name,
		"hp": "%d/%d" % [current_hp, max_hp],
		"atk": current_atk,
		"cd": current_cd
	}
