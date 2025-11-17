# DebugConsole.gd
# 類似 CS1.6 的開發者控制台
extends CanvasLayer

# ==================== 節點引用 ====================
@onready var console_panel: Panel = $ConsolePanel
@onready var output_label: RichTextLabel = $ConsolePanel/VBoxContainer/ScrollContainer/OutputLabel
@onready var input_field: LineEdit = $ConsolePanel/VBoxContainer/InputField

# ==================== 變數 ====================
var console_visible: bool = false
var command_history: Array[String] = []
var history_index: int = -1
var max_history: int = 50

# ==================== 初始化 ====================

func _ready():
	# 初始隱藏
	console_panel.visible = false
	console_visible = false

	# 連接信號
	input_field.text_submitted.connect(_on_command_submitted)

	# 歡迎訊息
	print_line("[color=yellow]===== Debug Console Ready =====[/color]")
	print_line("[color=gray]Type 'help' for available commands[/color]")

func _input(event):
	# 監聽波浪號鍵（~）或 ` 鍵
	if event is InputEventKey and event.pressed and not event.echo:
		# KeyCode for ` and ~
		if event.keycode == KEY_QUOTELEFT:  # ` / ~ 鍵
			toggle_console()
			get_viewport().set_input_as_handled()
		# ESC 關閉控制台
		elif event.keycode == KEY_ESCAPE and console_visible:
			hide_console()
			get_viewport().set_input_as_handled()
		# 上下箭頭瀏覽歷史
		elif console_visible and input_field.has_focus():
			if event.keycode == KEY_UP:
				navigate_history(-1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				navigate_history(1)
				get_viewport().set_input_as_handled()

# ==================== 顯示/隱藏 ====================

func toggle_console():
	if console_visible:
		hide_console()
	else:
		show_console()

func show_console():
	console_visible = true
	console_panel.visible = true
	input_field.clear()
	input_field.grab_focus()

	# 動畫效果
	var tween = create_tween()
	console_panel.modulate.a = 0
	console_panel.position.y = -console_panel.size.y
	tween.tween_property(console_panel, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(console_panel, "position:y", 0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hide_console():
	console_visible = false

	# 動畫效果
	var tween = create_tween()
	tween.tween_property(console_panel, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(console_panel, "position:y", -console_panel.size.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	console_panel.visible = false

# ==================== 輸出 ====================

func print_line(text: String):
	"""輸出一行到控制台"""
	output_label.append_text(text + "\n")
	# 自動滾動到底部
	await get_tree().process_frame
	var scroll_container = output_label.get_parent()
	if scroll_container is ScrollContainer:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func clear_output():
	"""清空輸出"""
	output_label.clear()

# ==================== 命令處理 ====================

func _on_command_submitted(command: String):
	"""處理輸入的命令"""
	command = command.strip_edges()

	if command.is_empty():
		return

	# 顯示輸入的命令
	print_line("[color=cyan]> " + command + "[/color]")

	# 添加到歷史
	add_to_history(command)

	# 清空輸入框
	input_field.clear()

	# 執行命令
	execute_command(command)

func execute_command(command: String):
	"""執行命令"""
	var parts = command.split(" ", false)
	if parts.is_empty():
		return

	var cmd = parts[0].to_lower()
	var args = parts.slice(1)

	match cmd:
		"help":
			show_help()
		"clear", "cls":
			clear_output()
		"/gm":
			if args.size() > 0:
				execute_gm_command(args)
			else:
				print_line("[color=red]Error: /gm requires a subcommand[/color]")
				print_line("[color=gray]Usage: /gm reset | /gm unlock_all[/color]")
		"echo":
			print_line(" ".join(args))
		"quit", "exit":
			hide_console()
		_:
			print_line("[color=red]Unknown command: " + cmd + "[/color]")
			print_line("[color=gray]Type 'help' for available commands[/color]")

func execute_gm_command(args: Array):
	"""執行 GM (Game Master) 命令"""
	var subcmd = args[0].to_lower()

	match subcmd:
		"reset":
			print_line("[color=yellow]Resetting all game data...[/color]")
			reset_game_data()
		"reload":
			print_line("[color=yellow]Reloading game...[/color]")
			reload_game()
		"unlock_all":
			print_line("[color=yellow]Unlocking all stages...[/color]")
			unlock_all_stages()
		"add_gold":
			if args.size() > 1:
				var amount = int(args[1])
				add_gold(amount)
			else:
				print_line("[color=red]Error: /gm add_gold requires amount[/color]")
		"add_card":
			if args.size() > 1:
				var card_id = args[1]
				add_card(card_id)
			else:
				print_line("[color=red]Error: /gm add_card requires card_id[/color]")
		_:
			print_line("[color=red]Unknown GM command: " + subcmd + "[/color]")
			print_line("[color=gray]Available: reset, reload, unlock_all, add_gold <amount>, add_card <id>[/color]")

# ==================== GM 命令實現 ====================

func reload_game():
	"""重新載入遊戲"""
	print_line("[color=green]✓ Reloading game scene...[/color]")
	# 重新載入當前場景（從主菜單開始）
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func reset_game_data():
	"""重置所有存檔數據"""
	# 清空 PlayerDataManager
	if PlayerDataManager:
		PlayerDataManager.reset_all_data()
		print_line("[color=green]✓ Player data reset[/color]")

	# 清空 TaskManager
	if TaskManager:
		TaskManager.active_quests.clear()
		TaskManager.completed_quests.clear()
		TaskManager.selected_starter_card = ""


		# ✅ 重置卡片選擇器狀態
		if TaskManager.card_selector_node != null:
			TaskManager.card_selector_node.hide()
			TaskManager.card_selector_node.selected_card_id = ""
			# 關閉打開的 CardDetailPanel
			if TaskManager.card_selector_node.has_method("close_detail_panel"):
				TaskManager.card_selector_node.close_detail_panel()
			print_line("[color=green]✓ Card selector reset[/color]")

		print_line("[color=green]✓ Task progress reset[/color]")

	# ✅ 清理所有打開的 CardDetailPanel 實例
	var root = get_tree().root
	for child in root.get_children():
		if child.name.contains("CardDetailPanel"):
			print_line("[color=yellow]  Removing stale CardDetailPanel: %s[/color]" % child.name)
			child.queue_free()

	# 刪除存檔文件
	var save_path = "user://save_data.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print_line("[color=green]✓ Save file deleted[/color]")

	# 刪除任務進度文件
	var task_progress_path = "user://task_progress.json"
	if FileAccess.file_exists(task_progress_path):
		DirAccess.remove_absolute(task_progress_path)
		print_line("[color=green]✓ Task progress file deleted[/color]")

	print_line("[color=lime]Game data reset complete![/color]")
	print_line("[color=yellow]Please restart the game for changes to take effect.[/color]")

func unlock_all_stages():
	"""解鎖所有關卡"""
	if PlayerDataManager:
		# 獲取所有關卡
		var all_stages = DataManager.get_all_stages()
		for stage_id in all_stages:
			PlayerDataManager.completed_stages.append(stage_id)

		PlayerDataManager.save_data()
		print_line("[color=green]✓ Unlocked " + str(all_stages.size()) + " stages[/color]")
	else:
		print_line("[color=red]Error: PlayerDataManager not found[/color]")

func add_gold(amount: int):
	"""添加金幣"""
	if PlayerDataManager:
		PlayerDataManager.gold += amount
		PlayerDataManager.save_data()
		print_line("[color=green]✓ Added " + str(amount) + " gold[/color]")
		print_line("[color=gray]Current gold: " + str(PlayerDataManager.gold) + "[/color]")
	else:
		print_line("[color=red]Error: PlayerDataManager not found[/color]")

func add_card(card_id: String):
	"""添加卡片到收藏"""
	if PlayerDataManager:
		if card_id not in PlayerDataManager.owned_cards:
			PlayerDataManager.owned_cards.append(card_id)
			PlayerDataManager.save_data()
			print_line("[color=green]✓ Added card: " + card_id + "[/color]")
		else:
			print_line("[color=yellow]Card already owned: " + card_id + "[/color]")
	else:
		print_line("[color=red]Error: PlayerDataManager not found[/color]")

# ==================== 幫助 ====================

func show_help():
	"""顯示幫助信息"""
	print_line("[color=yellow]===== Available Commands =====[/color]")
	print_line("[color=white]help[/color] - Show this help message")
	print_line("[color=white]clear / cls[/color] - Clear console output")
	print_line("[color=white]quit / exit[/color] - Close console")
	print_line("")
	print_line("[color=cyan]=== GM Commands ===[/color]")
	print_line("[color=white]/gm reset[/color] - Reset all game data")
	print_line("[color=white]/gm reload[/color] - Reload game (restart from main menu)")
	print_line("[color=white]/gm unlock_all[/color] - Unlock all stages")
	print_line("[color=white]/gm add_gold <amount>[/color] - Add gold")
	print_line("[color=white]/gm add_card <card_id>[/color] - Add card to collection")

# ==================== 命令歷史 ====================

func add_to_history(command: String):
	"""添加命令到歷史"""
	if command_history.size() >= max_history:
		command_history.pop_front()
	command_history.append(command)
	history_index = command_history.size()

func navigate_history(direction: int):
	"""瀏覽命令歷史"""
	if command_history.is_empty():
		return

	history_index = clamp(history_index + direction, 0, command_history.size())

	if history_index < command_history.size():
		input_field.text = command_history[history_index]
		input_field.caret_column = input_field.text.length()
	else:
		input_field.clear()
