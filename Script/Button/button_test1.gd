extends Button

## 主菜单上的"跳转到测试场景 1"按钮。
##
## 信号在 Scene/Main.tscn 里连接：pressed → _on_pressed。
## 这里只负责调用 SceneManager，不直接操作场景树。

func _on_pressed() -> void:
	SceneManager.change_scene("res://Scene/test_scene1.tscn")
