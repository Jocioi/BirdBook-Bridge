#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
mkdir -p .build dist
swiftc -module-cache-path .build/module-cache -O -target arm64-apple-macosx13.0 BirdBookBridge.lrplugin/RegisterFocus.swift -o .build/register-arm64
swiftc -module-cache-path .build/module-cache -O -target x86_64-apple-macosx13.0 BirdBookBridge.lrplugin/RegisterFocus.swift -o .build/register-x86_64
lipo -create .build/register-arm64 .build/register-x86_64 -output .build/register-focus
# Replacing only our generated directory avoids mixing previous builds into the ZIP.
python3 - <<'PY'
from pathlib import Path
import shutil
root = Path.cwd()
dest = root / 'dist/BirdBookBridge.lrplugin'
if dest.exists():
    shutil.rmtree(dest)
shutil.copytree(root / 'BirdBookBridge.lrplugin', dest)
shutil.copy2(root / '.build/register-focus', dest / 'register-focus')
(dest / 'register-focus').chmod(0o755)
for name in ['LICENSE', 'THIRD_PARTY_NOTICES.md', 'vendor-manifest.json', '项目说明.md', 'README.md', 'CHANGELOG.md']:
    shutil.copy2(root / name, dest / name)
shutil.copytree(root / 'licenses', dest / 'licenses')
shutil.copytree(root / 'docs', dest / 'docs')
shutil.copy2(root / 'README.md', dest / 'INSTALL.md')
shutil.make_archive(str(root / 'dist/BirdBook-Bridge-1.3.4'), 'zip', root / 'dist', 'BirdBookBridge.lrplugin')
print('Built dist/BirdBook-Bridge-1.3.4.zip')
PY
