extends State

## 受击状态：播放 Hurt_<朝向>，期间无敌，动画播完自动回 Idle。
##
## 触发方式：敌人的 Attack_Hit_box（Area2D）在 Run 状态检测到玩家，
## 调用 state_machine.change_state("Hurt", {"from": 敌人的 global_position})。
## 传了 "from" 就朝向攻击者播动画；没传就按输入方向刷新。
##
## 伤害数值由 BaseCharacter.take_damage() 扣除；这里只负责受击表现和无敌计时。

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

	# 无敌时长来自 Player.tscn 的 invincible_time（2.0 秒），
	# 计时器是节点，跟随暂停，重复受击会重新计时而不是留下多个协程。
	character.start_invincibility()

## 一次性受击动画播完 → 回 Idle。
func update(_delta: float) -> void:
	super.update(_delta)
	if not character.animated_sprite_2d.is_playing():
		parent_state_machine.change_state("Idle")
