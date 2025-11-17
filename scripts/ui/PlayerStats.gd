# PlayerStats.gd
# 玩家狀態顯示
extends PanelContainer

# ==================== 引用 ====================
@onready var turn_label = $VBoxContainer/TurnLabel
@onready var phase_label = $VBoxContainer/PhaseLabel
#@onready var hp_bar = $VBoxContainer/HPContainer/HPBar
@onready var recovery_label = $VBoxContainer/RecoveryLabel
@onready var wave_label = $VBoxContainer/WaveLabel # ✅ 1. 新增這一行
# ==================== 更新方法 ====================

func update_turn(turn: int):
	"""更新回合數"""
	turn_label.text = "回合：%d" % turn

func update_phase(is_player_turn: bool):
	"""更新階段"""
	if is_player_turn:
		phase_label.text = "玩家回合"
		phase_label.modulate = Color.GREEN
	else:
		phase_label.text = "敵人回合"
		phase_label.modulate = Color.RED

#func update_hp(current: int, max_hp: int):
	#"""更新HP"""
	#if hp_bar:
		#hp_bar.max_value = max_hp
		#hp_bar.value = current
	
	# HP低於30%時變紅
	#if current < max_hp * 0.3:
		#hp_bar.modulate = Color.RED
	#else:
		#hp_bar.modulate = Color.WHITE

func update_recovery(recovery: int):
	"""更新回復力"""
	recovery_label.text = "回復力：%d" % recovery
	
func play_damage_effect():
	"""播放受伤效果"""
	var tween = create_tween()
	
	# 整个面板闪红
	tween.tween_property(self, "modulate", Color(1.5, 0.5, 0.5, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1.5, 0.5, 0.5, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.1)
	
func update_wave(current: int, total: int): # ✅ 修正：現在是獨立的函式
	"""更新波次顯示"""
	if wave_label:
		wave_label.text = "WAVE: %d/%d" % [current, total]
