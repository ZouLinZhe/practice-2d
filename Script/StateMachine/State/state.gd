class_name State
extends Node

## 所有状态（Idle / Run / Attack / ...）的基类。
##
## 下面五个函数就是状态机对外的"接口"：状态机会在合适的时机调用它们，
## 子类按需覆写。函数名必须和这里一字不差（GDScript 区分大小写）：
## 写成 physics_process 或 Physics_process 都不会报错，只会调用到这里的
## 空实现，然后什么都不发生 —— 这是本状态机最容易踩的坑。

## 指向父节点上的状态机，由 StateMachine._ready() 自动注入。
var parent_state_machine: StateMachine

## 指向状态机所属的角色（玩家或敌人），由 StateMachine._ready() 自动注入。
var character: BaseCharacter

## 进入本状态时调用一次：适合在这里重置速度、播放动画、开启无敌帧等。
## [param _msg] 由 StateMachine.change_state() 传入的附加数据，默认为空字典。
func enter(_msg: Dictionary = {}) -> void:
	pass

## 离开本状态时调用一次：适合做收尾，比如停掉音效、恢复属性。
func exit() -> void:
	pass

## 每帧调用一次（渲染帧），用于和物理无关的更新。
## [param _delta] 距离上一帧经过的秒数。
func update(_delta: float) -> void:
	pass

## 每个物理帧调用一次（默认每秒 60 次）：移动、碰撞这类更新写在这里。
## [param _delta] 距离上一个物理帧经过的秒数。
func physics_update(_delta: float) -> void:
	pass

## 有未被 UI 消费掉的输入事件时调用。
## [param _event] 输入事件对象（按键、鼠标滚轮等）。
func handle_input(_event: InputEvent) -> void:
	pass

## 播放"本状态 + 朝向"的动画。
##
## 前缀自动取自状态节点名：Idle 节点播 Idle_Up，Run 节点播 Run_Left。
## 所以子类只要写 play_animation()，前缀就不可能拼错。
## [param heading] 指定朝向；省略(-1)时按角色输入方向自动刷新。
##                  受击这类"朝向由外部决定"的状态可以显式传入。
##                  用 -1 作哨兵，是因为枚举 0~3 都是合法值。
func play_animation(heading: int = -1) -> void:
	if heading < 0:
		character.play_animation(str(name))
	else:
		character.play_animation(str(name), heading)
