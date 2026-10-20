extends State

## 受击状态：播放 Hurt_<朝向>，期间无敌，动画播完自动回 Idle。
##
## 触发方式（计划中）：敌人攻击 Area2D 的 body_entered 信号调用
##   state_machine.change_state("Hurt", {"from": 攻击者的 global_position})
## 传了 "from" 就朝向攻击者播动画；没传就按输入方向刷新。
##
## 目前只实现了"表现"：还没有血量/伤害入口，所以这个状态暂时不会被触发。

## 进入受击：确定朝向、播动画、开启无敌。
func enter(_msg: Dictionary = {}) -> void:
	super.enter()

	# -1 表示"没有指定朝向"，交给 play_animation 的默认参数按输入方向刷新。
	var heading := -1
	if _msg.has("from"):
		var dir: Vector2 = _msg["from"] - character.global_position   # 从玩家指向攻击者
		if dir != Vector2.ZERO:
			heading = character.heading_from_direction(dir)
	play_animation(heading)

	# 无敌 2 秒。create_timer 第二个参数 false = 跟随暂停，暂停时不会倒计时。
	# 注意：每进一次本状态都会开一个协程；伤害入口必须在无敌期间拒绝再次进入，
	# 否则多个计时器会互相覆盖，导致无敌提前结束。
	character.is_invincible = true
	await get_tree().create_timer(2.0, false).timeout
	character.is_invincible = false

## 一次性受击动画播完 → 回 Idle。
func update(_delta: float) -> void:
	super.update(_delta)
	if not character.animated_sprite_2d.is_playing():
		parent_state_machine.change_state("Idle")
