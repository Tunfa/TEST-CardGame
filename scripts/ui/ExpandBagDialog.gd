# ExpandBagDialog.gd
# 擴充背包確認框
extends ConfirmationDialog

signal expand_5_pressed
signal expand_10_pressed

func _ready():
	# 設置對話框標題和內容
	title = "擴充背包"
	dialog_text = "你確定要擴充背包嗎？\n擴充背包需要消耗鑽石\n\n當前鑽石: %d 💎" % PlayerDataManager.get_diamond()

	# 隱藏默認的 OK 按鈕，保留 Cancel 按鈕
	get_ok_button().hide()
	get_cancel_button().text = "取消"

	# 添加自定義按鈕
	add_button("擴充五格 (5💎)", true, "expand_5")
	add_button("擴充十格 (10💎)", true, "expand_10")

	# 連接信號
	custom_action.connect(_on_custom_action)
	canceled.connect(_on_canceled)

	# 設置對話框大小
	size = Vector2(450, 220)

func _on_custom_action(action: String):
	"""處理自定義按鈕點擊"""
	match action:
		"expand_5":
			if PlayerDataManager.get_diamond() >= 5:
				if PlayerDataManager.expand_bag(5, 5):
					show_success_message("成功擴充 5 格！")
					expand_5_pressed.emit()
				else:
					show_error_message("鑽石不足！")
			else:
				show_error_message("鑽石不足！需要 5 顆鑽石")
			queue_free()

		"expand_10":
			if PlayerDataManager.get_diamond() >= 10:
				if PlayerDataManager.expand_bag(10, 10):
					show_success_message("成功擴充 10 格！")
					expand_10_pressed.emit()
				else:
					show_error_message("鑽石不足！")
			else:
				show_error_message("鑽石不足！需要 10 顆鑽石")
			queue_free()

func _on_canceled():
	"""取消按鈕點擊"""
	queue_free()

func show_success_message(message: String):
	"""顯示成功訊息"""
	var success_dialog = AcceptDialog.new()
	success_dialog.dialog_text = message
	success_dialog.title = "成功"
	get_tree().root.add_child(success_dialog)
	success_dialog.popup_centered()
	success_dialog.confirmed.connect(func(): success_dialog.queue_free())

func show_error_message(message: String):
	"""顯示錯誤訊息"""
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "錯誤"
	get_tree().root.add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())

func show_dialog():
	"""顯示對話框"""
	popup_centered()
