# TeamData.gd
# 隊伍資料結構
class_name TeamData
extends Resource

@export var team_id: String = ""
@export var team_name: String = "新隊伍"

# ✅ 改為存儲 instance_id（卡片實例ID）而非 card_id
# 隊長卡片實例ID
@export var leader_card_id: String = ""  # 實際上是 instance_id

# 隊員卡片實例ID列表（不包含隊長）
@export var member_card_ids: Array = []  # 實際上是 instance_id 列表

# ==================== 方法 ====================

func is_valid() -> bool:
	"""檢查隊伍是否有效"""
	if leader_card_id.is_empty():
		return false
	
	var total_size = 1 + member_card_ids.size()
	
	if total_size < Constants.MIN_TEAM_SIZE or total_size > Constants.MAX_TEAM_SIZE:
		return false
	
	return true

func get_all_instance_ids() -> Array:
	"""獲取所有卡片實例ID（包含隊長）"""
	var all_ids: Array = [leader_card_id]
	all_ids.append_array(member_card_ids)
	return all_ids

func get_all_card_ids() -> Array:
	"""【向後兼容】返回實例ID列表"""
	return get_all_instance_ids()

func get_team_size() -> int:
	"""獲取隊伍人數"""
	return 1 + member_card_ids.size()

func add_member(instance_id: String) -> bool:
	"""添加隊員（接收 instance_id）"""
	if get_team_size() >= Constants.MAX_TEAM_SIZE:
		print("隊伍已滿！")
		return false

	# ✅ 允許重複角色：同一 card_id 的不同 instance 可以加入
	member_card_ids.append(instance_id)
	return true

func remove_member(instance_id: String) -> bool:
	"""移除隊員（接收 instance_id）"""
	var index = member_card_ids.find(instance_id)
	if index >= 0:
		member_card_ids.remove_at(index)
		return true
	return false

func set_leader(instance_id: String):
	"""設定隊長（接收 instance_id）"""
	# 如果新隊長在隊員列表中，先移除
	remove_member(instance_id)

	# 如果原本有隊長，將其加入隊員
	if not leader_card_id.is_empty() and leader_card_id != instance_id:
		add_member(leader_card_id)

	leader_card_id = instance_id

func clear():
	"""清空隊伍"""
	leader_card_id = ""
	member_card_ids.clear()
