# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

project_root = Path.cwd().resolve()

hiddenimports = [
    "sentence_transformers",
    "sentence_transformers.models",
    "transformers",
    "torch",
    "faiss",
    "peft",
]


a = Analysis(
    ["apps/mac/desktop/app.py"],
    pathex=[str(project_root)],
    binaries=[],
    datas=[],
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["streamlit", "uvicorn", "fastapi"],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

app = BUNDLE(
    EXE(
        pyz,
        a.scripts,
        a.binaries,
        a.datas,
        [],
        name="PediatricsRAG",
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=True,
        upx_exclude=[],
        runtime_tmpdir=None,
        console=False,
        disable_windowed_traceback=False,
        argv_emulation=False,
        target_arch=None,
        codesign_identity=None,
        entitlements_file=None,
    ),
    name="PediatricsRAG.app",
    icon=None,
    bundle_identifier="com.local.pediatrics-rag",
    info_plist={
        "CFBundleName": "PediatricsRAG",
        "CFBundleDisplayName": "PediatricsRAG",
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "0.1.0",
    },
)
