import argparse
from pathlib import Path

from lupa.lua51 import LuaRuntime


root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--visible-helicopter-root", required=True, type=Path)
args = parser.parse_args()
compat = args.visible_helicopter_root / "42/media/lua/client/VisibleHelicopterEvent_Compat.lua"

for name in ("flights_spec.lua", "areas_spec.lua", "adapter_spec.lua"):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().projectClientPath = (root / "42/media/lua/client").as_posix()
    lua.globals().rendererCompatSource = compat.read_text(encoding="utf-8-sig")
    lua.execute('package.path = projectClientPath .. "/?.lua;" .. package.path')
    lua.execute((root / "tests" / name).read_text(encoding="utf-8"))
