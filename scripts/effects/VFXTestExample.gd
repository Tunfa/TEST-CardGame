# VFXTestExample.gd
# 測試範例腳本 - 展示如何使用 VFXManager
# 將此腳本附加到任何 Node2D 上即可測試

extends Node2D

# 測試用的位置偏移
var test_positions = [
	Vector2(200, 200),
	Vector2(400, 200),
	Vector2(600, 200),
	Vector2(800, 200),
	Vector2(1000, 200),
]

func _ready():
	print("\n=== VFX 測試範例 ===")
	print("按下數字鍵測試不同特效：")
	print("1 - 打擊特效 (Hit)")
	print("2 - 爆炸特效 (Explosion)")
	print("3 - 治療特效 (Heal)")
	print("4 - 暴擊特效 (Critical)")
	print("5 - 護盾特效 (Shield)")
	print("6 - 所有特效同時播放")
	print("7 - 多重爆炸測試")
	print("滑鼠左鍵 - 在點擊位置播放打擊特效")
	print("滑鼠右鍵 - 在點擊位置播放爆炸特效")

func _input(event):
	# 鍵盤測試
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				test_hit_effect()
			KEY_2:
				test_explosion_effect()
			KEY_3:
				test_heal_effect()
			KEY_4:
				test_critical_effect()
			KEY_5:
				test_shield_effect()
			KEY_6:
				test_all_effects()
			KEY_7:
				test_multiple_explosions()

	# 滑鼠測試
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			VFXManager.hit(event.position)
			print("播放打擊特效於: ", event.position)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			VFXManager.explosion(event.position)
			print("播放爆炸特效於: ", event.position)

# ==================== 測試方法 ====================

func test_hit_effect():
	print("\n[測試] 打擊特效")
	VFXManager.hit(test_positions[0])

func test_explosion_effect():
	print("\n[測試] 爆炸特效")
	VFXManager.explosion(test_positions[1])

func test_heal_effect():
	print("\n[測試] 治療特效")
	VFXManager.heal(test_positions[2])

func test_critical_effect():
	print("\n[測試] 暴擊特效")
	VFXManager.critical(test_positions[3])

func test_shield_effect():
	print("\n[測試] 護盾特效")
	VFXManager.shield(test_positions[4])

func test_all_effects():
	print("\n[測試] 所有特效同時播放")
	VFXManager.hit(test_positions[0])
	VFXManager.explosion(test_positions[1])
	VFXManager.heal(test_positions[2])
	VFXManager.critical(test_positions[3])
	VFXManager.shield(test_positions[4])

func test_multiple_explosions():
	print("\n[測試] 多重爆炸")
	var positions = []
	for i in range(5):
		positions.append(Vector2(200 + i * 150, 400))
	VFXManager.play_multiple_effects("explosion", positions)

# ==================== 自動測試（可選）====================

func _on_auto_test_timer_timeout():
	"""每 2 秒自動播放一個隨機特效"""
	var effects = ["hit", "explosion", "heal", "critical", "shield"]
	var random_effect = effects[randi() % effects.size()]
	var random_pos = Vector2(randf() * 1920, randf() * 1080)
	VFXManager.play_effect(random_effect, random_pos)
	print("自動測試: %s 於 %s" % [random_effect, random_pos])

# 取消下面的註釋以啟用自動測試
# func _ready():
# 	super._ready()
# 	var timer = Timer.new()
# 	add_child(timer)
# 	timer.wait_time = 2.0
# 	timer.autostart = true
# 	timer.timeout.connect(_on_auto_test_timer_timeout)
