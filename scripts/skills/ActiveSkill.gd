# ActiveSkill.gd
# 主動技能系統 - 玩家卡片可發動的技能
class_name ActiveSkill
extends SkillBase

# ==================== 主動技能屬性 ====================
# 注意：target_type 已在 SkillBase 中定義，不需要重複聲明
@export var skill_cost: int = 10  # 技能CD（回合數）
@export var duration: int = 1  # 持續回合數（0=瞬發，1=持續1回合，以此類推）

var current_cd: int = 0  # 當前CD計數（0=可用，>0=冷卻中）

# 技能效果配置（可複用 LeaderSkillEffectType）
var effects: Array[Dictionary] = []  # [{"type": "DAMAGE_MULTIPLIER", "multiplier": 2.0, ...}, ...]

# ==================== 初始化 ====================
func _init():
	# 注意：SkillBase 繼承自 RefCounted，不需要調用 super._init()
	trigger_timing = Constants.TriggerTiming.MANUAL  # 主動技能需要手動觸發
	skill_type = Constants.SkillType.ACTIVE  # 設置技能類型為主動技能

func init_from_json(id: String, info: Dictionary):
	"""從 JSON 初始化主動技能"""
	skill_id = id
	skill_name = info.get("skill_name", "未知主動技能")
	skill_description = info.get("description", "")
	skill_cost = info.get("skill_cost", 10)
	duration = info.get("duration", 1)

	# 將字符串轉換為枚舉類型
	var target_type_str = info.get("target_type", "SELF")
	match target_type_str:
		"SELF":
			target_type = Constants.TargetType.SELF
		"SINGLE_ENEMY":
			target_type = Constants.TargetType.SINGLE_ENEMY
		"ALL_ENEMIES":
			target_type = Constants.TargetType.ALL_ENEMIES
		"SINGLE_ALLY":
			target_type = Constants.TargetType.SINGLE_ALLY
		"ALL_ALLIES":
			target_type = Constants.TargetType.ALL_ALLIES
		"RANDOM_ENEMY":
			target_type = Constants.TargetType.RANDOM_ENEMY
		_:
			target_type = Constants.TargetType.SELF

	# 讀取效果列表
	if info.has("effects"):
		for effect_data in info.get("effects", []):
			effects.append(effect_data)

	current_cd = 0  # 初始可用

# ==================== 技能系統 ====================
func can_use() -> bool:
	"""檢查技能是否可用"""
	# CD 由 CardData 管理，這裡總是返回 true
	# 實際檢查在 CardData.can_use_active_skill() 中進行
	return true

func use_skill(context: SkillContext) -> bool:
	"""使用技能"""
	print("\n🔥 [主動技能] 發動: %s" % skill_name)

	# 應用技能效果
	var success = apply_effects(context)

	if success:
		print("  [主動技能] %s 效果已應用" % skill_name)
		# 注意：CD 由 BattleManager 調用 CardData.use_active_skill() 來管理

	return success

func apply_effects(context: SkillContext) -> bool:
	"""應用技能效果"""
	if effects.is_empty():
		print("  [主動技能] %s 沒有配置效果" % skill_name)
		return false

	# 創建 Buff 數據並存儲到 BattleManager
	if not context.battle_manager:
		return false

	# 獲取或創建 active_skill_buffs 陣列
	if not context.battle_manager.has_meta("active_skill_buffs"):
		context.battle_manager.set_meta("active_skill_buffs", [])

	var buffs = context.battle_manager.get_meta("active_skill_buffs")

	# 為每個效果創建 buff 實例或立即應用
	for effect in effects:
		var effect_type = effect.get("effect_type", "")

		# 處理元素專屬傷害倍率（ELEMENT_DAMAGE_BOOST + 元素名）
		if effect_type == "ELEMENT_DAMAGE_BOOST" and effect.has("element"):
			effect_type = "ELEMENT_DAMAGE_BOOST_%s" % effect.get("element", "FIRE")

		# 瞬發技能（duration = 0）需要立即應用
		if duration == 0:
			apply_instant_effect(effect_type, effect, context)
			continue

		# 獲取目標範圍（從effect_data或使用技能的target_type）
		var target_scope = effect.get("target_scope", "")
		if target_scope.is_empty():
			# 向後兼容：如果沒有target_scope，根據target_type推斷
			if target_type == Constants.TargetType.SELF:
				target_scope = "SELF"
			elif target_type == Constants.TargetType.ALL_ALLIES:
				target_scope = "ALL_ALLIES"
			else:
				target_scope = "ALL_ALLIES"  # 默認全隊

		# 持續型技能創建 Buff
		var buff_data = {
			"skill_id": skill_id,
			"skill_name": skill_name,
			"effect_type": effect_type,
			"effect_data": effect.duplicate(),
			"remaining_turns": duration,
			"target_type": target_type,  # 保留向後兼容
			"target_scope": target_scope,  # 新增：影響範圍
			"caster_instance_id": context.caster.instance_id if context.caster else "",  # 發動技能的卡片
			"affected_cards": []  # 用於 BASE_STAT_BOOST 記錄被影響的卡片
		}

		# 根據效果類型立即應用或創建持續BUFF
		if effect_type == "BASE_STAT_BOOST":
			# 基礎數值提升：立即修改卡片屬性並記錄原始值
			apply_base_stat_boost(buff_data, context)
			buffs.append(buff_data)
			print("  ✓ 新增 BASE_STAT_BOOST Buff: %s (持續 %d 回合)" % [skill_name, duration])
		else:
			# 其他效果類型：創建BUFF（在使用時計算）
			buffs.append(buff_data)
			print("  ✓ 新增 Buff: %s (持續 %d 回合)" % [skill_name, duration])

	context.battle_manager.set_meta("active_skill_buffs", buffs)
	return true

func apply_instant_effect(effect_type: String, effect: Dictionary, context: SkillContext):
	"""立即應用瞬發效果"""
	match effect_type:
		"EXTEND_SLASH_TIME":
			# 延長斬擊時間
			var extend_seconds = effect.get("extend_seconds", 0.0)
			if context.battle_manager and extend_seconds > 0:
				var battle_scene = context.battle_manager.get_tree().current_scene
				if battle_scene and battle_scene.has_node("UI/ElementPanel"):
					var element_panel = battle_scene.get_node("UI/ElementPanel")
					if element_panel and element_panel.has_method("add_slash_time_bonus"):
						element_panel.add_slash_time_bonus(extend_seconds)
						print("  ✓ 立即延長斬擊時間 +%.1f 秒" % extend_seconds)
		_:
			print("  ⚠️ 未知的瞬發效果類型: %s" % effect_type)

func tick_cooldown():
	"""每回合更新 CD（已由 CardData.reduce_skill_cd 管理）"""
	# 此方法保留以保持接口一致性，但實際 CD 管理在 CardData 中
	pass

func reset_cooldown():
	"""重置 CD（已由 CardData 管理）"""
	# 此方法保留以保持接口一致性，但實際 CD 管理在 CardData 中
	pass

# ==================== 觸發方法（繼承 SkillBase）====================
func execute(context: SkillContext):
	"""執行技能（繼承自 SkillBase）"""
	use_skill(context)

func apply_effect(context: SkillContext) -> bool:
	"""當被手動觸發時調用"""
	return use_skill(context)

# ==================== BASE_STAT_BOOST 相關方法 ====================

func apply_base_stat_boost(buff_data: Dictionary, context: SkillContext):
	"""應用基礎數值提升BUFF
	立即修改符合條件的卡片屬性，並記錄原始值到buff_data.affected_cards
	"""
	var effect_data = buff_data["effect_data"]
	var target_scope = buff_data["target_scope"]
	var caster_instance_id = buff_data["caster_instance_id"]

	# 獲取目標卡片列表
	var target_cards = get_target_cards(target_scope, caster_instance_id, context)

	# 應用到符合條件的卡片
	for card in target_cards:
		if match_card_criteria(card, effect_data):
			# 記錄原始值
			var original_data = {
				"instance_id": card.instance_id,
				"original_base_atk": card.base_atk,
				"original_base_hp": card.base_hp,
				"original_base_recovery": card.base_recovery
			}

			# 應用提升
			var target_stat = effect_data.get("target_stat", "base_atk")
			var boost_percent = effect_data.get("boost_percent", 0.0)

			match target_stat:
				"base_atk":
					var boost_value = int(card.base_atk * boost_percent / 100.0)
					card.base_atk += boost_value
					print("    [BASE_STAT_BOOST] %s 攻擊力 %d -> %d (+%d%%)" % [card.card_name, original_data["original_base_atk"], card.base_atk, boost_percent])
				"base_hp":
					var boost_value = int(card.base_hp * boost_percent / 100.0)
					card.base_hp += boost_value
					print("    [BASE_STAT_BOOST] %s 血量 %d -> %d (+%d%%)" % [card.card_name, original_data["original_base_hp"], card.base_hp, boost_percent])
				"base_recovery":
					var boost_value = int(card.base_recovery * boost_percent / 100.0)
					card.base_recovery += boost_value
					print("    [BASE_STAT_BOOST] %s 回復力 %d -> %d (+%d%%)" % [card.card_name, original_data["original_base_recovery"], card.base_recovery, boost_percent])

			# 更新當前屬性（重新計算）
			card.calculate_final_stats()

			# 記錄到buff的affected_cards
			buff_data["affected_cards"].append(original_data)

			# 觸發UI更新（通過BattleManager的信號）
			if context.battle_manager:
				# 查找對應的BattleCard並更新顯示
				var battle_scene = context.battle_manager.get_tree().current_scene
				if battle_scene and battle_scene.has_method("update_card_display"):
					battle_scene.update_card_display(card)

func get_target_cards(target_scope: String, caster_instance_id: String, context: SkillContext) -> Array:
	"""獲取目標卡片列表"""
	var target_cards = []

	match target_scope:
		"SELF":
			# 只影響發動者自己
			for card in context.battle_manager.player_team:
				if card.instance_id == caster_instance_id:
					target_cards.append(card)
					break
		"ALL_ALLIES":
			# 影響全隊
			target_cards = context.battle_manager.player_team.duplicate()
		_:
			# 默認全隊
			target_cards = context.battle_manager.player_team.duplicate()

	return target_cards

func match_card_criteria(card: CardData, effect_data: Dictionary) -> bool:
	"""判斷卡片是否符合篩選條件
	支持的篩選條件：
	- target_element: 元素類型（FIRE, WATER, WOOD, METAL, EARTH）
	- target_rarity: 稀有度（R, SR, SSR）
	- target_card_ids: 特定卡片ID陣列
	"""
	# 元素篩選
	if effect_data.has("target_element"):
		var target_element_str = effect_data["target_element"]
		var target_element = Constants.Element.FIRE

		match target_element_str.to_upper():
			"FIRE": target_element = Constants.Element.FIRE
			"WATER": target_element = Constants.Element.WATER
			"WOOD": target_element = Constants.Element.WOOD
			"METAL": target_element = Constants.Element.METAL
			"EARTH": target_element = Constants.Element.EARTH

		if card.element != target_element:
			return false

	# 稀有度篩選
	if effect_data.has("target_rarity"):
		var target_rarity_str = effect_data["target_rarity"]
		var target_rarity = Constants.CardRarity.COMMON

		match target_rarity_str.to_upper():
			"R", "COMMON": target_rarity = Constants.CardRarity.COMMON
			"SR", "RARE": target_rarity = Constants.CardRarity.RARE
			"SSR", "LEGENDARY": target_rarity = Constants.CardRarity.LEGENDARY

		if card.rarity != target_rarity:
			return false

	# 特定卡片ID篩選
	if effect_data.has("target_card_ids"):
		var target_ids = effect_data["target_card_ids"]
		if not card.card_id in target_ids:
			return false

	return true

static func restore_base_stats(buff_data: Dictionary, battle_manager: BattleManager):
	"""恢復卡片原始屬性（靜態方法，供BattleManager調用）"""
	var affected_cards = buff_data.get("affected_cards", [])

	for card_data in affected_cards:
		var instance_id = card_data["instance_id"]

		# 在player_team中找到對應的卡片
		for card in battle_manager.player_team:
			if card.instance_id == instance_id:
				# 恢復原始值
				card.base_atk = card_data["original_base_atk"]
				card.base_hp = card_data["original_base_hp"]
				card.base_recovery = card_data["original_base_recovery"]

				# 重新計算當前屬性
				card.calculate_final_stats()

				print("    [BASE_STAT_BOOST] 恢復 %s 原始屬性 (攻:%d, 血:%d, 回:%d)" % [
					card.card_name,
					card.base_atk,
					card.base_hp,
					card.base_recovery
				])

				# 觸發UI更新
				var battle_scene = battle_manager.get_tree().current_scene
				if battle_scene and battle_scene.has_method("update_card_display"):
					battle_scene.update_card_display(card)

				break
