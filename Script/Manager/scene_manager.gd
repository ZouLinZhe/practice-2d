extends Node

func change_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		push_error("场景路径为空")
		return
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("切换场景失败:%s，错误码：%d"%[scene_path,err])
