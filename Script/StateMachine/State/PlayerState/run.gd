extends State

## 移动状态：角色有移动方向时停留在这里，方向归零就切回 Idle。
##
## 分工：
## - update()（渲染帧）：处理攻击意图、判断方向是否归零、刷新朝向、播动画
## - physics_update()（物理帧）：按加速度逼近目标速度，再 move_and_slide() 处理碰撞和位移
## 动画和朝向跟着渲染帧走、移动跟着物理帧走，两者最多差一帧，肉眼看不出来。

## 每渲染帧：攻击优先，其次看方向还在不在。
func update(_delta: float) -> void:
	super.update(_delta)
	# 攻击优先，而且必须放在最前面：下面"方向归零就 return"会直接结束本帧，
	# 先前的写法正是因为攻击判断排在它后面，松手那一帧按攻击才会被吃掉。
	if character.consume_attack():
		parent_state_machine.change_state("Attack")
		return
	# 方向归零 → 回到待机。
	if character.input_direction == Vector2.ZERO:
		parent_state_machine.change_state("Idle")
		return   # 必须 return：下面要按方向播动画、算速度，零向量没有意义
	# 播放 Run_<朝向>：play_animation() 内部会先按 input_direction 刷新朝向。
	# 循环动画重复 play() 不会重播，所以每帧调用是安全的。
	play_animation()

## 每物理帧：按加速度逼近目标速度，然后移动。
func physics_update(_delta: float) -> void:
	super.physics_update(_delta)
	# 用 lerp 做速度过渡：accelerate 越大越跟手、越小越滑。
	# _delta * accelerate 是"这一帧追上去的比例"，所以它和帧率无关。
	character.velocity = character.velocity.lerp(
		character.input_direction * character.speed,
		_delta * character.accelerate)
	character.move_and_slide()
