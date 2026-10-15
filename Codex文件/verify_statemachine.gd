extends SceneTree

# 状态机 + 朝向/动画 验收脚本(由 Codex 生成, 放在 Codex文件/ 下)
# 用法: godot --headless --path <项目目录> -s res://Codex文件/verify_statemachine.gd
# 作用: 模拟按键, 检查 Idle <-> Run 切换、加速度过渡、位移、朝向枚举、实际播放的动画名

var _pass_count := 0
var _fail_count := 0

func _initialize() -> void:
	_run()

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass_count += 1
		print("[PASS] ", label, "  ", detail)
	else:
		_fail_count += 1
		print("[FAIL] ", label, "  ", detail)

func _step(frames: int) -> void:
	for i in frames:
		await physics_frame

## 四个方向攻击框里只要有一个开着就返回 true。
func _any_hitbox_enabled(box: Area2D) -> bool:
	for child in box.get_children():
		if not child.disabled:
			return true
	return false

## 把四个攻击框的开关状态拼成字符串，方便输出到报告里。
func _hitbox_states(box: Area2D) -> String:
	var s := ""
	for child in box.get_children():
		s += str(child.name).replace("_Hitbox", "") + ":" + ("关" if child.disabled else "开") + " "
	return s

func _run() -> void:
	var packed: PackedScene = load("res://Scene/Player.tscn")
	var character := packed.instantiate() as BaseCharacter
	root.add_child(character)
	await process_frame
	await physics_frame

	var sm := character.get_node("StateMachine") as StateMachine
	var sprite := character.animated_sprite_2d

	var initial: String = sm.current_state.name if sm.current_state else "<null>"
	_check("initial state is Idle", initial == "Idle", "state=" + initial)
	_check("initial animation is Idle_Down", str(sprite.animation) == "Idle_Down", "anim=" + str(sprite.animation))

	# --- 按右：先看起步是否"渐加速" ---
	Input.action_press("Right")
	await _step(2)
	var v_start: float = character.velocity.x
	_check("accelerates gradually (not instant)", v_start > 0.0 and v_start < character.speed,
		"velocity.x=" + str(v_start))

	await _step(20)
	var state_run: String = sm.current_state.name if sm.current_state else "<null>"
	_check("Idle -> Run after pressing Right", state_run == "Run", "state=" + state_run)
	_check("velocity converges to speed", absf(character.velocity.x - character.speed) < 2.0,
		"velocity=" + str(character.velocity))
	_check("facing is RIGHT", character.facing_direction == BaseCharacter.Heading.RIGHT,
		"facing=" + str(character.facing_direction))
	_check("animation is Run_Right", str(sprite.animation) == "Run_Right", "anim=" + str(sprite.animation))

	var x0: float = character.global_position.x
	await _step(30)
	_check("moves right on screen", character.global_position.x > x0, "dx=" + str(character.global_position.x - x0))

	# --- 松开 ---
	Input.action_release("Right")
	await _step(3)
	var state_idle: String = sm.current_state.name if sm.current_state else "<null>"
	_check("Run -> Idle after releasing", state_idle == "Idle", "state=" + state_idle)
	_check("velocity reset to zero in Idle", character.velocity == Vector2.ZERO, "velocity=" + str(character.velocity))
	_check("facing kept after leaving Run", str(sprite.animation) == "Idle_Right", "anim=" + str(sprite.animation))

	var x_idle: float = character.global_position.x
	await _step(20)
	_check("stands still while Idle", is_equal_approx(character.global_position.x, x_idle),
		"dx=" + str(character.global_position.x - x_idle))

	# --- 四个方向: 朝向枚举 / 动画名 ---
	var dirs := [
		{"action": "Left", "heading": BaseCharacter.Heading.LEFT, "suffix": "Left"},
		{"action": "Right", "heading": BaseCharacter.Heading.RIGHT, "suffix": "Right"},
		{"action": "Up", "heading": BaseCharacter.Heading.UP, "suffix": "Up"},
		{"action": "Down", "heading": BaseCharacter.Heading.DOWN, "suffix": "Down"},
	]
	for d in dirs:
		Input.action_press(d["action"])
		await _step(5)
		_check("press " + d["action"] + " -> facing", character.facing_direction == d["heading"],
			"facing=" + str(character.facing_direction))
		_check("press " + d["action"] + " -> anim Run_" + d["suffix"], str(sprite.animation) == "Run_" + d["suffix"],
			"anim=" + str(sprite.animation))
		Input.action_release(d["action"])
		await _step(5)

	# --- 攻击: 能否进入、判定窗口有没有开、结束后有没有关 ---
	var box: Area2D = character.get_node("Attack_Hit_Box")
	Input.action_press("Attack")
	await process_frame
	Input.action_release("Attack")
	for i in 10:
		if sm.current_state.name == "Attack":
			break
		await process_frame
	_check("attack key enters Attack state", sm.current_state.name == "Attack", "state=" + sm.current_state.name)
	_check("attack animation is Attack_*", str(sprite.animation).begins_with("Attack_"), "anim=" + str(sprite.animation))

	var hit_box_opened := false
	for i in 120:
		await process_frame
		if _any_hitbox_enabled(box):
			hit_box_opened = true
		if sm.current_state.name != "Attack":
			break
	_check("hit box opened during swing", hit_box_opened, "")
	_check("attack returns to Idle", sm.current_state.name == "Idle", "state=" + sm.current_state.name)
	_check("all hit boxes closed after attack", not _any_hitbox_enabled(box), "hitbox=" + _hitbox_states(box))

	# --- 攻击被打断: 攻击框必须被 exit() 关掉（以后 Hurt / Die 会走这条路）---
	Input.action_press("Attack")
	await process_frame
	Input.action_release("Attack")
	for i in 10:
		if sm.current_state.name == "Attack":
			break
		await process_frame
	var opened_mid_swing := false
	for i in 60:
		await process_frame
		if _any_hitbox_enabled(box):
			opened_mid_swing = true
			break
	_check("hit box opened mid swing", opened_mid_swing, "")
	sm.change_state("Idle")   # 模拟被强行打断
	await process_frame
	_check("interrupted attack closes hit box", not _any_hitbox_enabled(box), "hitbox=" + _hitbox_states(box))

	# --- 控制组: 站着不动按攻击, 应该能进 Attack ---
	Input.action_press("Attack")
	await process_frame
	Input.action_release("Attack")
	for i in 10:
		if sm.current_state.name == "Attack":
			break
		await process_frame
	_check("attack works while standing still", sm.current_state.name == "Attack", "state=" + sm.current_state.name)
	for i in 120:
		await process_frame
		if sm.current_state.name == "Idle":
			break

	# --- 回归: 松手那一帧按攻击, 不能被吃掉 ---
	Input.action_press("Right")
	await _step(5)
	_check("in Run before the regression test", sm.current_state.name == "Run", "state=" + sm.current_state.name)
	Input.action_release("Right")   # 同一帧里: 松开方向键...
	Input.action_press("Attack")    # ...同时按下攻击键
	await process_frame
	Input.action_release("Attack")
	for i in 10:
		if sm.current_state.name == "Attack":
			break
		await process_frame
	_check("attack pressed on the release frame still fires", sm.current_state.name == "Attack",
		"state=" + sm.current_state.name)

	print("----")
	print("RESULT: ", _pass_count, " passed, ", _fail_count, " failed")
	quit()
