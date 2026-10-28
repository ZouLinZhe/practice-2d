extends State

## 敌人受击：短硬直 + 短暂无敌，然后回到 Run 或 Idle。
##
## 无敌时长来自 enemy.tscn 的 invincible_time（0.2 秒），
## HURT_DURATION 与它保持一致：硬直结束就恢复行动。

## 受击硬直时长（秒）。
const HURT_DURATION := 0.2

## 硬直剩余时间（秒）；进入时设为 HURT_DURATION，update 里递减。
var _hurt_timer := 0.0

func enter(_msg: Dictionary = {}) -> void:
	super.enter()
	character.velocity = Vector2.ZERO
	character.move_direction = Vector2.ZERO

	# 调用方传了 "from" 就朝向攻击者，否则按当前朝向播。
	var heading := -1
	if _msg.has("from"):
		var dir: Vector2 = _msg["from"] - character.global_position
		if dir != Vector2.ZERO:
			heading = character.heading_from_direction(dir)
	play_animation(heading)

	character.start_invincibility()
	_hurt_timer = HURT_DURATION

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
