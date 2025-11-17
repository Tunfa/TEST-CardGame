# ElementOrb.gd
# 元素珠子 - 代表單個可消除的元素
class_name ElementOrb
extends Control

# ==================== 信號 ====================
# 

# ==================== 屬性 ====================
var element: Constants.Element = Constants.Element.METAL
var required_direction: Constants.SwipeDirection = Constants.SwipeDirection.DOWN
var is_active: bool = false  # 是否是當前需要消除的珠子

# ==================== UI 組件 ====================
@onready var orb_sprite = $OrbSprite  # ColorRect 或 Sprite2D
@onready var arrow_label = $ArrowLabel  # 顯示方向提示

# ==================== 元素配置 ====================
var element_colors = {
	Constants.Element.METAL: Color("FFD700"), # 金色
	Constants.Element.WOOD: Color("33CC33"),   # 綠色
	Constants.Element.WATER: Color("3388FF"),  # 藍色
	Constants.Element.FIRE: Color("FF3333"),   # 紅色
	Constants.Element.EARTH: Color("CC9933"),  # 土黃色
	Constants.Element.HEART: Color("FF66CC")   # 亮粉紅
}

var direction_arrows = {
	Constants.SwipeDirection.DOWN: "↓",
	Constants.SwipeDirection.UP: "↑",
	Constants.SwipeDirection.LEFT: "←",
	Constants.SwipeDirection.RIGHT: "→",
	Constants.SwipeDirection.DIAGONAL_DOWN_RIGHT: "↘",
	Constants.SwipeDirection.CIRCLE: "○",
	Constants.SwipeDirection.TAP: "●" # ✅ 新增：點擊的符號
}


# ==================== 初始化 ====================

func _ready():
	# 
	# 
	# 
	update_visual()

func setup(elem: Constants.Element, direction: Constants.SwipeDirection):
	"""設置元素和方向"""
	element = elem
	required_direction = direction
	update_visual()

func update_visual():
	"""更新視覺外觀"""
	if not is_node_ready():
		return

	# 設置顏色
	if orb_sprite:
		orb_sprite.modulate = element_colors.get(element, Color.WHITE)

	# 設置方向箭頭
	if arrow_label and is_active:
		arrow_label.text = direction_arrows.get(required_direction, "?")
		arrow_label.visible = true
	elif arrow_label:
		arrow_label.visible = false

func set_active(active: bool):
	"""設置是否為當前活躍珠子"""
	is_active = active
	update_visual()

	# 添加高亮效果
	if is_active:
		modulate = Color(1.5, 1.5, 1.5)
		# 可以添加閃爍動畫
		create_pulse_animation()
	else:
		modulate = Color.WHITE

func create_pulse_animation():
	"""創建脈衝動畫"""
	var tween = create_tween()
	tween.bind_node(self)  # ✅ 綁定到節點
	tween.set_loops(-1)  # ✅ 使用 -1 表示無限循環
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)


func play_success_effect():
	"""播放成功效果"""
	#AudioManager.play_sfx("orb_match") # ✅ 修正：您尚未定義 "orb_match" 音效，暫時註解
	match element:
		Constants.Element.METAL:
			AudioManager.play_sfx("orb_metal")
		Constants.Element.WOOD:
			AudioManager.play_sfx("orb_wood")
		Constants.Element.WATER:
			AudioManager.play_sfx("orb_water")
		Constants.Element.FIRE:
			AudioManager.play_sfx("orb_fire")
		Constants.Element.EARTH:
			AudioManager.play_sfx("orb_earth")
		Constants.Element.HEART:
			AudioManager.play_sfx("orb_heart")
		_:
			# 如果元素未定義，播放預設音效
			AudioManager.play_sfx("orb_match")

	# 放大後消失
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
	tween.tween_callback(queue_free)

func play_fail_effect():
	"""播放失敗效果"""
	# 搖晃效果
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)
