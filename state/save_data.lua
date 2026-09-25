local ids = require "core.ids"
local equipment_api = require "items.equipment"
local equipment_slots = require "items.equipment_slots"
local inventory_api = require "items.inventory"
local position = require "world.position"
local direction = require "world.direction"
local state_api = require "state.world_state"
local world_items = require "world.world_items"
local M = { VERSION = 4 }

local function equal(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do if not equal(value, right[key], seen) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function static_placements(map)
    local result = {}
    for _, placement in ipairs(map.item_placements or {}) do result[placement.id] = placement end
    return result
end

local function valid_id(value)
    return pcall(ids.require_stable, value)
end

local function valid_item(item)
    return type(item) == "table" and valid_id(item.id) and valid_id(item.type)
        and type(item.quantity) == "number" and item.quantity > 0 and item.quantity % 1 == 0
        and type(item.state) == "table"
end

local function reserve(used, id)
    if used[id] then return false end
    used[id] = true
    return true
end

function M.capture(player, world, map_id, player_combat)
    assert(player.inventory, "player inventory is required for save capture")
    assert(player.equipment, "player equipment is required for save capture")
    local placements = static_placements(world.map)
    local item_state = { static_overrides = {}, dynamic = {} }
    for placement_id, placement in pairs(placements) do
        local current = world_items.get(world, placement_id)
        if not current then
            item_state.static_overrides[placement_id] = { removed = true }
        else
            local initial_quantity = placement.item.quantity or 1
            local initial_state = placement.item.state or {}
            if current.item.quantity ~= initial_quantity or not equal(current.item.state, initial_state) then
                item_state.static_overrides[placement_id] = {
                    quantity = current.item.quantity,
                    state = state_api.copy(current.item.state),
                }
            end
        end
    end
    for _, world_item in ipairs(world_items.get_all(world)) do
        if not placements[world_item.id] then
            item_state.dynamic[#item_state.dynamic + 1] = { id = world_item.id,
                item = state_api.copy(world_item.item), x = world_item.position.x,
                y = world_item.position.y, z = world_item.position.z }
        end
    end
    table.sort(item_state.dynamic, function(left, right) return left.id < right.id end)
    player_combat = player_combat or { actor_id = player.id, max_health = 100, health = 100, dead = false }
    return { version = M.VERSION, map_id = map_id, player = { x = player.position.x,
        y = player.position.y, z = player.position.z, facing = player.facing },
        combat = { player = state_api.copy(player_combat) },
        objects = state_api.copy(world.state.objects), flags = state_api.copy(world.state.flags),
        inventory = inventory_api.snapshot(player.inventory), equipment = equipment_api.snapshot(player.equipment),
        world_items = item_state }
end

function M.validate(data, expected_map)
    if type(data) ~= "table" or data.version ~= M.VERSION then return false, "unsupported_save_version" end
    local expected_map_id = type(expected_map) == "table" and expected_map.id or expected_map
    if data.map_id ~= expected_map_id then return false, "wrong_map" end
    local p = data.player
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number"
        or p.x % 1 ~= 0 or p.y % 1 ~= 0 or p.z % 1 ~= 0 or not direction.is_valid(p.facing) then
        return false, "invalid_player"
    end
    if type(data.objects) ~= "table" or type(data.flags) ~= "table" then return false, "invalid_world_state" end
    for flag_id, value in pairs(data.flags) do
        if not valid_id(flag_id) or type(value) ~= "boolean" then return false, "invalid_world_flags" end
    end
    local player_combat = data.combat and data.combat.player
    if type(player_combat) ~= "table" or not valid_id(player_combat.actor_id)
        or type(player_combat.max_health) ~= "number" or player_combat.max_health <= 0 or player_combat.max_health % 1 ~= 0
        or type(player_combat.health) ~= "number" or player_combat.health < 0 or player_combat.health % 1 ~= 0
        or player_combat.health > player_combat.max_health or type(player_combat.dead) ~= "boolean"
        or player_combat.dead ~= (player_combat.health == 0) then return false, "invalid_combat_state" end
    local inventory = data.inventory
    if type(inventory) ~= "table" or not valid_id(inventory.id) or not valid_id(inventory.owner_id)
        or type(inventory.capacity) ~= "number" or inventory.capacity < 0 or inventory.capacity % 1 ~= 0
        or type(inventory.items) ~= "table" then return false, "invalid_inventory" end
    if #inventory.items > inventory.capacity then return false, "invalid_inventory" end
    if player_combat.actor_id ~= inventory.owner_id then return false, "invalid_combat_state" end
    local equipment = data.equipment
    if type(equipment) ~= "table" or not valid_id(equipment.id) or not valid_id(equipment.owner_id)
        or equipment.owner_id ~= inventory.owner_id or type(equipment.slots) ~= "table" then
        return false, "invalid_equipment"
    end
    local saved_world = data.world_items
    if type(saved_world) ~= "table" or type(saved_world.static_overrides) ~= "table"
        or type(saved_world.dynamic) ~= "table" then return false, "invalid_world_items" end

    local used_items, used_world = {}, {}
    for _, item in ipairs(inventory.items) do
        if not valid_item(item) or not reserve(used_items, item.id) then return false, "duplicate_item_ownership" end
    end
    for slot_id, item in pairs(equipment.slots) do
        if not equipment_slots.has(slot_id) or not valid_item(item) then return false, "invalid_equipment" end
        if not reserve(used_items, item.id) then return false, "duplicate_item_ownership" end
    end
    for _, world_item in ipairs(saved_world.dynamic) do
        if type(world_item) ~= "table" or not valid_id(world_item.id) or not valid_item(world_item.item)
            or type(world_item.x) ~= "number" or type(world_item.y) ~= "number" or type(world_item.z) ~= "number"
            or world_item.x % 1 ~= 0 or world_item.y % 1 ~= 0 or world_item.z % 1 ~= 0
            or not reserve(used_world, world_item.id) or not reserve(used_items, world_item.item.id) then
            return false, "duplicate_item_ownership"
        end
    end

    if type(expected_map) == "table" then
        local placements = static_placements(expected_map)
        for placement_id, override in pairs(saved_world.static_overrides) do
            if not placements[placement_id] or type(override) ~= "table" then return false, "invalid_static_item_override" end
            if override.removed ~= nil and override.removed ~= true then return false, "invalid_static_item_override" end
            if not override.removed and (type(override.quantity) ~= "number" or override.quantity <= 0
                or override.quantity % 1 ~= 0 or type(override.state) ~= "table") then
                return false, "invalid_static_item_override"
            end
        end
        for placement_id, placement in pairs(placements) do
            if used_world[placement_id] then return false, "duplicate_world_item_id" end
            local override = saved_world.static_overrides[placement_id]
            if not (override and override.removed) and not reserve(used_items, placement.item.id) then
                return false, "duplicate_item_ownership"
            end
        end
    end
    return true
end

function M.restore_inventory(data, registry)
    return inventory_api.restore(data.inventory, registry)
end

function M.restore_equipment(data, registry)
    return equipment_api.restore(data.equipment, registry)
end

function M.restore_player_combat(data)
    return state_api.copy(data.combat.player)
end

function M.apply_static_item_overrides(world, data)
    for placement_id, override in pairs(data.world_items.static_overrides) do
        world_items.restore_static(world, placement_id, override)
    end
end

function M.restore_dynamic_world_items(world, data)
    for _, snapshot in ipairs(data.world_items.dynamic) do world_items.restore_dynamic(world, snapshot) end
end

function M.create_item_id_allocator(data, map)
    local valid, reason = M.validate(data, map)
    assert(valid, reason)
    local existing = {}
    for _, item in ipairs(data.inventory.items) do existing[#existing + 1] = item.id end
    for _, item in pairs(data.equipment.slots) do existing[#existing + 1] = item.id end
    for _, world_item in ipairs(data.world_items.dynamic) do existing[#existing + 1] = world_item.item.id end
    local placements = static_placements(map)
    for placement_id, placement in pairs(placements) do
        local override = data.world_items.static_overrides[placement_id]
        if not (override and override.removed) then existing[#existing + 1] = placement.item.id end
    end
    return ids.new_allocator(existing)
end

function M.create_fresh_item_id_allocator(map)
    local existing = {}
    for _, placement in ipairs(map.item_placements or {}) do existing[#existing + 1] = placement.item.id end
    for _, item in ipairs(map.player_inventory and map.player_inventory.items or {}) do existing[#existing + 1] = item.id end
    for _, item in pairs(map.player_equipment and map.player_equipment.slots or {}) do existing[#existing + 1] = item.id end
    return ids.new_allocator(existing)
end

function M.restore_player(player, data)
    player.position = position.new(data.player.x, data.player.y, data.player.z)
    player.facing = data.player.facing or "south"
end

return M
