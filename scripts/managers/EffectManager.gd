# EffectManager.gd
# 效果管理器 - 管理戰鬥中的所有技能效果
class_name EffectManager
extends Node

# ==================== 效果列表 ====================
var active_effects: Array = []  # Array[Dictionary]
# 每个效果包含：
# {
#   "skill": SkillBase,
#   "effect_owner": CardData/EnemyData,  # 改名为 effect_owner
#   "trigger_timing": TriggerTiming
# }

var battle_manager = null  # BattleManager 引用

# ==================== 初始化 ====================

func _init(p_battle_manager = null):
	battle_manager = p_battle_manager

# ==================== 效果注册 ====================

func register_effect(skill: SkillBase, effect_owner):
	"""註冊技能效果"""
	var effect = {
		"skill": skill,
		"effect_owner": effect_owner,
		"trigger_timing": skill.trigger_timing
	}
	active_effects.append(effect)

	# 修復：直接檢查屬性，而不是使用 has()
	var owner_name = ""
	if effect_owner is CardData:
		owner_name = effect_owner.card_name
	elif effect_owner is EnemyData:
		owner_name = effect_owner.enemy_name
	else:
		owner_name = "未知"

	print("  [效果管理器] 註冊效果: %s (來自 %s)" % [skill.skill_name, owner_name])

func clear_effects():
	"""清空所有效果"""
	active_effects.clear()

# ==================== 觸發效果 ====================

func trigger_effects(timing: Constants.TriggerTiming, context: SkillContext):
	"""在特定時機觸發技能"""
	print("\n  [效果管理器] 觸發時機: %s" % Constants.TriggerTiming.keys()[timing])
	print("  [效果管理器] 檢查 %d 個效果..." % active_effects.size())

	var triggered_count = 0
	var triggered_enemy_skills = {}  # 記錄已觸發的敵人負面效果技能 {skill_id: true}

	for effect in active_effects:
		var skill = effect.skill
		var effect_owner = effect.effect_owner  # 改名

		# 檢查時機是否匹配
		if skill.trigger_timing != timing:
			continue

		# 檢查技能是否可以觸發
		if not skill.can_trigger(context):
			print("  [效果管理器] 技能 %s 無法觸發 (can_trigger 返回 false)" % skill.skill_name)
			continue

		# ✅ 敵人技能去重邏輯
		# 如果是敵人的負面效果技能（非條件類），相同 skill_id 只執行一次
		var is_enemy_skill = effect_owner is EnemyData
		if is_enemy_skill and skill.has_method("is_condition_skill"):
			var is_condition = skill.is_condition_skill()

			# 負面效果技能：檢查是否已經觸發過相同 skill_id
			if not is_condition:
				if skill.skill_id in triggered_enemy_skills:
					print("  [效果管理器] 跳過重複的負面效果技能: %s (skill_id: %s)" % [skill.skill_name, skill.skill_id])
					continue
				else:
					# 記錄已觸發
					triggered_enemy_skills[skill.skill_id] = true
					print("  [效果管理器] 首次觸發負面效果技能: %s (skill_id: %s)" % [skill.skill_name, skill.skill_id])
			else:
				# 條件類技能：每個敵人都需要執行
				print("  [效果管理器] 執行條件類技能: %s (所有敵人)" % skill.skill_name)

		# 設定施放者
		context.caster = effect_owner  # 使用新名稱

		# 執行技能
		print("  [效果管理器] 正在執行技能: %s" % skill.skill_name)
		skill.execute(context)
		triggered_count += 1

	print("  [效果管理器] 共觸發了 %d 個技能" % triggered_count)

func apply_permanent_effects(context: SkillContext):
	"""應用所有永久效果（PERMANENT類型）"""
	print("\n  [效果管理器] 應用永久效果...")
	print("  [效果管理器] 當前註冊的效果總數: %d" % active_effects.size())
	trigger_effects(Constants.TriggerTiming.PERMANENT, context)
