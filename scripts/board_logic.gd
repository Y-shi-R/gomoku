extends RefCounted
class_name GomokuBoard
## 棋盘数据模型（纯逻辑层）
## ------------------------------------------------------------
## 职责：只管「棋盘上有什么、能不能落、谁赢了」，完全不涉及绘制与动画。
## 用一维 PackedInt32Array 保存 15×15 数据：index = row * SIZE + col。
## 表现层（board_view.gd）通过信号与本类的 get_cell() 同步画面。

signal cell_placed(row: int, col: int, color: int)      ## 落子成功
signal stone_removed(row: int, col: int, color: int)    ## 悔棋撤销了一颗子

const EMPTY := 0
const BLACK := 1
const WHITE := 2

## 棋盘规格：标准 15 路
const SIZE := 15
## 四个方向向量：横、竖、撇(↗)、捺(↘)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1)
]
## 连成几子获胜
const WIN_COUNT := 5

## 落子历史（按顺序），元素为 Vector2i(col, row)，用于悔棋
var history: Array[Vector2i] = []

## 一维棋盘数据
var _cells: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	clear()


## 清空棋盘，回到初始状态。
func clear() -> void:
	_cells = PackedInt32Array()
	_cells.resize(SIZE * SIZE)
	_cells.fill(EMPTY)
	history.clear()


## 坐标是否落在棋盘内。
func is_inside(row: int, col: int) -> bool:
	return row >= 0 and row < SIZE and col >= 0 and col < SIZE


## 读取某格状态；越界返回 -1，方便调用方判断边界。
func get_cell(row: int, col: int) -> int:
	if not is_inside(row, col):
		return -1
	return _cells[row * SIZE + col]


## 该点是否为空。
func is_empty(row: int, col: int) -> bool:
	return get_cell(row, col) == EMPTY


## 棋盘是否已下满。
func is_full() -> bool:
	return history.size() >= SIZE * SIZE


## 落子：成功返回 true。
## 只负责「写数据 + 通知表现层」，胜负判定由调用方调用 check_winner 完成。
func place_stone(row: int, col: int, color: int) -> bool:
	if not is_empty(row, col):
		return false
	if color != BLACK and color != WHITE:
		return false
	_cells[row * SIZE + col] = color
	history.append(Vector2i(col, row))
	cell_placed.emit(row, col, color)
	return true


## 悔棋：撤销最后一颗棋子，返回 {row, col, color}；无子可撤返回空字典。
func undo_last() -> Dictionary:
	if history.is_empty():
		return {}
	var last: Vector2i = history.pop_back() as Vector2i
	var row: int = int(last.y)
	var col: int = int(last.x)
	var color: int = _cells[row * SIZE + col]
	_cells[row * SIZE + col] = EMPTY
	stone_removed.emit(row, col, color)
	return {"row": row, "col": col, "color": color}


## 【独立胜负判定函数】检查 (row, col) 处刚落下的 color 是否形成五连。
## 返回获胜的五个坐标 Vector2i(col, row)（长连时取连续的五个），未获胜返回空数组。
## 实现：沿四个方向向两侧延伸，统计连续同色棋子长度，>= 5 即胜。
func check_winner(row: int, col: int, color: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if get_cell(row, col) != color:
		return result

	for dir: Vector2i in DIRECTIONS:
		var line: Array[Vector2i] = [Vector2i(col, row)]

		# 正方向延伸
		var r: int = row + dir.x
		var c: int = col + dir.y
		while get_cell(r, c) == color:
			line.append(Vector2i(c, r))
			r += dir.x
			c += dir.y

		# 反方向延伸
		r = row - dir.x
		c = col - dir.y
		while get_cell(r, c) == color:
			line.append(Vector2i(c, r))
			r -= dir.x
			c -= dir.y

		if line.size() >= WIN_COUNT:
			for i in range(WIN_COUNT):
				result.append(line[i])
			return result
	return result


## 是否平局（棋盘下满且无人获胜时由控制器判定）。
func is_draw() -> bool:
	return is_full()


## 生成一份棋盘快照（一维数组拷贝），供 AI 在副本上推演。
func snapshot() -> PackedInt32Array:
	return _cells.duplicate()


## 从快照恢复数据（AI 推演用）。
func load_snapshot(data: PackedInt32Array) -> void:
	if data.size() == SIZE * SIZE:
		_cells = data.duplicate()
