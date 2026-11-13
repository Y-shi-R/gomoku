extends RefCounted
class_name GomokuAI
## 简单电脑对手（纯逻辑层，无状态）
## ------------------------------------------------------------
## 决策优先级：
##   ① 自己能五连 → 直接落下获胜；
##   ② 对方下一手能五连（四连）→ 立即封堵；
##   ③ 否则在「已有棋子附近」的空点里，按进攻+防守综合评分取最高分。
## 评分区分活四 / 冲四 / 活三 / 眠三 / 活二 等形态，天然偏好活三、冲四。

## 四个方向向量：横、竖、撇(↗)、捺(↘)
const DIRS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1)
]


## 主入口：为 ai_color 选出最佳落点，返回 Vector2i(col, row)；无处可下返回 (-1, -1)。
static func choose_move(board, ai_color: int) -> Vector2i:
	var human_color: int = 1 if ai_color == 2 else 2

	# ① 自己能赢就赢
	var win_move := _find_five_move(board, ai_color)
	if win_move.x >= 0:
		return win_move

	# ② 对方能赢就堵
	var block_move := _find_five_move(board, human_color)
	if block_move.x >= 0:
		return block_move

	# ③ 综合评分选点
	return _best_scored_move(board, ai_color, human_color)


## 找出能立刻连成五子的空点。
static func _find_five_move(board, color: int) -> Vector2i:
	for p: Vector2i in _candidate_points(board):
		if _would_win(board, p.y, p.x, color):
			return p
	return Vector2i(-1, -1)


## 判断在空点落子后是否形成五连（不修改棋盘）。
static func _would_win(board, row: int, col: int, color: int) -> bool:
	for d: Vector2i in DIRS:
		var count: int = 1
		var r: int = row + d.x
		var c: int = col + d.y
		while board.get_cell(r, c) == color:
			count += 1
			r += d.x
			c += d.y
		r = row - d.x
		c = col - d.y
		while board.get_cell(r, c) == color:
			count += 1
			r -= d.x
			c -= d.y
		if count >= 5:
			return true
	return false


## 综合评分：进攻分 + 防守分（防守略打折，保证有牌可打时优先进攻）。
static func _best_scored_move(board, ai_color: int, human_color: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score: float = -1.0e18
	for p: Vector2i in _candidate_points(board):
		var attack := _score_point(board, p.y, p.x, ai_color)
		var defend := _score_point(board, p.y, p.x, human_color)
		var score := attack + defend * 0.92
		# 同分时略偏向棋盘中心，开局更自然
		score += (14.0 - (absf(float(p.x) - 7.0) + absf(float(p.y) - 7.0))) * 0.15
		if score > best_score:
			best_score = score
			best = p
	return best


## 某空点对 color 的形态总评分（四个方向累加）。
static func _score_point(board, row: int, col: int, color: int) -> float:
	var total := 0.0
	for d: Vector2i in DIRS:
		total += _score_direction(board, row, col, color, d)
	return total


## 单方向评分：统计连子长度与两端开放情况，套用棋型分值表。
static func _score_direction(board, row: int, col: int, color: int, d: Vector2i) -> float:
	var count: int = 1
	var open_ends: int = 0

	var r: int = row + d.x
	var c: int = col + d.y
	while board.get_cell(r, c) == color:
		count += 1
		r += d.x
		c += d.y
	if board.get_cell(r, c) == 0:
		open_ends += 1

	r = row - d.x
	c = col - d.y
	while board.get_cell(r, c) == color:
		count += 1
		r -= d.x
		c -= d.y
	if board.get_cell(r, c) == 0:
		open_ends += 1

	if count >= 5:
		return 5000000.0
	if count == 4:
		if open_ends == 2:
			return 300000.0
		if open_ends == 1:
			return 30000.0
		return 0.0
	if count == 3:
		if open_ends == 2:
			return 20000.0
		if open_ends == 1:
			return 1800.0
		return 0.0
	if count == 2:
		if open_ends == 2:
			return 900.0
		if open_ends == 1:
			return 150.0
		return 0.0
	if count == 1:
		if open_ends == 2:
			return 40.0
		if open_ends == 1:
			return 12.0
	return 0.0


## 候选点：所有已有棋子的 2 格范围内（含 2 格）的空点；空棋盘返回天元。
static func _candidate_points(board) -> Array:
	var out: Array = []
	var seen := {}
	for y in 15:
		for x in 15:
			if board.get_cell(y, x) == 0:
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var ny: int = y + dy
					var nx: int = x + dx
					if ny < 0 or ny > 14 or nx < 0 or nx > 14:
						continue
					if board.get_cell(ny, nx) != 0:
						continue
					var key := Vector2i(nx, ny)
					if seen.has(key):
						continue
					seen[key] = true
					out.append(key)
	if out.is_empty():
		out.append(Vector2i(7, 7))
	return out
