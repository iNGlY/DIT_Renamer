# livingking5/DIT-Agent-Skill 相机识别实现分析

分析日期：2026-08-09

来源：[livingking5/DIT-Agent-Skill](https://github.com/livingking5/DIT-Agent-Skill)

## 结论

该项目的“相机识别”不是读取相机硬件协议，也不是调用 Silverstack 的相机数据库，而是三层逻辑：

1. 扫描 macOS `/Volumes` 下的一级目录。
2. 以素材路径、目录结构和文件扩展名匹配硬编码正则。
3. 对找到的第一个素材调用 `ffprobe`，尝试读取 `com.apple.quicktime.model` 和 reel/file name。

README/SKILL.md 宣称支持 RED、ARRI、Sony、Canon、Blackmagic、DJI，但当前实现更接近“文件系统形态识别”，不能保证识别所有相机卡，更不能可靠地识别具体机型。

## 调用链

```text
MCP detect_equipment()
  -> detect_camera_cards()
      -> scan /Volumes/*
      -> inspect only first 50 direct children
      -> detect_camera_system(str(volume_path))
  -> extract_project_from_card(card_path)
      -> recursively inspect first 100 sorted entries
      -> ffprobe first supported media file
      -> read camera_model / reel_name
```

对应源码：

- [`server.py`](https://github.com/livingking5/DIT-Agent-Skill/blob/main/server.py)：`detect_camera_cards()`、`extract_project_from_card()`、MCP `detect_equipment()` 和 `quick_offload()`。
- [`media_info.py`](https://github.com/livingking5/DIT-Agent-Skill/blob/main/media_info.py)：`CAMERA_PATTERNS`、`detect_camera_system()`、`get_media_info()`。

## 第一层：识别卡是否像媒体卡

`server.py` 的 `detect_camera_cards()` 扫描 `/Volumes` 下的目录，对每个卷执行：

```python
for f in list(item.iterdir())[:50]:
    if f.is_file() and f.suffix.lower() in media_exts:
        has_media = True
```

它只看卷根目录下前 50 个直接子项，不递归进入 `DCIM`、`PRIVATE`、`CONTENTS`、`CLIPS` 等目录。支持的扩展名包括 `.mov`、`.mp4`、`.mxf`、`.r3d`、`.braw`、`.ari` 等。

因此，常见的卡结构如：

- Sony：`PRIVATE/M4ROOT/CLIP/*.MXF`
- Canon：`PRIVATE/.../*.MXF` 或 `DCIM/.../*.MP4`
- Blackmagic：`DCIM/.../*.BRAW`
- RED：`DCIM/.../*.R3D`

很可能不会被第一层检测到。

## 第二层：路径正则识别系统

`media_info.py` 中的 `CAMERA_PATTERNS` 规则大致如下：

| 系统 | 规则示例 |
|---|---|
| RED | `DCIM.*\.R3D$`、`.RDC`、路径含 `R3D` |
| ARRI | `ARRI/... .ari/.mxf`、`.ari` |
| Sony | `PRIVATE/M4ROOT/CLIP/... .mp4/.mxf`、`PRIVATE/...MPROOT/... .cip` |
| Blackmagic | `DCIM/... .braw`、`.braw` |
| Canon | `DCIM/... .mxf/.mp4`、`PRIVATE/... .mxf/.mp4` |
| DJI | `DCIM/DJI_` |

但当前调用是：

```python
camera = detect_camera_system(str(item))
```

传入的是卷路径，例如 `/Volumes/CARD_A`，不是实际素材路径。因此大多数正则无法命中，结果会是 `Unknown`。`detect_camera_system()` 虽然支持 `directory_structure` 参数，但当前调用没有提供目录结构。

## 第三层：ffprobe 元数据

`extract_project_from_card()` 会递归列出卡内路径，但只取排序后的前 100 项，再筛选支持的媒体扩展名并调用 `get_media_info()`。

`media_info.py` 的 ffprobe 结果只从格式 tags 读取：

```python
camera_model = tags.get("com.apple.quicktime.model", "")
```

然后：

- 有 `camera_model`：将其用于建议项目名，例如 `Sony_FX6_2026-08-09`。
- 有 reel metadata：用作 `card_label`。
- 没有 reel metadata：退回素材文件名 stem。
- 没有 camera model：`camera_model` 保持 `Unknown`。

这层对部分 QuickTime/MOV 素材可能有效，但对 R3D、BRAW、ARRI MXF、Sony MXF 等格式不能假定一定有 `com.apple.quicktime.model`。

## 当前实现的主要问题

1. **嵌套目录卡可能检测不到**：卷根目录只检查一级、前 50 项。
2. **路径规则没有接收到素材路径**：实际调用卷路径，导致大部分相机规则无法命中。
3. **具体机型识别能力弱**：系统分类规则主要依赖目录和扩展名，机型主要依赖单个 ffprobe tag。
4. **只检查第一个合适素材**：同一卷混有多种格式或首个文件元数据异常时，结果可能误导。
5. **项目名和相机型号耦合**：识别出的 camera model 会直接参与建议项目目录命名，存在不稳定或含特殊字符的风险。
6. **没有置信度和人工确认字段**：`Unknown`、单规则命中和可靠元数据命中没有区分，MCP 仍可能继续给出建议路径。

## 更可靠的改进方向

建议改成“卡结构优先、素材元数据复核、低置信度必须确认”：

1. 用 `os.walk` 或 `Path.rglob` 扫描有限深度的相机卡结构，并跳过缓存/隐藏目录。
2. 对每个命中的素材传入完整相对路径：`detect_camera_system(str(file), relative_parts)`。
3. 为每种相机定义结构证据，例如 Sony 的 `PRIVATE/M4ROOT/CLIP`、ARRI 的 `A001R1...`/`.ari`、Blackmagic 的 `.braw`。
4. 对 1 到 3 个素材执行 ffprobe；多个结果一致才提升置信度。
5. 统一读取多种 metadata key，并把 ExifTool 作为补充，而不是只依赖 `com.apple.quicktime.model`。
6. 返回：`camera_system`、`camera_model`、`evidence`、`confidence`、`sample_files`。
7. 只有 `confidence=high` 才自动建议项目名；其余情况显示候选并要求 DIT 确认。

## 对实际 DIT 使用的判断

这个项目的相机识别可以作为“初筛提示”，不能作为自动改卷标、自动格式化或无人确认卸载的安全依据。真正执行卸载前，至少应把源卷路径、卷 UUID、相机目录结构、素材样本和人工确认一起记录；Silverstack、ASC MHL 和校验结果仍应作为拷贝完成的权威证据。

