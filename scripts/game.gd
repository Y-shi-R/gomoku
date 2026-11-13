extends Control
## 对局控制器（游戏主场景逻辑）
## ------------------------------------------------------------
## 职责：串联「逻辑层 ↔ 表现层 ↔ UI」，处理回合推进、胜负/平局、悔棋、重新开局、
## AI 调度、比分与结果面板。
## 设计要点：棋盘规则全在 GomokuBoard，AI 全在 GomokuAI，本脚本只管流程。

const MENU_SCENE := "res://scenes/main_menu.tscn"
const AI_THINK_DELAY := 0.42      ## AI「思考」延时（秒），让玩家看得清

var board: GomokuBoard                          ## 逻辑棋盘
var current_player: int = GomokuBoard.BLACK     ## 当前该谁下
var game_over := false

## 当前对局中 AI 的颜色（双人模式下为 0）
var ai_color := 0

## 本局是否已经计入比分（用于结束后悔棋时回退分数）
var _round_counted := false
var _round_winner := 0          ## 0=平局 1=黑 2=白

var _ai_timer := 0.0
var _ai_pending := false

@onready var _board_view: Control = $Root/Layout/BoardArea/Board
@onready var _turn_label: Label = $Root/Layout/TopBar/TopBox/TurnBox/TurnLabel
@onready var _turn_stone: Control = $Root/Layout/TopBar/TopBox/TurnBox/TurnStone
@onready var _score_label: Label = $Root/Layout/TopBar/TopBox/ScoreLabel
@onready var _mode_label: Label = $Root/Layout/TopBar/TopBox/ModeLabel
@onready var _undo_button: Button = $Root/Layout/BottomBar/Buttons/UndoButton
@onready var _restart_button: Button = $Root/Layout/BottomBar/Buttons/RestartButton
@onready var _sound_button: Button = $Root/Layout/BottomBar/Buttons/SoundButton
@onready var _menu_button: Button = $Root/Layout/BottomBar/Buttons/MenuButton
@onready var _result_panel: PanelContainer = $ResultPanel
@onready var _result_title: Label = $ResultPanel/ResultBox/ResultTitle
@onready var _result_detail: Label = $ResultPanel/ResultBox/ResultDetail
@onready var _again_button: Button = $ResultPanel/ResultBox/ResultButtons/AgainButton
@onready var _result_menu_button: Button = $ResultPanel/ResultBox/ResultButtons/ResultMenuButton


func _ready() -> void:
	# 逻辑层
	board = GomokuBoard.new()
	# 表现层绑定逻辑层
	_board_view.bind_board(board)
	_board_view.point_clicked.connect(_on_point_clicked)

	# 按钮信号
	_restart_button.pressed.connect(_on_restart_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	_sound_button.pressed.connect(_on_sound_pressed)
	_menu_button.pressed.connect(_return_to_menu)
	_again_button.pressed.connect(_on_restart_pressed)
	_result_menu_button.pressed.connect(_return_to_menu)

	# 同步音效按钮初始文案
	Sfx.enabled = GameState.sound_on
	_start_new_round()


# ---------------------------------------------------------------- 一局的生命周期

## 开新一局（保留累计比分）。
func _start_new_round() -> void:
	board.clear()
	_board_view.reset_view()
	game_over = false
	_round_counted = false
	_round_winner = 0
	_result_panel.visible = false
	current_player = GomokuBoard.BLACK

	# 人机模式：根据玩家执子颜色推算 AI 颜色
	ai_color = 0
	if GameState.mode == GameState.Mode.PVE:
		ai_color = GomokuBoard.WHITE if GameState.human_color == GomokuBoard.BLACK else GomokuBoard.BLACK

	_refresh_hud()
	_maybe_start_ai_turn()


## 刷新顶部栏（当前回合 + 比分 + 悔棋按钮可用性 + 音效按钮文案）。
func _refresh_hud() -> void:
	if not game_over:
		var is_black: bool = current_player == GomokuBoard.BLACK
		var stone_name := "黑棋" if is_black else "白棋"
		var turn_text := stone_name + "回合"
		# 人机模式下区分「你」和「电脑」
		if ai_color != 0:
			turn_text = "%s思考中…" % stone_name if current_player == ai_color else "%s回合（你）" % stone_name
		_turn_label.text = turn_text
		_turn_stone.set_color(current_player)
		_board_view.preview_color = current_player
	_update_score_label()
	_undo_button.disabled = board.history.is_empty()
	_sound_button.text = "音效 开" if Sfx.enabled else "音效 关"
	# 模式提示：双人 / 人机（你执黑或执白）
	if ai_color == 0:
		_mode_label.text = "双人对战"
	else:
		var mine := "黑" if GameState.human_color == GomokuBoard.BLACK else "白"
		_mode_label.text = "人机对战 · 你执%s" % mine


func _update_score_label() -> void:
	_score_label.text = "黑 %d  ·  平 %d  ·  白 %d" % [
		GameState.score_black, GameState.score_draw, GameState.score_white
	]


# ---------------------------------------------------------------- 落子

## 棋盘被点击（表现层已保证是空点）。
func _on_point_clicked(row: int, col: int) -> void:
	if game_over or _ai_pending:
		return
	# 人机模式下，不在玩家回合时忽略点击
	if ai_color != 0 and current_player == ai_color:
		return
	_place(row, col)


## 统一落子入口：写数据 → 音效 → 判定胜负 → 切换回合。
func _place(row: int, col: int) -> void:
	if not board.place_stone(row, col, current_player):
		return
	Sfx.play_place(current_player)

	var win_cells := board.check_winner(row, col, current_player)
	if not win_cells.is_empty():
		_finish_round(current_player, win_cells)
		return
	if board.is_draw():
		_finish_round(0, [])
		return

	current_player = GomokuBoard.WHITE if current_player == GomokuBoard.BLACK else GomokuBoard.BLACK
	_refresh_hud()
	_maybe_start_ai_turn()


# ---------------------------------------------------------------- 结算

## 结束一局。winner: 1=黑 2=白 0=平局
func _finish_round(winner: int, win_cells: Array[Vector2i]) -> void:
	game_over = true
	_ai_pending = false
	_board_view.interactive = false
	GameState.record_result(winner)
	_round_counted = true
	_round_winner = winner
	_update_score_label()

	if winner == 0:
		Sfx.play_undo()
		_turn_label.text = "平局"
		_result_title.text = "和局"
		_result_title.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
		_result_detail.text = "棋盘已满，势均力敌"
		_turn_stone.set_color(0)
	else:
		Sfx.play_win()
		_board_view.show_win(win_cells)
		var stone_name := "黑棋" if winner == GomokuBoard.BLACK else "白棋"
		_turn_label.text = "%s胜利" % stone_name
		_result_title.text = "%s胜利" % stone_name
		_result_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
		# 人机模式下说明是玩家胜还是电脑胜
		if ai_color != 0:
			_result_detail.text = "恭喜你赢了电脑" if winner != ai_color else "电脑赢了，再来一局？"
		else:
			_result_detail.text = "五子连珠，漂亮"
		_turn_stone.set_color(winner)

	_undo_button.disabled = false
	# 延迟一点再弹面板，让玩家先看到高亮
	await get_tree().create_timer(0.75).timeout
	if is_inside_tree() and game_over:
		_result_panel.visible = true


# ---------------------------------------------------------------- AI

## 若下一个该 AI 落子，则启动延时思考。
func _maybe_start_ai_turn() -> void:
	if game_over or ai_color == 0 or current_player != ai_color:
		_board_view.interactive = true
		return
	_board_view.interactive = false
	_ai_pending = true
	_ai_timer = AI_THINK_DELAY
	set_process(true)


func _process(delta: float) -> void:
	if not _ai_pending:
		set_process(false)
		return
	_ai_timer -= delta
	if _ai_timer > 0.0:
		return

	_ai_pending = false
	set_process(false)
	if game_over:
		return

	var move := GomokuAI.choose_move(board, ai_color)
	if move.x < 0:
		_finish_round(0, [])
		return
	_place(move.y, move.x)


# ---------------------------------------------------------------- 按钮

## 悔棋：人机模式一次撤两步（电脑 + 玩家），双人模式撤一步。
func _on_undo_pressed() -> void:
	if _ai_pending or board.history.is_empty():
		return

	# 若已结束，先收拾结算状态与比分，回到可下状态
	if game_over:
		game_over = false
		_result_panel.visible = false
		_board_view.clear_win()
		if _round_counted:
			_revoke_score(_round_winner)
			_round_counted = false

	var steps := 1
	if ai_color != 0 and board.history.size() >= 2:
		steps = 2

	for i in steps:
		board.undo_last()

	# 重新确定轮到谁：偶数子轮到黑棋，奇数子轮到白棋
	current_player = GomokuBoard.BLACK if board.history.size() % 2 == 0 else GomokuBoard.WHITE
	Sfx.play_undo()
	_refresh_hud()
	_board_view.interactive = true

	# 悔棋后若恰好轮到 AI（例如玩家执白），让 AI 补一手
	_maybe_start_ai_turn()


## 回退一条比分记录。winner: 0=平局 1=黑 2=白
func _revoke_score(winner: int) -> void:
	match winner:
		GomokuBoard.BLACK:
			GameState.score_black = maxi(0, GameState.score_black - 1)
		GomokuBoard.WHITE:
			GameState.score_white = maxi(0, GameState.score_white - 1)
		_:
			GameState.score_draw = maxi(0, GameState.score_draw - 1)
	_update_score_label()


func _on_restart_pressed() -> void:
	Sfx.play_place(GomokuBoard.BLACK)
	_start_new_round()


func _on_sound_pressed() -> void:
	Sfx.enabled = not Sfx.enabled
	GameState.sound_on = Sfx.enabled
	if Sfx.enabled:
		Sfx.play_place(GomokuBoard.BLACK)
	_refresh_hud()


func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
