extends State

## 敌人追击状态：朝玩家移动，玩家逃离一定距离后放弃并回 Idle。
##
## 性能上的两点：
## 1. 距离/方向每 THINK_INTERVAL 秒才重新算一次（决策限频）；
## 2. 移动仍然每个物理帧执行，所以看起来是平滑的，不会一卡一卡。
## 进入状态时会错开计时器相位，避免大量敌人在同一帧集中计算。

## 重新计算方向的间隔（秒）。越大越省，越小跟得越紧。
const THINK_INTERVAL := 0.1

## 持续接触时两次伤害之间的冷却（秒）。
const DAMAGE_COOLDOWN := 0.5

## 距离上次重新计算方向后累计的时间（秒）。
## 累加到 THINK_INTERVAL 才执行一次 _think()，中间的帧沿用上一次算好的方向。
var _think_timer := 0.0

## 距离上次成功造成接触伤害后累计的时间（秒）。
## 累加到 DAMAGE_COOLDOWN 前不会再次命中；
## 玩家处于无敌时 _try_damage() 直接返回、不会重置它，所以无敌一结束就会再次造成伤害。
var _damage_cooldown := 0.0

func enter(_msg: Dictionary = {}) -> void:
	super.enter()
	# 立刻朝玩家算一次，避免刚进 Run 的头 0.1 秒站着不动。
	_think()
	# 之后的下一次思考随机错开，避免所有敌人同一帧计算。
	_think_timer = randf() * THINK_INTERVAL
	_damage_cooldown = 0.0

## 每渲染帧：播动画，并按固定间隔重新算方向。
func update(delta: float) -> void:
	super.update(delta)
	play_animation()

	_think_timer += delta
	if _think_timer < THINK_INTERVAL:
		return
	_think_timer = 0.0
	_think()

## 每个物理帧：按上一次算好的方向平滑移动，并处理持续接触伤害。
func physics_update(delta: float) -> void:
	super.physics_update(delta)
	character.velocity = character.input_direction * character.speed
	character.move_and_slide()
	_tick_contact_damage(delta)

## 重新计算朝向玩家的方向；目标丢失或超出脱战半径就回 Idle。
func _think() -> void:
	var enemy := character as EnemyCharacter
	if enemy == null:
		return
	var target := enemy.get_player()
	if target == null or enemy.global_position.distance_to(target.global_position) > enemy.detection_escape_radius:
		parent_state_machine.change_state("Idle")
		return
	enemy.input_direction = (target.global_position - enemy.global_position).normalized()

## 玩家刚进入接触范围时立即尝试一次伤害。
## 信号在 enemy.tscn 里连接：Attack_Hit_box.body_entered → Run._on_attack_hit_box_body_entered。
func _on_attack_hit_box_body_entered(body: Node2D) -> void:
	# 连接是常驻的，只有处于追击状态才造成伤害（Idle 时碰到不扣血）。
	if parent_state_machine.current_state != self:
		return
	if body is BaseCharacter:
		_try_damage(body as BaseCharacter)

## 持续接触时按冷却重复造成伤害。
## body_entered 只在进入瞬间触发一次，所以"一直贴着"必须靠这里轮询处理。
func _tick_contact_damage(delta: float) -> void:
	_damage_cooldown = maxf(_damage_cooldown - delta, 0.0)
	if _damage_cooldown > 0.0:
		return
	var hit_box: Area2D = character.get_node_or_null("Attack_Hit_box")
	if hit_box == null:
		return
	for body in hit_box.get_overlapping_bodies():
		if body is BaseCharacter:
			_try_damage(body as BaseCharacter)
			return   # 同一帧只打一次

## 尝试对玩家造成一次接触伤害。
## 玩家无敌时直接跳过，并且**不进入冷却**——这样无敌结束后会马上再次命中。
func _try_damage(player: BaseCharacter) -> void:
	if player.is_invincible:
		return
	player.state_machine.change_state("Hurt", {"from": character.global_position})
	_damage_cooldown = DAMAGE_COOLDOWN
