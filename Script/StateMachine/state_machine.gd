class_name StateMachine
extends Node

## 状态机：挂在角色（BaseCharacter 的子类）下面，统一驱动 Idle / Run 等状态节点。
##
## 工作流程：
## 1. _ready() 把所有 State 子节点收进 states 字典，key 用节点名的小写形式；
## 2. 角色在自己的 _ready() 里调用 start() 进入初始状态；
## 3. 每帧把 update() / physics_update() / handle_input() 转发给当前状态；
## 4. 状态内部调用 change_state("Run") 完成切换。
##
## 场景结构（以 Scene/Player.tscn 为例）：
##     Player (CharacterBody2D，挂 player.gd，继承 BaseCharacter)
##     └─ StateMachine
##        ├─ Idle   ← initial_state 指向它
##        ├─ Run
##        ├─ Attack
##        ├─ Hurt
##        └─ Die

## 初始状态，在检查器里指定（本例指向 Idle 节点）。
@export var initial_state: State

## 当前正在运行的状态。
var current_state: State

## 状态池，形如 { "idle": Idle节点, "run": Run节点 }，key 统一为小写。
var states: Dictionary = {}

## 状态机所属的角色，由 _ready() 从父节点取得并注入给每个状态。
var character: BaseCharacter

## 收集子状态并注入引用。这里不进入初始状态，那一步交给 start()。
func _ready() -> void:
	# 父节点必须是 BaseCharacter 的子类（玩家或敌人）：
	# 状态里会访问 character.velocity / move_direction，父节点不对就会出错。
	character = get_parent() as BaseCharacter
	if character == null:
		push_error("状态机的父节点必须是 BaseCharacter 的子类")
		return
	# 遍历子节点，把所有 State 注册进字典（节点名 "Idle" → key "idle"）。
	# 没有挂 State 脚本的节点会被跳掉 —— 场景里放了个空的 Attack 节点就会这样。
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.parent_state_machine = self
			child.character = character

## 进入初始状态。由角色在自己 _ready() 里调用，不要在这里直接调。
##
## 为什么不干脆写在 _ready() 里：Godot 的初始化顺序是"子节点的 _ready() 先于父节点"，
## 而 @onready 变量是在各自 _ready() 之前才赋值的。状态机的 _ready() 触发时，
## 角色的 animated_sprite_2d 还是 null，状态的 enter() 里一访问就会报
## "Cannot call method 'play' on a null value"，初始动画也就播不出来。
## 改由角色启动，就保证所有 @onready 变量都已就位。
func start() -> void:
	if initial_state == null:
		push_error("请在检查器中设置初始状态")
		return
	current_state = initial_state
	current_state.enter()

## 每渲染帧把更新转发给当前状态。
func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

## 每物理帧把更新转发给当前状态（角色移动就发生在被调用到的 Run 状态里）。
func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

## 把没被 UI 消费掉的输入转发给当前状态。
func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

## 切换到另一个状态。
## [param state_name] 目标状态的节点名，大小写不敏感（内部会 to_lower()）。
## [param msg] 传给目标状态 enter() 的附加数据。
func change_state(state_name: String, msg: Dictionary = {}) -> void:
	var key := state_name.to_lower()
	# 名字写错时只警告、不崩溃，方便排查 —— 所以要多留意输出面板里的 warning。
	if not states.has(key):
		push_warning("状态不存在: " + state_name)
		return
	var next_state: State = states[key]
	# 已经在这个状态里就不再切换，避免 enter() 被反复调用。
	if next_state == current_state:
		return
	# 先让旧状态收尾，再进入新状态。
	if current_state:
		current_state.exit()
	current_state = next_state
	current_state.enter(msg)
