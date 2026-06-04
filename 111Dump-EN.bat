@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
rem Process .ncm files in this bat folder and all subfolders
for %%I in ("%~dp0.") do set "WORKDIR=%%~fI"

set "PYTHON="
for %%V in (313 312 311 310) do (
    if "!PYTHON!"=="" if exist "!LOCALAPPDATA!\Programs\Python\Python%%V\python.exe" set "PYTHON=!LOCALAPPDATA!\Programs\Python\Python%%V\python.exe"
)

if "!PYTHON!"=="" (
    where py >nul 2>&1
    if not errorlevel 1 for /f "delims=" %%P in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do if "!PYTHON!"=="" set "PYTHON=%%P"
)

if "!PYTHON!"=="" (
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON=python"
)

echo.

if "!PYTHON!"=="" (
    call :err_popup py_missing
    endlocal & exit /b 1
)

"!PYTHON!" -c "import sys" >nul 2>&1
if errorlevel 1 (
    call :err_popup py_invalid
    endlocal & exit /b 1
)

"!PYTHON!" -m pip --version >nul 2>&1
if errorlevel 1 (
    call :err_popup pip_missing
    endlocal & exit /b 1
)

"!PYTHON!" -c "import ncmdump" >nul 2>&1
if errorlevel 1 (
    call :ncmdump_offer_install
    if errorlevel 1 (
        call :err_popup ncmdump_missing
        endlocal & exit /b 1
    )
)

goto :do_run

:ncmdump_offer_install
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Add-Type -AssemblyName System.Windows.Forms; ^
  $r = [System.Windows.Forms.MessageBox]::Show( ^
    'ncmdump-py is not installed.`n`nInstall it now automatically?`n`n  [Yes] Run pip install -U ncmdump-py`n  [No] Show manual instructions and exit', ^
    '111Dump — Setup', ^
    [System.Windows.Forms.MessageBoxButtons]::YesNo, ^
    [System.Windows.Forms.MessageBoxIcon]::Question); ^
  if ($r -eq [System.Windows.Forms.DialogResult]::Yes) { exit 0 } else { exit 1 }"
if errorlevel 1 exit /b 1
echo Installing ncmdump-py ...
"!PYTHON!" -m pip install -U ncmdump-py
if errorlevel 1 (
    call :err_popup ncmdump_install_failed
    exit /b 1
)
"!PYTHON!" -c "import ncmdump" >nul 2>&1
if errorlevel 1 (
    call :err_popup ncmdump_install_failed
    exit /b 1
)
exit /b 0

:err_popup
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Add-Type -AssemblyName System.Windows.Forms; ^
  $icon = [System.Windows.Forms.MessageBoxIcon]::Error; ^
  if ('%~1' -eq 'py_missing') { $m = @'
No usable Python was found.

Install Python 3.10 or newer:
https://www.python.org/downloads/

Check "Add python.exe to PATH" during setup.
'@ } ^
  elseif ('%~1' -eq 'py_invalid') { $m = @'
Python is not usable (often the Microsoft Store stub).

Install the full release from:
https://www.python.org/downloads/
'@ } ^
  elseif ('%~1' -eq 'pip_missing') { $m = @'
pip is missing or not working.

Reinstall Python and include pip:
https://www.python.org/downloads/
'@ } ^
  elseif ('%~1' -eq 'ncmdump_install_failed') { $m = @'
Automatic install of ncmdump-py failed.

Run manually in a terminal:
pip install -U ncmdump-py

PyPI (copy):
https://pypi.org/project/ncmdump-py/

Project (copy):
https://github.com/ww-rm/ncmdump-py
'@ } ^
  else { $m = @'
The ncmdump-py module is not installed.

Run in a terminal:
pip install -U ncmdump-py

PyPI (copy):
https://pypi.org/project/ncmdump-py/

Project (copy):
https://github.com/ww-rm/ncmdump-py
'@ }; ^
  [void][System.Windows.Forms.MessageBox]::Show($m, '111Dump — Setup', 0, $icon)"
exit /b 0

:do_run
set "PYSCRIPT=%TEMP%\ncmdump_%RANDOM%.py"
more +135 "%~f0" > "!PYSCRIPT!"
"!PYTHON!" "!PYSCRIPT!" "!WORKDIR!"
set "ERR=!ERRORLEVEL!"
del "!PYSCRIPT!" 2>nul
echo.
pause
endlocal & exit /b !ERR!

# -*- coding: utf-8 -*-
import ctypes
import importlib
import logging
import os
import re
import shutil
import subprocess
import sys
from ctypes import wintypes
from pathlib import Path

os.environ.setdefault("LOGURU_LEVEL", "ERROR")
os.environ.setdefault("LOGURU_COLORIZE", "0")
logging.disable(logging.CRITICAL)

FROZEN = getattr(sys, "frozen", False)
_STDOUT_HANDLE = -11

MUSIC_SUFFIXES = {".mp3", ".flac", ".m4a", ".wav", ".aac", ".ogg", ".wma"}
MUSIC_SUFFIXES_CF = {suffix.casefold() for suffix in MUSIC_SUFFIXES}
LYRIC_SUFFIXES = {".lrc", ".krc", ".qrc", ".trc", ".yrc", ".lys"}
JUNK_FILE_NAMES = {
    "拷贝后其他播放器不可播放的解决方案.txt",
}
JUNK_NAME_PATTERNS = (
    re.compile(r"拷贝后.*不可播放.*\.txt$", re.IGNORECASE),
)
VIP_DOWNLOAD_DIR_NAMES = {"vipsongsdownload"}
SCAN_SUFFIXES = MUSIC_SUFFIXES | {".ncm"}
SCAN_SUFFIXES_CF = {suffix.casefold() for suffix in SCAN_SUFFIXES}
_COPY_SUFFIX_PATTERNS = (
    re.compile(r"\s*[\(\（]\d+[\)\）]$"),
    re.compile(r"\s*-\s*副本(?:\s*[\(\（]\d+[\)\）])?$", re.IGNORECASE),
    re.compile(r"\s*-\s*复制(?:\s*[\(\（]\d+[\)\）])?$", re.IGNORECASE),
    re.compile(r"\s*-\s*copy(?:\s*\d+)?$", re.IGNORECASE),
)
APP_TITLE = "111Dump"
MB_OK = 0x0
MB_YESNO = 0x04
MB_YESNOCANCEL = 0x03
MB_ICONINFORMATION = 0x40
MB_ICONERROR = 0x10
MB_ICONQUESTION = 0x20
MB_TOPMOST = 0x00040000
MB_SETFOREGROUND = 0x00010000
MB_DIALOG = MB_TOPMOST | MB_SETFOREGROUND
IDYES, IDNO, IDCANCEL = 6, 7, 2

console = None
NeteaseCloudMusicFile = None
Console = None
Group = None
Live = None
Rule = None
Text = None
Tree = None


def setup_console_output():
    os.environ["PYTHONUTF8"] = "1"
    os.environ["PYTHONIOENCODING"] = "utf-8"
    if os.name != "nt":
        return
    kernel32 = ctypes.windll.kernel32
    try:
        kernel32.SetConsoleCP(65001)
        kernel32.SetConsoleOutputCP(65001)
    except Exception:
        pass
    try:
        os.system("chcp 65001 >nul 2>nul")
    except Exception:
        pass
    try:
        h = kernel32.GetStdHandle(_STDOUT_HANDLE)
        mode = wintypes.DWORD()
        kernel32.GetConsoleMode(h, ctypes.byref(mode))
        kernel32.SetConsoleMode(h, mode.value | 0x0004)
    except Exception:
        pass
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except Exception:
                pass


def _console_encoding():
    if os.name != "nt":
        return "utf-8"
    cp = ctypes.windll.kernel32.GetConsoleOutputCP()
    if cp == 65001:
        return "utf-8"
    if cp in (936, 54936):
        return "gbk"
    return "utf-8"


def wprint(text: str = "", end: str = "\n"):
    chunk = text + end
    enc = _console_encoding()
    try:
        sys.stdout.buffer.write(chunk.encode(enc, errors="replace"))
        sys.stdout.buffer.flush()
    except Exception:
        sys.stdout.write(chunk)
        sys.stdout.flush()


def _console_supports_ansi() -> bool:
    if os.name != "nt":
        return True
    try:
        if ctypes.windll.kernel32.GetConsoleOutputCP() == 65001:
            return True
        h = ctypes.windll.kernel32.GetStdHandle(_STDOUT_HANDLE)
        mode = wintypes.DWORD()
        ctypes.windll.kernel32.GetConsoleMode(h, ctypes.byref(mode))
        return bool(mode.value & 0x0004)
    except Exception:
        return False


def wprint_ansi(text: str = "", end: str = "\n"):
    """Print with ANSI colors; use WriteConsoleW on Windows when possible."""
    chunk = text + end
    if os.name == "nt":
        try:
            h = ctypes.windll.kernel32.GetStdHandle(_STDOUT_HANDLE)
            ctypes.windll.kernel32.WriteConsoleW(h, chunk, len(chunk), None, None)
            return
        except Exception:
            pass
    wprint(text, end=end)


def ok_box(title, text, *, error=False):
    icon = MB_ICONERROR if error else MB_ICONINFORMATION
    ctypes.windll.user32.MessageBoxW(0, text, title, MB_OK | icon | MB_DIALOG)


def yes_no_box(title, text):
    return ctypes.windll.user32.MessageBoxW(0, text, title, MB_YESNO | MB_ICONQUESTION | MB_DIALOG)


def choice_box(title, text):
    return ctypes.windll.user32.MessageBoxW(
        0, text, title, MB_YESNOCANCEL | MB_ICONQUESTION | MB_DIALOG
    )


def confirm_start(title, text):
    return ctypes.windll.user32.MessageBoxW(0, text, title, MB_YESNO | MB_ICONQUESTION | MB_DIALOG)


def confirm_yes_no_cli(prompt, *, default=False):
    suffix = "Y/n" if default else "y/N"
    while True:
        wprint(f"{prompt} [{suffix}]: ", end="")
        try:
            answer = input()
        except EOFError:
            answer = ""
        choice = answer.strip().casefold()
        if not choice:
            return default
        if choice in {"y", "yes"}:
            return True
        if choice in {"n", "no"}:
            return False
        wprint("Please enter Y or N.")


def _pip_ok():
    try:
        subprocess.run(
            [sys.executable, "-m", "pip", "--version"],
            capture_output=True,
            check=True,
        )
        return True
    except (subprocess.CalledProcessError, OSError):
        return False


def _pip_install(pip_name: str) -> bool:
    try:
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "-U", pip_name],
            check=True,
        )
        return True
    except (subprocess.CalledProcessError, OSError):
        return False


def _ensure_import(module: str, pip_name: str) -> bool:
    try:
        if module == "ncmdump":
            from contextlib import redirect_stderr, redirect_stdout
            from io import StringIO

            _buf = StringIO()
            with redirect_stdout(_buf), redirect_stderr(_buf):
                importlib.import_module(module)
        else:
            importlib.import_module(module)
        return True
    except ImportError:
        pass

    if (
        yes_no_box(
            f"{APP_TITLE} — Setup",
            f"{pip_name} is not installed.\n\n"
            f"Install it now automatically?\n\n"
            f"  [Yes] Run pip install -U {pip_name}\n"
            f"  [No] Show manual instructions and exit",
        )
        != IDYES
    ):
        ok_box(
            f"{APP_TITLE} — Setup",
            f"The {pip_name} package is not installed.\n\n"
            f"Run in a terminal:\n"
            f"pip install -U {pip_name}\n\n"
            f"PyPI (copy):\n"
            f"https://pypi.org/project/{pip_name}/",
            error=True,
        )
        return False

    wprint(f"Installing {pip_name} ...")
    if not _pip_install(pip_name):
        ok_box(
            f"{APP_TITLE} — Setup",
            f"Automatic install of {pip_name} failed.\n\n"
            f"Run manually:\npip install -U {pip_name}",
            error=True,
        )
        return False

    importlib.invalidate_caches()
    try:
        importlib.import_module(module)
        return True
    except ImportError as e:
        ok_box(
            f"{APP_TITLE} — Setup",
            f"Still cannot import {module} after install.\n\n{e}",
            error=True,
        )
        return False


def bootstrap_env() -> bool:
    if sys.version_info < (3, 10):
        ok_box(
            f"{APP_TITLE} — Environment error",
            "No usable Python was found.\n\n"
            "Install Python 3.10 or newer:\n"
            "https://www.python.org/downloads/\n\n"
            'Check "Add python.exe to PATH" during setup.',
            error=True,
        )
        return False

    if not _pip_ok():
        ok_box(
            f"{APP_TITLE} — Environment error",
            "pip is missing or not working.\n\n"
            "Reinstall Python and include pip:\n"
            "https://www.python.org/downloads/",
            error=True,
        )
        return False

    if not _ensure_import("ncmdump", "ncmdump-py"):
        return False
    if not _ensure_import("rich", "rich"):
        return False
    return True


def init_conversion_stack():
    global console, NeteaseCloudMusicFile, Console, Group, Live, Rule, Text, Tree

    from contextlib import redirect_stderr, redirect_stdout
    from io import StringIO

    from rich.console import Console as _Console
    from rich.live import Live as _Live
    from rich.rule import Rule as _Rule
    from rich.text import Text as _Text
    from rich.tree import Tree as _Tree
    from rich.console import Group as _Group

    os.environ.setdefault("LOGURU_LEVEL", "ERROR")
    logging.disable(logging.CRITICAL)
    _buf = StringIO()
    with redirect_stdout(_buf), redirect_stderr(_buf):
        from ncmdump.core import NeteaseCloudMusicFile as _NCM

    logging.getLogger("App").disabled = True
    NeteaseCloudMusicFile = _NCM
    Console, Group, Live, Rule, Text, Tree = _Console, _Group, _Live, _Rule, _Text, _Tree
    console = Console(file=sys.stdout, force_terminal=True)


def _rich_text(value):
    from rich.markup import escape

    if isinstance(value, Path):
        text = value.resolve().as_posix()
    else:
        text = str(value).replace("\\", "/")
    return escape(text)


def print_banner():
    wprint()
    if FROZEN:
        wprint("  +-------------------------------------------------------+")
        wprint("  |              NCM Convert  -  TRENCH3                  |")
        wprint("  +-------------------------------------------------------+")
    else:
        cyan, yellow, reset = "\033[96m", "\033[93m", "\033[0m"
        use_color = _console_supports_ansi()
        art = (
            "\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2557   \u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2557",
            "\u255a\u2550\u2550\u2588\u2588\u2554\u2550\u2550\u255d\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2551\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557 \u255a\u2550\u2550\u2550\u2550\u2588\u2588\u2557",
            "    \u2588\u2588\u2551   \u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d\u2588\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2554\u2588\u2588\u2557 \u2588\u2588\u2551\u2588\u2588\u2551     \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2588\u2588\u2588\u2554\u255d",
            "    \u2588\u2588\u2551   \u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u255d  \u2588\u2588\u2551\u255a\u2588\u2588\u2557\u2588\u2588\u2551\u2588\u2588\u2551     \u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557      \u2588\u2588\u2551",
            "    \u2588\u2588\u2551   \u2588\u2588\u2551  \u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2551 \u255a\u2588\u2588\u2588\u2588\u2551\u255a\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2551  \u2588\u2588\u2551 \u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d",
            "    \u255a\u2550\u255d   \u255a\u2550\u255d  \u255a\u2550\u255d\u255a\u2550\u2550\u2550\u2550\u2550\u2550\u255d\u255a\u2550\u255d  \u255a\u2550\u2550\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u2550\u255d\u255a\u2550\u255d  \u255a\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u2550\u255d",
        )
        for line in art:
            if use_color:
                wprint_ansi(f"{cyan}{line}{reset}")
            else:
                wprint(line)
    wprint()
    if FROZEN:
        wprint("        Made by TRENCH3")
    elif _console_supports_ansi():
        wprint_ansi(f"\033[93m        Made by TRENCH3        \033[0m")
    else:
        wprint("        Made by TRENCH3")
    wprint(
        "  Batch decrypt .ncm to mp3/flac — scans this folder and subfolders"
        if not FROZEN
        else "  Batch decrypt .ncm to mp3/flac - scans this folder and subfolders"
    )
    wprint(
        "  Output stays next to each .ncm; converted .ncm archives to .\\ncm\\"
    )


def print_environment_check():
    wprint()
    wprint("===== Environment check =====")
    wprint()
    wprint(f"[OK] Python {sys.version.split()[0]}" + (" (bundled)" if FROZEN else ""))
    try:
        pip_line = (
            subprocess.check_output(
                [sys.executable, "-m", "pip", "--version"],
                text=True,
                stderr=subprocess.STDOUT,
            )
            .strip()
        )
        wprint(f"[OK] {pip_line}")
    except Exception:
        wprint("[OK] pip")
    logging.disable(logging.CRITICAL)
    ncmdump = importlib.import_module("ncmdump")
    wprint(f"[OK] ncmdump-py {ncmdump.__version__}")
    wprint()
    wprint("===== Starting conversion =====")
    wprint()


def normalize_song_key(stem):
    name = stem.strip()
    changed = True
    while changed:
        changed = False
        for pattern in _COPY_SUFFIX_PATTERNS:
            new_name = pattern.sub("", name).strip()
            if new_name != name:
                name = new_name
                changed = True
    return name.casefold()


def _duplicate_marker_rank(stem):
    cleaned = stem.strip()
    for pattern in _COPY_SUFFIX_PATTERNS:
        if pattern.search(cleaned):
            return 1
    return 0


def iter_music_files(root, archive_dir=None, include_archive=False):
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if _should_skip_hidden_path(path, root):
            continue
        if archive_dir is not None and not include_archive and _is_under_dir(path, archive_dir):
            continue
        if path.suffix.casefold() not in MUSIC_SUFFIXES_CF:
            continue
        yield path


def iter_song_files(root, archive_dir=None, include_archive=True):
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if _should_skip_hidden_path(path, root):
            continue
        if archive_dir is not None and not include_archive and _is_under_dir(path, archive_dir):
            continue
        if path.suffix.casefold() not in SCAN_SUFFIXES_CF:
            continue
        yield path


def iter_ncm_files(root, archive_dir, include_archive=False):
    for path in root.rglob("*.ncm"):
        if not path.is_file():
            continue
        if _should_skip_hidden_path(path, root):
            continue
        if not include_archive and _is_under_dir(path, archive_dir):
            continue
        yield path


def build_music_index(root, archive_dir):
    index = {}
    for path in iter_music_files(root, archive_dir=archive_dir, include_archive=False):
        key = normalize_song_key(path.stem)
        index.setdefault(key, []).append(path)
    for key in index:
        index[key] = sorted(index[key], key=lambda p: p.name.casefold())
    return index


def find_same_stem_music(ncm_path, root=None, archive_dir=None, music_index=None):
    key = normalize_song_key(ncm_path.stem)
    if music_index is not None:
        return list(music_index.get(key, []))

    search_root = root if root is not None else ncm_path.parent
    matches = []
    for path in iter_music_files(
        search_root,
        archive_dir=archive_dir,
        include_archive=False,
    ):
        if normalize_song_key(path.stem) != key:
            continue
        matches.append(path)
    if root is None:
        matches = [p for p in matches if p.parent == ncm_path.parent]
    return sorted(matches, key=lambda p: p.name.casefold())


def rel_path(path, root):
    try:
        return str(path.relative_to(root))
    except ValueError:
        return path.name


def count_duplicate_ncm(ncm_files, music_index):
    return sum(1 for p in ncm_files if music_index.get(normalize_song_key(p.stem)))


def ask_conflict_policy(ncm_path, existing, root, duplicate_count):
    names = "\n".join(f"  - {p.name}" for p in existing)
    choice = choice_box(
        f"{APP_TITLE} - Duplicate files",
        f"{duplicate_count} .ncm file(s) have music with the same name already on disk.\n\n"
        f"Choose once - applies to ALL of them in this run:\n\n"
        f"[Yes] Keep existing music (do not re-convert), still archive .ncm\n"
        f"[No] Keep new converted files (replace existing tracks), then archive .ncm\n"
        f"[Skip] Leave duplicates untouched - no convert, no archive (Cancel button)\n\n"
        f"Example - {rel_path(ncm_path, root)}:\n{names}",
    )
    if choice == IDYES:
        return "keep_original"
    if choice == IDNO:
        return "keep_new"
    return "skip_all"


def dump_one(ncm_path, out_folder, root, remove_existing=None):
    try:
        ncmfile = NeteaseCloudMusicFile(ncm_path).decrypt()
        fmt = ncmfile.music_metadata.format or "mp3"
        output_path = out_folder / f"{ncm_path.stem}.{fmt}"

        if remove_existing:
            for old in remove_existing:
                if old.exists() and old.resolve() != output_path.resolve():
                    old.unlink()

        ncmfile.dump_music(output_path)
        return True
    except Exception as e:
        ok_box(f"{APP_TITLE} - Conversion failed", f"{rel_path(ncm_path, root)}\n\n{e}", error=True)
        return False


def resolve_work_root():
    if FROZEN:
        return Path(sys.executable).resolve().parent
    if len(sys.argv) > 1:
        arg = sys.argv[1].strip().strip('"').rstrip("\\/")
        return Path(arg).resolve()
    return Path.cwd().resolve()


def _is_under_dir(path, directory):
    try:
        path.resolve().relative_to(directory.resolve())
        return True
    except ValueError:
        return False


def _should_skip_hidden_path(path, root):
    try:
        rel = path.relative_to(root)
    except ValueError:
        return True
    return any(part.startswith(".") for part in rel.parts)


def _should_skip_scan_path(path, root, archive_dir):
    if _is_under_dir(path, archive_dir):
        return True
    return _should_skip_hidden_path(path, root)


def _quality_rank(suffix):
    order = {
        ".flac": 0,
        ".wav": 1,
        ".m4a": 2,
        ".mp3": 3,
        ".aac": 4,
        ".ogg": 5,
        ".wma": 6,
        ".ncm": 7,
    }
    return order.get(suffix.lower(), 99)


def _dedupe_sort_key(path, root, archive_dir):
    rel = path.relative_to(root)
    in_archive = 1 if _is_under_dir(path, archive_dir) else 0
    return (
        in_archive,
        _duplicate_marker_rank(path.stem),
        _quality_rank(path.suffix),
        len(rel.parts),
        -path.stat().st_mtime,
        path.name.casefold(),
    )


def _move_item_up(item, parent):
    dest = parent / item.name
    if not dest.exists():
        shutil.move(str(item), str(dest))
        return 1

    if item.is_file() and dest.is_file():
        keep_src = item.stat().st_size > dest.stat().st_size
        if keep_src:
            dest.unlink()
            shutil.move(str(item), str(dest))
        else:
            item.unlink()
        return 1

    if item.is_dir() and dest.is_dir():
        moved = 0
        for child in list(item.iterdir()):
            moved += _move_item_up(child, dest)
        if not any(item.iterdir()):
            item.rmdir()
        return moved

    item.unlink()
    return 1


def extract_vip_download_folders(root, archive_dir):
    vip_dirs = sorted(
        (
            p
            for p in root.rglob("*")
            if p.is_dir()
            and not _should_skip_hidden_path(p, root)
            and p.name.casefold() in VIP_DOWNLOAD_DIR_NAMES
        ),
        key=lambda p: len(p.parts),
        reverse=True,
    )

    moved = 0
    removed_dirs = 0
    for vip_dir in vip_dirs:
        if not vip_dir.exists():
            continue
        parent = vip_dir.parent
        for item in list(vip_dir.iterdir()):
            moved += _move_item_up(item, parent)
        try:
            vip_dir.rmdir()
            removed_dirs += 1
        except OSError:
            shutil.rmtree(vip_dir, ignore_errors=True)
            removed_dirs += 1
    return moved, removed_dirs


def delete_lyric_files(root, archive_dir):
    deleted = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if _should_skip_hidden_path(path, root):
            continue
        if path.suffix.casefold() in LYRIC_SUFFIXES:
            path.unlink()
            deleted += 1
    return deleted


def delete_junk_files(root, archive_dir):
    junk_names = {name.casefold() for name in JUNK_FILE_NAMES}
    deleted = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if _should_skip_hidden_path(path, root):
            continue
        name = path.name
        if name.casefold() in junk_names:
            path.unlink()
            deleted += 1
            continue
        for pattern in JUNK_NAME_PATTERNS:
            if pattern.search(name):
                path.unlink()
                deleted += 1
                break
    return deleted


def dedupe_song_files(root, archive_dir):
    groups = {}
    for path in iter_music_files(root, archive_dir=archive_dir, include_archive=False):
        groups.setdefault(normalize_song_key(path.stem), []).append(path)

    deleted = 0
    for files in groups.values():
        if len(files) <= 1:
            continue
        files.sort(key=lambda p: _dedupe_sort_key(p, root, archive_dir))
        for duplicate in files[1:]:
            duplicate.unlink()
            deleted += 1
    return deleted


def dedupe_archived_ncm(root, archive_dir):
    groups = {}
    for path in iter_ncm_files(root, archive_dir, include_archive=True):
        if not _is_under_dir(path, archive_dir):
            continue
        groups.setdefault(normalize_song_key(path.stem), []).append(path)

    deleted = 0
    for files in groups.values():
        if len(files) <= 1:
            continue
        files.sort(
            key=lambda p: (
                _duplicate_marker_rank(p.stem),
                -p.stat().st_mtime,
                p.name.casefold(),
            )
        )
        for duplicate in files[1:]:
            duplicate.unlink()
            deleted += 1
    return deleted


def run_file_cleanup(root, archive_dir):
    wprint("[..] Extracting VipSongsDownload folders ...")
    vip_moved, vip_dirs = extract_vip_download_folders(root, archive_dir)
    wprint("[..] Removing lyric files ...")
    lyrics_removed = delete_lyric_files(root, archive_dir)
    wprint("[..] Removing junk text files ...")
    junk_removed = delete_junk_files(root, archive_dir)
    wprint("[..] Deduplicating playable audio ...")
    duplicates_removed = dedupe_song_files(root, archive_dir)
    wprint("[..] Deduplicating archived .ncm copies ...")
    archive_ncm_duplicates_removed = dedupe_archived_ncm(root, archive_dir)
    return {
        "vip_moved": vip_moved,
        "vip_dirs": vip_dirs,
        "lyrics_removed": lyrics_removed,
        "junk_removed": junk_removed,
        "duplicates_removed": duplicates_removed,
        "archive_ncm_duplicates_removed": archive_ncm_duplicates_removed,
    }


def prepare_workspace(root, archive_dir):
    wprint()
    wprint("===== Preparing files =====")
    wprint()

    cleanup = run_file_cleanup(root, archive_dir)

    wprint(
        f"[OK] VipSongsDownload: moved {cleanup['vip_moved']} item(s) from "
        f"{cleanup['vip_dirs']} folder(s)"
    )
    wprint(f"[OK] Lyrics removed: {cleanup['lyrics_removed']} file(s)")
    wprint(f"[OK] Junk files removed: {cleanup['junk_removed']} file(s)")
    wprint(f"[OK] Duplicate songs removed: {cleanup['duplicates_removed']} file(s)")
    wprint(
        f"[OK] Duplicate archived .ncm removed: "
        f"{cleanup['archive_ncm_duplicates_removed']} file(s)"
    )
    wprint()

    return cleanup


def finalize_workspace(root, archive_dir):
    wprint()
    wprint("===== Final cleanup =====")
    wprint()

    cleanup = run_file_cleanup(root, archive_dir)

    wprint(
        f"[OK] VipSongsDownload: moved {cleanup['vip_moved']} item(s) from "
        f"{cleanup['vip_dirs']} folder(s)"
    )
    wprint(f"[OK] Lyrics removed: {cleanup['lyrics_removed']} file(s)")
    wprint(f"[OK] Junk files removed: {cleanup['junk_removed']} file(s)")
    wprint(f"[OK] Duplicate songs removed: {cleanup['duplicates_removed']} file(s)")
    wprint(
        f"[OK] Duplicate archived .ncm removed: "
        f"{cleanup['archive_ncm_duplicates_removed']} file(s)"
    )
    wprint()

    return cleanup


def find_archived_ncm_with_converted_audio(root, archive_dir, music_index=None):
    if music_index is None:
        music_index = build_music_index(root, archive_dir)
    candidates = []
    for ncm_path in iter_ncm_files(root, archive_dir, include_archive=True):
        if not _is_under_dir(ncm_path, archive_dir):
            continue
        if music_index.get(normalize_song_key(ncm_path.stem)):
            candidates.append(ncm_path)
    return sorted(candidates, key=lambda p: p.name.casefold())


def offer_delete_converted_ncm_archive(root, archive_dir, music_index=None):
    candidates = find_archived_ncm_with_converted_audio(
        root, archive_dir, music_index=music_index
    )
    if not candidates:
        return 0

    wprint()
    wprint("===== Archived .ncm cleanup =====")
    wprint()
    wprint(
        f"{len(candidates)} archived .ncm file(s) in .\\ncm\\ already have "
        f"converted audio (FLAC/MP3) outside the archive."
    )
    wprint("Examples:")
    for path in candidates[:8]:
        wprint(f"  - {rel_path(path, root)}")
    if len(candidates) > 8:
        wprint(f"  ... and {len(candidates) - 8} more")
    wprint()

    if not confirm_yes_no_cli("Delete these archived .ncm files?", default=False):
        wprint("Archived .ncm copies kept.")
        return 0

    deleted = 0
    for path in candidates:
        try:
            path.unlink()
            deleted += 1
        except OSError as e:
            wprint(f"[ERROR] Failed to delete {rel_path(path, root)}: {e}")
    wprint(f"[OK] Removed {deleted} archived .ncm file(s) with existing audio.")
    return deleted


def archive_ncm(ncm_path, root, archive_dir):
    dest = archive_dir / rel_path(ncm_path, root)
    if dest.resolve() == ncm_path.resolve():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()
    shutil.move(str(ncm_path), str(dest))


def build_folder_tree_data(ncm_files, root):
    data = {"count": 0, "subs": {}}
    for p in ncm_files:
        rel = p.relative_to(root)
        parts = list(rel.parts[:-1])
        node = data
        for part in parts:
            node = node["subs"].setdefault(part, {"count": 0, "subs": {}})
        node["count"] += 1
    return data


def _fill_tree_branch(branch, node, budget):
    if budget[0] <= 0:
        return False
    if node["count"] > 0:
        branch.add(f"[green]\u25cf[/] [green bold]{node['count']}[/] .ncm file(s)")
        budget[0] -= 1
    for name in sorted(node["subs"], key=lambda x: x.lower()):
        if budget[0] <= 0:
            branch.add("[dim]\u2514\u2500 \u2026 more subfolders not shown[/]")
            return False
        sub = node["subs"][name]
        child = branch.add(f"[cyan]\U0001f4c1 {_rich_text(name)}[/]")
        budget[0] -= 1
        if not _fill_tree_branch(child, sub, budget):
            return False
    return True


def make_folder_tree(ncm_files, root, max_nodes=40):
    data = build_folder_tree_data(ncm_files, root)
    tree = Tree(
        f"[bold #d75f00]\U0001f4c2 {_rich_text(root.name)}[/]  "
        f"[dim]({_rich_text(root)})[/]  "
        f"[green]{len(ncm_files)}[/] .ncm file(s) total",
        guide_style="dim cyan",
    )
    _fill_tree_branch(tree, data, [max_nodes])
    return tree


def print_pre_summary(root, archive_dir, ncm_files):
    console.print(Rule(f"[bold #d75f00]{APP_TITLE}[/]", style="#d75f00"))
    console.print(
        f"[dim]Batch .ncm to mp3/flac converter \u00b7 Made by TRENCH3[/]\n\n"
        f"[bold]To convert[/]  [green bold]{len(ncm_files)}[/] .ncm file(s)\n\n"
        "[bold cyan]Music output[/]  Same folder as each .ncm (mp3 / flac alongside)\n"
        f"[bold cyan]Archive[/]  {_rich_text(archive_dir)}\n",
    )
    console.print()
    console.print(Rule("[bold cyan]Folder layout[/]", style="dim cyan"))
    console.print(make_folder_tree(ncm_files, root))
    console.print()
    console.print(
        "[dim]Shows folder levels and counts only, not every filename. "
        "A dialog will ask before conversion starts.[/]\n"
    )


def make_progress_bar(done, total, width=40):
    if total <= 0:
        pct = 0
    else:
        pct = min(1.0, done / total)
    filled = int(width * pct)
    bar_fill = chr(0x2588) * filled
    bar_empty = chr(0x2591) * (width - filled)
    return (
        f"[#d75f00]{bar_fill}[/][dim]{bar_empty}[/] "
        f"[bold]{done}/{total}[/]"
    )


def make_convert_panel(current, done, total):
    return Group(
        Text.from_markup(f"[bold cyan]Current:[/] {_rich_text(current)}"),
        Text.from_markup(f"[bold]Progress[/]  {make_progress_bar(done, total)}"),
    )


def main():
    root = resolve_work_root()
    archive_dir = (root / "ncm").resolve()
    archive_dir.mkdir(exist_ok=True)

    cleanup = prepare_workspace(root, archive_dir)

    ncm_files = sorted(iter_ncm_files(root, archive_dir, include_archive=False))

    if not ncm_files:
        wprint("No pending .ncm files to convert.")
        wprint("If a dialog is waiting, check the taskbar for 111Dump.")
        archived_ncm_removed = offer_delete_converted_ncm_archive(root, archive_dir)
        ok_box(
            APP_TITLE,
            f"No .ncm files found under this folder tree:\n{root}\n\n"
            f"Duplicate songs removed: {cleanup['duplicates_removed']}\n"
            f"Archived .ncm removed (optional): {archived_ncm_removed}",
        )
        return 0

    print_pre_summary(root, archive_dir, ncm_files)

    wprint("Waiting for confirmation dialog ...")
    if (
        confirm_start(
            f"{APP_TITLE} - Confirm start",
            f"About to convert {len(ncm_files)} .ncm file(s).\n\n"
            f"Root folder:\n{root}\n\n"
            f"Converted music -> folder of each .ncm\n"
            f"Original .ncm archive ->\n{archive_dir}\n\n"
            f"Start conversion now?",
        )
        != IDYES
    ):
        console.print("[yellow]Cancelled. Conversion not started.[/]")
        return 0

    wprint("[..] Indexing existing music files ...")
    music_index = build_music_index(root, archive_dir)
    duplicate_count = count_duplicate_ncm(ncm_files, music_index)
    if duplicate_count:
        wprint(
            f"Found {duplicate_count} .ncm file(s) with matching audio already on disk."
        )
        wprint("Waiting for duplicate policy dialog ...")
    conflict_policy = None
    converted = skipped = failed = archived = 0
    total_files = len(ncm_files)

    ui = {"current": "Preparing\u2026", "done": 0}
    processed = 0

    def convert_panel():
        return make_convert_panel(ui["current"], ui["done"], total_files)

    with Live(convert_panel(), console=console, auto_refresh=False) as live:
        for ncm_path in ncm_files:
            ui["current"] = rel_path(ncm_path, root)

            should_dump = True
            remove_existing = None
            archive_only = False
            existing = find_same_stem_music(
                ncm_path, root, archive_dir, music_index=music_index
            )

            if existing:
                if conflict_policy is None:
                    conflict_policy = ask_conflict_policy(
                        ncm_path, existing, root, duplicate_count
                    )
                if conflict_policy == "skip_all":
                    skipped += 1
                    should_dump = False
                elif conflict_policy == "keep_original":
                    should_dump = False
                    archive_only = True
                else:
                    remove_existing = existing

            if should_dump:
                if dump_one(ncm_path, ncm_path.parent, root, remove_existing):
                    converted += 1
                    try:
                        archive_ncm(ncm_path, root, archive_dir)
                        archived += 1
                    except Exception as e:
                        ok_box(
                            f"{APP_TITLE} - Archive failed",
                            f"{ui['current']}\n\n{e}",
                            error=True,
                        )
                else:
                    failed += 1
            elif archive_only:
                try:
                    archive_ncm(ncm_path, root, archive_dir)
                    archived += 1
                except Exception as e:
                    ok_box(
                        f"{APP_TITLE} - Archive failed",
                        f"{ui['current']}\n\n{e}",
                        error=True,
                    )
                    failed += 1

            processed += 1
            ui["done"] = processed
            live.update(convert_panel(), refresh=True)

    final_cleanup = finalize_workspace(root, archive_dir)
    post_music_index = build_music_index(root, archive_dir)
    archived_ncm_removed = offer_delete_converted_ncm_archive(
        root, archive_dir, music_index=post_music_index
    )

    console.print()
    summary = (
        f"Root: {root}\n"
        f"VipSongsDownload extracted: {cleanup['vip_moved']} item(s) "
        f"from {cleanup['vip_dirs']} folder(s)\n"
        f"Lyrics removed: {cleanup['lyrics_removed']}\n"
        f"Junk files removed: {cleanup['junk_removed']}\n"
        f"Duplicate songs removed (before): {cleanup['duplicates_removed']}\n"
        f"Duplicate archived .ncm removed (before): "
        f"{cleanup['archive_ncm_duplicates_removed']}\n"
        f"Duplicate songs removed (after): {final_cleanup['duplicates_removed']}\n"
        f"Duplicate archived .ncm removed (after): "
        f"{final_cleanup['archive_ncm_duplicates_removed']}\n"
        f"Scanned: {len(ncm_files)} .ncm file(s)\n"
        f"Converted: {converted}\n"
        f"Archived to .\\ncm: {archived}\n"
        f"Archived .ncm removed (optional): {archived_ncm_removed}\n"
        f"Skipped: {skipped}\n"
        f"Failed: {failed}"
    )
    console.print(Rule(f"[green]{APP_TITLE} - Done[/]", style="green"))
    console.print(summary)
    ok_box(f"{APP_TITLE} - Done", summary)
    return 0 if failed == 0 else 1


setup_console_output()

if __name__ == "__main__":
    if not bootstrap_env():
        sys.exit(1)
    init_conversion_stack()
    print_banner()
    print_environment_check()
    exit_code = main()
    if os.name == "nt" and FROZEN:
        os.system("pause")
    sys.exit(exit_code)
