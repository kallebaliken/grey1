"""Run the pure Lua suite when Lua exists; always validate project wiring."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).parents[1]
required = [
    "game.project",
    "main/main.collection",
    "tests/run.lua",
    "state/save_manager.lua",
    "items/item_defs.lua",
    "items/item_registry.lua",
    "items/item_instance.lua",
    "items/container.lua",
    "items/inventory.lua",
]
for name in required:
    assert (ROOT / name).is_file(), name

lua = next((shutil.which(name) for name in ("lua", "lua5.1", "luajit") if shutil.which(name)), None)
if lua:
    subprocess.run([lua, "tests/run.lua"], cwd=ROOT, check=True)
else:
    print("SKIP pure Lua execution: install Lua 5.1+ or run tests/run.lua in Defold")

project = (ROOT / "game.project").read_text()
assert "main_collection = /main/main.collectionc" in project
manager = (ROOT / "main/game_manager.script").read_text()
for contract in ("interaction.use", "save_manager.save", "movement.begin", "renderer.build"):
    assert contract in manager, contract
print("Greyhaven project wiring passed")
