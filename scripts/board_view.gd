@tool
extends Control
class_name GomokuBoardView
## 棋盘表现层（只负责画与鼠标交互，不保存棋局规则）
## ------------------------------------------------------------
## 木纹、网格、星位、棋子、落子动画、悬停预览、胜利高亮全部用 _draw() 程序化绘制，
## 不依赖任何外部图片。数据来源是绑定进来的 GomokuBoard（逻辑层）。

## 鼠标点击了有效的空交叉点
signal point_clicked(row: int, col: int)

const SIZE := 15
const CELL := 46.0          ## 相邻交叉点间距
const PAD := 46.0           ## 棋盘边缘留白（要能容下一颗棋子）
const STONE_R := 20.0       ## 棋子半径
const PLACE_ANIM := 0.20    ## 落子动画时长（秒）

## 逻辑棋盘（由 game.gd 注入）
var board = null

## 当前该谁下（用于悬停预览颜色）
var preview_color := 1
## 是否允许鼠标交互（AI 思考中、对局结束时置 false）
var interactive := false

var _hover := Vector2i(-1, -1)          ## 悬停的交叉点 (col, row)
var _last_move := Vector2i(-1, -1)      ## 最近一手
var _anims := {}                        ## 正在播放动画的棋子：Vector2i -> 已播放秒数
var _win_cells: Array[Vector2i] = []    ## 获胜的五颗棋子
var _win_time := 0.0
var _grains: Array = []                 ## 预生成的木纹线条


func _ready() -> void:
	_build_grains()
	custom_minimum_size = Vector2(SIZE * CELL - CELL + PAD * 2.0, SIZE * CELL - CELL + PAD * 2.0)
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## 绑定逻辑棋盘：把逻辑层的落子/悔棋信号接到表现层。
func bind_board(b) -> void:
	board = b
	if not board.cell_placed.is_connected(_on_cell_placed):
		board.cell_placed.connect(_on_cell_placed)
	if not board.stone_removed.is_connected(_on_stone_removed):
		board.stone_removed.connect(_on_stone_removed)
	queue_redraw()


## 重置显示状态（重新开局时调用）。
func reset_view() -> void:
	_hover = Vector2i(-1, -1)
	_last_move = Vector2i(-1, -1)
	_anims.clear()
	_win_cells.clear()
	_win_time = 0.0
	interactive = false
	set_process(false)
	queue_redraw()


## 高亮获胜的五颗棋子。
func show_win(cells: Array[Vector2i]) -> void:
	_win_cells = cells.duplicate()
	_win_time = 0.0
	set_process(true)
	queue_redraw()


## 清除胜利高亮。
func clear_win() -> void:
	_win_cells.clear()
	_win_time = 0.0
	queue_redraw()


# ---------------------------------------------------------------- 逻辑层信号

func _on_cell_placed(row: int, col: int, _color: int) -> void:
	_anims[Vector2i(col, row)] = 0.0
	_last_move = Vector2i(col, row)
	set_process(true)
	queue_redraw()


func _on_stone_removed(row: int, col: int, _color: int) -> void:
	_anims.erase(Vector2i(col, row))
	if board != null and not board.history.is_empty():
		_last_move = board.history[board.history.size() - 1]
	else:
		_last_move = Vector2i(-1, -1)
	queue_redraw()


func _process(delta: float) -> void:
	var busy := false
	# 推进落子动画
	if not _anims.is_empty():
		for key in _anims.keys():
			var t: float = _anims[key] + delta
			if t >= PLACE_ANIM:
				_anims.erase(key)
			else:
				_anims[key] = t
				busy = true
	# 推进胜利高亮呼吸
	if not _win_cells.is_empty():
		_win_time += delta
		busy = true
	if not busy:
		set_process(false)
	queue_redraw()


# ---------------------------------------------------------------- 鼠标输入

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _position_to_cell(event.position)
		if cell != _hover:
			_hover = cell
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and interactive:
			var cell := _position_to_cell(event.position)
			if cell.x >= 0:
				point_clicked.emit(cell.y, cell.x)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if _hover != Vector2i(-1, -1):
			_hover = Vector2i(-1, -1)
			queue_redraw()


## 像素坐标 -> 最近的交叉点 (col, row)；超出容忍范围返回 (-1, -1)。
func _position_to_cell(pos: Vector2) -> Vector2i:
	var col := int(round((pos.x - PAD) / CELL))
	var row := int(round((pos.y - PAD) / CELL))
	if row < 0 or row >= SIZE or col < 0 or col >= SIZE:
		return Vector2i(-1, -1)
	var center := _cell_to_position(col, row)
	if pos.distance_to(center) > CELL * 0.48:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


## 交叉点 -> 像素坐标。
func _cell_to_position(col: int, row: int) -> Vector2:
	return Vector2(PAD + col * CELL, PAD + row * CELL)


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	_draw_wood()
	_draw_grid()
	_draw_star_points()
	_draw_stones()
	_draw_hover_preview()
	_draw_win_highlight()


## 预生成木纹线条（固定种子，每次运行纹理一致）。
func _build_grains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261114
	var board_px := SIZE * CELL - CELL + PAD * 2.0
	for i in 46:
		var y := rng.randf_range(4.0, board_px - 4.0)
		var amp := rng.randf_range(1.0, 5.0)
		var phase := rng.randf_range(0.0, TAU)
		var freq := rng.randf_range(0.008, 0.02)
		var points := PackedVector2Array()
		var x := 0.0
		while x <= board_px:
			points.append(Vector2(x, y + sin(x * freq + phase) * amp))
			x += 22.0
		_grains.append({
			"points": points,
			"width": rng.randf_range(0.8, 2.4),
			"alpha": rng.randf_range(0.04, 0.13),
		})


## 木板底色 + 木纹 + 边框。
func _draw_wood() -> void:
	var board_px := SIZE * CELL - CELL + PAD * 2.0
	var rect := Rect2(Vector2.ZERO, Vector2(board_px, board_px))

	# 底色（中心稍亮，仿旧木板）
	draw_rect(rect, Color(0.839, 0.663, 0.427))
	draw_rect(rect.grow(-6.0), Color(0.878, 0.714, 0.478))

	# 木纹
	for g in _grains:
		draw_polyline(g["points"], Color(0.427, 0.290, 0.149, g["alpha"]), g["width"], true)

	# 内阴影（靠近边框变暗，增加立体感）
	for i in 5:
		var inset := float(i) * 2.5
		draw_rect(rect.grow(-inset), Color(0.3, 0.19, 0.09, 0.05), false, 2.5, true)

	# 外框
	draw_rect(rect, Color(0.286, 0.184, 0.098), false, 8.0, true)
	draw_rect(rect.grow(-8.0), Color(0.474, 0.325, 0.176, 0.65), false, 1.5, true)


## 15×15 网格。
func _draw_grid() -> void:
	var line_color := Color(0.267, 0.176, 0.094, 0.78)
	var end := PAD + (SIZE - 1) * CELL
	for i in SIZE:
		var p := PAD + i * CELL
		draw_line(Vector2(PAD, p), Vector2(end, p), line_color, 1.5, true)
		draw_line(Vector2(p, PAD), Vector2(p, end), line_color, 1.5, true)
	# 外框线加粗
	draw_rect(Rect2(Vector2(PAD, PAD), Vector2(end - PAD, end - PAD)), line_color, false, 2.5, true)


## 天元与四个星位。
func _draw_star_points() -> void:
	var stars: Array[Vector2i] = [
		Vector2i(7, 7), Vector2i(3, 3), Vector2i(11, 3), Vector2i(3, 11), Vector2i(11, 11)
	]
	for s: Vector2i in stars:
		var center := _cell_to_position(s.x, s.y)
		draw_circle(center, 5.0 if s == Vector2i(7, 7) else 4.0, Color(0.216, 0.137, 0.071, 0.9), true, -1.0, true)


## 所有棋子（带落子缩放动画）。
func _draw_stones() -> void:
	if board == null:
		return
	for row in SIZE:
		for col in SIZE:
			var color: int = board.get_cell(row, col)
			if color == 0:
				continue
			var center := _cell_to_position(col, row)
			var key := Vector2i(col, row)
			var scale_factor := 1.0
			var alpha := 1.0
			if _anims.has(key):
				var t: float = clampf(float(_anims[key]) / PLACE_ANIM, 0.0, 1.0)
				var eased := 1.0 - pow(1.0 - t, 3.0)
				scale_factor = lerpf(0.45, 1.0, eased)
				alpha = lerpf(0.15, 1.0, eased)
			_draw_stone(center, STONE_R * scale_factor, color, alpha)
			# 最近一手标记（红点）
			if key == _last_move and not _anims.has(key):
				draw_circle(center, 4.0, Color(0.949, 0.259, 0.259, 0.95), true, -1.0, true)


## 单颗棋子：黑棋带高光、白棋带描边，均有立体感。
func _draw_stone(center: Vector2, radius: float, color: int, alpha: float) -> void:
	# 投影
	draw_circle(center + Vector2(1.5, 2.5), radius * 1.02, Color(0.1, 0.06, 0.02, 0.22 * alpha), true, -1.0, true)
	if color == 1:
		draw_circle(center, radius, Color(0.07, 0.07, 0.085, alpha), true, -1.0, true)
		draw_circle(center + Vector2(-radius * 0.20, -radius * 0.24), radius * 0.62, Color(0.26, 0.27, 0.30, 0.75 * alpha), true, -1.0, true)
		draw_circle(center + Vector2(-radius * 0.32, -radius * 0.38), radius * 0.20, Color(0.88, 0.90, 0.95, 0.60 * alpha), true, -1.0, true)
	else:
		draw_circle(center, radius, Color(0.965, 0.953, 0.925, alpha), true, -1.0, true)
		draw_circle(center, radius * 0.99, Color(0.663, 0.635, 0.576, 0.85 * alpha), false, 1.6, true)
		draw_circle(center + Vector2(-radius * 0.28, -radius * 0.32), radius * 0.45, Color(1.0, 1.0, 1.0, 0.55 * alpha), true, -1.0, true)


## 悬停半透明预览。
func _draw_hover_preview() -> void:
	if not interactive or _hover.x < 0:
		return
	if board == null or not board.is_empty(_hover.y, _hover.x):
		return
	var center := _cell_to_position(_hover.x, _hover.y)
	_draw_stone(center, STONE_R * 0.96, preview_color, 0.38)
	draw_circle(center, STONE_R + 3.0, Color(1.0, 1.0, 1.0, 0.28), false, 1.5, true)


## 获胜五子高亮（呼吸光晕）。
func _draw_win_highlight() -> void:
	if _win_cells.is_empty():
		return
	var pulse := 0.55 + 0.45 * sin(_win_time * 6.0)
	for c: Vector2i in _win_cells:
		var center := _cell_to_position(c.x, c.y)
		draw_circle(center, STONE_R + 4.0 + pulse * 3.0, Color(1.0, 0.78, 0.22, 0.55 + 0.35 * pulse), false, 3.0, true)
		draw_circle(center, STONE_R + 2.0, Color(1.0, 0.62, 0.10, 0.35), false, 1.5, true)
