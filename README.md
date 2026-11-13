# 五子棋（Gomoku）—— Godot 4.x / GDScript

15×15 标准五子棋：双人对战 / 人机对战，无外部插件、无外部图片音频资源。
木纹棋盘、星位、悬停预览、落子动画、胜利高亮、音效全部由代码生成。

---

## 一、如何打开运行

1. 打开 Godot 4.x（本项目在 **4.7.2-stable** 上验证）。
2. 在启动器点「导入 / Import」，选目录 `E:\Godot\projects\五子棋\project.godot`。
3. 点「运行项目 / Run Project」。

主场景：`res://scenes/main_menu.tscn`（已在 project.godot 中设置）。
视口固定 900×1020，拉伸模式 `canvas_items` + `keep`，可自由缩放窗口不变形。

> 不需要任何外部字体文件：主题里用的是 Godot 内置 `SystemFont`，自动调用系统中文黑体（微软雅黑 / 苹方 / 思源黑体）。

---

## 二、如何切换模式

全部在**主菜单**完成，开局后不能改：

| 想做什么 | 操作 |
|---|---|
| 两人在同一台电脑轮流下 | 主菜单 → 点「**双人对战**」（金色高亮即选中） |
| 和电脑下 | 主菜单 → 点「**人机对战**」 |
| 人机时你想执黑先手 | 再点「**执黑先行**」 |
| 人机时你想执白后手 | 再点「**执白后行**」 |
| 开始 | 点「**开始对局**」 |

双人模式下「执子颜色」两个按钮会自动置灰（无意义）。
对局中想换模式：底栏「**返回主菜单**」→ 重新选。

---

## 三、操作说明

- **落子**：鼠标移到交叉点，出现半透明预览棋子；左键点击落下。
- **悔棋**：底栏「**悔棋**」。双人模式撤 1 步；人机模式自动撤 2 步（电脑 + 你），保证还是你的回合。
  已结束的局面也可以悔棋，会同时回退比分。
- **重新开始**：底栏「**重新开始**」（保留比分）或结果面板的「**再来一局**」。
- **音效开关**：底栏「**音效 开 / 音效 关**」。
- **返回主菜单**：底栏或结果面板的「**返回主菜单**」。

---

## 四、规则

- 标准 15×15，**黑棋先手**，双方轮流。
- 横 / 竖 / 两斜任一方向连成 5 子即胜（长连也算胜，超过 5 子时高亮其中连续 5 颗）。
- **不用禁手**（无三三禁、四四禁、长连禁）。
- 棋盘 225 格下满仍无五连则为平局。
- 落子后**立即判定**，胜方五子亮起黄色呼吸光晕。

---

## 五、场景树结构

### 1. `res://scenes/main_menu.tscn`（主菜单）

```
MainMenu (Control)  ← 挂 scripts/main_menu.gd
├─ BG (ColorRect)                    深色背景，铺满
└─ Center (CenterContainer)          full_rect，保证内容居中
   └─ CenterBox (VBoxContainer)
      ├─ TitleBox (VBoxContainer)
      │  ├─ Title (Label)             「五 子 棋」
      │  └─ Subtitle (Label)          「GOMOKU · 15 × 15」
      ├─ MainBox (VBoxContainer)
      │  ├─ ModeLabel (Label)         「对局模式」
      │  ├─ ModeRow (HBoxContainer)
      │  │  ├─ PvpButton (Button)      「双人对战」
      │  │  └─ PveButton (Button)      「人机对战」
      │  ├─ ColorLabel (Label)         「执子颜色（仅人机对战生效）」
      │  ├─ ColorRow (HBoxContainer)
      │  │  ├─ BlackButton (Button)    「执黑先行」
      │  │  └─ WhiteButton (Button)    「执白后行」
      │  └─ StartButton (Button)       「开 始 对 局」
      └─ Footer (VBoxContainer)
         ├─ Hint (Label)             规则提示
         └─ ScoreLabel (Label)       累计比分
```

### 2. `res://scenes/game.tscn`（对局）

```
Game (Control)  ← 挂 scripts/game.gd
├─ BG (ColorRect)                              铺满的深色背景
├─ Root (MarginContainer)                      四边留白 20/18
│  └─ Layout (VBoxContainer)
│     ├─ TopBar (PanelContainer)    高 92     顶部状态栏
│     │  └─ TopBox (HBoxContainer)
│     │     ├─ TurnBox (HBoxContainer)
│     │     │  ├─ TurnStone (Control)  ← 挂 scripts/turn_indicator.gd
│     │     │  └─ TurnLabel (Label)    「黑棋回合 / 白棋思考中…」
│     │     └─ ScoreLabel (Label)      「黑 0 · 平 0 · 白 0」
│     ├─ BoardArea (CenterContainer)            棋盘居中
│     │  └─ Board (Control)          ← 挂 scripts/board_view.gd
│     └─ BottomBar (PanelContainer)  高 84     按钮栏
│        └─ Buttons (HBoxContainer)
│           ├─ RestartButton (Button)  「重新开始」
│           ├─ UndoButton (Button)     「悔棋」
│           ├─ SoundButton (Button)    「音效 开 / 关」
│           └─ MenuButton (Button)     「返回主菜单」
└─ ResultPanel (PanelContainer, 默认隐藏)
   └─ ResultBox (VBoxContainer)
      ├─ ResultTitle (Label)           「黑棋胜利 / 和局」
      ├─ ResultDetail (Label)          副标题
      └─ ResultButtons (HBoxContainer)
         ├─ AgainButton (Button)       「再来一局」
         └─ ResultMenuButton (Button)  「返回主菜单」
```

---

## 六、脚本职责

| 脚本 | 类型 | 职责 |
|---|---|---|
| `scripts/board_logic.gd` | `RefCounted`，`class_name GomokuBoard` | **纯逻辑层**。一维 `PackedInt32Array` 存 225 格；`place_stone()` / `undo_last()` / `check_winner()` / `is_draw()`。不碰任何绘制。 |
| `scripts/ai_player.gd` | `RefCounted`，`class_name GomokuAI` | **AI 决策**。静态类，无状态，直接读传入的 board。 |
| `scripts/board_view.gd` | `Control`，`class_name GomokuBoardView` | **表现层**。`_draw()` 画木板/木纹/网格/星位/棋子/预览/胜利高亮；处理鼠标悬停与点击；棋子落子缩放淡入动画。 |
| `scripts/game.gd` | `Control`（挂在 Game 根） | **对局控制器**。串联三层的流程：回合推进、胜负/平局结算、悔棋、重开、AI 调度、比分、结果面板。 |
| `scripts/game_state.gd` | `Node`，**Autoload `GameState`** | 跨场景状态：模式、玩家执子颜色、累计比分、音效开关。 |
| `scripts/sfx.gd` | `Node`，**Autoload `Sfx`** | 音效。运行时用正弦/噪声/琶音合成 `AudioStreamWAV`，8 个播放器轮转。 |
| `scripts/main_menu.gd` | `Control`（挂在 MainMenu 根） | 主菜单：模式/颜色选择、选中态高亮、跳转对局。 |
| `scripts/turn_indicator.gd` | `Control`（`@tool`，挂在 TurnStone） | 顶部那颗小棋子图标，随回合切黑白，带呼吸缩放。 |

### 逻辑与表现分离具体做了什么

- 棋盘数据由 `GomokuBoard` 独立持有，`GomokuBoardView` 只通过 `get_cell()` 读、通过两个信号（`cell_placed` / `stone_removed`）被动通知。
- 胜负判定是独立函数 `check_winner(row, col, color) -> Array[Vector2i]`：沿四方向双向延伸计数，返回获胜坐标数组，不修改任何状态。
- AI 只接受 `(board, color)` 两个参数，不依赖场景、不依赖 UI，可单跑测试。

---

## 七、AI 决策逻辑

优先级从高到低（`GomokuAI.choose_move`）：

1. **自己能五连** → 直接落子获胜（`_find_five_move(board, ai_color)`）。
2. **对方能五连** → 立即堵住（`_find_five_move(board, human_color)`）。
3. **综合评分选点**：只在「已有棋子的 2 格车程内」的候选点里搜索，对每个空点算
   `进攻分 + 防守分 × 0.92 + 中心偏好`，取最高分。

单方向棋型分值（`_score_direction`）：

| 棋型 | 分值 |
|---|---|
| 成五 | 5,000,000 |
| 活四（两端开） | 300,000 |
| 冲四（一端开） | 30,000 |
| 活三 | 20,000 |
| 眠三 | 1,800 |
| 活二 | 900 |
| 眠二 | 150 |
| 单子 | 40 / 12 |

防守乘 0.92 是为了「有活三可做时优先进攻而非被动跟防」，同时因为冲四/活四分值量级远高于活三，真正的威胁依然会优先被堵。

---

## 八、已验证项

在 Godot 4.7.2 中实机运行验证：

- ✅ 棋盘渲染：木纹纹理、15×15 网格、天元 + 四星位、黑白棋子立体质感
- ✅ 落子：数据写入、缩放淡入动画、音效播放（`AudioStreamPlayer.playing == true`）
- ✅ 胜负：横向五连、斜向五连均正确判定，五子黄色呼吸高亮
- ✅ 平局：`is_full()` / `is_draw()` 返回值正确
- ✅ 悔棋：3 子→2 子、被撤格子清空、回合回到黑棋、无子时按钮置灰
- ✅ 重新开始：棋盘归零、按钮状态重置
- ✅ AI 三项优先级：能赢先赢、对方四连必堵、空盘落天元
- ✅ 人机对局流：玩家下天元 → AI 自动应手 → 回合交回玩家
- ✅ 主菜单：模式切换、执子颜色切换、双人模式置灰、跳转对局
- ✅ 场景返回、音效开关、比分累计

---

## 九、文件清单

```
五子棋/
├─ project.godot
├─ icon.svg
├─ README.md
├─ scenes/
│  ├─ main_menu.tscn
│  └─ game.tscn
├─ scripts/
│  ├─ board_logic.gd
│  ├─ ai_player.gd
│  ├─ board_view.gd
│  ├─ game.gd
│  ├─ game_state.gd
│  ├─ main_menu.gd
│  ├─ sfx.gd
│  └─ turn_indicator.gd
├─ themes/
│  ├─ main_theme.tres
│  └─ panel_result.tres
└─ addons/godot_ai/        ← 编辑器插件，游戏本身不依赖，可整个删掉
```

> `addons/godot_ai` 只是开发时用来远程操纵编辑器的工具，删掉不影响游戏运行。
