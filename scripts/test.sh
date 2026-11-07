#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
mkdir -p .build/fixtures
if command -v lua >/dev/null 2>&1; then
    lua tests/filter.lua
else
    echo 'Lua export-flow tests: run tests/filter.lua with a Lua 5.1-compatible interpreter.'
fi
swiftc -module-cache-path .build/module-cache tests/formats.swift -o .build/format-fixtures
.build/format-fixtures generate .build/fixtures
perl -I BirdBookBridge.lrplugin/lib tests/formats.t .build/fixtures .build/format-fixtures
perl -I BirdBookBridge.lrplugin/lib -c BirdBookBridge.lrplugin/write-focus.pl
python3 - <<'PY'
from pathlib import Path
import hashlib, json
root = Path.cwd()
manifest = json.loads((root / 'vendor-manifest.json').read_text())
for name, expected in manifest['git_blob_sha1'].items():
    data = (root / 'BirdBookBridge.lrplugin' / name).read_bytes()
    actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    assert actual == expected, name
print('PASS: pinned ExifTool library hashes')
source = (root / 'BirdBookBridge.lrplugin/RegisterFocus.swift').read_text()
boundary = '// Bound the export delay even if the system image-registration service stalls.'
assert source.count(boundary) == 1
(root / '.build/main.swift').write_text(source.split(boundary)[0] + (root / 'tests/registration.swift').read_text())
PY
# Keep assertions enabled in the test harness.
swiftc -module-cache-path .build/module-cache .build/main.swift -o .build/registration-tests
.build/registration-tests .build/fixtures
perl -I BirdBookBridge.lrplugin/lib tests/metadata.t .build/fixtures/sample.jpg
if [ -x dist/BirdBookBridge.lrplugin/register-focus ]; then
    python3 tests/helper_cli.py dist/BirdBookBridge.lrplugin/register-focus .build/fixtures
fi
