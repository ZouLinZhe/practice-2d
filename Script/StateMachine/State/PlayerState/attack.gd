extends State

## 攻击状态：按下攻击键进入，播一次挥击动画，动画播完自动回 Idle。
##
## 攻击判定靠四块方向攻击框（Up/Down/Left/Right_Hitbox）：
## 进入时按角色朝向挑出对应的一块，挥到动画第 2 帧打开、第 5 帧关闭。
## 判定窗口用"区间"而不是"正好等于某帧"，这样掉帧时不会漏开或漏关。

## 这一刀要用的那块攻击框，在 enter() 里按朝向选出。
## 攻击结束（含被打断）时一定要关掉，否则会带着它走进别的状态，见 exit()。
var attack_collision_shape: CollisionShape2D

## 攻击框容器，$"../../Attack_Hit_Box" 即 角色/Attack_Hit_Box。
@onready var attack_hit_box: Area2D = $"../../Attack_Hit_Box"

## 进入攻击：播攻击动画，挑出这一刀要用的攻击框（先关着，挥到第 2 帧才打开）。
func enter(_msg: Dictionary = {}) -> void:
	super.enter()
	play_animation()   # 内部会先按 input_direction 刷新朝向，再播 Attack_<朝向>
	if attack_hit_box == null:
		push_error(str(name) + " 找不到 Attack_Hit_Box 节点")
		return
	# 朝向枚举 → "Up" / "Down" / "Left" / "Right"，拼出对应的那块攻击框。
	# 注意：HEADING_SUFFIX 是未标注类型的数组，取元素得到的是 Variant，
	# 所以这里必须显式写 : String，不能用 := 推断。
	var suffix: String = BaseCharacter.HEADING_SUFFIX[character.facing_direction]
	attack_collision_shape = attack_hit_box.get_node_or_null(suffix + "_Hitbox")
	if attack_collision_shape == null:
		push_error("找不到攻击框节点：" + suffix + "_Hitbox")
		return
	attack_collision_shape.disabled = true   # 先关掉，等动画挥到第 2 帧再打开

## 离开攻击：不管是正常播完还是被别的状态打断，都把攻击框关掉。
func exit() -> void:
	super.exit()
	if attack_collision_shape:
		attack_collision_shape.disabled = true

## 每帧：按动画帧开关攻击框，动画播完就回 Idle。
func update(_delta: float) -> void:
	super.update(_delta)
	# enter() 里没找到攻击框时已经报过错了，这里直接跳过，避免每帧刷屏报错。
	if attack_collision_shape == null:
		return
	# 攻击过程中再按攻击键直接丢掉，不做连击缓冲。
	# （想改成"缓冲一键连击"，把这行删掉即可：攻击结束回 Idle 时会被取走。）
	character.consume_attack()
	# 判定窗口 = 动画第 2~4 帧（原先是 frame == 2 打开、frame == 5 关闭，等价）。
	# 写成区间是为了掉帧时也能正确开关：万一从第 1 帧跳到第 3 帧，照样打得中。
	var frame := character.animated_sprite_2d.frame
	attack_collision_shape.disabled = not (frame >= 2 and frame <= 4)
	# 等价于 attack_collision_shape.disabled = frame < 2 or frame > 4
	# 一次性动画播完 → 回待机（这时如果还按着方向键，待机下一帧会再切到 Run）。
	if not character.animated_sprite_2d.is_playing():
		parent_state_machine.change_state("Idle")
