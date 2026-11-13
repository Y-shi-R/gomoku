@tool
extends Control
## 回合指示棋子（小圆点）
## 顶部栏左侧的小棋子图标，随当前回合切换黑白，并用轻微缩放动画提示「该谁下」。

var stone_color := 1        ## 1=黑 2=白 0=隐藏
var _pulse := 0.0


func set_color(c: int) -> void:
	stone_color = c
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if stone_color == 0:
		return
	var r := minf(size.x, size.y) * 0.5 - 1.0
	var center := size * 0.5
	var breathe := 1.0 + 0.06 * sin(_pulse * 4.0)
	# 外圈光晕
	draw_circle(center, r * breathe + 3.0, Color(1.0, 0.82, 0.45, 0.22), true, -1.0, true)
	if stone_color == 1:
		draw_circle(center, r, Color(0.07, 0.07, 0.085), true, -1.0, true)
		draw_circle(center + Vector2(-r * 0.3, -r * 0.32), r * 0.32, Color(0.9, 0.92, 0.96, 0.55), true, -1.0, true)
	else:
		draw_circle(center, r, Color(0.965, 0.953, 0.925), true, -1.0, true)
		draw_circle(center, r * 0.98, Color(0.62, 0.6, 0.56), false, 1.4, true)
		draw_circle(center + Vector2(-r * 0.3, -r * 0.32), r * 0.3, Color(1, 1, 1, 0.7), true, -1.0, true)
