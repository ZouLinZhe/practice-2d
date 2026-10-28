extends State

## 玩家死亡状态（占位）。
##
## 目前只播放 Die_<朝向>；关闭碰撞、Game Over 和重开流程还没接。
func enter(_msg: Dictionary = {}) -> void:
	super.enter()
	play_animation()
