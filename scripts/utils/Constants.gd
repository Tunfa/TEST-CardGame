# Constants.gd
# 全局常數和枚舉定義
class_name Constants
extends Node

# ==================== 技能相關枚舉 ====================

# 技能類型
enum SkillType {
	PASSIVE,    # 被動技能（隊長技能）
	ACTIVE,     # 主動技能
	ENEMY       # 敵人技能/條件
}

# 技能觸發時機
enum TriggerTiming {
	PERMANENT,        # 永久生效（屬性倍率類）
	BATTLE_START,     # 戰鬥開始時
	TURN_START,       # 回合開始時
	TURN_END,         # 回合結束時
	BEFORE_ATTACK,    # 攻擊前
	AFTER_ATTACK,     # 攻擊後
	BEFORE_DAMAGED,   # 受傷前
	AFTER_DAMAGED,    # 受傷後
	ON_ATTACK,        # 敵人攻擊時（用於敵人attack_skills）
	ON_DAMAGE_CALC,   # 傷害計算時
	ON_ORB_GEN,       # 靈珠生成時
	ON_SLASH,         # 斬擊時
	MANUAL           # 手動觸發（主動技能）
}

# 技能目標類型
enum TargetType {
	SELF,             # 自己
	SINGLE_ENEMY,    # 單一敵人
	ALL_ENEMIES,     # 所有敵人
	SINGLE_ALLY,     # 單一隊友
	ALL_ALLIES,      # 所有隊友
	RANDOM_ENEMY,    # 隨機敵人
}

# ==================== 技能效果類型 ====================
# 隊長技能效果類型（模組化設計）
enum LeaderSkillEffectType {
	# 1. 傷害倍率類
	DAMAGE_MULTIPLIER,              # X屬性傷害 X 倍
	BASE_DAMAGE_BOOST,              # X屬性基礎傷害提升 X%
	ALL_DAMAGE_BOOST,               # X屬性所有傷害提升 X%（包含主動技能）
	IGNORE_RESISTANCE,              # X屬性傷害無視屬性克制

	# 2. 靈珠相關
	FORCE_ORB_SPAWN,                # 前X粒固定出現X屬性靈珠
	ORB_DROP_ON_SLASH,              # 斬裂X屬性X次掉落X個靈珠
	SLASH_ORB_SPAWN,                # 斬裂X屬性X次立刻出現X個斬擊珠
	ORB_SPAWN_RATE_BOOST,           # X屬性靈珠出現機率額外 X%
	ORB_CAPACITY_BOOST,             # X屬性靈珠最高容量額外增加X個
	ORB_DUAL_EFFECT,                # X屬性靈珠兼具X屬性靈珠 X% 效果
	ORB_DROP_END_TURN,              # 回合結束掉落X粒X屬性靈珠

	# 3. 數值動態倍率類
	ORB_COUNT_MULTIPLIER,           # X屬性靈珠越多X屬性傷害越高 最高X倍
	TEAM_ELEMENT_MULTIPLIER,        # 隊伍中越多X屬性成員 X屬性傷害越高 最高X倍
	TEAM_DIVERSITY_MULTIPLIER,      # 隊伍中越多不同屬性成員 全隊攻擊力越高 最高X倍

	# 4. 屬性倍率類
	HP_MULTIPLIER,                  # X屬性生命力 X 倍
	RECOVERY_MULTIPLIER,            # X屬性回復力 X 倍

	# 5. 時間延長
	EXTEND_SLASH_TIME,              # 額外延長X秒斬擊時間

	# 6. 回合結束效果
	END_TURN_DAMAGE,                # 每回合結束對敵方造成X屬性X傷害
}

# 敵人技能/條件類型
enum EnemySkillEffectType {
	# 條件限制類（不滿足無法造成傷害，但至少1點）
	REQUIRE_COMBO,                  # 需斬擊累積 X 連擊才可對敵人造成傷害
	REQUIRE_COMBO_EXACT,            # 須保持連擊數 = X 連擊才可對敵人造成傷害
	REQUIRE_COMBO_MAX,              # 連擊數不可高於 X 連擊否則無法造成傷害
	REQUIRE_ORB_TOTAL,              # 需斬擊累積 X 粒X屬性靈珠才可對敵人造成傷害
	REQUIRE_ORB_CONTINUOUS,         # 需連續斬擊X粒X屬性靈珠才可對敵人造成傷害
	REQUIRE_ORB_SEQUENCE,           # 需先斬擊X粒X屬性靈珠再斬擊X粒X屬性靈珠才能造成傷害
	REQUIRE_ENEMY_ATTACK,           # 敵人必須先攻擊否則無法造成傷害（條件可繼承回合）
	REQUIRE_ELEMENTS,               # 需斬擊X種屬性靈珠才能造成傷害
	REQUIRE_STORED_ORB_MIN,         # 儲存X屬性靈珠必須達到Y個(含以上)才可對敵人造成傷害
	REQUIRE_STORED_ORB_EXACT,       # 儲存X屬性靈珠必須達到Y個(完全一樣)才可對敵人造成傷害

	# 傷害減免類
	DAMAGE_REDUCTION_PERCENT,       # 降低所受X%傷害
	DAMAGE_REDUCTION_FLAT,          # 降低所受X傷害（固定值）
	DAMAGE_ONCE_ONLY,               # 敵人只會被攻擊一次，第二次以後無法造成傷害

	# 封鎖類
	SEAL_ACTIVE_SKILL,              # 封鎖X回合主動技能
	SEAL_ORB_SWAP,                  # 封鎖X回合靈珠使用（排版）
	DISABLE_ELEMENT_SLASH,          # X回合內X屬性靈珠斬擊無效
	ZERO_RECOVERY,                  # X回合內回復力歸零

	# 敵人強化類
	ENEMY_DAMAGE_BY_PLAYER_ORBS,    # 玩家靈珠越多敵人傷害越高
	ENEMY_DAMAGE_BY_PLAYER_LOW_ORBS,# 玩家靈珠越少敵人傷害越高

	# 靈珠移除類
	REMOVE_RANDOM_ORBS,             # 每回合隨機減少玩家X粒X屬性靈珠

	# 干擾類
	REDUCE_SLASH_TIME,              # 斬擊時間減少X秒
	SPAWN_INVALID_ORBS,             # 斬擊途中隨機出現無效珠
	REDUCE_DAMAGE_TURNS,            # X回合內傷害降低X%

	# 特殊類
	ENTER_HP_TO_ONE,                # 進場生命力扣至1
	DEATH_DAMAGE,                   # 自身死亡時對玩家造成X點傷害
	REVIVE_ONCE,                    # 自身可以復活一次
}

# ==================== 戰鬥相關枚舉 ====================

# 戰鬥階段
enum BattlePhase {
	PLAYER_TURN,    # 玩家回合
	ENEMY_TURN,     # 敵人回合
	BATTLE_END      # 戰鬥結束
}

# 戰鬥結果
enum BattleResult {
	VICTORY,        # 勝利
	DEFEAT,         # 失敗
	ESCAPED         # 逃跑（預留）
}

# ==================== 卡片相關 ====================

# 卡片稀有度
enum CardRarity {
	COMMON,         # 普通
	RARE,           # 稀有
	EPIC,           # 史詩
	LEGENDARY       # 傳說
}

# 卡片種族
enum CardRace {
	HUMAN,          # 人類
	ELF,            # 精靈
	DWARF,          # 矮人
	ORC,            # 獸人
	DEMON,          # 惡魔
	UNDEAD,         # 不死
	DRAGON,         # 龍族
	ELEMENTAL       # 元素
}

# 卡片元素屬性（五行+心）
enum Element {
	METAL,          # 金
	WOOD,           # 木
	WATER,          # 水
	FIRE,           # 火
	EARTH,          # 土
	HEART           # 心
}

# 元素滑動方向
enum SwipeDirection {
	DOWN,           # 向下 (金)
	RIGHT,          # 向右 (木)
	UP,             # 向上 (水)
	LEFT,           # 向左 (火)
	DIAGONAL_DOWN_RIGHT,  # 右下對角線 (土)
	CIRCLE,         # 畫圈 (心)
	TAP             # ✅ 新增：點擊
}

# ==================== 遊戲狀態 ====================

enum GameState {
	MAIN_MENU,      # 主選單
	STAGE_SELECT,   # 關卡選擇
	TEAM_LIST,     # 組隊
	INVENTORY,      # 背包
	BATTLE,         # 戰鬥中
	REWARD          # 獎勵結算
}

# ==================== 遊戲設定常數 ====================

# 背包相關
const DEFAULT_BAG_CAPACITY: int = 20
const BAG_COLUMNS: int = 5  # 背包一行5列

# SP相關
const DEFAULT_MAX_SP: int = 3
const DEFAULT_INITIAL_SP: int = 1

# 隊伍相關
const MAX_TEAM_SIZE: int = 5
const MIN_TEAM_SIZE: int = 1

# 存檔相關
const SAVE_FILE_PATH: String = "user://player_save.json"

# 資料檔案路徑
const CARDS_DATA_PATH: String = "res://data/cards.json"
const ENEMIES_DATA_PATH: String = "res://data/enemies.json"
const STAGES_DATA_PATH: String = "res://data/stages.json"
# 注意：目前技能由 SkillRegistry 自動載入腳本，不使用 JSON 文件
# const SKILLS_DATA_PATH: String = "res://data/skills.json"  # 保留供將來使用
