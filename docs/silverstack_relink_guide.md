# Silverstack 中的路径变更与重新链接

这份说明只适用于已经完成拷贝、而目的地文件夹后来需要改名的情况。DIT Renamer 的设计场景是在拷贝开始前改卷名；只要流程允许，应优先在拷贝前完成卷名确认，避免改变 Silverstack 已记录的目的地路径。

## 为什么改名会影响 Silverstack

Silverstack 会保存源和目的地的路径、素材信息以及校验结果。直接在 Finder 中改目的地文件夹名后，数据库中的旧路径就不再存在，相关素材可能显示为离线。改名本身不会改变素材内容，但会改变 Silverstack 查找素材的路径。

## 已完成拷贝时的处理方法

1. 确认没有任务正在读取或写入目标文件夹。
2. 在 Finder 中修改文件夹名称，并记下新的完整路径。
3. 在 Silverstack 的 Library 中找到显示为离线的卷或 Bin。
4. 选择 `Relink...`，将路径指向新的文件夹。
5. 按当前 Silverstack 版本提供的选项替换丢失的资源路径；完成后运行文件验证。
6. 确认卷恢复在线，并检查报告中的素材数量、路径和校验状态。

菜单名称会随 Silverstack 版本变化。发布前请以现场安装版本的帮助文档为准。不要把“重新链接成功”当成新的拷贝校验；如果素材发生过移动或改名，仍应使用 Silverstack 的验证功能重新确认。

## 使用路径模板减少返工

在 Silverstack 的 Offload 工作流中，可以用 Path Wildcards 根据项目、机位、卷号或 Bin 名生成目的地路径。先在测试项目中确认模板输出，再用于现场。模板决定的是备份目的地的文件夹组织方式，不会改变摄影机卡内的原始目录和素材文件名。

DIT Renamer 只修改已确认卷的 macOS volume label。它不改卡内素材、不复制素材，也不执行 Silverstack 的 checksum 校验。

参考：[Silverstack Offload Menu](https://kb.pomfort.com/silverstack/reference/library/offload-menu/)、[File Renaming on Offload](https://kb.pomfort.com/silverstack/hands-on/managing-data/file-renaming-on-offload/)、[Path Wildcards](https://kb.pomfort.com/silverstack/reference/workflow-configuration/path-wildcards/)。
