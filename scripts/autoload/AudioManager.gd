# AudioManager.gd
extends Node

# 1. 預先載入你的音效檔
#    (請將 "res://..." 路徑替換成您自己的音效檔案路徑)
var sfx_library = {
	"player_attack": preload("res://resources/audio/sfx/092-Attack04.ogg"), # 範例路徑
	"enemy_attack": preload("res://resources/audio/sfx/117-Fire01.ogg"),   # 範例路徑
	"skill1": preload("res://resources/audio/sfx/098-Attack10.ogg"),     # 範例路徑
	"orb_match": preload("res://resources/audio/sfx/096-Attack08.ogg"), # 範例路徑+
	"orb_metal": preload("res://resources/audio/sfx/135-Light01.ogg"),
	"orb_wood": preload("res://resources/audio/sfx/042-Knock03.ogg"),
	"orb_water": preload("res://resources/audio/sfx/126-Water01.ogg"),
	"orb_fire": preload("res://resources/audio/sfx/118-Fire02.ogg"),
	"orb_earth": preload("res://resources/audio/sfx/129-Earth01.ogg"),
	"wave_move": preload("res://resources/audio/sfx/013-Move01.ogg"),
	"victory": preload("res://resources/audio/sfx/戰鬥勝利.mp3"),
	"orb_heart": preload("res://resources/audio/sfx/105-Heal01.ogg")
	# ... 您可以繼續添加更多音效
}

# 2. 創建 AudioStreamPlayer 節點池
#    這可以避免一個音效還沒播完又被立即觸發導致被切斷的問題
var audio_players = []

func _ready():
	# 預先創建幾個播放器節點
	for i in range(5): # 5個播放器應該足夠同時播放多個音效
		var player = AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)

# 3. 創建一個全局播放函數
func play_sfx(sound_name: String):
	# 檢查音效是否存在
	if not sfx_library.has(sound_name):
		push_error("AudioManager: 找不到音效: " + sound_name)
		return
	
	# 尋找一個當前沒有在播放的播放器
	for player in audio_players:
		if not player.is_playing():
			player.stream = sfx_library[sound_name]
			player.play()
			return
	
	# (可選) 如果所有播放器都在忙，動態新增一個
	var new_player = AudioStreamPlayer.new()
	add_child(new_player)
	audio_players.append(new_player)
	new_player.stream = sfx_library[sound_name]
	new_player.play()
