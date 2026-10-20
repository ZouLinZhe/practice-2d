extends BaseCharacter
class_name EnemyCharacter

## 敌人角色：在 BaseCharacter 的基础上，额外持有"当前目标（玩家）"。
##
## 敌人和玩家共用 BaseCharacter 的数据、动画和状态机，
## 这里只加两样敌人专属的东西：探测半径 + 玩家引用。
##
## 状态节点：Idle / Run（Hurt、Die 节点暂时没挂脚本）。
## 目前 Idle 只做一件事：玩家进入 detection_radius 就切到 Run；
## Run 的追击逻辑还是占位。

## 发现玩家的距离（像素）。在检查器里按敌人类型单独调。
@export var detection_radius := 100.0

## 当前锁定的玩家。可能为 null：玩家还没生成，或者已经被场景切换释放。
var player: BaseCharacter

func _ready() -> void:
	# 先尝试找一次；找不到也没关系，get_player() 会在需要时再查。
	player = get_tree().get_first_node_in_group("player") as BaseCharacter
	# 覆盖 _ready 时一定要调父类：BaseCharacter._ready() 负责启动状态机。
	super._ready()

## 获取当前玩家；引用为空或已失效时重新查一次分组。
##
## 不能只在 _ready() 里查一次：玩家可能晚于敌人生成，也可能被场景切换释放，
## 那时旧引用会变成一个"已释放的节点"，必须用 is_instance_valid 判断。
func get_player() -> BaseCharacter:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as BaseCharacter
	return player
