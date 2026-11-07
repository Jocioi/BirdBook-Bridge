"""Exercise the built helper, with generated fixtures only."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

helper = str(Path(sys.argv[1]).resolve())
fixtures = Path(sys.argv[2]).resolve()
with tempfile.TemporaryDirectory(prefix="bbb-cli-") as tmp:
    config = Path(tmp) / "input.json"
    config.write_text(json.dumps({"crop": [0, 0, 1, 1], "frame": [0.4, 0.3, 0.2, 0.2]}))
    def run(a, b):
        return subprocess.run([helper, str(a), str(b), str(config)], capture_output=True, timeout=15)
    result = run(fixtures / "sample.jpg", fixtures / "sample.jpg")
    assert result.returncode == 0, result.stderr
    rect = json.loads(result.stdout)["rect"]
    assert all(abs(a-b) < 0.003 for a, b in zip(rect, [0.4, 0.3, 0.2, 0.2]))
    assert run(fixtures / "flat.jpg", fixtures / "flat.jpg").returncode != 0
    config.write_text("{}"); assert run(fixtures / "sample.jpg", fixtures / "sample.jpg").returncode != 0
    config.write_text("not json"); assert run(fixtures / "sample.jpg", fixtures / "sample.jpg").returncode != 0
print("PASS: 4 compiled helper CLI cases")
