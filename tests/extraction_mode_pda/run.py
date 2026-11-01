from pathlib import Path

from lupa.lua51 import LuaRuntime


repo = Path(__file__).resolve().parents[2]
mod = repo / "content/mods/ExtractionModePDA"
client = mod / "42/media/lua/client"

for name in (
    "extraction_pda_optional_spec.lua",
    "extraction_pda_spec.lua",
    "extraction_pda_hud_spec.lua",
    "extraction_dashboard_spec.lua",
):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().projectClientPath = client.as_posix()
    lua.execute('package.path = projectClientPath .. "/?.lua;" .. package.path')
    lua.execute((Path(__file__).parent / name).read_text(encoding="utf-8"))
