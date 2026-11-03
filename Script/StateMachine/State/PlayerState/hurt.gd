extends State

## 受击状态：播放 Hurt_<朝向>，期间无敌，动画播完自动回 Idle。
##
## 触发方式：敌人的 Attack_Hit_box（Area2D）在 Run 状态检测到玩家，
## 调用 state_machine.change_state("Hurt", {"from": 敌人的 global_position})。
## 传了 "from" 就朝向攻击者播动画；没传就按输入方向刷新。
##
## 伤害数值由 BaseCharacter.take_damage() 扣除；
## 这里负责受击表现、无敌计时和短距离击退。

## 击退方向：从攻击者指向玩家。
var _knockback_direction := Vector2.ZERO

## 当前这次击退的持续时间，进入状态时从角色属性复制。
var _knockback_duration := 0.0

## 击退剩余时间。归零后停止击退位移。
var _knockback_time_left := 0.0

## 进入受击：确定朝向、播动画、开启无敌并开始击退。
func enter(msg: Dictionary = {}) -> void:
	super.enter()

	# -1 表示"没有指定朝向"，交给 play_animation 的默认参数按输入方向刷新。
	var heading := -1
	var to_attacker := Vector2.ZERO
	if msg.has("from"):
		to_attacker = msg["from"] - character.global_position   # 从玩家指向攻击者
		if to_attacker != Vector2.ZERO:
			heading = character.heading_from_direction(to_attacker)
	play_animation(heading)

	# 玩家朝攻击者，位移方向则与它相反，也就是远离攻击者。
	_knockback_direction = -to_attacker.normalized()
	_knockback_duration = maxf(character.knockback_duration, 0.0)
	_knockback_time_left = _knockback_duration
	character.velocity = _knockback_direction * character.knockback_speed

	# 无敌时长来自 Player.tscn 的 invincible_time（2.0 秒），
	# 计时器是节点，跟随暂停，重复受击会重新计时而不是留下多个协程。
	character.start_invincibility()

## 每个物理帧执行击退，并按剩余时间线性降低速度。
## Hurt 状态不读取 move_direction，因此玩家输入不会覆盖这段击退位移。
func physics_update(delta: float) -> void:
	super.physics_update(delta)
	if _knockback_time_left <= 0.0:
		character.velocity = Vector2.ZERO
		return

	_knockback_time_left = maxf(_knockback_time_left - delta, 0.0)
	var weight := _knockback_time_left / _knockback_duration
	character.velocity = _knockback_direction * character.knockback_speed * weight
	character.move_and_slide()

	if _knockback_time_left <= 0.0:
		character.velocity = Vector2.ZERO

## 一次性受击动画播完 → 回 Idle。
func update(_delta: float) -> void:
	super.update(_delta)
	if not character.animated_sprite_2d.is_playing():
		parent_state_machine.change_state("Idle")
