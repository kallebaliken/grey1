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
    "event_bindings/binding_defs.lua",
    "event_bindings/binding_registry.lua",
    "event_bindings/event_bindings.lua",
    "world/direction.lua",
    "render/actor_renderer.lua",
    "render/viewport.lua",
    "render/render_definition.lua",
    "render/world_animations.lua",
    "render/sprite_reconciler.lua",
    "render/sprite_diagnostics.lua",
    "render/command_diagnostics.lua",
    "render/world_sprite_renderer.script",
    "render/world_render_piece.go",
    "render/world_render_piece.sprite",
    "render/world_render_piece.factory",
    "assets/world.atlas",
    "simulation/pathfinding.lua",
    "simulation/movement_controller.lua",
    "simulation/perception.lua",
    "world/line_of_sight.lua",
    "world/world_items.lua",
    "simulation/item_transfers.lua",
    "data/maps/prototype.lua",
    "main/world.gui",
    "main/world.gui_script",
    "input/game.input_binding",
    "assets/world/ASSET_MANIFEST.md",
]
for name in required:
    assert (ROOT / name).is_file(), name

world_pngs = [
    "ground/grass_01.png", "ground/dirt_01.png", "ground/wood_floor_01.png",
    "ground/basement_floor_01.png", "objects/wall_01.png", "objects/door_closed_01.png",
    "objects/door_open_01.png", "objects/table_01.png", "objects/chest_01.png",
    "objects/stairs_01.png", "objects/roof_01.png", "objects/fallback_01.png",
    "actors/player_01.png", "actors/villager_01.png", "actors/rat_01.png",
    "items/herb_01.png", "items/key_01.png", "items/sword_01.png", "items/leather_armor_01.png",
]
atlas_source = (ROOT / "assets/world.atlas").read_text()
manifest_source = (ROOT / "assets/world/ASSET_MANIFEST.md").read_text()
for relative in world_pngs:
    full_path = f"assets/world/{relative}"
    assert f'/{full_path}' in atlas_source, full_path
    assert f'`{full_path}`' in manifest_source, full_path

lua = next((shutil.which(name) for name in ("lua", "lua5.1", "luajit") if shutil.which(name)), None)
if lua:
    subprocess.run([lua, "tests/run.lua"], cwd=ROOT, check=True)
else:
    print("SKIP pure Lua execution: install Lua 5.1+ or run tests/run.lua in Defold")

project = (ROOT / "game.project").read_text()
assert "main_collection = /main/main.collectionc" in project
assert "game_binding = /input/game.input_bindingc" in project
assert "[collection]" in project and "max_instances = 4096" in project
assert "[sprite]" in project and "max_count = 2048" in project
assert "default_texture_min_filter = nearest" in project
assert "default_texture_mag_filter = nearest" in project
assert "camera_zoom = 2" in project
collection = (ROOT / "main/main.collection").read_text()
assert 'component: \\"/main/game_manager.script\\"' in collection
assert 'component: \\"/main/world.gui\\"' in collection
gui = (ROOT / "main/world.gui").read_text()
assert 'script: "/main/world.gui_script"' in gui
assert 'font: "/builtins/fonts/default.font"' in gui
assert "max_nodes: 64" in gui
assert 'name: "hud"' in gui
assert 'id: "dialogue_panel"' in gui and 'id: "dialogue_text"' in gui
gui_script = (ROOT / "main/world.gui_script").read_text()
assert "gui.new_box_node" not in gui_script
assert "gui.set_scale" not in gui_script
assert "world_sprite_renderer" in collection
assert "world_piece_factory" in collection
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
assert 'input: KEY_V action: "debug_rat_perception"' in binding
map_loader = (ROOT / "world/map_loader.lua").read_text()
assert 'require("data.maps.prototype")' in map_loader
assert "require(module_name)" not in map_loader
assert 'quest_registry_api.new(quest_definitions)' in map_loader
manager = (ROOT / "main/game_manager.script").read_text()
assert 'sys.get_config_int("collection.max_instances", 1024)' in manager
assert 'sys.get_config_int("sprite.max_count", 128)' in manager
assert "camera_api.visible_tiles" in manager
for contract in ("interaction.use", "item_transfers.drop", "pathfinding.find_path", "movement_controller.set_path", "movement_controller.update", "combat_registry.apply_damage", "attacks.try_attack", "attacks.update", "creatures.spawn", "factions.associate", "factions.relationship_between_actors", "dialogue.is_active", "dialogue.choose_index", "dialogue.close", "quests.start", "quests.advance_objective", "quests.complete", "quests.get_snapshot", "state_api.get_flag", "state_api.set_flag", "save_manager.save", "movement.begin", "renderer.build"):
    assert contract in manager, contract
conditions_source = (ROOT / "conditions/conditions.lua").read_text()
assert 'condition.type == "quest_status"' in conditions_source
assert 'condition.type == "quest_objective"' in conditions_source
world_actions_source = (ROOT / "actions/world_actions.lua").read_text()
for action_type in ("start_quest", "advance_quest", "complete_quest"):
    assert action_type in world_actions_source
for contract in ("binding_registry_api.new", "event_bindings.create", "event_bindings.destroy",
                 "perception.create", "perception.get_awareness"):
    assert contract in manager, contract
object_defs_source = (ROOT / "objects/object_defs.lua").read_text()
assert "blocks_sight = true" in object_defs_source
assert "blocks_sight_state" in object_defs_source
atlas = atlas_source
for animation in ("grass_01", "dirt_01", "wood_floor_01", "basement_floor_01", "wall_01",
                  "door_closed_01", "door_open_01", "roof_01", "player_01", "villager_01", "rat_01"):
    assert animation in atlas, animation
sprite_adapter = (ROOT / "render/world_sprite_renderer.script").read_text()
for contract in ("factory.create", "sprite.play_flipbook", "go.set_position", "go.delete"):
    assert contract in sprite_adapter, contract
assert "if not instance_id" in sprite_adapter
assert "animation_changed" in sprite_adapter
assert 'msg.url(nil, instance_id, "sprite")' in sprite_adapter
assert 'sys.get_config_int("sprite.max_count", 128)' in sprite_adapter
sprite_go = (ROOT / "render/world_render_piece.go").read_text()
assert 'id: "sprite"' in sprite_go
reconciler_source = (ROOT / "render/sprite_reconciler.lua").read_text()
assert "reconciler.instances[command.id] = entry" in reconciler_source
assert "if handle then" in reconciler_source
print("Greyhaven project wiring passed")
