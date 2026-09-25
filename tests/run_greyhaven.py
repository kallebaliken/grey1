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
    "items/equipment_slots.lua",
    "items/equipment.lua",
    "actors/actor_types.lua",
    "actors/registry.lua",
    "actors/capabilities.lua",
    "combat/health.lua",
    "combat/registry.lua",
    "combat/attacks.lua",
    "combat/attack_damage.lua",
    "combat/armor.lua",
    "creatures/creature_defs.lua",
    "creatures/creature_registry.lua",
    "creatures/creatures.lua",
    "factions/faction_defs.lua",
    "factions/relationship_defs.lua",
    "factions/relationships.lua",
    "factions/faction_registry.lua",
    "factions/factions.lua",
    "dialogue/dialogue_defs.lua",
    "dialogue/dialogue_registry.lua",
    "dialogue/dialogue.lua",
    "conditions/conditions.lua",
    "actions/world_actions.lua",
    "quests/quest_statuses.lua",
    "quests/quest_defs.lua",
    "quests/quest_registry.lua",
    "quests/quests.lua",
    "world/direction.lua",
    "render/actor_renderer.lua",
    "render/viewport.lua",
    "simulation/pathfinding.lua",
    "simulation/movement_controller.lua",
    "world/world_items.lua",
    "simulation/item_transfers.lua",
    "data/maps/prototype.lua",
    "main/world.gui",
    "main/world.gui_script",
    "input/game.input_binding",
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
assert "game_binding = /input/game.input_bindingc" in project
collection = (ROOT / "main/main.collection").read_text()
assert 'component: \\"/main/game_manager.script\\"' in collection
assert 'component: \\"/main/world.gui\\"' in collection
gui = (ROOT / "main/world.gui").read_text()
assert 'script: "/main/world.gui_script"' in gui
assert 'font: "/builtins/fonts/default.font"' in gui
assert "max_nodes: 1024" in gui
assert 'name: "world"' in gui and 'name: "hud"' in gui
assert 'id: "dialogue_panel"' in gui and 'id: "dialogue_text"' in gui
gui_script = (ROOT / "main/world.gui_script").read_text()
assert "gui.set_enabled(self.nodes[index], false)" in gui_script
assert "vmath.vector3(x, y, 0)" in gui_script
assert "gui.move_above(node, self.nodes[index - 1])" in gui_script
assert "command.order" not in gui_script
binding = (ROOT / "input/game.input_binding").read_text()
assert 'input: KEY_K action: "attack"' in binding
assert 'input: KEY_L action: "debug_toggle_weapon"' in binding
assert 'input: KEY_O action: "debug_toggle_armor"' in binding
assert 'input: KEY_P action: "debug_rat_attack"' in binding
assert 'input: KEY_1 action: "dialogue_1"' in binding
assert 'input: KEY_ESC action: "dialogue_close"' in binding
assert 'input: KEY_T action: "debug_toggle_dialogue_flag"' in binding
assert 'input: KEY_Y action: "debug_quest_start"' in binding
assert 'input: KEY_U action: "debug_quest_advance"' in binding
assert 'input: KEY_I action: "debug_quest_complete"' in binding
map_loader = (ROOT / "world/map_loader.lua").read_text()
assert 'require("data.maps.prototype")' in map_loader
assert "require(module_name)" not in map_loader
assert 'quest_registry_api.new(quest_definitions)' in map_loader
manager = (ROOT / "main/game_manager.script").read_text()
for contract in ("interaction.use", "item_transfers.drop", "pathfinding.find_path", "movement_controller.set_path", "movement_controller.update", "combat_registry.apply_damage", "attacks.try_attack", "attacks.update", "creatures.spawn", "factions.associate", "factions.relationship_between_actors", "dialogue.is_active", "dialogue.choose_index", "dialogue.close", "quests.start", "quests.advance_objective", "quests.complete", "quests.get_snapshot", "state_api.get_flag", "state_api.set_flag", "save_manager.save", "movement.begin", "renderer.build"):
    assert contract in manager, contract
conditions_source = (ROOT / "conditions/conditions.lua").read_text()
assert 'condition.type == "quest_status"' in conditions_source
assert 'condition.type == "quest_objective"' in conditions_source
world_actions_source = (ROOT / "actions/world_actions.lua").read_text()
for action_type in ("start_quest", "advance_quest", "complete_quest"):
    assert action_type in world_actions_source
print("Greyhaven project wiring passed")
