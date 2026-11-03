extends State

## 玩家死亡状态。
##
## 负责播放死亡动画、停止移动和无敌计时，并关闭角色碰撞与攻击框。
## 动画结束后释放玩家，再通过 SceneManager 返回 Main 场景。
## 当前不包含独立的 Game Over 界面或结算系统。
@onready var collision_shape_2d: CollisionShape2D = $"../../CollisionShape2D"
@onready var attack_hit_box: Area2D = $"../../Attack_Hit_Box"

func enter(msg: Dictionary = {}) -> void:
	super.enter()

	character.attack_pressed = false
	# 有攻击来源时让死亡动画朝向攻击者；没有来源则沿用当前朝向。
	var heading := -1
	if msg.has("from"):
		var direction: Vector2 = msg["from"] - character.global_position
		if direction != Vector2.ZERO:
			heading = character.heading_from_direction(direction)
	play_animation(heading)

	# 死亡后立即停止移动，并清除无敌状态。
	character.velocity = Vector2.ZERO
	character.move_direction = Vector2.ZERO
	if character.invincible_timer:
		character.invincible_timer.stop()
	character.is_invincible = false

	# set_deferred 用于避免在物理回调期间直接修改碰撞状态。
	collision_shape_2d.set_deferred("disabled", true)
	attack_hit_box.set_deferred("monitoring", false)


func update(_delta: float) -> void:
	super.update(_delta)
	# 死亡动画只播放一次；结束后释放玩家并返回 Main 场景。
	if not character.animated_sprite_2d.is_playing():
		character.queue_free()
		SceneManager.change_scene("res://Scene/Main.tscn")
