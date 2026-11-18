# Desktop Todo

Windows 托盘待办。支持添加、编辑、删除和勾选完成。数据保存在本机的 `%LOCALAPPDATA%\DesktopTodo\tasks.json`。

双击 `LaunchTodo.vbs` 打开窗口。若希望登录时自动启动，在 `shell:startup` 中创建指向 `LaunchTodo.vbs` 的快捷方式，并附加 `-Tray` 参数。快捷方式可以使用随项目提供的 `Todo.ico`。

当前使用 Windows 自带的脚本宿主启动。TodoLauncher.cs 是可选的独立启动程序源码。
