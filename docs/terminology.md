# DIT Renamer 术语 / Terminology

这些词在软件界面、现场说明和导出报告中保持同一含义。

These terms carry the same meaning in the app, field guides, and exported reports.

| 中文 / English | 含义 / Meaning |
| --- | --- |
| 存储卡 / Camera card | 摄影机或录机使用，并以可移除卷挂载到 Mac 的介质。 / Removable media used by a camera or recorder and mounted on the Mac. |
| 卷 / Volume | macOS 挂载并分配卷名的文件系统对象。 / A filesystem mounted by macOS and assigned a volume name. |
| 卷名 / Volume name | Finder 和 `/Volumes` 显示的名称。DIT Renamer 只修改这个名称。 / The name shown in Finder and `/Volumes`. This is the only name DIT Renamer changes. |
| 素材 / Clip | 摄影机写入的单个视频或音频媒体文件。 / One video or audio media file written by the camera. |
| 媒体结构 / Media structure | 卡内目录、扩展名和素材名共同提供的可观察信息。 / Observable information from folders, extensions, and clip names on the card. |
| 卷名建议 / Name suggestion | 根据扫描结果生成、由操作员确认的候选卷名。 / A candidate volume name produced from scan results and confirmed by the operator. |
| 强制重挂载 / Forced remount | 重命名后卸载并重新挂载同一 BSD 分区，再核对 UUID、卷名和挂载路径。 / Unmounting and mounting the same BSD partition after rename, followed by UUID, name, and mount-path checks. |
| 校验通过 / Verification passed | ParaShoot 日志明确记录 `missingFiles: 0`。它不表示 DIT Renamer 执行了拷贝校验。 / ParaShoot explicitly recorded `missingFiles: 0`. It does not mean DIT Renamer verified the transfer. |
| 高置信度关联 / High-confidence association | 校验记录和擦除事件中的源路径明确相同。不会根据相邻日志文本推断。 / The source path is an exact match between the verification and erase records. Nearby log text is not used to infer a match. |
| 审计记录 / Audit record | DIT Renamer 保存的原卷名、新卷名、UUID、BSD 节点、素材范围和操作时间。 / Renamer's record of names, UUIDs, BSD node, clip range, and operation time. |
| HDE 容量参考 / HDE capacity reference | 根据检测到的 ARRIRAW 内容估算的容量，不是编码结果或容量保证。 / An estimated capacity for detected ARRIRAW media, not an encoded result or guaranteed size. |

卷名建议不是相机官方命名的证明。证据不足时，保留原卷名或手动输入。卷名变化也不会改变卡内素材名、目录或内容。

A name suggestion is not proof of an official camera naming scheme. Keep the existing name or enter one manually when evidence is incomplete. Changing a volume name does not change clip names, folders, or media content.
