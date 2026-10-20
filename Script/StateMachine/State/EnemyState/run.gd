extends State

## 敌人追击状态（目前是占位）。
##
## 计划中的逻辑：
## 1. update() 用 EnemyCharacter.get_player() 取当前玩家；
## 2. 目标存在且仍在 detection_radius 内 → 把方向写进 character.input_direction；
## 3. 目标丢失或超出范围 → change_state("Idle")；
## 4. physics_update() 里按 velocity 调 move_and_slide() 推动身体。
##
## 现在只保留空回调，便于先把场景和状态机结构搭起来。

func enter(_msg: Dictionary = {}) -> void:
	super.enter()

func update(_delta: float) -> void:
	super.update(_delta)
