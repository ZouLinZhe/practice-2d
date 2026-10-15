extends SceneTree

# 敌人规模压测(保留, 改完代码可以重跑对比)
# 用法: godot --headless --path <项目目录> -s res://Codex文件/bench_enemies.gd
#
# 用真实的 base_character.gd + state_machine.gd + idle/run 拼出 N 个敌人, 测每帧 CPU 时间。
# 两种场景对照:
#   spread —— 网格排开、统一朝右走, 互不重叠  => 看状态机/动画本身的开销
#   chase  —— 随机散布、全部追向中心           => 敌人挤成一团, 碰撞查询量大增
# 注意: 无头模式不含渲染/GPU; 60fps 的整帧预算是 16.67ms

var _char_script: Script
var _sm_script: Script
var _idle_script: Script
var _run_script: Script
var _frames: SpriteFrames
var _shape: Shape2D

func _initialize() -> void:
	Engine.max_fps = 60   # 让 process 帧数接近真实游戏的 60fps
	_run()

func _load_assets() -> void:
	_char_script = load("res://Script/base_character.gd")
	_sm_script = load("res://Script/StateMachine/state_machine.gd")
	_idle_script = load("res://Script/StateMachine/State/PlayerState/idle.gd")
	_run_script = load("res://Script/StateMachine/State/PlayerState/run.gd")
	var proto := (load("res://Scene/Player.tscn") as PackedScene).instantiate()
	_frames = proto.get_node("AnimatedSprite2D").sprite_frames
	_shape = proto.get_node("CollisionShape2D").shape
	proto.free()

## 照抄玩家场景的结构拼一个敌人: CharacterBody2D + CollisionShape2D + AnimatedSprite2D + StateMachine + Idle + Run
func _make_enemy(index: int, spread: bool) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.name = "E%d" % index
	e.set_script(_char_script)
	if spread:
		e.position = Vector2((index % 50) * 40.0 - 1000.0, (index / 50) * 40.0 - 800.0)
	else:
		e.position = Vector2(randf_range(-800.0, 800.0), randf_range(-800.0, 800.0))

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	col.shape = _shape
	e.add_child(col)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _frames
	e.add_child(sprite)

	var sm := Node.new()
	sm.name = "StateMachine"
	sm.set_script(_sm_script)
	var idle := Node.new()
	idle.name = "Idle"
	idle.set_script(_idle_script)
	var run_state := Node.new()
	run_state.name = "Run"
	run_state.set_script(_run_script)
	sm.add_child(idle)
	sm.add_child(run_state)
	e.add_child(sm)
	sm.initial_state = idle
	return e

## 采样 frames 个物理帧, 返回 [平均 process 耗时 ms, 平均 physics 耗时 ms]
func _sample(enemies: Array, frames: int, chase: bool) -> Vector2:
	var process_ms := 0.0
	var physics_ms := 0.0
	for i in frames:
		for e in enemies:
			if chase:
				var dir: Vector2 = (Vector2.ZERO - e.position).normalized()
				e.input_direction = dir if dir != Vector2.ZERO else Vector2.RIGHT
			else:
				e.input_direction = Vector2.RIGHT
		await physics_frame
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS)
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	return Vector2(process_ms / frames * 1000.0, physics_ms / frames * 1000.0)

func _run() -> void:
	_load_assets()
	for chase in [false, true]:
		print("=== ", ("chase: 全部追向中心(会挤成一团)" if chase else "spread: 网格排开、互不重叠"), " ===")
		for count in [100, 500, 1000, 2000]:
			var enemies: Array = []
			for i in count:
				var e := _make_enemy(i, not chase)
				root.add_child(e)
				enemies.append(e)
			for i in 15:
				await physics_frame
			var m: Vector2 = await _sample(enemies, 60, chase)
			print("  ", count, " 个\tprocess=", "%.2f" % m.x, "\tphysics=", "%.2f" % m.y,
				"\t合计=", "%.2f" % (m.x + m.y), " ms\t每敌人=", "%.4f" % ((m.x + m.y) / count), " ms")
			for e in enemies:
				e.free()
			await process_frame
	print("注: 无头模式不含渲染/GPU; 60fps 整帧预算 = 16.67ms")
	quit()
