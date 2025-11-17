# SkillEffectHandler.gd
# 技能效果處理器 - 實現具體的技能效果邏輯
class_name SkillEffectHandler
extends Node

# ==================== 引用 ====================
var battle_manager: BattleManager = null
var skill_system: SkillSystem = null

# ==================== 當前激活的效果 ====================
var active_leader_effects: Array = []  # 當前激活的隊長技能效果
var active_enemy_effects: Array = []   # 當前激活的敵人技能效果

# ==================== 技能修飾符緩存 ====================
var damage_multipliers: Dictionary = {}  # element -> multiplier
var hp_multipliers: Dictionary = {}      # element -> multiplier
var recovery_multipliers: Dictionary = {} # element -> multiplier
var slash_time_extension: float = 0.0

# ==================== 初始化 ====================
func init_with_managers(_battle_manager: BattleManager, _skill_system: SkillSystem):
	"""初始化處理器，關聯管理器"""
	battle_manager = _battle_manager
	skill_system = _skill_system
	_reset_modifiers()

func _reset_modifiers():
	"""重置所有修飾符"""
	damage_multipliers.clear()
	hp_multipliers.clear()
	recovery_multipliers.clear()
	slash_time_extension = 0.0

	# 為每個元素初始化基礎倍率
	for element in [Constants.Element.FIRE, Constants.Element.WATER, Constants.Element.WOOD,
					Constants.Element.METAL, Constants.Element.EARTH, Constants.Element.HEART]:
		damage_multipliers[element] = 1.0
		hp_multipliers[element] = 1.0
		recovery_multipliers[element] = 1.0

# ==================== 隊長技能效果應用 ====================
func apply_leader_skill(skill_id: String):
	"""應用隊長技能"""
	var skill_data = skill_system.get_leader_skill(skill_id)
	if skill_data.is_empty():
		return

	print("🔮 [SkillEffectHandler] 應用隊長技能: %s" % skill_data.get("skill_name", "未知"))

	for effect in skill_data.get("effects", []):
		_apply_leader_effect(effect)

func _apply_leader_effect(effect: Dictionary):
	"""應用單個隊長技能效果"""
	var effect_type_str = effect.get("effect_type", "")
	var effect_type = skill_system.parse_leader_skill_effect_type(effect_type_str)

	match effect_type:
		# ========== 傷害倍率類 ==========
		Constants.LeaderSkillEffectType.DAMAGE_MULTIPLIER:
			_apply_damage_multiplier(effect)

		Constants.LeaderSkillEffectType.BASE_DAMAGE_BOOST:
			_apply_base_damage_boost(effect)

		Constants.LeaderSkillEffectType.ALL_DAMAGE_BOOST:
			_apply_all_damage_boost(effect)

		Constants.LeaderSkillEffectType.IGNORE_RESISTANCE:
			_apply_ignore_resistance(effect)

		# ========== 靈珠相關 ==========
		Constants.LeaderSkillEffectType.FORCE_ORB_SPAWN:
			_apply_force_orb_spawn(effect)

		Constants.LeaderSkillEffectType.ORB_SPAWN_RATE_BOOST:
			_apply_orb_spawn_rate_boost(effect)

		Constants.LeaderSkillEffectType.ORB_CAPACITY_BOOST:
			_apply_orb_capacity_boost(effect)

		Constants.LeaderSkillEffectType.ORB_DROP_END_TURN:
			_apply_orb_drop_end_turn(effect)

		# ========== 數值動態倍率類 ==========
		Constants.LeaderSkillEffectType.ORB_COUNT_MULTIPLIER:
			_apply_orb_count_multiplier(effect)

		Constants.LeaderSkillEffectType.TEAM_ELEMENT_MULTIPLIER:
			_apply_team_element_multiplier(effect)

		Constants.LeaderSkillEffectType.TEAM_DIVERSITY_MULTIPLIER:
			_apply_team_diversity_multiplier(effect)

		# ========== 屬性倍率類 ==========
		Constants.LeaderSkillEffectType.HP_MULTIPLIER:
			_apply_hp_multiplier(effect)

		Constants.LeaderSkillEffectType.RECOVERY_MULTIPLIER:
			_apply_recovery_multiplier(effect)

		# ========== 時間延長 ==========
		Constants.LeaderSkillEffectType.EXTEND_SLASH_TIME:
			_apply_extend_slash_time(effect)

		# ========== 回合結束效果 ==========
		Constants.LeaderSkillEffectType.END_TURN_DAMAGE:
			_apply_end_turn_damage(effect)

		_:
			print("  ⚠️ 未實現的效果類型: %s" % effect_type_str)

# ==================== 具體效果實現 ====================

# 1. 傷害倍率
func _apply_damage_multiplier(effect: Dictionary):
	"""應用傷害倍率效果"""
	var element_str = effect.get("target_element", "FIRE")
	var multiplier = effect.get("multiplier", 1.0)

	var element = skill_system.parse_element(element_str)
	damage_multipliers[element] *= multiplier

	print("  ✓ 傷害倍率: %s x%.1f (總計: x%.1f)" % [element_str, multiplier, damage_multipliers[element]])

# 2. 基礎傷害提升
func _apply_base_damage_boost(effect: Dictionary):
	"""應用基礎傷害提升效果"""
	var element_str = effect.get("target_element", "FIRE")
	var boost_percent = effect.get("boost_percent", 0.0)

	# 基礎傷害提升需要在傷害計算時應用
	# 這裡先記錄效果
	active_leader_effects.append({
		"type": "BASE_DAMAGE_BOOST",
		"element": skill_system.parse_element(element_str),
		"boost": boost_percent / 100.0
	})

	print("  ✓ 基礎傷害提升: %s +%.0f%%" % [element_str, boost_percent])

# 3. 全傷害提升
func _apply_all_damage_boost(effect: Dictionary):
	"""應用全傷害提升效果（包含主動技能）"""
	var element_str = effect.get("target_element", "FIRE")
	var boost_percent = effect.get("boost_percent", 0.0)

	active_leader_effects.append({
		"type": "ALL_DAMAGE_BOOST",
		"element": skill_system.parse_element(element_str),
		"boost": boost_percent / 100.0
	})

	print("  ✓ 全傷害提升: %s +%.0f%%" % [element_str, boost_percent])

# 4. 無視屬性克制
func _apply_ignore_resistance(effect: Dictionary):
	"""應用無視屬性克制效果"""
	var element_str = effect.get("target_element", "FIRE")

	active_leader_effects.append({
		"type": "IGNORE_RESISTANCE",
		"element": skill_system.parse_element(element_str)
	})

	print("  ✓ 無視屬性克制: %s" % element_str)

# 5. 固定出現靈珠
func _apply_force_orb_spawn(effect: Dictionary):
	"""應用固定出現靈珠效果"""
	var element_str = effect.get("target_element", "FIRE")
	var count = effect.get("count", 0)

	var element = skill_system.parse_element(element_str)

	# 調用BattleManager的靈珠規則設置
	if battle_manager:
		battle_manager.set_orb_rules_for_turn({
			"force_element": element,
			"force_count": count
		})

	print("  ✓ 固定出現靈珠: %s x%d" % [element_str, count])

# 6. 靈珠出現機率提升
func _apply_orb_spawn_rate_boost(effect: Dictionary):
	"""應用靈珠出現機率提升效果"""
	var element_str = effect.get("target_element", "FIRE")
	var boost_percent = effect.get("boost_percent", 0.0)

	active_leader_effects.append({
		"type": "ORB_SPAWN_RATE_BOOST",
		"element": skill_system.parse_element(element_str),
		"boost": boost_percent / 100.0
	})

	print("  ✓ 靈珠出現機率提升: %s +%.0f%%" % [element_str, boost_percent])

# 7. 靈珠容量提升
func _apply_orb_capacity_boost(effect: Dictionary):
	"""應用靈珠容量提升效果"""
	var element_str = effect.get("target_element", "FIRE")
	var bonus_capacity = effect.get("bonus_capacity", 0)

	active_leader_effects.append({
		"type": "ORB_CAPACITY_BOOST",
		"element": skill_system.parse_element(element_str),
		"bonus": bonus_capacity
	})

	print("  ✓ 靈珠容量提升: %s +%d" % [element_str, bonus_capacity])

# 8. 回合結束掉落靈珠
func _apply_orb_drop_end_turn(effect: Dictionary):
	"""應用回合結束掉落靈珠效果"""
	var element_str = effect.get("element", "HEART")
	var count = effect.get("count", 0)

	active_leader_effects.append({
		"type": "ORB_DROP_END_TURN",
		"element": skill_system.parse_element(element_str),
		"count": count
	})

	print("  ✓ 回合結束掉落靈珠: %s x%d" % [element_str, count])

# 9. 靈珠數量倍率
func _apply_orb_count_multiplier(effect: Dictionary):
	"""應用靈珠數量傷害倍率效果"""
	var element_str = effect.get("target_element", "FIRE")
	var base_multiplier = effect.get("base_multiplier", 1.0)
	var max_multiplier = effect.get("max_multiplier", 3.0)
	var orb_per_tier = effect.get("orb_per_tier", 3)

	active_leader_effects.append({
		"type": "ORB_COUNT_MULTIPLIER",
		"element": skill_system.parse_element(element_str),
		"base": base_multiplier,
		"max": max_multiplier,
		"per_tier": orb_per_tier
	})

	print("  ✓ 靈珠數量倍率: %s %.1f~%.1fx (每%d粒)" % [element_str, base_multiplier, max_multiplier, orb_per_tier])

# 10. 隊伍元素倍率
func _apply_team_element_multiplier(effect: Dictionary):
	"""應用隊伍元素成員倍率效果"""
	var element_str = effect.get("target_element", "FIRE")
	var base_multiplier = effect.get("base_multiplier", 1.0)
	var max_multiplier = effect.get("max_multiplier", 2.5)
	var per_member_boost = effect.get("per_member_boost", 0.3)

	# 計算隊伍中該元素成員數量
	var element_count = _count_team_element(skill_system.parse_element(element_str))
	var actual_multiplier = min(base_multiplier + (element_count * per_member_boost), max_multiplier)

	damage_multipliers[skill_system.parse_element(element_str)] *= actual_multiplier

	print("  ✓ 隊伍元素倍率: %s x%.1f (%d個成員)" % [element_str, actual_multiplier, element_count])

# 11. 隊伍多樣性倍率
func _apply_team_diversity_multiplier(effect: Dictionary):
	"""應用隊伍多樣性倍率效果"""
	var base_multiplier = effect.get("base_multiplier", 1.0)
	var max_multiplier = effect.get("max_multiplier", 2.0)
	var per_unique_boost = effect.get("per_unique_boost", 0.2)

	# 計算隊伍中不同屬性數量
	var unique_elements = _count_unique_team_elements()
	var actual_multiplier = min(base_multiplier + (unique_elements * per_unique_boost), max_multiplier)

	# 應用到所有元素
	for element in damage_multipliers.keys():
		damage_multipliers[element] *= actual_multiplier

	print("  ✓ 隊伍多樣性倍率: x%.1f (%d種屬性)" % [actual_multiplier, unique_elements])

# 12. 生命力倍率
func _apply_hp_multiplier(effect: Dictionary):
	"""應用生命力倍率效果"""
	var element_str = effect.get("target_element", "ALL")
	var multiplier = effect.get("multiplier", 1.0)

	if element_str == "ALL":
		# 應用到所有元素
		for element in hp_multipliers.keys():
			hp_multipliers[element] *= multiplier
		print("  ✓ 全隊生命力倍率: x%.1f" % multiplier)
	else:
		var element = skill_system.parse_element(element_str)
		hp_multipliers[element] *= multiplier
		print("  ✓ 生命力倍率: %s x%.1f" % [element_str, multiplier])

# 13. 回復力倍率
func _apply_recovery_multiplier(effect: Dictionary):
	"""應用回復力倍率效果"""
	var element_str = effect.get("target_element", "ALL")
	var multiplier = effect.get("multiplier", 1.0)

	if element_str == "ALL":
		for element in recovery_multipliers.keys():
			recovery_multipliers[element] *= multiplier
		print("  ✓ 全隊回復力倍率: x%.1f" % multiplier)
	else:
		var element = skill_system.parse_element(element_str)
		recovery_multipliers[element] *= multiplier
		print("  ✓ 回復力倍率: %s x%.1f" % [element_str, multiplier])

# 14. 延長斬擊時間
func _apply_extend_slash_time(effect: Dictionary):
	"""應用延長斬擊時間效果"""
	var extend_seconds = effect.get("extend_seconds", 0.0)
	slash_time_extension += extend_seconds

	print("  ✓ 延長斬擊時間: +%.1f秒 (總計: +%.1f秒)" % [extend_seconds, slash_time_extension])

# 15. 回合結束傷害
func _apply_end_turn_damage(effect: Dictionary):
	"""應用回合結束傷害效果"""
	var element_str = effect.get("element", "FIRE")
	var damage = effect.get("damage", 0)

	active_leader_effects.append({
		"type": "END_TURN_DAMAGE",
		"element": skill_system.parse_element(element_str),
		"damage": damage
	})

	print("  ✓ 回合結束傷害: %s %d點" % [element_str, damage])

# ==================== 輔助函數 ====================
func _count_team_element(element: Constants.Element) -> int:
	"""計算隊伍中特定元素的成員數量"""
	if not battle_manager:
		return 0

	var count = 0
	for card in battle_manager.player_team:
		if card and card.element == element:
			count += 1

	return count

func _count_unique_team_elements() -> int:
	"""計算隊伍中不同屬性的數量"""
	if not battle_manager:
		return 0

	var unique_elements = {}
	for card in battle_manager.player_team:
		if card:
			unique_elements[card.element] = true

	return unique_elements.size()

# ==================== 獲取修飾符 ====================
func get_damage_multiplier(element: Constants.Element) -> float:
	"""獲取元素傷害倍率"""
	return damage_multipliers.get(element, 1.0)

func get_hp_multiplier(element: Constants.Element) -> float:
	"""獲取元素生命力倍率"""
	return hp_multipliers.get(element, 1.0)

func get_recovery_multiplier(element: Constants.Element) -> float:
	"""獲取元素回復力倍率"""
	return recovery_multipliers.get(element, 1.0)

func get_slash_time_extension() -> float:
	"""獲取斬擊時間延長秒數"""
	return slash_time_extension

# ==================== 觸發效果 ====================
func trigger_end_turn_effects():
	"""觸發回合結束效果"""
	for effect in active_leader_effects:
		if effect.get("type") == "END_TURN_DAMAGE":
			_trigger_end_turn_damage(effect)

func _trigger_end_turn_damage(effect: Dictionary):
	"""觸發回合結束傷害"""
	var damage = effect.get("damage", 0)
	var _element = effect.get("element", Constants.Element.FIRE)  # Reserved for future use

	if battle_manager and battle_manager.enemies.size() > 0:
		# 對所有敵人造成傷害
		for enemy in battle_manager.enemies:
			if enemy and enemy.current_hp > 0:
				print("🔥 回合結束傷害: 對 %s 造成 %d 點傷害" % [enemy.enemy_name, damage])
				# TODO: 實際扣血邏輯
				# battle_manager.deal_damage_to_enemy(enemy, damage, element)
