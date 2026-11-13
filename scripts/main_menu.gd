extends Control
## 主菜单控制器
## ------------------------------------------------------------
## 职责：选择对局模式与执子颜色，写入全局 GameState，然后跳转到对局场景。
## 选中的按钮会被手动标成金黄高亮（普通 Button 没有「锁定选中」状态）。

const GAME_SCENE := "res://scenes/game.tscn"

## 选中/未选中按钮的颜色配置
const COLOR_SELECTED_BG := Color(0.757, 0.549, 0.259)
const COLOR_SELECTED_BORDER := Color(1.0, 0.859, 0.573)
const COLOR_NORMAL_BG := Color(0.278, 0.2, 0.137)
const COLOR_NORMAL_BORDER := Color(0.451, 0.325, 0.196)

@onready var _pvp_button: Button = $Center/CenterBox/MainBox/ModeRow/PvpButton
@onready var _pve_button: Button = $Center/CenterBox/MainBox/ModeRow/PveButton
@onready var _black_button: Button = $Center/CenterBox/MainBox/ColorRow/BlackButton
@onready var _white_button: Button = $Center/CenterBox/MainBox/ColorRow/WhiteButton
@onready var _start_button: Button = $Center/CenterBox/MainBox/StartButton
@onready var _score_label: Label = $Center/CenterBox/Footer/ScoreLabel


func _ready() -> void:
	_pvp_button.pressed.connect(_on_pvp_pressed)
	_pve_button.pressed.connect(_on_pve_pressed)
	_black_button.pressed.connect(_on_black_pressed)
	_white_button.pressed.connect(_on_white_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_refresh_ui()


## 刷新选中态与比分显示。
func _refresh_ui() -> void:
	var is_pvp: bool = GameState.mode == GameState.Mode.PVP
	_style_toggle(_pvp_button, is_pvp)
	_style_toggle(_pve_button, not is_pvp)

	var is_black: bool = GameState.human_color == GomokuBoard.BLACK
	_style_toggle(_black_button, is_black)
	_style_toggle(_white_button, not is_black)

	# 双人模式下「执子颜色」不生效，置灰提示
	_black_button.disabled = is_pvp
	_white_button.disabled = is_pvp

	_score_label.text = "比分   黑 %d : %d 白   平局 %d" % [
		GameState.score_black, GameState.score_white, GameState.score_draw
	]


## 把一个按钮画成选中金框 / 普通棕框。
func _style_toggle(button: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(12.0)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.bg_color = COLOR_SELECTED_BG if selected else COLOR_NORMAL_BG
	style.border_color = COLOR_SELECTED_BORDER if selected else COLOR_NORMAL_BORDER
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_color_override("font_color", Color(0.16, 0.11, 0.06) if selected else Color(0.965, 0.929, 0.867))


func _on_pvp_pressed() -> void:
	GameState.mode = GameState.Mode.PVP
	Sfx.play_undo()
	_refresh_ui()


func _on_pve_pressed() -> void:
	GameState.mode = GameState.Mode.PVE
	Sfx.play_undo()
	_refresh_ui()


func _on_black_pressed() -> void:
	GameState.human_color = GomokuBoard.BLACK
	Sfx.play_place(GomokuBoard.BLACK)
	_refresh_ui()


func _on_white_pressed() -> void:
	GameState.human_color = GomokuBoard.WHITE
	Sfx.play_place(GomokuBoard.WHITE)
	_refresh_ui()


func _on_start_pressed() -> void:
	Sfx.play_place(GomokuBoard.BLACK)
	get_tree().change_scene_to_file(GAME_SCENE)
