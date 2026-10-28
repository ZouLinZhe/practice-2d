extends State

## 敌人死亡：停下、关闭碰撞与攻击框、播放 Die_<朝向>，动画播完释放自身。
##
## 碰撞形状在物理回调里可能正被查询，所以统一用 set_deferred 关闭。
@onready var collision_shape_2d: CollisionShape2D = $"../../CollisionShape2D"
@onready var attack_collision_shape_2d: CollisionShape2D = $"../../Attack_Hit_box/CollisionShape2D"

func enter(_msg: Dictionary = {}) -> void:
	super.enter()
	play_animation()
	character.velocity = Vector2.ZERO
	character.move_direction = Vector2.ZERO

	# 死亡后不再需要无敌计时，停掉并清掉标记，避免残留状态。
	if character.invincible_timer:
		character.invincible_timer.stop()
	character.is_invincible = false

	collision_shape_2d.set_deferred("disabled", true)
	attack_collision_shape_2d.set_deferred("disabled", true)

## 死亡动画播完就移除敌人。
func update(_delta: float) -> void:
	super.update(_delta)
	if not character.animated_sprite_2d.is_playing():
		character.queue_free()
