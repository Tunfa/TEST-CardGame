# PlayerDataManager.gd
# 玩家資料管理器（Autoload 單例）
extends Node

# ==================== 信號 ====================
signal data_loaded()
signal data_saved()
signal gold_changed(new_gold: int)
signal exp_changed(new_exp: int)
signal bag_over_capacity()  # ✅ 新增：背包超出上限時發出

# ==================== 玩家資料 ====================
var player_data: Dictionary = {
	"gold": 0,
	"diamond": 0, # ✅ 新增：鑽石（高級貨幣）
	"exp": 0,
	"level": 1,
	"inventory": [],  # ✅ 改為存儲 instance_id 列表（唯一實例ID）
	"card_instances": {},  # ✅ 新增：instance_id -> {card_id, level, exp} 映射
	"next_instance_id": 1,  # ✅ 新增：下一個要分配的實例ID
	"bag_capacity": Constants.DEFAULT_BAG_CAPACITY,
	"teams": {},  # 保存的隊伍配置 {team_id: TeamData}
	"completed_stages": [],  # 已完成的關卡ID
	"unlocked_training_rooms": [],  # 已解鎖的訓練室ID列表
	"active_training": null,  # 當前進行中的訓練 {room_id, start_time, duration, teams, exp_reward}
	"shop_purchases": {}  # ✅ 商店購買記錄 {item_id: purchase_count}
}

# ==================== 初始化 ====================

func _ready():
	print("💾 PlayerDataManager 初始化完成")
	load_data()

# ==================== 存檔系統 ====================

func save_data():
	"""保存資料到檔案"""
	var file = FileAccess.open(Constants.SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(player_data, "\t")
		file.store_string(json_string)
		file.close()
		print("✅ 存檔成功")
		data_saved.emit()
	else:
		push_error("❌ 存檔失敗")

func load_data():
	"""從檔案載入資料"""
	if not FileAccess.file_exists(Constants.SAVE_FILE_PATH):
		print("⚠️  存檔不存在，創建新存檔")
		create_new_save()
		return
	
	var file = FileAccess.open(Constants.SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			player_data = json.data
			print("✅ 讀檔成功")
			# ⬇️ ========== 從這裡開始新增 ========== ⬇️
			# 檢查並修復舊存檔，確保新欄位存在
			var save_changed = false

			# 檢查 "completed_stages"
			if not player_data.has("completed_stages"):
				player_data["completed_stages"] = []
				save_changed = true

			# 檢查 "diamond"
			if not player_data.has("diamond"):
				player_data["diamond"] = 0
				save_changed = true

			# ✅ 新增：檢查卡片實例系統
			if not player_data.has("card_instances") or not player_data.has("next_instance_id"):
				print("🔧 偵測到舊版背包系統，正在遷移到實例ID系統...")
				migrate_old_inventory_to_instance_system()
				save_changed = true

			# ✅ 新增：檢查訓練室解鎖列表
			if not player_data.has("unlocked_training_rooms"):
				player_data["unlocked_training_rooms"] = []
				save_changed = true

			# ✅ 新增：檢查訓練狀態
			if not player_data.has("active_training"):
				player_data["active_training"] = null
				save_changed = true

			# ✅ 新增：檢查商店購買記錄
			if not player_data.has("shop_purchases"):
				player_data["shop_purchases"] = {}
				save_changed = true

			# 如果修復了存檔，就立刻存回去
			if save_changed:
				print("🔧 偵測到舊版存檔，已自動更新欄位。")
				save_data()
			# ⬆️ ========== 新增到這裡 ========== ⬆️
			data_loaded.emit()
		else:
			push_error("❌ JSON 解析失敗")
			create_new_save()
	else:
		push_error("❌ 讀檔失敗")
		create_new_save()

func create_new_save():
	"""創建新存檔"""
	player_data = {
		"gold": 500,
		"diamond": 100,
		"exp": 0,
		"level": 1,
		"inventory": [],  # 空背包，通過新手教學獲得卡片
		"card_instances": {},
		"next_instance_id": 1,
		"bag_capacity": Constants.DEFAULT_BAG_CAPACITY,
		"teams": {},
		"completed_stages": [],
		"unlocked_training_rooms": [],  # 訓練室解鎖列表
		"active_training": null,  # 當前訓練狀態
		"shop_purchases": {}  # 商店購買記錄
	}
	# ✅ 不再自動添加初始卡片，改由新手教學獲得
	save_data()

func reset_save():
	"""重置存檔"""
	create_new_save()

func migrate_old_inventory_to_instance_system():
	"""將舊版背包系統（card_id列表）遷移到新版（instance_id系統）"""
	print("  開始遷移背包系統...")

	# 確保新欄位存在
	if not player_data.has("card_instances"):
		player_data["card_instances"] = {}
	if not player_data.has("next_instance_id"):
		player_data["next_instance_id"] = 1

	# 複製舊的 inventory
	var old_inventory = player_data.inventory.duplicate() if player_data.has("inventory") else []

	# 清空 inventory，準備填入 instance_id
	player_data.inventory = []

	# 檢查是否需要從舊格式（instance_id -> card_id）遷移到新格式（instance_id -> {card_id, level, exp}）
	var needs_format_upgrade = false
	for instance_id in player_data.card_instances.keys():
		var value = player_data.card_instances[instance_id]
		if typeof(value) == TYPE_STRING:  # 舊格式：直接是 card_id 字串
			needs_format_upgrade = true
			break

	if needs_format_upgrade:
		print("  🔧 偵測到舊格式 card_instances，升級到新格式...")
		var old_card_instances = player_data.card_instances.duplicate()
		player_data.card_instances = {}

		for instance_id in old_card_instances.keys():
			var card_id = old_card_instances[instance_id]
			player_data.card_instances[instance_id] = {
				"card_id": card_id,
				"level": 1,
				"exp": 0
			}
			print("  升級實例：instance_%s (%s) -> Lv.1" % [instance_id, card_id])

	# 遷移每張卡片（如果是從完全舊的格式）
	for card_id in old_inventory:
		var instance_id = str(player_data.next_instance_id)
		player_data.next_instance_id += 1

		player_data.card_instances[instance_id] = {
			"card_id": card_id,
			"level": 1,
			"exp": 0
		}
		player_data.inventory.append(instance_id)

		print("  遷移：%s -> instance_%s (Lv.1)" % [card_id, instance_id])

	print("  ✅ 遷移完成！共 %d 張卡片" % old_inventory.size())

# ==================== 金錢系統 ====================

func add_gold(amount: int):
	"""增加金錢"""
	player_data.gold += amount
	gold_changed.emit(player_data.gold)
	print("💰 獲得金幣: +%d (總計: %d)" % [amount, player_data.gold])

func spend_gold(amount: int) -> bool:
	"""消費金錢"""
	if player_data.gold >= amount:
		player_data.gold -= amount
		gold_changed.emit(player_data.gold)
		print("💰 消費金幣: -%d (剩餘: %d)" % [amount, player_data.gold])
		return true
	else:
		print("❌ 金錢不足！")
		return false

func get_gold() -> int:
	"""獲取當前金錢"""
	return player_data.gold
# ==================== 鑽石系統 (新) ====================

func add_diamond(amount: int):
	"""增加鑽石"""
	player_data.diamond += amount
	# signal diamond_changed(player_data.diamond) # (可選：如果UI需要即時更新)
	print("💎 獲得鑽石: +%d (總計: %d)" % [amount, player_data.diamond])

func spend_diamond(amount: int) -> bool:
	"""消費鑽石"""
	if player_data.diamond >= amount:
		player_data.diamond -= amount
		# signal diamond_changed(player_data.diamond)
		print("💎 消費鑽石: -%d (剩餘: %d)" % [amount, player_data.diamond])
		return true
	else:
		print("❌ 鑽石不足！")
		return false

func get_diamond() -> int:
	"""獲取當前鑽石"""
	return player_data.diamond


# ==================== 經驗系統 ====================

func add_exp(amount: int):
	"""增加經驗"""
	player_data.exp += amount
	exp_changed.emit(player_data.exp)
	print("⭐ 獲得經驗: +%d (總計: %d)" % [amount, player_data.exp])
	check_level_up()

func check_level_up():
	"""檢查是否升級（簡單的升級系統）"""
	var required_exp = player_data.level * 100
	if player_data.exp >= required_exp:
		player_data.level += 1
		print("🎉 升級！當前等級: %d" % player_data.level)

# ==================== 背包系統 ====================

func add_card(card_id: String, force_add: bool = true) -> String:
	"""添加卡片到背包，返回生成的 instance_id
	   force_add: 是否允許臨時突破上限（默認為 true）
	"""
	# ✅ 允許臨時突破上限
	if not force_add and player_data.inventory.size() >= player_data.bag_capacity:
		print("❌ 背包已滿！")
		return ""

	# 檢查添加前是否已經超限
	var was_over_capacity = is_bag_over_capacity()

	# 生成唯一的 instance_id
	var instance_id = str(player_data.next_instance_id)
	player_data.next_instance_id += 1

	# 保存映射和添加到背包（包含等級和經驗值）
	player_data.card_instances[instance_id] = {
		"card_id": card_id,
		"level": 1,
		"exp": 0
	}
	player_data.inventory.append(instance_id)

	if player_data.inventory.size() > player_data.bag_capacity:
		print("⚠️  背包已滿，臨時突破上限！獲得卡片: %s (instance_%s) [%d/%d]" % [card_id, instance_id, player_data.inventory.size(), player_data.bag_capacity])

		# ✅ 如果這是第一次超限（剛才還沒超，現在超了），發出信號
		if not was_over_capacity:
			bag_over_capacity.emit()
	else:
		print("✅ 獲得卡片: %s (instance_%s) Lv.1" % [card_id, instance_id])

	return instance_id

func remove_card_by_instance(instance_id: String) -> bool:
	"""通過 instance_id 從背包移除卡片"""
	var index = player_data.inventory.find(instance_id)
	if index >= 0:
		var card_id = player_data.card_instances.get(instance_id, "未知")
		player_data.inventory.remove_at(index)
		player_data.card_instances.erase(instance_id)
		print("✅ 移除卡片: %s (instance_%s)" % [card_id, instance_id])
		return true

	print("❌ 找不到卡片實例: " + instance_id)
	return false

func remove_card(card_id: String) -> bool:
	"""【舊版兼容】從背包移除第一張匹配的卡片"""
	for instance_id in player_data.inventory:
		if player_data.card_instances.get(instance_id) == card_id:
			return remove_card_by_instance(instance_id)
	return false

func has_card(card_id: String) -> bool:
	"""檢查是否擁有卡片（任意一張）"""
	for instance_id in player_data.inventory:
		if player_data.card_instances.get(instance_id) == card_id:
			return true
	return false

func get_inventory() -> Array:
	"""獲取背包內容（返回 instance_id 列表）"""
	return player_data.inventory

func get_card_id_from_instance(instance_id: String) -> String:
	"""通過 instance_id 獲取 card_id"""
	var instance_data = player_data.card_instances.get(instance_id, null)
	if instance_data == null:
		return ""
	# 兼容舊格式（直接是字串）和新格式（字典）
	if typeof(instance_data) == TYPE_STRING:
		return instance_data
	elif typeof(instance_data) == TYPE_DICTIONARY:
		return instance_data.get("card_id", "")
	return ""

func get_card_instance(instance_id: String) -> CardData:
	"""通過 instance_id 獲取卡片實例（CardData對象，包含等級和經驗值）"""
	var card_id = get_card_id_from_instance(instance_id)
	if card_id.is_empty():
		return null

	# 從 DataManager 獲取卡片模板
	var card_instance = DataManager.get_card(card_id)
	if card_instance:
		# 設置實例ID
		card_instance.instance_id = instance_id

		# 載入保存的等級和經驗值
		var instance_data = player_data.card_instances.get(instance_id, null)
		if typeof(instance_data) == TYPE_DICTIONARY:
			card_instance.current_level = instance_data.get("level", 1)
			card_instance.current_exp = instance_data.get("exp", 0)
	return card_instance

func get_all_card_instances() -> Array:
	"""獲取所有卡片實例（CardData對象陣列）"""
	var instances = []
	for instance_id in player_data.inventory:
		var card_instance = get_card_instance(instance_id)
		if card_instance:
			instances.append(card_instance)
	return instances

func update_card_instance(instance_id: String, card: CardData) -> bool:
	"""更新卡片實例的等級和經驗值到存檔
	返回: 是否成功更新
	"""
	if not player_data.card_instances.has(instance_id):
		push_error("❌ 無法找到卡片實例: " + instance_id)
		return false

	var instance_data = player_data.card_instances[instance_id]

	# 升級舊格式（如果需要）
	if typeof(instance_data) == TYPE_STRING:
		player_data.card_instances[instance_id] = {
			"card_id": instance_data,
			"level": card.current_level,
			"exp": card.current_exp
		}
	elif typeof(instance_data) == TYPE_DICTIONARY:
		instance_data["level"] = card.current_level
		instance_data["exp"] = card.current_exp
	else:
		push_error("❌ 無效的實例數據格式")
		return false

	return true

func is_bag_over_capacity() -> bool:
	"""檢查背包是否超過上限"""
	return player_data.inventory.size() > player_data.bag_capacity

func get_bag_overflow_count() -> int:
	"""獲取背包超出的數量"""
	var overflow = player_data.inventory.size() - player_data.bag_capacity
	return max(0, overflow)

func expand_bag(additional_slots: int, diamond_cost: int) -> bool:
	"""擴充背包（使用鑽石）"""
	if spend_diamond(diamond_cost):
		player_data.bag_capacity += additional_slots
		print("✅ 背包擴充至: %d 格 (消耗 %d 鑽石)" % [player_data.bag_capacity, diamond_cost])
		save_data()  # 立即保存
		return true
	else:
		print("❌ 鑽石不足！需要 %d 鑽石" % diamond_cost)
		return false

# ==================== 隊伍系統 ====================

func save_team(team_id: String, team: TeamData):
	"""保存隊伍配置"""
	player_data.teams[team_id] = {
		"team_name": team.team_name,
		"leader_card_id": team.leader_card_id,
		"member_card_ids": team.member_card_ids
	}
	print("✅ 保存隊伍: " + team_id)

func load_team(team_id: String) -> TeamData:
	"""載入隊伍配置"""
	if team_id not in player_data.teams:
		return null
	
	var team_dict = player_data.teams[team_id]
	var team = TeamData.new()
	team.team_id = team_id
	team.team_name = team_dict.team_name
	team.leader_card_id = team_dict.leader_card_id
	team.member_card_ids = team_dict.member_card_ids
	
	return team

func get_all_teams() -> Dictionary:
	"""獲取所有隊伍"""
	return player_data.teams
	
func clear_team(team_id: String):
	"""從 player_data 中移除一個隊伍配置"""
	if player_data.teams.has(team_id):
		player_data.teams.erase(team_id)
		print("🗑️ 隊伍已清空: " + team_id)
		# 如果清空的是預設隊伍，也清除預設ID
		if player_data.has("default_team_id") and player_data.default_team_id == team_id:
			player_data.default_team_id = ""
	else:
		print("ℹ️ 嘗試清空一個不存在的隊伍: " + team_id)

func get_current_team() -> Array:
	"""獲取當前隊伍（從背包中的前5張卡片）"""
	# 簡單實現：返回背包中的前5張卡片ID
	var team = []
	var inventory = get_inventory()
	for i in range(min(5, inventory.size())):
		team.append(inventory[i])
	return team

func get_all_cards_in_teams() -> Array:
	"""【向後兼容】獲取所有隊伍中的卡片模板ID（去重）"""
	var all_card_ids = []
	var all_instance_ids = get_all_instance_ids_in_teams()

	for instance_id in all_instance_ids:
		var card_id = get_card_id_from_instance(instance_id)
		if not card_id.is_empty() and card_id not in all_card_ids:
			all_card_ids.append(card_id)

	return all_card_ids

func get_all_instance_ids_in_teams() -> Array:
	"""✅ 獲取所有隊伍中的卡片實例ID（包含重複）"""
	var all_instance_ids = []
	var all_teams = get_all_teams()

	for team_id in all_teams.keys():
		var team_data = load_team(team_id)
		if team_data:
			# 添加隊長（instance_id）
			if not team_data.leader_card_id.is_empty():
				all_instance_ids.append(team_data.leader_card_id)

			# 添加隊員（instance_id）
			for instance_id in team_data.member_card_ids:
				if not instance_id.is_empty():
					all_instance_ids.append(instance_id)

	return all_instance_ids

# ==================== 關卡進度 ====================

func complete_stage(stage_id: String):
	"""完成關卡"""
	if stage_id not in player_data.completed_stages:
		player_data.completed_stages.append(stage_id)
		print("✅ 完成關卡: " + stage_id)

func is_stage_completed(stage_id: String) -> bool:
	"""檢查關卡是否完成"""
	return stage_id in player_data.completed_stages

func get_completed_stages() -> Array:
	"""獲取已完成的關卡列表"""
	return player_data.completed_stages

# ==================== 訓練室解鎖 ====================

func is_training_room_unlocked(room_id: String) -> bool:
	"""檢查訓練室是否已解鎖"""
	return room_id in player_data.unlocked_training_rooms

func unlock_training_room(room_id: String, cost_gold: int = 0, cost_diamond: int = 0) -> bool:
	"""解鎖訓練室
	返回: 是否成功解鎖
	"""
	# 檢查是否已解鎖
	if is_training_room_unlocked(room_id):
		print("⚠️ 訓練室 %s 已經解鎖" % room_id)
		return false

	# 檢查金幣
	if cost_gold > 0:
		if player_data.gold < cost_gold:
			print("❌ 金幣不足！需要 %d，當前 %d" % [cost_gold, player_data.gold])
			return false
		player_data.gold -= cost_gold

	# 檢查鑽石
	if cost_diamond > 0:
		if player_data.diamond < cost_diamond:
			print("❌ 鑽石不足！需要 %d，當前 %d" % [cost_diamond, player_data.diamond])
			return false
		player_data.diamond -= cost_diamond

	# 解鎖訓練室
	player_data.unlocked_training_rooms.append(room_id)
	print("✅ 解鎖訓練室: %s" % room_id)
	save_data()
	return true

func get_unlocked_training_rooms() -> Array:
	"""獲取已解鎖的訓練室列表"""
	return player_data.unlocked_training_rooms

# ==================== 訓練狀態管理 ====================

func start_training(room_id: String, duration: int, teams: Array, exp_reward: int):
	"""開始訓練（保存到存檔中）
	參數:
	  room_id: 訓練室ID
	  duration: 訓練時長（秒）
	  teams: 訓練隊伍陣列 [[instance_id, ...], ...]
	  exp_reward: 經驗值獎勵
	"""
	var start_time = Time.get_unix_time_from_system()
	player_data.active_training = {
		"room_id": room_id,
		"start_time": start_time,
		"duration": duration,
		"teams": teams.duplicate(true),  # 深拷貝
		"exp_reward": exp_reward
	}
	save_data()
	print("🏋️ 開始訓練：%s，時長 %d 秒，完成時間 %s" % [room_id, duration, Time.get_datetime_string_from_unix_time(start_time + duration)])

func get_active_training() -> Dictionary:
	"""獲取當前訓練狀態
	返回: {room_id, start_time, duration, teams, exp_reward, remaining_time, is_completed}
	"""
	if player_data.active_training == null:
		return {}

	var training = player_data.active_training.duplicate()
	var current_time = Time.get_unix_time_from_system()
	var elapsed_time = current_time - training.start_time
	training.remaining_time = max(0, training.duration - elapsed_time)
	training.is_completed = elapsed_time >= training.duration

	return training

func complete_training() -> Dictionary:
	"""完成訓練並領取獎勵
	返回: {success: bool, total_cards: int, level_ups: Array, exp_reward: int}
	"""
	if player_data.active_training == null:
		return {"success": false, "error": "沒有進行中的訓練"}

	var training = get_active_training()
	if not training.is_completed:
		return {"success": false, "error": "訓練尚未完成"}

	# 分配獎勵
	var total_cards_trained = 0
	var level_ups: Array = []

	for team in training.teams:
		for card_instance_id in team:
			if card_instance_id != "":
				var card_instance = get_card_instance(card_instance_id)
				if card_instance:
					# 記錄升級前的等級
					var old_level = card_instance.current_level

					# 增加經驗值
					var result = card_instance.add_exp(training.exp_reward)
					total_cards_trained += 1

					# ✅ 關鍵修復：保存卡片的等級和經驗值變更
					update_card_instance(card_instance_id, card_instance)

					# 記錄升級資訊
					if result.leveled_up:
						level_ups.append({
							"card_id": card_instance.card_id,
							"card_name": card_instance.card_name,
							"old_level": old_level,
							"new_level": result.new_level
						})
						print("🎉 %s 升級了！%d -> %d" % [card_instance.card_name, old_level, result.new_level])

	# 清除訓練狀態
	player_data.active_training = null
	save_data()

	print("✅ 訓練完成！共 %d 張卡片獲得經驗，%d 張卡片升級" % [total_cards_trained, level_ups.size()])

	return {
		"success": true,
		"total_cards": total_cards_trained,
		"level_ups": level_ups,
		"exp_reward": training.exp_reward
	}

func cancel_training():
	"""取消當前訓練（不給獎勵）"""
	if player_data.active_training != null:
		player_data.active_training = null
		save_data()
		print("❌ 訓練已取消")

func is_training_active() -> bool:
	"""檢查是否有進行中的訓練"""
	return player_data.active_training != null

# ==================== 卡片進化系統 ====================

func is_card_in_team(instance_id: String) -> bool:
	"""檢查卡片是否在任何隊伍中"""
	for team_data in player_data.teams.values():
		# teams 存的是普通字典，欄位是 member_card_ids
		for card_instance_id in team_data.member_card_ids:
			if card_instance_id == instance_id:
				return true
	return false

func evolve_card(target_instance_id: String, new_card_id: String, material_instance_ids: Array, gold_cost: int) -> bool:
	"""進化卡片
	參數:
		target_instance_id: 要進化的卡片實例ID
		new_card_id: 進化後的卡片ID
		material_instance_ids: 素材卡片實例ID列表
		gold_cost: 金幣消耗
	返回: 是否成功進化
	"""
	# 檢查金幣
	if player_data.gold < gold_cost:
		print("❌ 金幣不足！需要 %d，當前 %d" % [gold_cost, player_data.gold])
		return false

	# 檢查目標卡片是否存在
	if not player_data.card_instances.has(target_instance_id):
		print("❌ 找不到目標卡片: " + target_instance_id)
		return false

	# 檢查目標卡片是否在組隊中
	if is_card_in_team(target_instance_id):
		print("❌ 目標卡片正在組隊中")
		return false

	# 檢查並移除素材卡片
	for mat_instance_id in material_instance_ids:
		if not player_data.card_instances.has(mat_instance_id):
			print("❌ 找不到素材卡片: " + mat_instance_id)
			return false

		if is_card_in_team(mat_instance_id):
			print("❌ 素材卡片 %s 正在組隊中" % mat_instance_id)
			return false

	# 移除素材卡片
	for mat_instance_id in material_instance_ids:
		# 從 card_instances 中移除
		player_data.card_instances.erase(mat_instance_id)
		# 從 inventory 中移除
		var idx = player_data.inventory.find(mat_instance_id)
		if idx != -1:
			player_data.inventory.remove_at(idx)
		print("✅ 移除素材卡片: " + mat_instance_id)

	# 扣除金幣
	player_data.gold -= gold_cost
	print("💰 扣除 %d 金幣，剩餘 %d" % [gold_cost, player_data.gold])

	# 替換為新卡片（重置等級和經驗）
	player_data.card_instances[target_instance_id]["card_id"] = new_card_id
	player_data.card_instances[target_instance_id]["level"] = 1
	player_data.card_instances[target_instance_id]["exp"] = 0

	print("✨ 進化成功！%s -> %s" % [target_instance_id, new_card_id])

	# 保存數據
	save_data()

	return true

# ==================== 商店購買記錄 ====================

func get_shop_purchase_count(item_id: String) -> int:
	"""獲取商品的購買次數"""
	if not player_data.has("shop_purchases"):
		player_data["shop_purchases"] = {}

	return player_data.shop_purchases.get(item_id, 0)

func record_shop_purchase(item_id: String):
	"""記錄商品購買（增加購買次數）"""
	if not player_data.has("shop_purchases"):
		player_data["shop_purchases"] = {}

	var current_count = player_data.shop_purchases.get(item_id, 0)
	player_data.shop_purchases[item_id] = current_count + 1

	print("📝 記錄購買: %s (第 %d 次)" % [item_id, player_data.shop_purchases[item_id]])
	save_data()

func can_purchase_item(item_id: String, purchase_limit: int) -> bool:
	"""檢查是否可以購買商品（檢查購買限制）"""
	# 如果沒有購買限制，總是可以購買
	if purchase_limit <= 0:
		return true

	var current_count = get_shop_purchase_count(item_id)
	return current_count < purchase_limit

# ==================== Debug/GM 功能 ====================

func reset_all_data():
	"""完全重置所有存檔數據（由 Debug Console 調用）"""
	reset_save()
