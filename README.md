# practice-2d

用 **Godot 4.7** 做的 2D 练习项目，目标是练透**角色状态机**，并向"单人生存一晚"的小目标推进：四方向移动、朝向、动画、带方向判定框的攻击、受击与无敌帧，全部由状态机驱动，并配套可重复运行的验收脚本和性能压测脚本。

> 这是学习项目，不是成品游戏。代码以"讲清楚为什么这么写"为目标，注释密度偏高。

## 目前进度

**已完成**

- 玩家四方向移动，带加速度过渡（起步渐快）
- 四方向朝向系统（枚举 + 动画后缀表），Idle / Run / Attack / Hurt 共 16 条动画
- 攻击状态：一次性动画 + 按动画帧开关的**方向攻击框**（四个方向各一块碰撞形状）
- 受伤状态：可按攻击来源朝向播放 Hurt 动画、无敌 2 秒（跟随暂停）、动画播完自动回 Idle
- 角色基类 `BaseCharacter`：玩家和敌人共用的数据、动画播放与状态机启动
- 敌人 `EnemyCharacter`：通过 `"player"` 分组找到玩家；Idle 探测 → Run 限频追击 → 超出脱战半径回 Idle
- 接触伤害：敌人 `Attack_Hit_box` 检测到玩家时触发 Hurt；持续接触按 0.5 秒冷却重复触发
- 场景切换：`SceneManager`（autoload）+ Main 场景的按钮
- 验收脚本（30 项，覆盖玩家）与性能压测脚本

**进行中 / 还没做**

- 没有血量、`take_damage()`：接触伤害目前只触发 Hurt 动画与无敌，没有扣血数值
- 玩家和敌人的 `Die` 节点都还没挂脚本
- 没有 HUD、暂停菜单和死亡重开流程

## 运行

需要 **Godot 4.7**（Steam 版或官网版都可以）。

- 用 Godot 打开本目录，按 **F5** 运行（主场景已设为 `Scene/Main.tscn`）
- 只测某个场景：在"文件系统"面板里右键场景 → 运行此场景（F6）

### 操作

| 按键 | 动作 |
| --- | --- |
| `W` `A` `S` `D` | 四方向移动 |
| `J` | 攻击 |

输入动作配置在 项目设置 → 输入映射，动作名是 `Up` / `Down` / `Left` / `Right` / `Attack`。

## 目录结构

```
Scene/
  Main.tscn                   入口场景（一个"跳转"按钮）
  Player.tscn                 玩家：碰撞 + 16 条动画 + 状态机 + 攻击框
  enemy.tscn                  敌人：碰撞 + 8 条动画 + 状态机 + 攻击框
  test_scene1.tscn            测试场景（玩家 + 敌人 + 一张背景图）
Script/
  base_character.gd           角色基类：数据、动画、状态机启动
  player.gd                   玩家：读键盘，并把自己加入 "player" 分组
  enemy.gd                    敌人：探测半径 + 玩家引用 + 懒查找
  StateMachine/
    state_machine.gd          状态机：收集状态、每帧转发、change_state
    State/
      state.gd                状态基类：五个回调 + play_animation
      PlayerState/
        idle.gd               玩家待机
        run.gd                玩家移动
        attack.gd             玩家攻击（含方向攻击框）
        hurt.gd               玩家受击（朝向 + 无敌 + 自动回 Idle）
      EnemyState/
        idle.gd               敌人待机（探测玩家）
        run.gd                敌人追击（限频决策 + 脱战 + 接触伤害）
  Manager/scene_manager.gd    场景切换（autoload 名：SceneManager）
  Button/button_test1.gd      按钮脚本
Codex文件/
  verify_statemachine.gd      验收脚本（30 项，覆盖玩家）
  bench_enemies.gd            敌人规模性能压测
Asset/                        角色、敌人动画图集与背景图
```

## 架构

### 各层职责

| 谁 | 负责什么 |
| --- | --- |
| `BaseCharacter` | 所有角色共有的东西：朝向、速度、加速度、`input_direction`、动画播放、状态机启动 |
| `Player`（继承它） | 只决定"往哪走"：读键盘写进 `input_direction`，把攻击键写进 `attack_pressed`，并加入 `"player"` 分组 |
| `EnemyCharacter`（继承它） | 敌人专属：`detection_radius`、`detection_escape_radius`、玩家引用、`get_player()` |
| `StateMachine` | 收集子状态、每帧把回调转发给当前状态、执行状态切换 |
| `State`（基类） | 定义五个回调接口 + `play_animation(heading)` 转发 |
| `Idle` / `Run` / `Attack` / `Hurt` | 具体逻辑：怎么动、什么时候切到下一个状态 |

关键设计：**状态不自己读键盘**。它只读角色的 `input_direction`（移动意图）和 `consume_attack()`（攻击意图），所以同一套状态能同时服务玩家和敌人。

### 玩家场景结构（Player.tscn）

```
Player (CharacterBody2D)         ← player.gd（继承 BaseCharacter），layer = 玩家层（2）
├─ CollisionShape2D              身体碰撞（胶囊，radius 10 / height 30）
├─ AnimatedSprite2D              16 条动画：Idle_/Run_/Attack_/Hurt_ × 上/下/左/右
├─ Camera2D                      跟随
├─ StateMachine                  ← state_machine.gd，initial_state = Idle
│  ├─ Idle                       ← idle.gd
│  ├─ Run                        ← run.gd
│  ├─ Attack                     ← attack.gd
│  ├─ Hurt                       ← hurt.gd
│  └─ Die                        （暂时没有脚本，不会注册进状态池）
└─ Attack_Hit_Box (Area2D)       攻击判定区（layer 0 / mask 4，只检测敌人层）
   ├─ Up_Hitbox / Down_Hitbox / Left_Hitbox / Right_Hitbox  (CollisionShape2D)
```

### 敌人场景结构（enemy.tscn）

```
Enemy (CharacterBody2D)          ← enemy.gd（EnemyCharacter，继承 BaseCharacter），layer = 敌人层（4）
├─ AnimatedSprite2D              8 条动画：Idle_/Run_ × 上/下/左/右
├─ CollisionShape2D              身体碰撞（圆形）
├─ Attack_Hit_box (Area2D)       接触伤害判定区（layer 0 / mask 2，只检测玩家层）
│  └─ CollisionShape2D
└─ StateMachine                  initial_state = Idle
   ├─ Idle                       ← EnemyState/idle.gd
   ├─ Run                        ← EnemyState/run.gd（占位）
   ├─ Hurt                       （暂时没有脚本）
   └─ Die                        （暂时没有脚本）
```

### 状态机的调用流程

```
StateMachine._process         → current_state.update()           每渲染帧
StateMachine._physics_process → current_state.physics_update()   每物理帧
StateMachine._unhandled_input → current_state.handle_input()     输入事件
change_state("Run")           → 旧状态 exit() → 新状态 enter(msg)
```

启动顺序有个坑：Godot 的 `_ready()` 是**子节点先于父节点**执行，而 `@onready` 变量在各自 `_ready()` 之前才赋值。所以状态机不能在自己的 `_ready()` 里进入初始状态（那时 `character.animated_sprite_2d` 还是 `null`）。改由 `BaseCharacter._ready()` 调用 `state_machine.start()`，保证所有引用都就位了再进第一个状态。

**子类覆盖 `_ready()` 时必须调用 `super._ready()`**，否则父类里启动状态机的代码不会执行——敌人的 `EnemyCharacter._ready()` 就是这个写法。

### 敌人怎么找到玩家

玩家在 `player.gd` 的 `_ready()` 里加入 `"player"` 分组；敌人通过分组查找，而不是硬编码节点路径：

```gdscript
func get_player() -> BaseCharacter:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as BaseCharacter
	return player
```

懒查找解决两个问题：玩家可能晚于敌人生成；场景切换后旧引用会变成"已释放的节点"。状态里使用前必须判空。

### 受伤状态的朝向

`Hurt.enter()` 支持从 `msg` 里取攻击者位置：

```gdscript
state_machine.change_state("Hurt", {"from": attacker.global_position})
```

传了 `from` 就朝攻击者播 `Hurt_<方向>`；没传就按输入方向刷新。`play_animation(prefix, heading)` 的 `heading` 省略时会自动调用 `face_towards()`，显式传入时会写回 `facing_direction`。

### 接触伤害流程

```
玩家走进敌人的 Attack_Hit_box（mask = 玩家层）
  → Run._on_attack_hit_box_body_entered()  立即尝试一次
  → Run._tick_contact_damage()             持续接触时每 0.5 秒重试
  → player.state_machine.change_state("Hurt", {"from": 敌人位置})
```

`body_entered` 只在进入瞬间触发一次，所以"一直贴着"必须靠物理帧轮询 `get_overlapping_bodies()` 补上。玩家处于无敌时会跳过伤害且不进入冷却，无敌结束后会立刻再次命中。只有 Run 状态会造成接触伤害，Idle 碰到不扣血。

玩家和敌人之间**没有物理碰撞**（两者可以互相穿过），伤害完全由 Area2D 负责。

### 加一个新状态要做什么

1. 在角色的 `StateMachine` 下新建 Node，**节点名就是动画名前缀**（比如 `Hurt` 对应 `Hurt_Up` / `Hurt_Down` …）
2. 给它挂一个 `extends State` 的脚本
3. 在 `AnimatedSprite2D` 的 SpriteFrames 里准备对应动画
4. 在别的状态里用 `parent_state_machine.change_state("Hurt")` 触发
5. 想让角色一开始就停在这个状态，把 `StateMachine.initial_state` 指向它

## 验收与压测

两个脚本都在 `Codex文件/` 下，用无头模式运行（把 `godot` 换成你自己的 Godot 可执行文件路径）：

```powershell
# 验收：30 项检查——状态切换、加速度过渡、四方向朝向与动画、攻击框开关、被打断时的清理
godot --headless --path . -s res://Codex文件/verify_statemachine.gd

# 压测：模拟不同数量的敌人，测每帧 CPU 开销
godot --headless --path . -s res://Codex文件/bench_enemies.gd
```

验收脚本逐条打印 `[PASS]` / `[FAIL]` 并给出总数。目前 30 项都针对玩家；敌人的"探测 → Run"行为是在开发过程中用临时探针验证的，还没有加入这个脚本。

### 性能压测结果

本机实测，无头模式（不含渲染），60fps 的整帧预算是 **16.67ms**。下表是在加入敌人状态之前测的，作为量级参考：

| 敌人数 | process | physics | 合计 |
| --- | --- | --- | --- |
| 100 | 0.15 ms | 0.18 ms | **0.33 ms** |
| 500 | 7.83 ms | 1.18 ms | **9.01 ms** |
| 1000 | 23.47 ms | 5.54 ms | **29.01 ms** |
| 2000 | 44.88 ms | 12.12 ms | **56.99 ms** |

上表是敌人分散、互不重叠的情况；如果敌人全挤在玩家周围，physics 会明显上升（压测脚本里有 `chase` 对照场景）。

结论：

- 状态机逻辑本身的开销可以忽略——每帧不过是查一次字典、调一次函数
- 大头在 **process 侧**：移动状态每帧都调 `play_animation()`，内部要做 `str(name)`、字符串拼接、`AnimatedSprite2D.play()`
- 优化方向：只在朝向或状态**变化**时才播动画，预期能把这一块压到接近 0

## 约定与坑

都是踩过的，加新状态前先看一遍：

1. **状态回调名必须一字不差。** `State` 基类有五个空实现兜底，写成 `physics_process` 或 `Physics_process` 都不会报错，只是**静默不执行**
2. **状态节点名 = 动画名前缀。** `Idle` 节点播的是 `Idle_Up`，改了节点名要连带改动画名
3. **`HEADING_SUFFIX` 的顺序必须和 `enum Heading` 一一对应。** 往枚举中间插新方向时忘了同步，表现是"朝左播了下方的动画"，而且不报错
4. **一次性动画必须 `loop = false`。** 循环开着的话状态永远退不出去（攻击会变成原地无限挥）
5. **进状态时打开的东西，必须在 `exit()` 里关掉。** 攻击框、无敌帧、加速状态都算；否则一旦被打断就会泄漏到别的状态去
6. **循环动画每帧调 `play()` 没关系**（同一动画不会重播），但**播完之后**再调会重新开始——一次性动画只能在 `enter()` 里播一次
7. **攻击框结构是约定**：角色根节点下的 `Attack_Hit_Box`（Area2D），里面是 `Up_Hitbox` / `Down_Hitbox` / `Left_Hitbox` / `Right_Hitbox`
8. **重命名或移动脚本请在 Godot 的"文件系统"面板里做。** 在编辑器外面增删文件，Godot 会给文件重新分配 UID，场景里的旧引用随之失效并打印 `invalid UID` 警告
9. **覆盖 `_ready()` 必须调 `super._ready()`。** 否则父类里启动状态机的代码不会执行（敌人一开始就踩过）
10. **找玩家用分组，不要硬编码路径。** `get_tree().root.get_node("Scene/Player")` 这种写法在单独运行场景、换场景、玩家改名时都会失败；用 `"player"` 分组 + `is_instance_valid` 懒查找
11. **动画名拼写要在四个方向上都核对。** 项目里出现过两次 `Letf`（应为 `Left`），表现是朝左时动画不播、输出面板报 `There is no animation with name ...`
12. **`body_entered` 只在进入瞬间触发一次。** 持续接触要在物理帧轮询 `get_overlapping_bodies()`（配合冷却），否则玩家贴着敌人只会掉一次血

## 已知限制（当前阶段）

- 没有血量与 `take_damage()`：接触伤害只触发动画和无敌，没有扣血
- 玩家和敌人的 `Die` 节点都没有脚本，进不了死亡状态
- 敌人的 `Hurt` / `Die` 状态还没有实现
- 没有 HUD、暂停菜单、死亡重开

## 后续计划

- [ ] 血量、`take_damage()`，把接触伤害收口成数值伤害
- [ ] `Die` 状态（玩家 / 敌人）+ 死亡后重开
- [x] 敌人 `Run`：限频追击、超出范围回 Idle
- [x] 接触伤害：敌人攻击框 + 冷却触发玩家 Hurt
- [ ] 敌人 `Hurt` / `Die` 状态脚本
- [ ] 把敌人的追击 / 脱战 / 接触伤害加入验收脚本
- [ ] 小重构：`input_direction` → `move_direction`；`HEADING_SUFFIX` 标注成 `Array[String]`；移动逻辑收成 `BaseCharacter` 的动词

## 素材

角色与敌人动画素材的来源和授权信息待补充。如果这些素材来自第三方素材包，请在这里注明来源与许可协议。
