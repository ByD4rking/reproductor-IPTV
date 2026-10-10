from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
p = ROOT / "shared" / "player.js"
assert p.is_file(), f"no existe {p}"
s = p.read_text(encoding="utf-8")
assert "IPTV-CHILE-GENERADOR.m3u" in s
assert "retries>=6" in s
assert "Math.pow(2,retries)" in s
assert 'addEventListener("error"' in s
assert 'addEventListener("stalled"' in s
assert 'addEventListener("ended"' in s
print("TV legacy static/reconnect checks: OK")
