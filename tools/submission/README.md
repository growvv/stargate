# 提交材料制作脚本

本目录用于生成 `submission/` 中的最终材料，**不属于提交内容**。提交时只需要打包 `submission/`。

## 目录

- `assets/`：文档与 PPT 使用的截图、架构图、路线图和品牌素材。
- `make_assets.py`：生成截图裁切、示意图和能力分布图。
- `make_doc.py`：生成项目文档 DOCX。
- `_update_doc.py`：刷新 Word 目录与页码，并导出 PDF。
- `make_ppt.py`：生成答辩 PPT。
- `_export_pdf.py`：把答辩 PPT 导出为 PDF。
- `_export_slides.py`：把 PPT 导出为 1920×1080 PNG，供视频使用。
- `video/`：演示视频的旁白稿、TTS 脚本和合成脚本。

## 生成顺序

1. `make_assets.py`
2. `make_doc.py` → `_update_doc.py`
3. `make_ppt.py` → `_export_pdf.py` → `_export_slides.py`
4. `video/_tts.ps1` → `video/_build_video.py`

生成结果统一写入仓库根目录的 `submission/`；签名 HAP 由 `harmony/` 工程构建与签名流程产出，直接放在 `submission/`。中间文件（渲染图、音频、视频片段）由 `.gitignore` 排除。
