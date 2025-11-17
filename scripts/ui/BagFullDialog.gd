# BagFullDialog.gd
# 背包已滿提示框
extends ConfirmationDialog

signal goto_inventory_pressed
signal expand_bag_pressed

func _ready():
	# 設置對話框標題和內容
	title = "背包已滿"
	dialog_text = "您的背包已經滿了！\n請前往背包整理或擴充背包。"

	# 隱藏默認的 OK/Cancel 按鈕
	get_ok_button().hide()
	get_cancel_button().hide()

	# 添加自定義按鈕
	add_button("前往背包", true, "goto_inventory")
	add_button("擴充背包", false, "expand_bag")

	# 連接信號
	custom_action.connect(_on_custom_action)

	# 設置對話框大小
	size = Vector2(400, 200)

func _on_custom_action(action: String):
	"""處理自定義按鈕點擊"""
	match action:
		"goto_inventory":
			goto_inventory_pressed.emit()
			queue_free()
		"expand_bag":
			expand_bag_pressed.emit()
			queue_free()

func show_dialog():
	"""顯示對話框"""
	popup_centered()
