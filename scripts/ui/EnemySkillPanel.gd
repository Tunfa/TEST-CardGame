# EnemySkillPanel.gd
# 敌人技能查看面板
extends PanelContainer

signal close_requested

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var skill_list = $MarginContainer/VBoxContainer/ScrollContainer/SkillList
@onready var close_button = $MarginContainer/VBoxContainer/CloseButton

func _ready():
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	# ESC 键关闭
	set_process_input(true)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_button_pressed()

func setup(enemy_data: EnemyData):
	"""设置显示敌人技能信息"""
	if not enemy_data:
		return

	# 设置标题
	if title_label:
		title_label.text = "%s - 技能列表" % enemy_data.enemy_name

	# 清空旧内容
	if skill_list:
		for child in skill_list.get_children():
			child.queue_free()

	# 显示被动技能
	if not enemy_data.passive_skills.is_empty():
		_add_section_header("【被動技能】")
		for skill in enemy_data.passive_skills:
			_add_skill_info(skill)

	# 显示攻击技能
	if not enemy_data.attack_skills.is_empty():
		_add_section_header("【攻擊技能】")
		for skill in enemy_data.attack_skills:
			_add_skill_info(skill)

	# 如果没有技能
	if enemy_data.passive_skills.is_empty() and enemy_data.attack_skills.is_empty():
		var no_skill_label = Label.new()
		no_skill_label.text = "此敵人沒有特殊技能"
		no_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_list.add_child(no_skill_label)

func _add_section_header(text: String):
	"""添加分组标题"""
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # ✅ 居中
	skill_list.add_child(header)

	# 添加分隔线
	var separator = HSeparator.new()
	skill_list.add_child(separator)

func _add_skill_info(skill):
	"""添加单个技能信息"""
	if not skill:
		return

	# 创建技能容器
	var skill_container = VBoxContainer.new()
	skill_container.add_theme_constant_override("separation", 8)  # ✅ 增加間距

	# 技能名称
	var name_label = Label.new()
	name_label.text = "◆ %s" % skill.skill_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.8, 1.0, 1.0))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # ✅ 居中
	skill_container.add_child(name_label)

	# 技能描述（效果說明）
	if skill.skill_description and not skill.skill_description.is_empty():
		var desc_label = Label.new()
		desc_label.text = "效果：%s" % skill.skill_description  # ✅ 移除前導空格
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # ✅ 居中
		desc_label.custom_minimum_size = Vector2(400, 0)  # ✅ 設置最小寬度，讓描述不會太擠
		skill_container.add_child(desc_label)
	else:
		# 如果沒有描述，顯示提示
		var no_desc_label = Label.new()
		no_desc_label.text = "（暫無效果描述）"  # ✅ 移除前導空格
		no_desc_label.add_theme_font_size_override("font_size", 12)
		no_desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		no_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # ✅ 居中
		skill_container.add_child(no_desc_label)

	skill_list.add_child(skill_container)

	# 添加间隔
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	skill_list.add_child(spacer)

func _on_close_button_pressed():
	"""关闭按钮被点击"""
	close_requested.emit()
	queue_free()
