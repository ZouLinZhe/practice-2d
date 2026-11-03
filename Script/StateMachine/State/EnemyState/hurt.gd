extends State

## 敌人受击：短硬直、短暂无敌和击退，然后回到 Run 或 Idle。
##
## 硬直时长由 HURT_DURATION 控制；无敌时长来自 enemy.tscn 的
## invincible_time（当前为 0.25 秒）。硬直会先结束，随后恢复 Run / Idle。

## 受击硬直时长（秒）。
const HURT_DURATION := 0.2

## 硬直剩余时间（秒）；进入时设为 HURT_DURATION，update 里递减。
var _hurt_timer := 0.0

## 击退方向：从攻击者指向敌人。
var _knockback_direction := Vector2.ZERO

## 当前这次击退的持续时间，进入状态时从角色属性复制。
var _knockback_duration := 0.0

## 击退剩余时间；归零后停止击退位移。
var _knockback_time_left := 0.0

func enter(msg: Dictionary = {}) -> void:
	super.enter()
	character.velocity = Vector2.ZERO
	character.move_direction = Vector2.ZERO

	# 调用方传了 "from" 就朝向攻击者，否则按当前朝向播。
	var heading := -1
	var to_attacker := Vector2.ZERO
	if msg.has("from"):
		to_attacker = msg["from"] - character.global_position
		if to_attacker != Vector2.ZERO:
			heading = character.heading_from_direction(to_attacker)
	play_animation(heading)

	# 朝攻击者播放受击动画，同时向相反方向被击退。
	_knockback_direction = -to_attacker.normalized()
	_knockback_duration = maxf(character.knockback_duration, 0.0)
	_knockback_time_left = _knockback_duration
	character.velocity = _knockback_direction * character.knockback_speed

	character.start_invincibility()
	_hurt_timer = HURT_DURATION

## 每个物理帧执行击退，并随时间逐渐降低击退速度。
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

## 硬直结束后：玩家还在追击范围内就回 Run，否则回 Idle。
func update(delta: float) -> void:
	super.update(delta)
	_hurt_timer -= delta
	if _hurt_timer > 0.0:
		return

	var enemy := character as EnemyCharacter
	if enemy == null:
		parent_state_machine.change_state("Idle")
		return
	var target := enemy.get_player()
	if target != null and enemy.global_position.distance_to(target.global_position) <= enemy.detection_escape_radius:
		parent_state_machine.change_state("Run")
	else:
		parent_state_machine.change_state("Idle")
