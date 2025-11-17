# RestButton.gd
# 休息按鈕
extends Button

signal rest_pressed()

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	rest_pressed.emit()

func set_interactable(enabled: bool):
	"""設定是否可互動"""
	disabled = not enabled
