local direction = require "world.direction"
local position = require "world.position"
local M = { DEFAULT_MAX_NODES = 2048 }

local function failure(reason, visited)
    return { success = false, reason = reason, visited = visited or 0 }
end

local function valid_position(value)
    return type(value) == "table" and type(value.x) == "number" and type(value.y) == "number"
        and type(value.z) == "number" and value.x == value.x and value.y == value.y and value.z == value.z
        and value.x % 1 == 0 and value.y % 1 == 0 and value.z % 1 == 0
end

local function manhattan(left, right)
    return math.abs(left.x - right.x) + math.abs(left.y - right.y)
end

local function less(left, right)
    if left.f ~= right.f then return left.f < right.f end
    if left.h ~= right.h then return left.h < right.h end
    return left.sequence < right.sequence
end

local function push(heap, value)
    heap[#heap + 1] = value
    local index = #heap
    while index > 1 do
        local parent = math.floor(index / 2)
        if not less(heap[index], heap[parent]) then break end
        heap[index], heap[parent] = heap[parent], heap[index]
        index = parent
    end
end

local function pop(heap)
    local first = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local index = 1
        while true do
            local left, right = index * 2, index * 2 + 1
            if left > #heap then break end
            local child = right <= #heap and less(heap[right], heap[left]) and right or left
            if not less(heap[child], heap[index]) then break end
            heap[index], heap[child] = heap[child], heap[index]
            index = child
        end
    end
    return first
end

local function reconstruct(nodes, goal_key)
    local path, key = {}, goal_key
    while nodes[key].parent do
        table.insert(path, 1, position.copy(nodes[key].position))
        key = nodes[key].parent
    end
    return path
end

function M.find_path(world, actor_id, goal, options)
    options = options or {}
    local actor = world:get_actor(actor_id)
    if not actor then return failure("unknown_actor") end
    local start = actor.position
    if not valid_position(start) or world:get_actor_at(start.x, start.y, start.z) ~= actor
        or not world:has_ground(start.x, start.y, start.z) then return failure("invalid_start") end
    if not valid_position(goal) or not world:has_ground(goal.x, goal.y, goal.z) then return failure("invalid_goal") end
    if start.z ~= goal.z then return failure("different_z") end
    local max_nodes = options.max_nodes or M.DEFAULT_MAX_NODES
    if type(max_nodes) ~= "number" or max_nodes % 1 ~= 0 or max_nodes < 1 then return failure("invalid_limit") end
    if position.equals(start, goal) then return { success = true, path = {}, cost = 0, visited = 0 } end

    local allow_occupied_goal = options.allow_occupied_goal == true
    local goal_occupant = world:get_actor_at(goal.x, goal.y, goal.z)
    if goal_occupant and goal_occupant.id ~= actor.id and not allow_occupied_goal then return failure("blocked_goal") end
    if not world:is_walkable(goal.x, goal.y, goal.z, actor.id, allow_occupied_goal) then return failure("blocked_goal") end

    local start_key, goal_key = position.key(start.x, start.y, start.z), position.key(goal.x, goal.y, goal.z)
    local nodes, closed, heap = {}, {}, {}
    local neighbor_order = direction.ordered()
    local sequence = 1
    local start_h = manhattan(start, goal)
    nodes[start_key] = { position = position.copy(start), g = 0, h = start_h, f = start_h, sequence = sequence }
    push(heap, nodes[start_key])
    local visited = 0

    while #heap > 0 do
        local current = pop(heap)
        local current_key = position.key(current.position.x, current.position.y, current.position.z)
        if not closed[current_key] and nodes[current_key] == current then
            visited = visited + 1
            if visited > max_nodes then return failure("search_limit", max_nodes) end
            if current_key == goal_key then
                return { success = true, path = reconstruct(nodes, goal_key), cost = current.g, visited = visited }
            end
            closed[current_key] = true
            for _, facing in ipairs(neighbor_order) do
                local dx, dy = direction.offset(facing)
                local next_position = position.offset(current.position, dx, dy, 0)
                local next_key = position.key(next_position.x, next_position.y, next_position.z)
                local is_goal = next_key == goal_key
                if not closed[next_key] and world:is_walkable(next_position.x, next_position.y, next_position.z,
                    actor.id, is_goal and allow_occupied_goal) then
                    local tentative_g = current.g + 1
                    local known = nodes[next_key]
                    if not known or tentative_g < known.g then
                        sequence = sequence + 1
                        local h = manhattan(next_position, goal)
                        local node = { position = next_position, g = tentative_g, h = h,
                            f = tentative_g + h, parent = current_key, sequence = sequence }
                        nodes[next_key] = node
                        push(heap, node)
                    end
                end
            end
        end
    end
    return failure("no_path", visited)
end

return M
