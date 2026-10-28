extends BaseCharacter

## 玩家角色。除了"输入从哪来"，其余全部继承 BaseCharacter。
##
## 特意没有 class_name：这个脚本只挂在 Scene/Player.tscn 上，不需要当类型用。
## 代码里要按类型判断时请用基类 BaseCharacter（敌人也继承它）。

## 把自己登记到 "player" 分组，敌人通过这个分组找到当前玩家。
##
## 先登记再调父类 _ready()：父类会在 _ready() 里初始化血量并启动状态机，
## 这样状态机跑起来的时候，玩家已经能在分组里被查到了。
func _ready() -> void:
	add_to_group("player")
	super._ready()

## 每物理帧把键盘输入写进基类的 move_direction。
##
## 放在 _physics_process 而不是 _unhandled_input：Input.get_vector 是轮询式 API，
## 每帧读一次最稳，不会因为 UI 抢走事件而丢输入。
## 角色的 _physics_process 比子节点状态机先执行，所以状态拿到的永远是本帧最新值。
func _physics_process(_delta: float) -> void:
	move_direction = Input.get_vector("Left", "Right", "Up", "Down")
	# 攻击键只记录"意图"，由当前状态决定什么时候切到 Attack
	# （见 BaseCharacter.consume_attack）。
	if Input.is_action_just_pressed("Attack"):
		attack_pressed = true
