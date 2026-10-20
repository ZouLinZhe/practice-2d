class_name BaseCharacter
extends CharacterBody2D

## 角色基类：玩家和敌人都继承它。
##
## 放在这里的是"所有角色都有的东西"：
## - 数据：朝向、速度、加速度、这一帧想往哪走
## - 表现：AnimatedSprite2D 引用、动画播放
## - 骨架：StateMachine 子节点，并在 _ready() 里启动它
##
## 子类只负责决定"往哪走"，把结果写进 input_direction 就行：
## - Player：读键盘 / 手柄
## - Enemy：由 AI 决定方向（当前是"发现玩家就追"的雏形）
## 至于怎么移动、怎么攻击、被打到怎么办，全部交给 StateMachine 下的各个状态。

## 朝向枚举。用枚举而不是字符串，是为了让写错的值直接报错，
## 而不是像 "Up" 写成 "up" 那样静默失效。
enum Heading { UP, DOWN, LEFT, RIGHT }

## 把朝向枚举翻译成动画名的后缀：Idle_Up / Run_Down 里的 "Up"、"Down"。
##
## 注意：数组顺序必须和 enum Heading 的声明顺序一一对应。
## 将来往枚举中间插入新方向（比如做八方向）时，这里必须同步改，
## 否则会静默播错方向的动画。
const HEADING_SUFFIX := ["Up", "Down", "Left", "Right"]

## 移动速度（像素/秒）。可以在检查器里直接改这个值。
@export var speed := 200

## 速度过渡系数：每帧向目标速度逼近的比例，越大越跟手、越小越滑。
## 在 Run 状态里参与计算：_delta * accelerate。
var accelerate := 15.0

## 这一帧想往哪个方向走，长度 0~1。由子类负责写入：
## 玩家写输入方向，敌人以后写 AI 结果。状态只读它，不自己读键盘。
var input_direction := Vector2.ZERO

## 攻击意图：为 true 表示"想攻击了"。同样由子类写入：
## 玩家按攻击键时置 true，敌人以后由 AI 决定什么时候置 true。
## 状态用 consume_attack() 把它取走，取走后自动清空。
var attack_pressed := false

## 当前朝向，默认朝下，用来挑对应方向的动画。
## 平时不用手动管：play_animation() 会先按 input_direction 刷新它。
## 需要"不移动也转向"时（比如敌人站着面向玩家、攻击锁定方向）再手动写这个字段。
var facing_direction := Heading.DOWN

## 动画播放器，对应各角色场景里的 AnimatedSprite2D 子节点。
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

## 状态机子节点，由本类负责启动。
@onready var state_machine: StateMachine = $StateMachine

## 受伤后的无敌标记：true 时免疫伤害。
##
## 由 Hurt 状态在进入时置 true、计时结束后置 false。
## 伤害入口（以后的 take_damage()）必须先检查它，否则无敌形同虚设。
var is_invincible = false

## 等自己所有的 @onready 变量就位之后，再启动状态机进入初始状态。
##
## 顺序很重要：Godot 的 _ready() 是子节点先执行、父节点后执行，所以状态机无法
## 在自己的 _ready() 里访问本脚本的 @onready 变量（那时它们还是 null）。
## 交给角色来启动就没这个问题。
func _ready() -> void:
	if state_machine == null:
		push_error("角色缺少 StateMachine 子节点：" + str(name))
		return
	state_machine.start()

## 方向向量 → 四方向（斜向取主轴）
func heading_from_direction(direction: Vector2) -> int:
	if abs(direction.x) > abs(direction.y):
		return Heading.LEFT if direction.x < 0 else Heading.RIGHT
	return Heading.UP if direction.y < 0 else Heading.DOWN

## 根据 input_direction 刷新朝向，并返回当前朝向。
## 没有输入时保持原朝向不变。
##
## 返回值作为 play_animation() 的默认参数：省略 heading 时自动取它。
func face_towards() -> int:
	if input_direction != Vector2.ZERO:
		# 枚举本质是 int，赋回枚举字段时编译器会提示，这里明确忽略。
		@warning_ignore("int_as_enum_without_cast")
		facing_direction = heading_from_direction(input_direction)
	return facing_direction

## 取一次攻击意图：有就返回 true 并清空，没有就返回 false。
##
## 为什么要"先存下来、等状态来取"，而不是让每个状态自己去读按键：
## 1. 输入判断只有一处，以后加 Hurt / Die 等状态不用再抄一遍；
## 2. 按键那一帧如果正好赶上状态切换，标记会留在身上，等新状态下一帧取走；
##    即时读取按键就不会给这个机会，那一帧的输入直接丢了。
func consume_attack() -> bool:
	if not attack_pressed:
		return false
	attack_pressed = false
	return true

## 播放 "<前缀>_<朝向>" 的动画，例如 Run_Left、Idle_Up。
## [param state_prefix] 动画名前缀，通常就是状态节点名（Idle / Run / Attack / Hurt）。
## [param heading] 要播放的朝向；省略时调用 face_towards() 按输入方向刷新。
##                  显式传入时会写回 facing_direction，保证"朝向"和"动画"一致。
func play_animation(state_prefix: String, heading: int = face_towards()) -> void:
	# 枚举本质是 int；显式写回字段，避免动画方向和实际朝向不一致。
	@warning_ignore("int_as_enum_without_cast")
	facing_direction = heading   # ★ 必须写回，否则下一次 Idle/攻击会用错方向
	animated_sprite_2d.play(state_prefix + "_" + HEADING_SUFFIX[heading])
