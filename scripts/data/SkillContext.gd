# SkillContext.gd
# 技能執行時的上下文資訊
class_name SkillContext
extends RefCounted

# ==================== 戰鬥管理器 ====================
var battle_manager = null  # BattleManager 的引用

# ==================== 技能相關 ====================
var skill = null  # SkillBase - 正在執行的技能
var caster = null  # CardData/EnemyData - 施放者
var target = null  # CardData/EnemyData - 目標
var action_causer = null # ✅ 新增：儲存原始的事件觸發者 (例如攻擊者)
var targets: Array = []  # 多目標

# ==================== 傷害/治療 ====================
var damage: int = 0  # 傷害數值
var heal: int = 0    # 治療數值
var is_critical: bool = false  # 是否暴擊（預留）

# ==================== 特殊標記 ====================
var skip_normal_attack: bool = false  # 是否跳過普通攻擊
var is_dodged: bool = false  # 是否被迴避
var damage_multiplier: float = 1.0  # 傷害倍率（可疊加）
var custom_data: Dictionary = {}  # ✅ 新增：自訂資料（用於敵人技能等）


# ==================== 回合資訊 ====================
var turn_count: int = 0  # 當前回合數
var is_player_turn: bool = true

# ==================== 構造函數 ====================

func _init(
	p_battle_manager = null,
	p_skill = null,
	p_caster = null,
	p_target = null
):
	battle_manager = p_battle_manager
	skill = p_skill
	caster = p_caster
	action_causer = p_caster  # ✅ 新增：在初始化時保存原始的 p_caster
	target = p_target

# ==================== 工具方法 ====================

func set_damage(value: int):
	"""設定傷害值"""
	damage = value

func apply_damage_multiplier(multiplier: float):
	"""應用傷害倍率（可疊加）"""
	damage_multiplier *= multiplier

func get_final_damage() -> int:
	"""獲取最終傷害（套用所有倍率）"""
	if is_dodged:
		return 0
	return int(damage * damage_multiplier)

func add_target(new_target):
	"""添加目標"""
	if new_target and new_target not in targets:
		targets.append(new_target)

func clear_targets():
	"""清空目標列表"""
	targets.clear()
