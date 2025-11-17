# TakeFightButton.gd
extends Button

# 
signal leave_battle_pressed()

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	# 
	leave_battle_pressed.emit()

func set_interactable(enabled: bool):
	"""設定是否可互動"""
	disabled = not enabled
