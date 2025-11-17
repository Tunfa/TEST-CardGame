# SkillBase.gd
# 技能抽象基類 - 所有技能都繼承這個類
class_name SkillBase
extends RefCounted

# ==================== 基礎屬性 ====================
var skill_id: String = ""
var skill_name: String = ""
var skill_description: String = ""
var skill_description2: String = ""
var skill_icon_path: String = ""  # 技能圖示路徑（預留）

# ==================== 技能類型 ====================
var skill_type: Constants.SkillType = Constants.SkillType.PASSIVE
var trigger_timing: Constants.TriggerTiming = Constants.TriggerTiming.PERMANENT
var target_type: Constants.TargetType = Constants.TargetType.SELF

# ==================== 技能參數 ====================
var cooldown: int = 0  # CD回合數（主動技能用）
var max_trigger_count: int = -1  # 最大觸發次數（-1=無限）
var current_trigger_count: int = 0  # 已觸發次數

# ==================== 技能數值 ====================
var damage_value: int = 0  # 傷害值
var heal_value: int = 0  # 治療值
var multiplier: float = 1.0  # 倍率

# ==================== 技能狀態 ====================
var is_active: bool = true  # 技能是否激活

# ==================== 核心方法（子類需實作） ====================

func can_trigger(_context: SkillContext) -> bool:  # 注意有下划线
	"""检查是否可以触发技能"""
	# 检查是否达到最大触发次数
	if max_trigger_count > 0 and current_trigger_count >= max_trigger_count:
		return false
	
	# 检查技能是否激活
	if not is_active:
		return false
	
	return true

func execute(_context: SkillContext):
	"""執行技能效果 - 子類必須重寫此方法"""
	push_error("SkillBase.execute() 必須被子類重寫！")

func get_targets(context: SkillContext) -> Array:
	"""獲取技能目標"""
	var targets: Array = []
	
	match target_type:
		Constants.TargetType.SELF:
			targets.append(context.caster)
		
		Constants.TargetType.SINGLE_ENEMY:
			if context.target:
				targets.append(context.target)
		
		Constants.TargetType.ALL_ENEMIES:
			if context.battle_manager:
				targets = context.battle_manager.enemies.duplicate()
		
		Constants.TargetType.SINGLE_ALLY:
			if context.target:
				targets.append(context.target)
		
		Constants.TargetType.ALL_ALLIES:
			if context.battle_manager:
				targets = context.battle_manager.player_team.duplicate()
		
		Constants.TargetType.RANDOM_ENEMY:
			if context.battle_manager and not context.battle_manager.enemies.is_empty():
				var random_enemy = context.battle_manager.enemies[randi() % context.battle_manager.enemies.size()]
				targets.append(random_enemy)
	
	return targets

# ==================== 工具方法 ====================

func on_trigger():
	"""技能觸發時調用"""
	current_trigger_count += 1

func reset():
	"""重置技能狀態"""
	current_trigger_count = 0
	is_active = true

func deactivate():
	"""停用技能"""
	is_active = false

func get_info() -> Dictionary:
	"""獲取技能資訊"""
	return {
		"skill_id": skill_id,
		"skill_name": skill_name,
		"skill_description": skill_description,
		"skill_description2": skill_description2,
		"skill_type": Constants.SkillType.keys()[skill_type],
		"trigger_timing": Constants.TriggerTiming.keys()[trigger_timing],
		"cooldown": cooldown,
		"trigger_count": "%d/%d" % [current_trigger_count, max_trigger_count] if max_trigger_count > 0 else "無限"
	}
