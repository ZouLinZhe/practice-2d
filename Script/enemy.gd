extends BaseCharacter
class_name EnemyCharacter

## 敌人角色：在 BaseCharacter 的基础上，额外持有"当前目标（玩家）"。
##
## 敌人和玩家共用 BaseCharacter 的数据、动画和状态机；
## 这里放敌人专属的数据：
## - detection_radius：进入这个距离开始追；
## - detection_escape_radius：超过这个距离放弃追击；
## - player / get_player()：懒查找当前玩家。
##
## 行为逻辑在 EnemyState/ 下：
## - Idle：待机，发现玩家后切到 Run；
## - Run：限频计算方向并持续移动；接触玩家时调用 take_damage；
## - Hurt：短硬直 + 0.2 秒无敌，然后回到 Run / Idle；
## - Die：播放死亡动画、关闭碰撞并释放自己。
##
## 注意：玩家和敌人之间没有物理碰撞（两者可以互相穿过），
## 接触伤害完全由 Attack_Hit_box（Area2D）检测。

## 发现玩家的距离（像素）：进入这个范围就切到 Run。
@export var detection_radius := 100.0

## 脱战半径（像素）：超过这个距离就放弃追击、回到 Idle。
## 必须比 detection_radius 大，形成迟滞，避免玩家在边界来回走时状态闪烁。
@export var detection_escape_radius := 200.0

## 当前锁定的玩家。可能为 null：玩家还没生成，或者已经被场景切换释放。
var player: BaseCharacter

func _ready() -> void:
	# 先尝试找一次；找不到也没关系，get_player() 会在需要时再查。
	player = get_tree().get_first_node_in_group("player") as BaseCharacter
	# 覆盖 _ready 时一定要调父类：BaseCharacter._ready() 负责初始化血量并启动状态机。
	super._ready()

## 获取当前玩家；引用为空或已失效时重新查一次分组。
##
## 不能只在 _ready() 里查一次：玩家可能晚于敌人生成，也可能被场景切换释放，
## 那时旧引用会变成一个"已释放的节点"，必须用 is_instance_valid 判断。
func get_player() -> BaseCharacter:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as BaseCharacter
	return player
