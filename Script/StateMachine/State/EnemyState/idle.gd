extends State

## 敌人待机状态：站着播待机动画；玩家进入探测范围就切到 Run。
##
## 探测半径和玩家引用都放在 EnemyCharacter 上，这个状态只负责判断。

## 进入待机：清掉速度和方向，避免从 Run 回来时还带着旧的运动。
func enter(_msg: Dictionary = {}) -> void:
	super.enter()
	character.velocity = Vector2.ZERO
	character.input_direction = Vector2.ZERO
	play_animation()

## 每渲染帧：始终播待机动画，然后检查玩家是否进入范围。
func update(_delta: float) -> void:
	super.update(_delta)
	play_animation()

	# character 的类型是 BaseCharacter，这里要拿敌人独有的 get_player()/detection_radius，
	# 所以先转成 EnemyCharacter；转换失败说明这个状态被挂到了非敌人角色上。
	var enemy := character as EnemyCharacter
	if enemy == null:
		return

	var target := enemy.get_player()
	if target == null:
		return   # 玩家还没生成，等下一帧再试

	if enemy.global_position.distance_to(target.global_position) <= enemy.detection_radius:
		parent_state_machine.change_state("Run")
