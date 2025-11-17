# ElementPanel.gd
# 元素面板 - 管理元素珠子的生成、消除和傷害計算
class_name ElementPanel
extends Control

# ==================== 信號 ====================
signal orb_eliminated(element: Constants.Element, combo_count: int, eliminate_count: int)
signal combo_finished(total_damage: int)
signal healing_phase_finished(heal_amount: int)
signal slashing_started # ✅ 新增：斬擊開始信號
signal slashing_ended   # ✅ 新增：斬擊結束信號
signal slashing_phase_finished(multipliers: Dictionary)
var element_multipliers: Dictionary = {}
signal multipliers_updated(multipliers: Dictionary)

# ✅ 新增信號：(靈珠元素, 是否來自玩家序列)
signal orb_dropped(element: Constants.Element, is_player_sequence: bool)

# ==================== 引用 ====================
# ✅✅✅ 修正：將 battle_manager 宣告加回來 ✅✅✅
var battle_manager: BattleManager = null

# ==================== UI 組件 ====================
@onready var orb_container = $OrbContainer  # GridContainer
@onready var combo_label = $ComboLabel  # 顯示連擊數
# ===== Combo 特效相關（Godot 4 專用） =====
var combo_fx_tween: Tween        # 縮放 / 亮度特效
var combo_color_tween: Tween     # 顏色漸變特效
var combo_color: Color = Color.WHITE:
	set(value):
		combo_color = value
		if combo_label:
			# Godot 4：用 theme override 來改字體顏色
			combo_label.add_theme_color_override("font_color", value)
@onready var damage_preview_label = $DamagePreviewLabel  # 預覽傷害
@onready var countdown_bar = $CountdownBar # 
# ==================== 元素珠子 ====================
var orb_scene = preload("res://scenes/battle/ui_components/ElementOrb.tscn")
var current_orb: ElementOrb = null  # 當前需要消除的珠子
var orb_queue: Array[Dictionary] = []  # 待生成的珠子隊列

# ==================== 戰鬥數據 ====================
var combo_count: int = 0  # 連擊數
var eliminate_counts: Dictionary = {}  # 每種元素的消除次數 {Element: int}
var is_combo_active: bool = false # 是否正在連擊中
var combo_timeout_timer: Timer = null
var slash_timer: Timer = null #
var can_start_slashing: bool = true #

# ==================== 條件型技能追蹤 ====================
var orb_totals: Dictionary = {}  # 累積消除的靈珠數 {Element: count}
var last_eliminated_element: int = -1  # 上一次消除的元素
var continuous_count: int = 0  # 當前連續消除計數
var unique_elements: Array = []  # 消除過的屬性種類 
const OWN_ELEMENT_BONUS = 0.25  #  基礎消除倍率 125%
const OTHER_ELEMENT_BONUS = 0.05 #  其他消除倍率 105%
const COMBO_MULTIPLIER_PER_HIT = 0.10 # 每次連擊增加 10%
# 用於儲存技能效果
var orb_rules: Dictionary = {}
var leader_bonus_config: Dictionary = {}
var leader_extra_drop_counter: int = 0
var leader_bonus_element: int = -1

# (移除 is_first_spawn_of_turn 和 force_count_remaining)

# 新增靈珠累積計數器 (用於 3 換 1 保底)
var slash_accumulators: Dictionary = {
	Constants.Element.METAL: 0,
	Constants.Element.WOOD: 0,
	Constants.Element.WATER: 0,
	Constants.Element.FIRE: 0,
	Constants.Element.EARTH: 0,
	Constants.Element.HEART: 0
}

# 斬擊時間加成/減少
var slash_time_bonus: float = 0.0
var slash_time_penalty: float = 0.0

const COMBO_TIMEOUT: float = 1  # 連擊超時時間（秒）
const SLASH_DURATION: float = 5.0 # 

# 元素與方向的映射
var element_direction_map = {
	Constants.Element.METAL: Constants.SwipeDirection.DOWN,
	Constants.Element.WOOD: Constants.SwipeDirection.RIGHT,
	Constants.Element.WATER: Constants.SwipeDirection.UP,
	Constants.Element.FIRE: Constants.SwipeDirection.LEFT,
	Constants.Element.EARTH: Constants.SwipeDirection.DIAGONAL_DOWN_RIGHT,
	Constants.Element.HEART: Constants.SwipeDirection.TAP
}

# 
var is_swiping: bool = false
var swipe_start_pos: Vector2 = Vector2.ZERO
var swipe_positions: Array[Vector2] = []
const SWIPE_MIN_DISTANCE: float = 20.0  # 
const DIAGONAL_ANGLE_TOLERANCE: float = 30.0 # 
# ==================== 初始化 ====================

func _ready():
	# 創建超時計時器
	combo_timeout_timer = Timer.new()
	add_child(combo_timeout_timer)
	combo_timeout_timer.one_shot = true
	combo_timeout_timer.timeout.connect(_on_combo_timeout)

	# 
	slash_timer = Timer.new()
	add_child(slash_timer)
	slash_timer.one_shot = true
	slash_timer.timeout.connect(_on_slash_timeout) # 
	
	update_ui()
	countdown_bar.visible = false # 
# 
func _process(_delta):
	if not slash_timer.is_stopped():
		countdown_bar.value = slash_timer.time_left

# ==================== 輸入處理 (新) ====================
func _gui_input(event: InputEvent):
	# (此函數保持不變)
	if not can_start_slashing and is_combo_active == false:
		return
	if not current_orb:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_swiping = true
				swipe_start_pos = event.position
				swipe_positions.clear()
				swipe_positions.append(event.position)
			else:
				if is_swiping:
					var swipe_end_pos = event.position
					check_swipe(swipe_start_pos, swipe_end_pos)
					is_swiping = false
	
	elif event is InputEventMouseMotion and is_swiping:
		swipe_positions.append(event.position)

# ==================== 滑動檢測 (新) ====================
func check_swipe(start_pos: Vector2, end_pos: Vector2):
	# (此函數保持不變)
	if not current_orb: return

	var swipe_vector = end_pos - start_pos
	var distance = swipe_vector.length()

	var detected_direction: Constants.SwipeDirection
	var required_direction = current_orb.required_direction

	if distance < SWIPE_MIN_DISTANCE:
		detected_direction = Constants.SwipeDirection.TAP
	else:
		detected_direction = detect_swipe_direction(start_pos, end_pos)

	if detected_direction == required_direction:
		current_orb.play_success_effect()
		_on_orb_swiped(current_orb.element, detected_direction, end_pos)
	else:
		current_orb.play_fail_effect()

func detect_swipe_direction(start_pos: Vector2, end_pos: Vector2) -> Constants.SwipeDirection:
	# (此函數保持不變)
	var swipe_vector = end_pos - start_pos
	var angle = rad_to_deg(swipe_vector.angle())

	while angle > 180:
		angle -= 360
	while angle < -180:
		angle += 360

	if abs(angle - 45) < DIAGONAL_ANGLE_TOLERANCE:
		return Constants.SwipeDirection.DIAGONAL_DOWN_RIGHT

	if abs(angle) < 45:  # 向右
		return Constants.SwipeDirection.RIGHT
	elif abs(angle - 90) < 45:  # 向下
		return Constants.SwipeDirection.DOWN
	elif abs(angle + 90) < 45:  # 向上
		return Constants.SwipeDirection.UP
	else:  # 向左
		return Constants.SwipeDirection.LEFT

func get_random_element_with_modified_rates() -> Constants.Element:
	# (此函數保持不變)
	var elements = [
		Constants.Element.METAL, Constants.Element.WOOD,
		Constants.Element.WATER, Constants.Element.FIRE,
		Constants.Element.EARTH, Constants.Element.HEART
	]
	
	var bonus_element = orb_rules.get("bonus_element", null)
	var bonus_rate = orb_rules.get("bonus_rate", 0.0)
	
	if bonus_element == null or bonus_rate == 0.0:
		return elements[randi() % elements.size()]

	var base_weight = 1.0 / 6.0
	var boosted_weight = base_weight * (1.0 + bonus_rate)
	
	var remaining_weight = 1.0 - boosted_weight
	var other_weight = remaining_weight / 5.0
	
	var weights = {}
	for el in elements:
		if el == bonus_element:
			weights[el] = boosted_weight
		else:
			weights[el] = other_weight
	
	var roll = randf()
	var cumulative_weight = 0.0
	
	for el in elements:
		cumulative_weight += weights[el]
		if roll < cumulative_weight:
			return el
	
	return elements[0] # 備用

func is_circle_gesture() -> bool:
	# (此函數保持不變)
	if swipe_positions.size() < 10:
		return false
	var center = size / 2
	var quadrants = {1: false, 2: false, 3: false, 4: false}
	for pos in swipe_positions:
		var relative = pos - center
		if relative.x >= 0 and relative.y >= 0:
			quadrants[1] = true
		elif relative.x < 0 and relative.y >= 0:
			quadrants[2] = true
		elif relative.x < 0 and relative.y < 0:
			quadrants[3] = true
		else:
			quadrants[4] = true
	var covered_quadrants = 0
	for visited in quadrants.values():
		if visited:
			covered_quadrants += 1
	return covered_quadrants >= 3
# ==================== (以上是新加入的) ====================

func setup(battle_mgr: BattleManager):
	"""設置戰鬥管理器"""
	battle_manager = battle_mgr
	# 重置斬擊時間修正值（新戰鬥開始時）
	reset_slash_time_modifiers()

# ==================== 珠子生成 ====================

func spawn_next_orb():
	"""(最終版) 生成下一顆元素珠子 (只處理序列)"""
	# 清除舊珠子
	if current_orb:
		current_orb.queue_free()
		current_orb = null

	if not is_combo_active:
		return
		
	var generated_element: Constants.Element
	var is_player_sequence = false # 預設為 false (隨機或技能珠)

	# 1. (最高優先級) 檢查「疊加後」的序列
	if orb_rules.has("orb_sequence") and not orb_rules.orb_sequence.is_empty():
		
		# LIFO (先點後出現)，所以用 pop_back()
		var orb_data = orb_rules.orb_sequence.pop_front()
		
		generated_element = orb_data.element
		is_player_sequence = orb_data.is_player_sequence # (來自 BattleScene 的標記)
		
	else:
		# 2. (最低優先級) 隨機生成 (包含 bonus_rate)
		generated_element = get_random_element_with_modified_rates()
		is_player_sequence = false # 隨機珠

	var required_direction = element_direction_map[generated_element]

	# 創建珠子
	current_orb = orb_scene.instantiate()
	orb_container.add_child(current_orb)
	current_orb.setup(generated_element, required_direction)
	current_orb.set_active(true)

	# (重要) 將 "is_player_sequence" 狀態附加到珠子上
	current_orb.set_meta("is_player_sequence", is_player_sequence)

	# print("生成元素珠子: %s (來自玩家排版: %s)" % [
	# 	Constants.Element.keys()[generated_element],
	# 	is_player_sequence
	# ])

# ==================== 消除處理 ====================

func _on_orb_swiped(element: Constants.Element, _swipe_direction: Constants.SwipeDirection, swipe_end_pos: Vector2):
	print("🔔🔔🔔 [ElementPanel._on_orb_swiped] 函數被調用！元素: %s, can_start_slashing: %s, is_combo_active: %s" % [Constants.Element.keys()[element], can_start_slashing, is_combo_active])
	if can_start_slashing:
		can_start_slashing = false
		is_combo_active = true
		combo_count = 0

		# ✅ 重置斬擊結束標記（新斬擊開始，允許使用 END_TURN_DAMAGE 技能）
		if battle_manager:
			battle_manager.slash_ended = false
			battle_manager.set_meta("current_combo", combo_count)

			# ✅ 重置條件型技能追蹤數據
			battle_manager.set_meta("current_orb_totals", {})
			battle_manager.set_meta("current_continuous_element", -1)
			battle_manager.set_meta("current_continuous_count", 0)
			battle_manager.set_meta("current_unique_elements", [])

		eliminate_counts.clear()

		# ✅ 重置本地條件追蹤
		orb_totals.clear()
		last_eliminated_element = -1
		continuous_count = 0
		unique_elements.clear()

		# 重置保底計數器
		slash_accumulators = {
			Constants.Element.METAL: 0, Constants.Element.WOOD: 0,
			Constants.Element.WATER: 0, Constants.Element.FIRE: 0,
			Constants.Element.EARTH: 0, Constants.Element.HEART: 0
		}

		# ✅ 重置斬擊時間修正值（每次斬擊開始時重置）
		# 注意：不在這裡重置，因為敵人技能是戰鬥開始時應用的
		# slash_time_bonus 和 slash_time_penalty 應該在戰鬥結束時清除

		# 計算實際斬擊時間（基礎時間 + 加成 - 減少）
		var actual_slash_time = SLASH_DURATION + slash_time_bonus - slash_time_penalty
		actual_slash_time = max(1.0, actual_slash_time)  # 至少1秒

		slash_timer.start(actual_slash_time)
		countdown_bar.max_value = actual_slash_time
		countdown_bar.value = actual_slash_time
		countdown_bar.visible = true
		slashing_started.emit() # ✅ 新增：發出斬擊開始信號
		print("--- 斬擊計時開始: %.1f秒 (基礎%.1f + 加成%.1f - 減少%.1f) ---" % [actual_slash_time, SLASH_DURATION, slash_time_bonus, slash_time_penalty])

	if not is_combo_active:
		return

	combo_count += 1
	if not eliminate_counts.has(element):
		eliminate_counts[element] = 0
	eliminate_counts[element] += 1

	print("🎯🎯🎯 [ElementPanel._on_orb_swiped] 消除 %s 珠！當前連擊: %d" % [Constants.Element.keys()[element], combo_count])
	# ⬇️ ========== 在這裡加上特效 ========== ⬇️
	if current_orb and is_instance_valid(current_orb):
		# `swipe_end_pos` 是 ElementPanel 內的局部座標
		# 我們需要用 `get_global_transform().xform()` 把它轉換成全局座標
		var global_spawn_pos = get_global_transform() * swipe_end_pos
		var effect_instance = VFXManager.play_effect("slash", global_spawn_pos, self)
		if effect_instance:
			effect_instance.z_index = 10
			
			# ⬇️ ========== 根據滑動方向設定斬擊角度 ========== ⬇️
			var slash_angle_rad = 0.0 # 預設角度 (0度 = 水平)
			match _swipe_direction:
				Constants.SwipeDirection.UP, Constants.SwipeDirection.DOWN:
					# 垂直斬擊
					slash_angle_rad = deg_to_rad(90.0)
				Constants.SwipeDirection.DIAGONAL_DOWN_RIGHT:
					# 45度斜斬
					slash_angle_rad = deg_to_rad(45.0)
				Constants.SwipeDirection.TAP, Constants.SwipeDirection.CIRCLE:
					# 點擊或畫圈，給一個隨機角度 (增加華麗感)
					slash_angle_rad = deg_to_rad(randf_range(0.0, 90.0))
				_: 
					# LEFT 或 RIGHT，保持 0 度水平
					slash_angle_rad = 0.0
			# 套用旋轉
			effect_instance.rotation = slash_angle_rad
			# ⬆️ ========== 修改到這裡結束 ========== ⬆️

	# ✅ 更新條件型技能追蹤數據
	# 1. 累積靈珠總數
	if not orb_totals.has(element):
		orb_totals[element] = 0
	orb_totals[element] += 1

	# 2. 連續消除檢查
	if last_eliminated_element == element:
		continuous_count += 1
	else:
		continuous_count = 1
		last_eliminated_element = element

	# 3. 記錄消除過的屬性種類
	if not (element in unique_elements):
		unique_elements.append(element)

	# 將連擊數和條件數據存儲到 BattleManager 的 meta 中
	if battle_manager:
		battle_manager.set_meta("current_combo", combo_count)
		battle_manager.set_meta("current_orb_totals", orb_totals.duplicate())
		battle_manager.set_meta("current_continuous_element", last_eliminated_element)
		battle_manager.set_meta("current_continuous_count", continuous_count)
		battle_manager.set_meta("current_unique_elements", unique_elements.duplicate())
		print("💾💾💾 [ElementPanel] 儲存條件數據: 連擊=%d, 累積=%s, 連續=%s(%d), 種類=%d" % [
			combo_count,
			orb_totals.get(element, 0),
			Constants.Element.keys()[element] if element >= 0 else "無",
			continuous_count,
			unique_elements.size()
		])
	else:
		print("❌❌❌ [ElementPanel._on_orb_swiped] battle_manager 是 null！無法儲存條件數據！")

	# ✅ ORB_DROP_ON_SLASH: 斬擊時掉落靈珠（支持机率和不同属性）
	if battle_manager and battle_manager.has_meta("orb_drop_on_slash"):
		var drops = battle_manager.get_meta("orb_drop_on_slash")
		if drops.has(element):
			var drop_data = drops[element]
			var count = 0
			var chance_percent = 100.0
			var drop_element = element  # 默认掉落相同属性

			# 兼容旧格式（直接是count）和新格式（字典）
			if drop_data is Dictionary:
				drop_element = drop_data.get("drop_element", element)
				count = drop_data.get("count", 1)
				chance_percent = drop_data.get("chance_percent", 100.0)
			else:
				count = drop_data  # 旧格式：直接是数字

			# 检查机率
			var roll = randf() * 100.0
			if roll < chance_percent:
				var battle_scene = get_tree().current_scene
				if battle_scene and battle_scene.has_method("add_stored_orb"):
					for i in range(count):
						battle_scene.add_stored_orb(drop_element)
					var slash_name = Constants.Element.keys()[element]
					var drop_name = Constants.Element.keys()[drop_element]
					if chance_percent < 100.0:
						print("  [ORB_DROP_ON_SLASH] 斬擊%s觸發%.0f%%機率，掉落%s x%d" % [slash_name, chance_percent, drop_name, count])
					else:
						print("  [ORB_DROP_ON_SLASH] 斬擊%s掉落%s x%d" % [slash_name, drop_name, count])
			else:
				print("  [ORB_DROP_ON_SLASH] 斬擊%s未觸發機率(%.1f%% < %.0f%%)" % [Constants.Element.keys()[element], roll, chance_percent])

	# ✅ SLASH_ORB_SPAWN: 斬擊生成靈珠（累積計數，支持不同属性）
	if battle_manager and battle_manager.has_meta("slash_orb_spawn"):
		var spawns = battle_manager.get_meta("slash_orb_spawn")
		for slash_element in spawns:
			# 只處理當前斬擊的屬性
			if element != slash_element:
				continue

			var spawn_data = spawns[slash_element]
			var spawn_element = slash_element
			var required_count = 3
			var spawn_count = 1

			# 兼容旧格式（直接是count）和新格式（字典）
			if spawn_data is Dictionary:
				spawn_element = spawn_data.get("spawn_element", slash_element)
				required_count = spawn_data.get("required_count", 3)
				spawn_count = spawn_data.get("spawn_count", 1)
			else:
				required_count = spawn_data  # 旧格式：直接是数字

			# 初始化計數器
			if not battle_manager.has_meta("slash_orb_spawn_counter"):
				battle_manager.set_meta("slash_orb_spawn_counter", {})
			var counters = battle_manager.get_meta("slash_orb_spawn_counter")

			var current_count = counters.get(slash_element, 0)
			current_count += 1

			if current_count >= required_count:
				# 達到要求，下N顆必然出現該元素
				counters[slash_element] = 0
				# 添加到序列前面（優先生成）
				if not orb_rules.has("orb_sequence"):
					orb_rules["orb_sequence"] = []
				for i in range(spawn_count):
					orb_rules["orb_sequence"].push_front({
						"element": spawn_element,
						"is_player_sequence": false
					})
				var slash_name = Constants.Element.keys()[slash_element]
				var spawn_name = Constants.Element.keys()[spawn_element]
				print("  [SLASH_ORB_SPAWN] 累積斬%d粒%s，下%d顆必出%s！" % [required_count, slash_name, spawn_count, spawn_name])
			else:
				counters[slash_element] = current_count
				print("  [SLASH_ORB_SPAWN] 累積斬%d/%d粒%s" % [current_count, required_count, Constants.Element.keys()[slash_element]])

			battle_manager.set_meta("slash_orb_spawn_counter", counters)

	# --- 新增掉落邏輯 ---
	# 規則 1: 3 換 1 保底
	if not slash_accumulators.has(element):
		slash_accumulators[element] = 0
	slash_accumulators[element] += 1
	
	if slash_accumulators[element] >= 3:
		slash_accumulators[element] = 0 # 重置計數
		print("  [掉落] 3 換 1 保底: ", Constants.Element.keys()[element])
		orb_dropped.emit(element, false) # (is_player_sequence = false)

	# 規則 2: 25% 額外掉落
	var is_from_player_sequence = current_orb.get_meta("is_player_sequence", false)
	
	if not is_from_player_sequence:
		# (來自技能 或 隨機)
		if randf() < 0.25:
			print("  [掉落] 25%% 額外: ", Constants.Element.keys()[element])
			orb_dropped.emit(element, false) # (is_player_sequence = false)
		if not leader_bonus_config.is_empty() and leader_bonus_config.get("element", null) == element:
				var interval = int(leader_bonus_config.get("extra_drop_interval", 0))
				if interval > 0:
						leader_extra_drop_counter += 1
						if leader_extra_drop_counter >= interval:
								leader_extra_drop_counter = 0
								print("  [掉落] 隊長加成: ", Constants.Element.keys()[element])
								orb_dropped.emit(element, true)
		# else:
				# (來自玩家排版)
				# print("  [掉落] 來自玩家排版，跳過 25% 檢查")
		# --- 掉落邏輯結束 ---
	
	# --- 掉落邏輯結束 ---

	
	update_all_element_multipliers()
	orb_eliminated.emit(element, combo_count, eliminate_counts[element])
	
	combo_timeout_timer.start(COMBO_TIMEOUT)
	
	await get_tree().create_timer(0.05).timeout
	
	spawn_next_orb()
	
func update_all_element_multipliers():
	# ✅ 支援雙重效果和連擊加成
	var C_combo_count = combo_count

	# ✅ 檢查是否有連擊加成 (COMBO_BOOST)
	# 支持兩種來源：1) 隊長技能（永久）2) 主動技能（Buff）
	# 邏輯：如果 combo_bonus = 10，則從10連擊開始計算，第一下是11，第二下是12...
	if battle_manager:
		var total_combo_bonus = 0

		# 1. 檢查隊長技能的 COMBO_BOOST（永久效果）
		if battle_manager.has_meta("leader_combo_boost"):
			var leader_bonus = battle_manager.get_meta("leader_combo_boost")
			total_combo_bonus += leader_bonus
			print("  [COMBO_BOOST] 隊長技能加成: +%d" % leader_bonus)

		# 2. 檢查主動技能的 COMBO_BOOST（Buff 效果）
		if battle_manager.has_active_buff("COMBO_BOOST"):
			var active_bonus = battle_manager.get_active_buff_value("COMBO_BOOST", "combo_bonus", 0)
			total_combo_bonus += active_bonus
			print("  [COMBO_BOOST] 主動技能加成: +%d" % active_bonus)

		# 應用總加成
		if total_combo_bonus > 0:
			C_combo_count = combo_count + total_combo_bonus
			print("  [COMBO_BOOST] 連擊從%d開始 (實際: %d → 顯示: %d)" % [total_combo_bonus, combo_count, C_combo_count])

	var combo_multiplier = 1.0 + (C_combo_count * COMBO_MULTIPLIER_PER_HIT)
	var all_elements = element_direction_map.keys()

	# ✅ 首先計算有效的消除次數（包含雙重效果）
	var effective_eliminate_counts = eliminate_counts.duplicate()

	# ✅ 應用雙重效果
	if battle_manager and battle_manager.has_meta("orb_dual_effects"):
		var dual_effects = battle_manager.get_meta("orb_dual_effects")
		print("  [ORB_DUAL_EFFECT] 檢測到雙重效果配置: %s" % str(dual_effects))
		for source_element in dual_effects:
			var dual_data = dual_effects[source_element]
			var target_element = dual_data.get("target", Constants.Element.FIRE)
			var effect_percent = dual_data.get("percent", 50.0)

			# 如果消除了來源珠，也計入目標珠的效果
			var source_hits = eliminate_counts.get(source_element, 0)
			if source_hits > 0:
				var bonus_hits = source_hits * (effect_percent / 100.0)
				var current_target_hits = effective_eliminate_counts.get(target_element, 0)
				effective_eliminate_counts[target_element] = current_target_hits + bonus_hits
				print("  [ORB_DUAL_EFFECT] %s兼具%s，%.0f%%效果：%d hits → +%.2f hits 到 %s" % [
					Constants.Element.keys()[source_element],
					Constants.Element.keys()[target_element],
					effect_percent,
					source_hits,
					bonus_hits,
					Constants.Element.keys()[target_element]
				])

	# ✅ 使用有效的消除次數計算倍率
	for attacking_element in all_elements:
		var B_own_element_hits = 0
		var D_other_element_hits = 0

		for hit_element in effective_eliminate_counts:
			var hits = effective_eliminate_counts[hit_element]
			if hit_element == attacking_element:
				B_own_element_hits += hits
			else:
				D_other_element_hits += hits

		var element_bonus_multiplier = 1.0 + (B_own_element_hits * OWN_ELEMENT_BONUS) + (D_other_element_hits * OTHER_ELEMENT_BONUS)
		var final_multiplier = element_bonus_multiplier * combo_multiplier
		element_multipliers[attacking_element] = final_multiplier

	if damage_preview_label:
		damage_preview_label.text = ""
		damage_preview_label.visible = false

	# 用新的 Combo UI 函數來處理顯示 + 特效
	if combo_label:
		update_combo_ui(C_combo_count, combo_multiplier)

	multipliers_updated.emit(element_multipliers)

func update_combo_ui(display_combo_count: int, combo_multiplier: float) -> void:
	if combo_label == null:
		return

	if display_combo_count > 0:
		var percentage := int(combo_multiplier * 100)
		combo_label.text = "%d Combo %d%%" % [display_combo_count, percentage]
		combo_label.visible = true

		# 1️⃣ 決定目標顏色（依顯示 combo）
		var target_color: Color
		if display_combo_count >= 9:
			target_color = Color("ff3333")  # 9+：暴走紅
		elif display_combo_count >= 7:
			target_color = Color("ffd700")  # 7~8：金
		elif display_combo_count >= 5:
			target_color = Color("33ccff")  # 5~6：藍
		else:
			target_color = Color.WHITE      # 1~4：白

		# 2️⃣ 顏色漸變：Tween → combo_color → Label
		if combo_color_tween != null and is_instance_valid(combo_color_tween):
			combo_color_tween.kill()

		combo_color_tween = create_tween()
		combo_color_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		combo_color_tween.tween_property(self, "combo_color", target_color, 0.25)

		# 3️⃣ 縮放彈跳 + 亮度閃爍
		_play_combo_bounce_and_flash()

		# 4️⃣ 生成後方殘影
		_spawn_combo_afterimages()
	else:
		combo_label.visible = false
		combo_label.remove_theme_color_override("font_color")
		
func _play_combo_bounce_and_flash() -> void:
	if combo_label == null:
		return

	# 🔹 設定 pivot 在自身中心，縮放就不會「往右下拖」
	combo_label.pivot_offset = combo_label.size / 2

	# 重置狀態
	combo_label.scale = Vector2.ONE
	combo_label.modulate = Color(1, 1, 1, 1)

	if combo_fx_tween != null and is_instance_valid(combo_fx_tween):
		combo_fx_tween.kill()

	combo_fx_tween = create_tween()
	combo_fx_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 字體縮放彈跳：1.0 → 1.3 → 1.0
	combo_fx_tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.08)
	combo_fx_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.12)

	# 亮度閃爍：modulate(1) → (1.4) → (1.0)
	var flash_tween := create_tween()
	flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(combo_label, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.06)
	flash_tween.tween_property(combo_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	
	
func _spawn_combo_afterimages() -> void:
	if combo_label == null:
		return

	# 🔹 殘影丟到整個場景根節點，避免被容器 layout 亂動
	var root := get_tree().current_scene
	if root == null:
		return

	# 用 global_position，確保跟畫面實際位置對齊
	var base_pos = combo_label.global_position

	for i in range(3):
		var ghost := combo_label.duplicate() as Label
		if ghost == null:
			continue

		ghost.text = combo_label.text
		ghost.add_theme_color_override("font_color", combo_color)
		ghost.modulate = Color(1, 1, 1, 0.5)
		ghost.scale = combo_label.scale

		root.add_child(ghost)

		# 直接設定 global_position，不讓容器干涉
		ghost.global_position = base_pos + Vector2(4 * (i + 1), -4 * (i + 1))
		ghost.z_index = combo_label.z_index - 1

		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		var duration := 0.35 + 0.05 * i
		tw.tween_property(ghost, "modulate:a", 0.0, duration)
		tw.parallel().tween_property(ghost, "global_position", ghost.global_position + Vector2(0, -10), duration)

		tw.finished.connect(func ():
			if is_instance_valid(ghost):
				ghost.queue_free()
		)


func _on_combo_timeout():
	# (此函數保持不變)
	if is_combo_active:
		print("--- 1秒連擊中斷，重置 Combo ---")
		combo_count = 0
		if battle_manager:
			battle_manager.set_meta("current_combo", combo_count)
		update_all_element_multipliers()

# 
func _on_slash_timeout():
	slashing_ended.emit() # ✅ 新增：在函數開頭發出斬擊結束信號
	# (此函數保持不變)
	print("--- 5秒斬擊時間到 ---")

	if not is_combo_active: # 如果已經結束了，就不用再跑
		return

	var heal_amount = calculate_final_heal()
	if heal_amount > 0:
		print(" ElementPanel: 結算治療量: %d" % heal_amount)
		healing_phase_finished.emit(heal_amount)

	# ✅ 處理斬擊結束立刻掉落的靈珠
	if battle_manager and battle_manager.has_method("apply_immediate_orb_drops"):
		battle_manager.apply_immediate_orb_drops()
		print("  [ORB_DROP_END_TURN] 應用 immediate 模式掉落")

	# ✅ 設置斬擊結束標記（用於限制 END_TURN_DAMAGE 技能使用）
	if battle_manager:
		battle_manager.slash_ended = true

	# ✅ 處理斬擊結束時的傷害效果（END_TURN_DAMAGE）
	if battle_manager and battle_manager.has_method("apply_end_turn_damage"):
		battle_manager.apply_end_turn_damage()

	slash_timer.stop()
	visible = false
	countdown_bar.visible = false
	is_combo_active = false
	can_start_slashing = true # 允許下一輪

	if current_orb:
		current_orb.queue_free()
		current_orb = null

	print(" ElementPanel: 斬擊結束，發送倍率: %s" % str(element_multipliers))
	slashing_phase_finished.emit(element_multipliers.duplicate()) # 傳送副本

	# ✅ 不要在這裡重置 combo_count！
	# 玩家需要使用這個 combo_count 來檢查敵人的傷害條件
	# combo_count 會在以下時機重置：
	# 1. 玩家休息時（BattleManager.player_rest()）
	# 2. 新的斬擊開始時（_on_orb_swiped()）
	# combo_count = 0
	# eliminate_counts.clear()
	
func end_combo():
	# (此函數保持不變)
	print("\n🎯 連擊結束！總連擊: %d" % combo_count)
	is_combo_active = false
	var total_damage = 0
	for count in eliminate_counts.values():
		total_damage += count
	combo_finished.emit(total_damage)
	combo_count = 0
	if battle_manager:
		battle_manager.set_meta("current_combo", combo_count)
	eliminate_counts.clear()
	update_ui()

# ==================== 傷害計算 ====================


# ==================== UI 更新 ====================

func update_ui():
	# (此函數保持不變)
	if combo_label:
		if combo_count > 0:
			combo_label.text = "連擊: %d" % combo_count
			combo_label.visible = true
		else:
			combo_label.visible = false

	if damage_preview_label:
		damage_preview_label.visible = false

# ==================== 控制方法 ====================

func start_element_combat():
	"""開始元素戰鬥 (由 BattleScene 在玩家回合開始時呼叫)"""
	reset()
	visible = true
	can_start_slashing = true
	is_combo_active = true # 允許開始斬擊
	
	# (移除 is_first_spawn_of_turn 和 force_count_remaining 的設置)
	
	# 🔔 ---- 從 BattleManager 讀取規則 ---- 🔔
		# 🔔 ---- 從 BattleManager 讀取規則 ---- 🔔
	if battle_manager:
			orb_rules = battle_manager.get_orb_rules()
			leader_bonus_config = battle_manager.get_leader_bonus_config()
			var new_element = leader_bonus_config.get("element", -1)
			if new_element != leader_bonus_element:
					leader_bonus_element = new_element
					leader_extra_drop_counter = 0
	else:
			orb_rules = {}
			leader_bonus_config = {}
			if leader_bonus_element != -1:
					leader_bonus_element = -1
					leader_extra_drop_counter = 0
		# 🔔 ---------------------------------- 🔔

		# 重置上一輪的倍率
	element_multipliers.clear()
	update_all_element_multipliers() # 更新UI (全部重置為 x1.0)
	
	# 呼叫新的生成函數
	spawn_next_orb()
	
func stop_element_combat():
	# (此函數保持不變)
	if is_combo_active:
		_on_slash_timeout() 
		
	if current_orb:
		current_orb.queue_free()
		current_orb = null

	visible = false
	can_start_slashing = false
	slash_timer.stop()
	countdown_bar.visible = false
	
func reset():
	# (此函數保持不變)
	combo_count = 0
	if battle_manager:
		battle_manager.set_meta("current_combo", combo_count)
	eliminate_counts.clear()
	is_combo_active = false
	
	countdown_bar.visible = false # 
	
	if combo_timeout_timer:
		combo_timeout_timer.stop()
	
	if slash_timer: # 
		slash_timer.stop() # 
		
	update_ui()

func calculate_final_heal() -> int:
	"""(新) 根據斬擊結果計算最終治療量（支援雙重效果）"""
	if not battle_manager:
		return 0

	var total_recovery = battle_manager.total_recovery
	if total_recovery <= 0:
		return 0

	var heart_hits = eliminate_counts.get(Constants.Element.HEART, 0)

	# ✅ 檢查是否有雙重效果（例如：火珠兼具心珠效果）
	if battle_manager.has_meta("orb_dual_effects"):
		var dual_effects = battle_manager.get_meta("orb_dual_effects")
		for source_element in dual_effects:
			var dual_data = dual_effects[source_element]
			var target_element = dual_data.get("target", Constants.Element.HEART)
			var effect_percent = dual_data.get("percent", 50.0)

			# 如果目標是心珠，且有消除來源珠
			if target_element == Constants.Element.HEART:
				var source_hits = eliminate_counts.get(source_element, 0)
				if source_hits > 0:
					var bonus_hits = source_hits * (effect_percent / 100.0)
					heart_hits += bonus_hits
					print("  治療計算：%s兼具心珠%.0f%%效果，額外 %.2f 心珠" % [Constants.Element.keys()[source_element], effect_percent, bonus_hits])

	if heart_hits == 0:
		print("  治療計算：未消除心珠，治療量 0")
		return 0

	var total_combo = combo_count
	var combo_multiplier = 1.0 + (total_combo * COMBO_MULTIPLIER_PER_HIT)
	var heart_bonus_multiplier = 1.0 + (heart_hits * OWN_ELEMENT_BONUS)
	var final_heal = total_recovery * heart_bonus_multiplier * combo_multiplier

	print("  治療計算：基礎(%d) * 心珠加成(x%.2f) * 連擊(x%.2f) = %d" % [total_recovery, heart_bonus_multiplier, combo_multiplier, final_heal])

	return int(final_heal)

# ==================== 斬擊時間控制 ====================

func add_slash_time_bonus(seconds: float):
	"""增加斬擊時間加成（技能用）"""
	slash_time_bonus += seconds
	print("  [ElementPanel] 增加斬擊時間加成: +%.1f秒 (總加成: %.1f秒)" % [seconds, slash_time_bonus])

func reduce_slash_time(seconds: float):
	"""減少斬擊時間（敵人技能用）"""
	slash_time_penalty += seconds
	print("  [ElementPanel] 增加斬擊時間減少: +%.1f秒 (總減少: %.1f秒)" % [seconds, slash_time_penalty])

func reset_slash_time_modifiers():
	"""重置斬擊時間修正"""
	slash_time_bonus = 0.0
	slash_time_penalty = 0.0
