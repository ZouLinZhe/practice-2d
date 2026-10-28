extends State

## 待机状态：角色没有移动方向时停留在这里。
##
## 进入时把速度清零、播好待机动画；之后每渲染帧检查一次"想不想打 / 想不想动"，
## 有攻击意图就切 Attack，有移动意图就切 Run。

## 进入待机：停下脚步，并播放 Idle_<当前朝向>。
##
## 朝向不用在这里更新 —— 待机期间如果没有输入，朝向本来就不该变；
## 一旦有输入，马上就会切到 Run，由 Run 去更新朝向。
func enter(_msg: Dictionary = {}) -> void:
	super.enter()                        # 基类是空实现，这里调用只是为了保持结构统一
	character.velocity = Vector2.ZERO    # 速度清零，否则角色会带着上次的速度继续滑
	play_animation()                     # 播放 Idle_<朝向>，切回来时朝向保持不变

## 每渲染帧：先看要不要攻击，再看要不要起身移动。
func update(_delta: float) -> void:
	super.update(_delta)
	# 攻击优先：取到一次攻击意图就切 Attack，本帧不再处理别的。
	# 用 consume_attack() 而不是直接读按键，一是多个状态共用同一份判断，
	# 二是状态刚好在这一帧切换时输入也不会被吃掉。
	if character.consume_attack():
		parent_state_machine.change_state("Attack")
		return
	# 方向来自角色本身：玩家由 player.gd 每帧写入，敌人以后由 AI 写入。
	# 状态不直接读键盘，这样同一套状态才能同时给玩家和敌人用。
	if character.move_direction != Vector2.ZERO:
		parent_state_machine.change_state("Run")
