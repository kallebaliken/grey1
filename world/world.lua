local chunks = require "world.chunks"
local tile_api = require "world.tile"
local instance_api = require "world.object_instance"
local state_api = require "state.world_state"
local M = {}

local methods = {}
methods.__index = methods

function M.new(map, registry, runtime_state)
    local self = setmetatable({ map = map, registry = registry, state = runtime_state,
        chunks = {}, objects = {}, actors = {} }, methods)
    for _, placement in ipairs(map.placements) do self:add_object(instance_api.new(placement)) end
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

function methods:is_walkable(x, y, z, moving_actor_id)
    if x < 0 or y < 0 or x >= self.map.width or y >= self.map.height then return false end
    local target = self:get_tile(x, y, z)
    if not target or not tile_api.has_ground(target) then return false end
    if target.actor_id and target.actor_id ~= moving_actor_id then return false end
    for _, entry in ipairs(target.objects) do
        local state = instance_api.state(entry.instance, self.state)
        local blocking = entry.definition.blocking
        if entry.definition.blocking_state then blocking = entry.definition.blocking_state(state) end
        if blocking then return false end
    end
    return true
end

function methods:place_actor(actor)
    local target = assert(self:get_tile(actor.tile_position.x, actor.tile_position.y, actor.tile_position.z), "actor requires a tile")
    assert(not target.actor_id or target.actor_id == actor.id, "tile occupied")
    target.actor_id, self.actors[actor.id] = actor.id, actor
end

function methods:move_actor(actor, destination)
    local old = self:get_tile(actor.tile_position.x, actor.tile_position.y, actor.tile_position.z)
    local target = assert(self:get_tile(destination.x, destination.y, destination.z), "destination requires a tile")
    if old then old.actor_id = nil end
    target.actor_id = actor.id
end

return M
