extends Node
## 全局游戏状态（自动加载单例 GameState）
## ------------------------------------------------------------
## 存储跨场景数据：对局模式、玩家执子颜色、累计比分、音效开关。
## 场景之间通过它传递「开局选择」，避免用全局变量满处乱飞。

## 对局模式
enum Mode {
	PVP,   ## 双人对战
	PVE,   ## 人机对战
}

## 开局设置（由主菜单写入，由 game.tscn 读取）
var mode: int = Mode.PVP
var human_color: int = 1        ## 人机模式下玩家执子：1=黑 2=白

## 累计比分（返回主菜单后仍保留，直到手动重置）
var score_black := 0
var score_white := 0
var score_draw := 0

## 音效开关镜像（真正生效的是 Sfx.enabled）
var sound_on := true


## 重置比分。
func reset_scores() -> void:
	score_black = 0
	score_white = 0
	score_draw = 0


## 记录一局结果。winner: 1=黑胜 2=白胜 0=平局
func record_result(winner: int) -> void:
	match winner:
		1:
			score_black += 1
		2:
			score_white += 1
		_:
			score_draw += 1


## mode 的中文描述，供 UI 使用。
func mode_text() -> String:
	return "双人对战" if mode == Mode.PVP else "人机对战"


## 玩家执子颜色描述（仅人机模式有意义）。
func color_text() -> String:
	return "黑棋" if human_color == 1 else "白棋"
