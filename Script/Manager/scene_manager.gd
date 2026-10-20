extends Node

## 场景切换管理器（项目设置里的 autoload 名：SceneManager）。
##
## 做成 autoload 的原因：
## 1. 切换场景时旧的场景树会被释放，管理器必须活在场景之外；
## 2. 全局只需要一个实例，按钮等任意节点都能直接调用。
##
## 用法：SceneManager.change_scene("res://Scene/test_scene1.tscn")

## 切换到指定场景。路径为空或切换失败时打印错误，方便在输出面板定位问题。
func change_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		push_error("场景路径为空")
		return
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("切换场景失败：%s，错误码：%d" % [scene_path, err])
