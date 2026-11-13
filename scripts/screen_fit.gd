extends Node
## 窗口自适应（自动加载单例 ScreenFit）
## ------------------------------------------------------------
## 为什么要它：项目设计视口是 900×1020。若直接按这个尺寸开窗，
## 在 1366×768 这类笔记本上窗口会超出屏幕，底部按钮点不到。
## 这里在启动时读取显示器可用区域，等比缩小窗口（保持 900:1020），
## 并居中显示。游戏内布局用 stretch 模式缩放，因此不会变形。
##
## 只在「独立运行」时生效；在编辑器里按 F5 时不改动编辑器窗口尺寸。

## 设计基准分辨率（与 project.godot 的 viewport 一致）
const DESIGN := Vector2i(900, 1020)
## 窗口最多占屏幕可用区域的百分比（留出任务栏与边框余量）
const MAX_RATIO := 0.92
## 是否在启动时自动适配
const ENABLE := true


func _ready() -> void:
	if not ENABLE:
		return
	# 编辑器里运行时不干预窗口，避免影响调试
	if OS.has_feature("editor"):
		return
	_fit_to_screen()


## 按当前屏幕可用区域计算并应用窗口尺寸 + 居中。
func _fit_to_screen() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)   # 已扣除任务栏
	var avail := Vector2(usable.size)

	var max_w := avail.x * MAX_RATIO
	var max_h := avail.y * MAX_RATIO

	# 等比缩放到能放下的最大尺寸
	var scale_factor := minf(max_w / float(DESIGN.x), max_h / float(DESIGN.y))
	scale_factor = minf(scale_factor, 1.0)      # 屏幕大时不放大，保持原始清晰度

	var win_size := Vector2i(
		int(round(DESIGN.x * scale_factor)),
		int(round(DESIGN.y * scale_factor))
	)
	win_size.x = maxi(win_size.x, 480)          # 极小屏兜底
	win_size.y = maxi(win_size.y, 544)

	DisplayServer.window_set_size(win_size)
	_center_window(usable, win_size)


## 让窗口在可用区域内居中。
func _center_window(usable: Rect2i, win_size: Vector2i) -> void:
	var pos := Vector2i(
		usable.position.x + (usable.size.x - win_size.x) / 2,
		usable.position.y + (usable.size.y - win_size.y) / 2
	)
	DisplayServer.window_set_position(pos)
