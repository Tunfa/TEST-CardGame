# SkillRegistry.gd
# 技能註冊表（Autoload 單例）
extends Node

# ==================== 技能註冊表 ====================
var registered_skills: Dictionary = {}  # {skill_id: Script}
var skill_system: SkillSystem = null  # JSON技能系統

# ==================== 初始化 ====================

func _ready():
	print("🔮 SkillRegistry 初始化完成")

	# 初始化JSON技能系統
	skill_system = SkillSystem.new()
	add_child(skill_system)

	load_all_skills()

# ==================== 載入技能 ====================

func load_all_skills():
	"""載入所有技能腳本"""
	print("開始載入技能...")
	
	# 載入玩家被動技能
	load_skills_from_directory("res://scripts/skills/passive/permanent/")
	load_skills_from_directory("res://scripts/skills/passive/battle_start/")
	load_skills_from_directory("res://scripts/skills/passive/turn_start/")
	load_skills_from_directory("res://scripts/skills/passive/before_damaged/")
	load_skills_from_directory("res://scripts/skills/passive/after_damaged/")
	
	# 載入玩家主動技能
	load_skills_from_directory("res://scripts/skills/active/damage/")
	load_skills_from_directory("res://scripts/skills/active/heal/")
	load_skills_from_directory("res://scripts/skills/active/buff/")
	load_skills_from_directory("res://scripts/skills/active/debuff/")
	
	# 載入敵人技能
	load_skills_from_directory("res://scripts/skills/enemy/passive/")
	load_skills_from_directory("res://scripts/skills/enemy/attack/")
	
	print("✅ 技能載入完成，共 %d 個技能" % registered_skills.size())

func load_skills_from_directory(dir_path: String):
	"""從目錄載入技能腳本"""
	var dir = DirAccess.open(dir_path)
	if not dir:
		# 目錄不存在是正常的（因為技能還沒創建）
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd"):
			var script_path = dir_path + file_name
			var script = load(script_path)
			
			if script:
				# 創建臨時實例以獲取 skill_id
				var temp_instance = script.new()
				if "skill_id" in temp_instance and temp_instance.skill_id and not temp_instance.skill_id.is_empty():
					var skill_id = temp_instance.skill_id
					registered_skills[skill_id] = script
					print("  ✓ 註冊技能: %s (%s)" % [skill_id, file_name])
				# RefCounted 對象不需要手動釋放，會自動被 GC 回收
				temp_instance = null  # 清空引用即可
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

# ==================== 技能創建 ====================

func create_skill_instance(skill_id: String):
	"""根據ID創建技能實例（支持GDScript和JSON技能）"""
	if skill_id.is_empty():
		return null

	# 優先查找GDScript技能
	if skill_id in registered_skills:
		var skill_script = registered_skills[skill_id]
		return skill_script.new()

	# 如果不是GDScript技能，檢查是否是JSON技能
	if is_json_skill(skill_id):
		# 主動技能
		if skill_id.begins_with("AS_"):
			return create_active_skill_instance(skill_id)
		# 敵人技能
		elif skill_id.begins_with("ES_"):
			return create_enemy_skill_wrapper(skill_id)
		# 隊長技能
		else:
			return create_json_skill_wrapper(skill_id)

	push_error("❌ 技能不存在: " + skill_id)
	return null

func get_skill_info(skill_id: String) -> Dictionary:
	"""獲取技能資訊（不創建實例）"""
	# 優先查找GDScript技能
	if skill_id in registered_skills:
		var skill = create_skill_instance(skill_id)
		if not skill:
			return {}

		var info = {
			"skill_id": skill.skill_id,
			"skill_name": skill.skill_name,
			"skill_description": skill.skill_description,
			"skill_description2": skill.skill_description2,
			"skill_type": skill.skill_type,
			"cooldown": skill.cooldown
		}

		skill = null
		return info

	# 如果是JSON技能，從SkillSystem獲取信息
	if is_json_skill(skill_id):
		return get_json_skill_info(skill_id)

	return {}

func skill_exists(skill_id: String) -> bool:
	"""檢查技能是否存在（支持GDScript和JSON技能）"""
	return (skill_id in registered_skills) or is_json_skill(skill_id)

func get_all_skill_ids() -> Array:
	"""獲取所有技能ID"""
	return registered_skills.keys()

# ==================== JSON技能支持 ====================

func is_json_skill(skill_id: String) -> bool:
	"""檢查是否是JSON配置的技能"""
	if not skill_system:
		return false

	# 主動技能以 AS_ 開頭
	if skill_id.begins_with("AS_"):
		return skill_system.active_skills.has(skill_id)

	# 隊長技能以 LS_ 開頭
	if skill_id.begins_with("LS_"):
		return skill_system.leader_skills.has(skill_id)

	# 敵人技能以 ES_ 開頭
	if skill_id.begins_with("ES_"):
		return skill_system.enemy_skills.has(skill_id)

	return false

func get_json_skill_info(skill_id: String) -> Dictionary:
	"""獲取JSON技能信息"""
	if not skill_system:
		return {}

	var skill_data: Dictionary = {}
	var skill_type: Constants.SkillType = Constants.SkillType.PASSIVE
	var cooldown: int = 0

	# 主動技能
	if skill_id.begins_with("AS_"):
		skill_data = skill_system.get_active_skill(skill_id)
		skill_type = Constants.SkillType.ACTIVE
		cooldown = skill_data.get("skill_cost", 0)  # 主動技能的CD
	# 隊長技能
	elif skill_id.begins_with("LS_"):
		skill_data = skill_system.get_leader_skill(skill_id)
		skill_type = Constants.SkillType.PASSIVE
		cooldown = 0
	# 敵人技能
	elif skill_id.begins_with("ES_"):
		skill_data = skill_system.get_enemy_skill(skill_id)
		skill_type = Constants.SkillType.ENEMY
		cooldown = 0

	if skill_data.is_empty():
		return {}

	# 轉換為統一格式
	var description = skill_data.get("description", "無描述")
	return {
		"skill_id": skill_data.get("skill_id", skill_id),
		"skill_name": skill_data.get("skill_name", "未知技能"),
		"skill_description": description,
		"skill_description2": description,  # JSON技能使用同一個描述
		"skill_type": skill_type,
		"cooldown": cooldown
	}

func create_json_skill_wrapper(skill_id: String):
	"""創建JSON技能的包裝對象 - 可能返回多個實例"""
	# JSON技能可能需要在多个时机触发，所以返回一个数组
	var wrappers = []

	# 获取技能数据
	var skill_data = skill_system.get_leader_skill(skill_id)
	if not skill_data:
		return null

	var effects = skill_data.get("effects", [])
	var required_timings = []  # 需要的触发时机列表

	# 分析需要哪些触发时机
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		match effect_type:
			"HP_MULTIPLIER", "RECOVERY_MULTIPLIER", "TEAM_ELEMENT_MULTIPLIER", "TEAM_DIVERSITY_MULTIPLIER", "EXTEND_SLASH_TIME", "IGNORE_RESISTANCE", "ORB_DUAL_EFFECT", "ORB_CAPACITY_BOOST", "BASE_DAMAGE_BOOST", "END_TURN_DAMAGE", "COMBO_BOOST":
				if not Constants.TriggerTiming.PERMANENT in required_timings:
					required_timings.append(Constants.TriggerTiming.PERMANENT)
			"DAMAGE_MULTIPLIER", "ALL_DAMAGE_BOOST", "ORB_COUNT_MULTIPLIER":
				if not Constants.TriggerTiming.BEFORE_ATTACK in required_timings:
					required_timings.append(Constants.TriggerTiming.BEFORE_ATTACK)
			"FORCE_ORB_SPAWN", "ORB_SPAWN_RATE_BOOST", "ORB_DROP_END_TURN", "ORB_DROP_ON_SLASH", "SLASH_ORB_SPAWN":
				if not Constants.TriggerTiming.TURN_START in required_timings:
					required_timings.append(Constants.TriggerTiming.TURN_START)

	# 为每个需要的时机创建一个包装器实例
	for timing in required_timings:
		var wrapper = JSONSkillWrapper.new()
		# ✅ 直接传入完整的 skill_data，不要在 wrapper 内部获取
		wrapper.init_from_json_with_timing(skill_id, get_json_skill_info(skill_id), timing, effects)
		wrappers.append(wrapper)

	# 如果只有一个，直接返回
	return wrappers[0] if wrappers.size() == 1 else wrappers

# ==================== JSON技能包裝類 ====================
class JSONSkillWrapper extends SkillBase:
	"""JSON技能的包裝類，繼承自SkillBase以確保與EffectManager兼容"""
	var json_effects: Array = []  # 存储JSON效果配置

	func init_from_json(id: String, info: Dictionary):
		init_from_json_with_timing(id, info, Constants.TriggerTiming.PERMANENT, [])

	func init_from_json_with_timing(id: String, info: Dictionary, timing: Constants.TriggerTiming, effects: Array):
		skill_id = id
		skill_name = info.get("skill_name", "")
		skill_description = info.get("skill_description", "")
		skill_description2 = info.get("skill_description2", "")
		skill_type = info.get("skill_type", Constants.SkillType.PASSIVE)
		cooldown = info.get("cooldown", 0)
		trigger_timing = timing  # 直接设置触发时机
		json_effects = effects  # ✅ 直接使用传入的 effects，不再获取


	func execute(context: SkillContext):
		"""執行JSON技能效果 - 直接应用效果，不使用SkillEffectHandler"""
		if not context or not context.battle_manager:
			return

		print("  [JSON技能] 執行技能: %s (時機: %s)" % [skill_name, Constants.TriggerTiming.keys()[trigger_timing]])

		# 根据当前触发时机应用相应的效果
		for effect in json_effects:
			_apply_json_effect(effect, context)

	func _apply_json_effect(effect: Dictionary, context: SkillContext):
		"""应用单个JSON效果"""
		var effect_type = effect.get("effect_type", "")
		var current_timing = trigger_timing

		match effect_type:
			# ========== 永久属性倍率 (PERMANENT) ==========
			"HP_MULTIPLIER":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_hp_multiplier(effect, context)

			"RECOVERY_MULTIPLIER":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_recovery_multiplier(effect, context)

			"TEAM_ELEMENT_MULTIPLIER":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_team_element_multiplier(effect, context)

			"TEAM_DIVERSITY_MULTIPLIER":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_team_diversity_multiplier(effect, context)

			"EXTEND_SLASH_TIME":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_extend_slash_time(effect, context)

			"IGNORE_RESISTANCE":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_ignore_resistance(effect, context)

			"ORB_DUAL_EFFECT":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_orb_dual_effect(effect, context)

			"ORB_CAPACITY_BOOST":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_orb_capacity_boost(effect, context)

			# ✅ BASE_DAMAGE_BOOST 改為 PERMANENT 效果
			"BASE_DAMAGE_BOOST":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_base_damage_boost(effect, context)

			# ✅ END_TURN_DAMAGE 改為 PERMANENT 效果（在戰鬥開始時註冊）
			"END_TURN_DAMAGE":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_end_turn_damage(effect, context)

			# ✅ COMBO_BOOST 可作為隊長技能（PERMANENT 永久效果）
			"COMBO_BOOST":
				if current_timing == Constants.TriggerTiming.PERMANENT:
					_apply_combo_boost(effect, context)

			# ========== 伤害倍率 (BEFORE_ATTACK) ==========
			"DAMAGE_MULTIPLIER":
				if current_timing == Constants.TriggerTiming.BEFORE_ATTACK:
					_apply_damage_multiplier(effect, context)

			"ALL_DAMAGE_BOOST":
				if current_timing == Constants.TriggerTiming.BEFORE_ATTACK:
					_apply_all_damage_boost(effect, context)

			"ORB_COUNT_MULTIPLIER":
				if current_timing == Constants.TriggerTiming.BEFORE_ATTACK:
					_apply_orb_count_multiplier(effect, context)

			# ========== 灵珠规则 (TURN_START) ==========
			"FORCE_ORB_SPAWN":
				if current_timing == Constants.TriggerTiming.TURN_START:
					_apply_force_orb_spawn(effect, context)

			"ORB_SPAWN_RATE_BOOST":
				if current_timing == Constants.TriggerTiming.TURN_START:
					_apply_orb_spawn_rate_boost(effect, context)

			"ORB_DROP_END_TURN":
				if current_timing == Constants.TriggerTiming.TURN_START:
					_apply_orb_drop_end_turn(effect, context)

			"ORB_DROP_ON_SLASH":
				if current_timing == Constants.TriggerTiming.TURN_START:
					_apply_orb_drop_on_slash(effect, context)

			"SLASH_ORB_SPAWN":
				if current_timing == Constants.TriggerTiming.TURN_START:
					_apply_slash_orb_spawn(effect, context)

	# ========== 效果实现 ==========
	func _apply_hp_multiplier(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "ALL")
		var mult_value = effect.get("multiplier", 1.0)

		if element_str == "ALL":
			for card in context.battle_manager.player_team:
				card.apply_multiplier("hp", mult_value)
			print("    ✓ 全隊生命力 x%.1f" % mult_value)
		else:
			var element = _parse_element(element_str)
			for card in context.battle_manager.player_team:
				if card.element == element:
					card.apply_multiplier("hp", mult_value)
			print("    ✓ %s生命力 x%.1f" % [element_str, mult_value])

	func _apply_recovery_multiplier(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "ALL")
		var mult_value = effect.get("multiplier", 1.0)

		if element_str == "ALL":
			for card in context.battle_manager.player_team:
				card.apply_multiplier("recovery", mult_value)
			print("    ✓ 全隊回復力 x%.1f" % mult_value)
		else:
			var element = _parse_element(element_str)
			for card in context.battle_manager.player_team:
				if card.element == element:
					card.apply_multiplier("recovery", mult_value)
			print("    ✓ %s回復力 x%.1f" % [element_str, mult_value])

	func _apply_damage_multiplier(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "FIRE")
		var mult_value = effect.get("multiplier", 1.0)
		var element = _parse_element(element_str)

		# 只对匹配元素的攻击者应用倍率
		if context.action_causer and context.action_causer.element == element:
			context.apply_damage_multiplier(mult_value)
			print("    ✓ %s傷害 x%.1f" % [element_str, mult_value])

	func _apply_force_orb_spawn(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "FIRE")
		var count = effect.get("count", 0)
		var element = _parse_element(element_str)

		context.battle_manager.set_orb_rules_for_turn({
			"force_element": element,
			"force_count": count
		})
		print("    ✓ 固定出現%s x%d" % [element_str, count])

	func _apply_orb_spawn_rate_boost(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "FIRE")
		var boost_percent = effect.get("boost_percent", 0.0)
		var element = _parse_element(element_str)

		context.battle_manager.set_orb_rules_for_turn({
			"bonus_element": element,
			"bonus_rate": boost_percent / 100.0
		})
		print("    ✓ %s出現率 +%.0f%%" % [element_str, boost_percent])

	func _apply_orb_drop_end_turn(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("element", "HEART")
		var count = effect.get("count", 0)
		var element = _parse_element(element_str)
		var drop_timing = effect.get("drop_timing", "end_turn")  # 默認回合結束掉落

		# 根據 drop_timing 存儲到不同的 meta
		if context.battle_manager:
			var meta_key = ""
			var timing_text = ""

			if drop_timing == "immediate":
				meta_key = "orb_drop_immediate"
				timing_text = "斬擊結束立刻掉落"
			else:  # "end_turn" 或其他默認為回合結束
				meta_key = "orb_drop_end_turn"
				timing_text = "回合結束掉落"

			if not context.battle_manager.has_meta(meta_key):
				context.battle_manager.set_meta(meta_key, {})
			var drops = context.battle_manager.get_meta(meta_key)
			drops[element] = count
			context.battle_manager.set_meta(meta_key, drops)
			print("    ✓ %s %s x%d" % [timing_text, element_str, count])

	func _apply_extend_slash_time(effect: Dictionary, context: SkillContext):
		var extend_seconds = effect.get("extend_seconds", 0.0)

		# 將延長時間傳遞給 ElementPanel
		if context.battle_manager and extend_seconds > 0:
			var battle_scene = context.battle_manager.get_tree().current_scene
			if battle_scene and battle_scene.has_node("UI/ElementPanel"):
				var element_panel = battle_scene.get_node("UI/ElementPanel")
				if element_panel and element_panel.has_method("add_slash_time_bonus"):
					element_panel.add_slash_time_bonus(extend_seconds)
					print("    ✓ 延長斬擊時間 +%.1f秒" % extend_seconds)
				else:
					print("    ⚠️ ElementPanel 未實現 add_slash_time_bonus 方法")
			else:
				print("    ⚠️ 找不到 ElementPanel")

	func _apply_team_element_multiplier(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "FIRE")
		var base_mult = effect.get("base_multiplier", 1.0)
		var max_mult = effect.get("max_multiplier", 2.5)
		var per_member = effect.get("per_member_boost", 0.3)
		var element = _parse_element(element_str)

		var count = 0
		for card in context.battle_manager.player_team:
			if card.element == element:
				count += 1

		var actual_mult = min(base_mult + (count * per_member), max_mult)
		for card in context.battle_manager.player_team:
			if card.element == element:
				card.apply_multiplier("atk", actual_mult)

		print("    ✓ %s隊員倍率 x%.1f (%d人)" % [element_str, actual_mult, count])

	func _apply_team_diversity_multiplier(effect: Dictionary, context: SkillContext):
		var base_mult = effect.get("base_multiplier", 1.0)
		var max_mult = effect.get("max_multiplier", 2.0)
		var per_unique = effect.get("per_unique_boost", 0.2)

		var unique_elements = {}
		for card in context.battle_manager.player_team:
			unique_elements[card.element] = true

		var count = unique_elements.size()
		var actual_mult = min(base_mult + (count * per_unique), max_mult)

		for card in context.battle_manager.player_team:
			card.apply_multiplier("atk", actual_mult)

		print("    ✓ 多樣性倍率 x%.1f (%d種屬性)" % [actual_mult, count])

	func _apply_orb_count_multiplier(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "FIRE")
		var base_mult = effect.get("base_multiplier", 1.0)
		var max_mult = effect.get("max_multiplier", 3.0)
		var orb_per_tier = effect.get("orb_per_tier", 3)
		var element = _parse_element(element_str)

		# 只对匹配元素的攻击者应用倍率
		if not context.action_causer or context.action_causer.element != element:
			return

		# 获取储存的灵珠数量
		var stored_orbs = 0
		if context.battle_manager:
			stored_orbs = context.battle_manager.get_stored_orb_count(element)

		# 计算倍率：base + (stored_orbs / orb_per_tier) * (max - base)，最高 max
		var ratio = float(stored_orbs) / float(orb_per_tier) if orb_per_tier > 0 else 0.0
		var calc_mult = base_mult + ratio * (max_mult - base_mult)
		var actual_mult = min(calc_mult, max_mult)

		if actual_mult > 1.0:
			context.apply_damage_multiplier(actual_mult)
			print("    ✓ %s靈珠數量倍率 x%.2f (%d顆)" % [element_str, actual_mult, stored_orbs])

	func _apply_ignore_resistance(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "FIRE")
		var element = _parse_element(element_str)

		# 設置無視屬性克制標記
		if context.battle_manager:
			if not context.battle_manager.has_meta("ignore_resistance"):
				context.battle_manager.set_meta("ignore_resistance", [])
			var ignored = context.battle_manager.get_meta("ignore_resistance")
			if not element in ignored:
				ignored.append(element)
			context.battle_manager.set_meta("ignore_resistance", ignored)
			print("    ✓ %s無視屬性克制" % element_str)

	func _apply_orb_dual_effect(effect: Dictionary, context: SkillContext):
		var source_str = effect.get("source_element", "HEART")
		var target_str = effect.get("target_element", "FIRE")
		var effect_percent = effect.get("effect_percent", 50.0)
		var source = _parse_element(source_str)
		var target = _parse_element(target_str)

		# 存儲雙重效果規則
		if context.battle_manager:
			if not context.battle_manager.has_meta("orb_dual_effects"):
				context.battle_manager.set_meta("orb_dual_effects", {})
			var dual_effects = context.battle_manager.get_meta("orb_dual_effects")
			dual_effects[source] = {"target": target, "percent": effect_percent}
			context.battle_manager.set_meta("orb_dual_effects", dual_effects)
			print("    ✓ %s兼具%s %.0f%%效果" % [source_str, target_str, effect_percent])

	func _apply_orb_capacity_boost(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "WATER")
		var bonus_capacity = effect.get("bonus_capacity", 5)
		var element = _parse_element(element_str)

		# 修改靈珠容量上限
		if context.battle_manager:
			if not context.battle_manager.has_meta("orb_capacity_boost"):
				context.battle_manager.set_meta("orb_capacity_boost", {})
			var boosts = context.battle_manager.get_meta("orb_capacity_boost")
			boosts[element] = bonus_capacity
			context.battle_manager.set_meta("orb_capacity_boost", boosts)
			print("    ✓ %s容量+%d" % [element_str, bonus_capacity])

	func _apply_base_damage_boost(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "FIRE")
		var boost_percent = effect.get("boost_percent", 30.0)
		var element = _parse_element(element_str)

		# ✅ 基礎傷害提升：直接應用到卡牌的攻擊力倍率（PERMANENT效果）
		if context.battle_manager:
			var boost_multiplier = 1.0 + (boost_percent / 100.0)
			for card in context.battle_manager.player_team:
				if card.element == element:
					card.apply_multiplier("atk", boost_multiplier)
			print("    ✓ %s基礎傷害+%.0f%% (攻擊力倍率 x%.2f)" % [element_str, boost_percent, boost_multiplier])

	func _apply_all_damage_boost(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("target_element", "FIRE")
		var boost_percent = effect.get("boost_percent", 30.0)
		var element = _parse_element(element_str)

		# 全能傷害提升：包含主動技能等所有傷害類型
		if context.action_causer and context.action_causer.element == element:
			var boost_value = boost_percent / 100.0
			context.apply_damage_multiplier(1.0 + boost_value)
			print("    ✓ %s全能傷害+%.0f%%" % [element_str, boost_percent])

	func _apply_orb_drop_on_slash(effect: Dictionary, context: SkillContext):
		var slash_element_str = effect.get("slash_element", "HEART")  # 斬擊的屬性
		var drop_element_str = effect.get("drop_element", slash_element_str)  # 掉落的屬性（默認同斬擊屬性）
		var count = effect.get("count", 1)
		var chance_percent = effect.get("chance_percent", 100.0)
		var slash_element = _parse_element(slash_element_str)
		var drop_element = _parse_element(drop_element_str)

		# 存儲斬擊掉落規則（包含机率和掉落屬性）
		if context.battle_manager:
			if not context.battle_manager.has_meta("orb_drop_on_slash"):
				context.battle_manager.set_meta("orb_drop_on_slash", {})
			var drops = context.battle_manager.get_meta("orb_drop_on_slash")
			drops[slash_element] = {
				"drop_element": drop_element,
				"count": count,
				"chance_percent": chance_percent
			}
			context.battle_manager.set_meta("orb_drop_on_slash", drops)
			if slash_element == drop_element:
				if chance_percent < 100.0:
					print("    ✓ 斬擊%s時有%.0f%%機率掉落%s x%d" % [slash_element_str, chance_percent, drop_element_str, count])
				else:
					print("    ✓ 斬擊%s時掉落%s x%d" % [slash_element_str, drop_element_str, count])
			else:
				if chance_percent < 100.0:
					print("    ✓ 斬擊%s時有%.0f%%機率掉落%s x%d" % [slash_element_str, chance_percent, drop_element_str, count])
				else:
					print("    ✓ 斬擊%s時掉落%s x%d" % [slash_element_str, drop_element_str, count])

	func _apply_slash_orb_spawn(effect: Dictionary, context: SkillContext):
		var slash_element_str = effect.get("slash_element", "HEART")  # 斬擊的屬性
		var spawn_element_str = effect.get("spawn_element", slash_element_str)  # 生成的屬性（默認同斬擊屬性）
		var required_count = effect.get("required_count", 3)  # 累積所需數量
		var spawn_count = effect.get("spawn_count", 1)  # 生成數量
		var slash_element = _parse_element(slash_element_str)
		var spawn_element = _parse_element(spawn_element_str)

		# 存儲斬擊生成規則（包含生成屬性）
		if context.battle_manager:
			if not context.battle_manager.has_meta("slash_orb_spawn"):
				context.battle_manager.set_meta("slash_orb_spawn", {})
			var spawns = context.battle_manager.get_meta("slash_orb_spawn")
			spawns[slash_element] = {
				"spawn_element": spawn_element,
				"required_count": required_count,
				"spawn_count": spawn_count
			}
			context.battle_manager.set_meta("slash_orb_spawn", spawns)
			if slash_element == spawn_element:
				print("    ✓ 斬擊%s累積%d粒後生成%s x%d" % [slash_element_str, required_count, spawn_element_str, spawn_count])
			else:
				print("    ✓ 斬擊%s累積%d粒後生成%s x%d" % [slash_element_str, required_count, spawn_element_str, spawn_count])

	func _apply_end_turn_damage(effect: Dictionary, context: SkillContext):
		var element_str = effect.get("element", "FIRE")
		var damage = effect.get("damage", 500)
		var element = _parse_element(element_str)

		# ✅ 存儲 END_TURN_DAMAGE 配置，在斬擊結束時觸發
		if context.battle_manager:
			if not context.battle_manager.has_meta("end_turn_damage"):
				context.battle_manager.set_meta("end_turn_damage", [])
			var damage_configs = context.battle_manager.get_meta("end_turn_damage")
			damage_configs.append({
				"element": element,
				"damage": damage
			})
			context.battle_manager.set_meta("end_turn_damage", damage_configs)
			print("    ✓ 斬擊結束%s傷害 %d (對滿足攻擊條件的敵人)" % [element_str, damage])

	func _apply_combo_boost(effect: Dictionary, context: SkillContext):
		var combo_bonus = effect.get("combo_bonus", 5)

		# ✅ 存儲 COMBO_BOOST 配置（隊長技能版本 - 永久效果）
		if context.battle_manager:
			context.battle_manager.set_meta("leader_combo_boost", combo_bonus)
			print("    ✓ 連擊從%d開始計算（隊長技能）" % combo_bonus)

	func _parse_element(element_str: String) -> Constants.Element:
		match element_str.to_upper():
			"FIRE": return Constants.Element.FIRE
			"WATER": return Constants.Element.WATER
			"WOOD": return Constants.Element.WOOD
			"METAL": return Constants.Element.METAL
			"EARTH": return Constants.Element.EARTH
			"HEART": return Constants.Element.HEART
			_: return Constants.Element.FIRE

# ==================== 敵人技能系統 ====================

func create_active_skill_instance(skill_id: String):
	"""創建主動技能實例"""
	var skill_data = skill_system.get_active_skill(skill_id)
	if not skill_data:
		return null

	# 加載 ActiveSkill 腳本
	var active_skill_script = preload("res://scripts/skills/ActiveSkill.gd")
	var skill_instance = active_skill_script.new()
	skill_instance.init_from_json(skill_id, skill_data)
	return skill_instance

func create_enemy_skill_wrapper(skill_id: String):
	"""創建敵人技能的包裝對象"""
	var skill_data = skill_system.get_enemy_skill(skill_id)
	if not skill_data:
		return null

	var effects = skill_data.get("effects", [])
	var wrapper = EnemySkillWrapper.new()
	wrapper.init_from_json(skill_id, get_json_skill_info(skill_id), effects)
	return wrapper

# ==================== 敵人技能包裝類 ====================
class EnemySkillWrapper extends SkillBase:
	"""敵人技能的包裝類，繼承自SkillBase"""

	# 注意：skill_id 和 skill_name 已在 SkillBase 中定義，不需要重複聲明
	var json_effects: Array = []

	# 用於追蹤狀態的變量
	var status_data: Dictionary = {}  # 儲存技能狀態（如剩餘回合數、是否已觸發等）

	func init_from_json(id: String, info: Dictionary, effects: Array):
		skill_id = id
		skill_name = info.get("skill_name", "未知技能")
		skill_description = info.get("skill_description", "")  # ✅ 修正：使用 skill_description 而不是 description
		skill_description2 = info.get("skill_description2", skill_description)
		json_effects = effects

		# 設置觸發時機（敵人技能大多是被動永久或觸發時）
		trigger_timing = Constants.TriggerTiming.PERMANENT

		print("  [敵人技能] 初始化: %s (描述: %s)" % [skill_name, skill_description])

	func can_trigger(_context: SkillContext) -> bool:
		return true

	func is_condition_skill() -> bool:
		"""判斷是否為條件類技能（需要疊加）"""
		# 條件類技能：所有敵人的條件都需要滿足
		for effect in json_effects:
			var effect_type = effect.get("effect_type", "")
			match effect_type:
				"REQUIRE_COMBO", "REQUIRE_COMBO_EXACT", "REQUIRE_COMBO_MAX", \
				"REQUIRE_ORB_TOTAL", "REQUIRE_ORB_CONTINUOUS", "REQUIRE_ELEMENTS", \
				"REQUIRE_STORED_ORB_MIN", "REQUIRE_STORED_ORB_EXACT", \
				"REQUIRE_ENEMY_ATTACK", "DAMAGE_ONCE_ONLY":
					return true
		return false

	func execute(context: SkillContext):
		if not context:
			return

		print("  [敵人技能] 執行技能: %s" % skill_name)

		for effect in json_effects:
			_apply_enemy_effect(effect, context)

	func _apply_enemy_effect(effect: Dictionary, context: SkillContext):
		"""應用單個敵人技能效果"""
		var effect_type = effect.get("effect_type", "")

		match effect_type:
			# ========== 條件類（阻擋傷害） ==========
			"REQUIRE_COMBO":
				_apply_require_combo(effect, context)

			"REQUIRE_COMBO_EXACT":
				_apply_require_combo_exact(effect, context)

			"REQUIRE_COMBO_MAX":
				_apply_require_combo_max(effect, context)

			"REQUIRE_ORB_TOTAL":
				_apply_require_orb_total(effect, context)

			"REQUIRE_ORB_CONTINUOUS":
				_apply_require_orb_continuous(effect, context)

			"REQUIRE_ELEMENTS":
				_apply_require_elements(effect, context)

			"REQUIRE_STORED_ORB_MIN":
				_apply_require_stored_orb_min(effect, context)

			"REQUIRE_STORED_ORB_EXACT":
				_apply_require_stored_orb_exact(effect, context)

			"REQUIRE_ENEMY_ATTACK":
				_apply_require_enemy_attack(effect, context)

			# ========== 減傷類 ==========
			"DAMAGE_REDUCTION_PERCENT":
				_apply_damage_reduction_percent(effect, context)

			"DAMAGE_REDUCTION_FLAT":
				_apply_damage_reduction_flat(effect, context)

			"DAMAGE_ONCE_ONLY":
				_apply_damage_once_only(effect, context)

			# ========== 限制類 ==========
			"SEAL_ACTIVE_SKILL":
				_apply_seal_active_skill(effect, context)

			"DISABLE_ELEMENT_SLASH":
				_apply_disable_element_slash(effect, context)

			"ZERO_RECOVERY":
				_apply_zero_recovery(effect, context)

			"REDUCE_SLASH_TIME":
				_apply_reduce_slash_time(effect, context)

			# ========== 特殊類 ==========
			"ENTER_HP_TO_ONE":
				_apply_enter_hp_to_one(effect, context)

			"DEATH_DAMAGE":
				_apply_death_damage(effect, context)

			"REVIVE_ONCE":
				_apply_revive_once(effect, context)

	# ========== 效果實現 ==========

	func _apply_require_combo(effect: Dictionary, context: SkillContext):
		var required_combo = effect.get("required_combo", 10)
		# ✅ 將條件存儲在 battle_manager 的 meta 中，這樣可以在多次攻擊之間保持
		if context.battle_manager and context.caster:
			# 為每個敵人存儲條件
			# ✅ 使用絕對值避免負號，確保 meta key 是有效標識符
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			# ✅ 安全地獲取或創建數組
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing
			requirements.append({
				"type": "combo",
				"required_combo": required_combo,
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)
			print("    ✓ 需要%d連擊才能造成傷害" % required_combo)

	func _apply_require_orb_total(effect: Dictionary, context: SkillContext):
		var required_element_str = effect.get("required_element", "FIRE")
		var required_count = effect.get("required_count", 5)
		var element = _parse_element(required_element_str)

		# ✅ 將條件存儲在 battle_manager 的 meta 中
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			# ✅ 安全地獲取或創建數組
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing
			requirements.append({
				"type": "orb_total",
				"required_element": element,
				"required_count": required_count,
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)
			print("    ✓ 需要%d粒%s靈珠才能造成傷害" % [required_count, required_element_str])

	func _apply_require_orb_continuous(effect: Dictionary, context: SkillContext):
		var required_element_str = effect.get("required_element", "WATER")
		var required_count = effect.get("required_count", 3)
		var element = _parse_element(required_element_str)

		# ✅ 將條件存儲在 battle_manager 的 meta 中
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			# ✅ 安全地獲取或創建數組
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing
			requirements.append({
				"type": "orb_continuous",
				"required_element": element,
				"required_count": required_count,
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)
			print("    ✓ 需要連續%d粒%s靈珠才能造成傷害" % [required_count, required_element_str])

	func _apply_require_elements(effect: Dictionary, context: SkillContext):
		var required_unique = effect.get("required_unique_elements", 3)

		# ✅ 將條件存儲在 battle_manager 的 meta 中
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			# ✅ 安全地獲取或創建數組
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing
			requirements.append({
				"type": "unique_elements",
				"required_unique": required_unique,
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)
			print("    ✓ 需要%d種元素才能造成傷害" % required_unique)

	func _apply_require_combo_exact(effect: Dictionary, context: SkillContext):
		var required_combo = effect.get("required_combo", 10)
		# ✅ 將條件存儲在 battle_manager 的 meta 中
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing
			requirements.append({
				"type": "combo_exact",
				"required_combo": required_combo,
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)
			print("    ✓ 須保持連擊數 = %d 才能造成傷害" % required_combo)

	func _apply_require_combo_max(effect: Dictionary, context: SkillContext):
		var max_combo = effect.get("max_combo", 10)
		# ✅ 將條件存儲在 battle_manager 的 meta 中
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing
			requirements.append({
				"type": "combo_max",
				"max_combo": max_combo,
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)
			print("    ✓ 連擊數不可高於 %d 否則無法造成傷害" % max_combo)

	func _apply_require_stored_orb_min(effect: Dictionary, context: SkillContext):
		var requirements_list = effect.get("requirements", [])  # [{element: "FIRE", count: 3}, {element: "WATER", count: 2}]

		# ✅ 將條件存儲在 battle_manager 的 meta 中
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing

			var orb_requirements = []
			for req in requirements_list:
				var element_str = req.get("element", "FIRE")
				var count = req.get("count", 0)
				var element = _parse_element(element_str)
				orb_requirements.append({"element": element, "count": count})

			requirements.append({
				"type": "stored_orb_min",
				"orb_requirements": orb_requirements,
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)

			var desc = ""
			for req in orb_requirements:
				var element_name = Constants.Element.keys()[req["element"]]
				desc += "%s%d顆 " % [element_name, req["count"]]
			print("    ✓ 需儲存靈珠達到 %s(含以上) 才能造成傷害" % desc)

	func _apply_require_stored_orb_exact(effect: Dictionary, context: SkillContext):
		var requirements_list = effect.get("requirements", [])  # [{element: "FIRE", count: 3}, {element: "WATER", count: 2}]

		# ✅ 將條件存儲在 battle_manager 的 meta 中
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing

			var orb_requirements = []
			for req in requirements_list:
				var element_str = req.get("element", "FIRE")
				var count = req.get("count", 0)
				var element = _parse_element(element_str)
				orb_requirements.append({"element": element, "count": count})

			requirements.append({
				"type": "stored_orb_exact",
				"orb_requirements": orb_requirements,
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)

			var desc = ""
			for req in orb_requirements:
				var element_name = Constants.Element.keys()[req["element"]]
				desc += "%s%d顆 " % [element_name, req["count"]]
			print("    ✓ 需儲存靈珠完全達到 %s才能造成傷害" % desc)

	func _apply_require_enemy_attack(_effect: Dictionary, context: SkillContext):
		# ✅ 將條件存儲在 battle_manager 的 meta 中（這個條件可以繼承回合）
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing
			requirements.append({
				"type": "enemy_attack",
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)
			print("    ✓ 敵人必須先攻擊才能造成傷害（條件可繼承回合）")

	func _apply_damage_once_only(_effect: Dictionary, context: SkillContext):
		# ✅ 將條件存儲在 battle_manager 的 meta 中
		if context.battle_manager and context.caster:
			var instance_id = abs(context.caster.get_instance_id())
			var meta_key = "enemy_dmg_req_%d" % instance_id
			var requirements = []
			if context.battle_manager.has_meta(meta_key):
				var existing = context.battle_manager.get_meta(meta_key)
				if existing != null:
					requirements = existing
			requirements.append({
				"type": "damage_once_only",
				"skill_name": skill_name
			})
			context.battle_manager.set_meta(meta_key, requirements)
			print("    ✓ 敵人只會被攻擊一次，第二次以後無法造成傷害")

	func _apply_damage_reduction_percent(effect: Dictionary, context: SkillContext):
		var reduction_percent = effect.get("reduction_percent", 50.0)

		# 在受到傷害時減少傷害
		if context.damage > 0:
			var reduction = context.damage * (reduction_percent / 100.0)
			context.damage -= int(reduction)
			print("    ✓ 減傷%.0f%% (減少%d點傷害)" % [reduction_percent, int(reduction)])

	func _apply_damage_reduction_flat(effect: Dictionary, context: SkillContext):
		var reduction_amount = effect.get("reduction_amount", 100)

		# 在受到傷害時減少固定傷害
		if context.damage > 0:
			context.damage = max(0, context.damage - reduction_amount)
			print("    ✓ 減傷%d點 (固定)" % reduction_amount)

	func _apply_seal_active_skill(effect: Dictionary, context: SkillContext):
		var duration = effect.get("duration", 3)

		# 封印玩家主動技能 - 在 battle_manager 中添加狀態
		if context.battle_manager:
			if not context.battle_manager.has_meta("active_skill_sealed"):
				context.battle_manager.set_meta("active_skill_sealed", 0)
			context.battle_manager.set_meta("active_skill_sealed", duration)
			print("    ✓ 封印主動技能%d回合" % duration)

	func _apply_disable_element_slash(effect: Dictionary, context: SkillContext):
		var target_element_str = effect.get("target_element", "FIRE")
		var duration = effect.get("duration", 2)
		var element = _parse_element(target_element_str)

		# 禁用特定元素斬擊 - 在 battle_manager 中添加狀態
		if context.battle_manager:
			if not context.battle_manager.has_meta("disabled_elements"):
				context.battle_manager.set_meta("disabled_elements", {})
			var disabled = context.battle_manager.get_meta("disabled_elements")
			disabled[element] = duration
			context.battle_manager.set_meta("disabled_elements", disabled)
			print("    ✓ 禁用%s斬擊%d回合" % [target_element_str, duration])

	func _apply_zero_recovery(effect: Dictionary, context: SkillContext):
		var duration = effect.get("duration", 2)

		# 使回復力歸零 - 在 battle_manager 中添加狀態
		if context.battle_manager:
			if not context.battle_manager.has_meta("zero_recovery"):
				context.battle_manager.set_meta("zero_recovery", 0)
			context.battle_manager.set_meta("zero_recovery", duration)
			print("    ✓ 回復力歸零%d回合" % duration)

	func _apply_reduce_slash_time(effect: Dictionary, context: SkillContext):
		var reduce_seconds = effect.get("reduce_seconds", 2.0)

		# 減少斬擊時間
		if context.battle_manager:
			var battle_scene = context.battle_manager.get_tree().current_scene
			if battle_scene and battle_scene.has_node("UI/ElementPanel"):
				var element_panel = battle_scene.get_node("UI/ElementPanel")
				if element_panel and element_panel.has_method("reduce_slash_time"):
					element_panel.reduce_slash_time(reduce_seconds)
					print("    ✓ 減少斬擊時間%.1f秒" % reduce_seconds)
				else:
					print("    ⚠️ ElementPanel 未實現 reduce_slash_time 方法")
			else:
				print("    ⚠️ 找不到 ElementPanel")

	func _apply_enter_hp_to_one(_effect: Dictionary, context: SkillContext):
		# 進場時生命力扣至1
		if context.battle_manager:
			context.battle_manager.player_current_hp = 1
			print("    ✓ 進場時玩家生命力扣至1")

	func _apply_death_damage(effect: Dictionary, context: SkillContext):
		var damage = effect.get("damage", 1000)

		# 死亡時造成傷害（需要在敵人死亡時觸發）
		if context.battle_manager:
			context.battle_manager.deal_damage_to_player(damage)
			print("    ✓ 死亡時對玩家造成%d點傷害" % damage)

	func _apply_revive_once(_effect: Dictionary, context: SkillContext):
		# 復活一次
		if context.battle_manager:
			if not status_data.get("has_revived", false):
				print("    ✓ 可以復活一次 (待實現)")
				status_data["has_revived"] = true
			else:
				print("    ✓ 已經復活過了")

	func _parse_element(element_str: String) -> Constants.Element:
		match element_str.to_upper():
			"FIRE": return Constants.Element.FIRE
			"WATER": return Constants.Element.WATER
			"WOOD": return Constants.Element.WOOD
			"METAL": return Constants.Element.METAL
			"EARTH": return Constants.Element.EARTH
			"HEART": return Constants.Element.HEART
			_: return Constants.Element.FIRE
