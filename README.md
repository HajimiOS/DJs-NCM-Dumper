# 111Dump (TRENCH3)

**中文** · 批量将 `.ncm` 解密为 mp3/flac。把 `.bat` 放进含 `.ncm` 的文件夹后，会扫描**该文件夹及所有子文件夹**。

**EN** · Batch-decrypt `.ncm` files to mp3/flac. Copy the `.bat` into your music folder; it scans **that folder and all subfolders**.

---

## 文件 / Files

| File | 说明 (ZH) | Description (EN) |
|------|-----------|------------------|
| `111Dump-中文版.bat` | 中文版源码（便于修改、调试） | Chinese source (edit & debug) |
| `111Dump-EN.bat` | 英文版源码（便于修改、调试） | English source (edit & debug) |
| `111Dump-中文版-beta.bat` | **中文版 beta**（内嵌压缩脚本，**推荐日常使用**） | Chinese **beta** build (compressed embedded script; **recommended**) |
| `111Dump-EN-beta.bat` | 英文版 beta（内嵌压缩脚本） | English beta build (compressed embedded script) |

- **中文**：文件名以 `111` 开头，便于在资源管理器里排在靠前位置。  
- **EN**: Files are prefixed with `111` so they sort near the top in Explorer.

| | 中文 | EN |
|---|------|-----|
| **日常使用** | 将 **`111Dump-中文版-beta.bat`** 拖入含 `.ncm` 的根目录，再双击运行 | Drag **`111Dump-中文版-beta.bat`** (or **`111Dump-EN-beta.bat`**) into your `.ncm` root folder, then double-click |
| **改逻辑** | 编辑 `111Dump-中文版.bat` / `111Dump-EN.bat`，再运行 `python _build_release.py` 重新生成 beta 版 | Edit the source `.bat` files, then run `python _build_release.py` to rebuild beta builds |

---

## 环境要求 / Requirements

| | 中文 | EN |
|---|------|-----|
| OS | **Windows**（`.bat` 使用 `cmd.exe`） | **Windows** (`cmd.exe`) |
| Python | **Python 3.10+** 与 `pip`（安装时勾选 *Add to PATH*） | **Python 3.10+** and `pip` (*Add python.exe to PATH* during install) |
| 依赖 / deps | 首次运行可自动安装：`ncmdump-py`、`rich` | On first run, missing packages can be installed automatically: `ncmdump-py`, `rich` |

---

## 使用 / Usage

1. **中文**：把要用的 `.bat`（推荐 **`111Dump-中文版-beta.bat`**）复制或拖进**放有 `.ncm` 的那一层目录**（例如歌单根目录 `TRANCE\`）。`.ncm` 可以在该目录下的任意子文件夹里，不必和 `.bat` 放在同一层。  
   **EN**: Copy or drag the `.bat` you want (recommended: **`111Dump-中文版-beta.bat`**) into the **root folder that contains your `.ncm` files** (e.g. your playlist folder). `.ncm` files may sit in subfolders under that root; they do not need to be next to the `.bat`.

2. **中文**：在该目录里**双击**这个 `.bat` 运行（不要只在仓库目录里双击，除非 `.ncm` 就在仓库里）。  
   **EN**: **Double-click** the `.bat` in that folder to run it (running it from the Git repo only works if your `.ncm` files are actually there).

3. **中文**：按窗口或命令行提示确认，等待转换完成。  
   **EN**: Confirm the dialogs or prompts and wait until conversion finishes.

> **中文**：脚本以 **`.bat` 所在文件夹** 为工作根目录，不会自动去扫别的盘符路径。  
> **EN**: The script uses the **folder where the `.bat` lives** as the work root; it does not scan other drives unless you place the `.bat` there.

### 运行前自动处理 / Automatic pre-processing

| 中文 | EN |
|------|-----|
| 删除歌词、无用说明文本 | Remove lyric files and junk text files |
| 提取 `VipSongsDownload` 文件夹内容到上级目录 | Extract contents of `VipSongsDownload` folders upward |
| 去重 `(1)`、`副本` 等重复的可播放音频 | Deduplicate playable audio with `(1)`, copy suffixes, etc. |
| **不自动删除** `.\ncm\` 归档；仅在转换结束后由你确认是否删除已有 FLAC/MP3 对应的归档 `.ncm` | **Does not** auto-delete `.\ncm\` archive; optional cleanup of archived `.ncm` only after you confirm at the end |

### 输出位置 / Output layout

| 中文 | EN |
|------|-----|
| 转换后的 **mp3/flac** 留在各 `.ncm` 所在目录 | Converted **mp3/flac** stay next to each `.ncm` |
| 原始 `.ncm` 移入 **`.\ncm\`** 归档 | Original `.ncm` files are moved into **`.\ncm\`** |

---

## 维护 / Maintenance

**中文**

- 逻辑与修复：优先改 `111Dump-EN.bat` 中的内嵌 Python，再同步 `111Dump-中文版.bat` 的中文文案与弹窗。
- beta 版：修改源码后执行 `python _build_release.py`，会生成/更新 `111Dump-中文版-beta.bat` 与 `111Dump-EN-beta.bat`。

**EN**

- Logic changes: edit the embedded Python in `111Dump-EN.bat` first, then mirror updates in `111Dump-中文版.bat` (Chinese strings and dialogs).
- Beta builds: after editing sources, run `python _build_release.py` to refresh `111Dump-中文版-beta.bat` and `111Dump-EN-beta.bat`.

---

Made by **TRENCH3**
