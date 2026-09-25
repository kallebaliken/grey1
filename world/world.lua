local chunks = require "world.chunks"
local actor_api = require "actors.actor"
local actor_registry_api = require "actors.registry"
local tile_api = require "world.tile"
local instance_api = require "world.object_instance"
local item_instance = require "items.item_instance"
local world_items = require "world.world_items"
local position = require "world.position"
local state_api = require "state.world_state"
local M = {}

local methods = {}
methods.__index = methods

function M.new(map, registry, runtime_state, item_registry)
    local self = setmetatable({ map = map, registry = registry, state = runtime_state,
        item_registry = item_registry, chunks = {}, objects = {}, world_items = {},
        actor_registry = actor_registry_api.new() }, methods)
    for _, placement in ipairs(map.placements) do self:add_object(instance_api.new(placement)) end
    for _, placement in ipairs(map.item_placements or {}) do
        assert(item_registry, "map item placements require an item registry")
        local item = item_instance.new(placement.item, item_registry)
        world_items.place(self, item, placement.position, placement.id)
    end
    for _, placement in ipairs(map.actor_placements or {}) do
        -- Legacy/direct Actor placements remain useful to pure-Lua fixtures. Creature-backed
        -- placements are composed after combat/attack services exist.
        if placement.type then
            self:place_actor(actor_api.new(placement.id, placement.type, placement.x, placement.y, placement.z, placement.facing))
        end
    end
    return self
end

function methods:get_chunk(chunk_x, chunk_y, z, create)
    local key = chunks.key(chunk_x, chunk_y, z)
    if create and not self.chunks[key] then self.chunks[key] = chunks.new(chunk_x, chunk_y, z) end
    return self.chunks[key]
end

function methods:get_tile(x, y, z, create)
    local chunk_x, chunk_y = chunks.coordinates(x, y)
    local chunk = self:get_chunk(chunk_x, chunk_y, z, create)
    if not chunk then return nil end
    local key = chunks.tile_key(x, y)
    if create and not chunk.tiles[key] then chunk.tiles[key] = tile_api.new(x, y, z) end
    return chunk.tiles[key]
end

function methods:get_objects(x, y, z)
    local target = self:get_tile(x, y, z)
    return target and target.objects or {}
end

function methods:add_object(instance)
    assert(not self.objects[instance.id], "duplicate object id: " .. instance.id)
    local definition = self.registry:get(instance.type)
    self.objects[instance.id] = instance
    for dy = 0, (definition.footprint_height or 1) - 1 do
        for dx = 0, (definition.footprint_width or 1) - 1 do
            tile_api.insert(self:get_tile(instance.position.x + dx, instance.position.y + dy, instance.position.z, true), instance, definition)
        end
    end
end

function methods:remove_object(id)
    local instance = self.objects[id]
    if not instance then return false end
    local definition = self.registry:get(instance.type)
    for dy = 0, (definition.footprint_height or 1) - 1 do
        for dx = 0, (definition.footprint_width or 1) - 1 do
            tile_api.remove(self:get_tile(instance.position.x + dx, instance.position.y + dy, instance.position.z), id)
        end
    end
    self.objects[id] = nil
    return true
end

function methods:object_state(id) return instance_api.state(assert(self.objects[id], "unknown object: " .. id), self.state) end

function methods:set_object_state(id, patch, events)
    assert(self.objects[id], "unknown object: " .. id)
    local result = state_api.patch_object(self.state, id, patch)
    if events then events.emit("object_state_changed", { object_id = id, state = state_api.copy(result) }) end
    return result
end

function methods:has_ground(x, y, z)
    local target = self:get_tile(x, y, z)
    return target ~= nil and tile_api.has_ground(target)
end

function methods:is_walkable(x, y, z, moving_actor_id, allow_occupied)
    if x < 0 or y < 0 or x >= self.map.width or y >= self.map.height then return false end
    local target = self:get_tile(x, y, z)
    if not target or not tile_api.has_ground(target) then return false end
    if not allow_occupied and target.actor_id and target.actor_id ~= moving_actor_id then return false end
    for _, entry in ipairs(target.objects) do
        local blocking = entry.definition.blocking
        if entry.definition.blocking_state then
            local state = entry.instance.item and state_api.copy(entry.instance.item.state) or instance_api.state(entry.instance, self.state)
            blocking = entry.definition.blocking_state(state)
        end
        if blocking then return false end
    end
    return true
end

function methods:blocks_sight(x, y, z)
    for _, entry in ipairs(self:get_objects(x, y, z)) do
        local blocking = entry.definition.blocks_sight == true
        if entry.definition.blocks_sight_state then
            local state = entry.instance.item and state_api.copy(entry.instance.item.state)
                or instance_api.state(entry.instance, self.state)
            blocking = entry.definition.blocks_sight_state(state)
        end
        if blocking then return true end
    end
    return false
end

function methods:place_actor(actor, events)
    local target = assert(self:get_tile(actor.position.x, actor.position.y, actor.position.z), "actor requires a tile")
    assert(not target.actor_id or target.actor_id == actor.id, "tile occupied")
    local existing = self.actor_registry:get(actor.id)
    assert(not existing or existing == actor, "duplicate actor id: " .. actor.id)
    if not existing then self.actor_registry:add(actor) end
    target.actor_id = actor.id
    if events and not existing then events.emit("actor_added", { actor_id = actor.id, actor_type = actor.type,
        position = position.copy(actor.position) }) end
end

function methods:move_actor(actor, destination)
    assert(self.actor_registry:get(actor.id) == actor, "actor is not registered in world")
    local old = self:get_tile(actor.position.x, actor.position.y, actor.position.z)
    local target = assert(self:get_tile(destination.x, destination.y, destination.z), "destination requires a tile")
    assert(not target.actor_id or target.actor_id == actor.id, "destination occupied")
    if old then old.actor_id = nil end
    target.actor_id = actor.id
end

function methods:get_actor(id)
    return self.actor_registry:get(id)
end

function methods:get_actor_at(x, y, z)
    local tile = self:get_tile(x, y, z)
    return tile and tile.actor_id and self.actor_registry:get(tile.actor_id) or nil
end

function methods:get_actors()
    return self.actor_registry:get_all()
end

function methods:remove_actor(id, events)
    local actor = self.actor_registry:get(id)
    if not actor then return nil end
    local tile = self:get_tile(actor.position.x, actor.position.y, actor.position.z)
    if tile and tile.actor_id == id then tile.actor_id = nil end
    local removed = self.actor_registry:remove(id)
    if events then events.emit("actor_removed", { actor_id = actor.id, actor_type = actor.type,
        position = position.copy(actor.position) }) end
    return removed
end

return M
