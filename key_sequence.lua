local inspect = require 'inspect'
local util = require 'util'

function create_sequence(keys, action, persistent)
    return { keys = keys, action = action, persistent = persistent }
end

local function tree_insert(tree, path, value)
    if #path == 1 then
        tree[path[1]] = value
        return tree
    end
    if tree[path[1]] == nil then
        tree[path[1]] = {}
    end
    return tree_insert(tree[path[1]], util.slice(path, 2, #path), value)
end

local driver = function(sequences)
    local trees = {}
    local drivers = {}
    for k, device in pairs(sequences) do
        local tree = {}
        for j = 1, #device do
            local sequence = device[j]
            tree_insert(tree, sequence.keys, sequence)
        end
        trees[k] = tree
    end

    local function single_device_driver(tree)
        local current_tree = tree
        local suspended = {}
        local function revert()
            for i = 1, #suspended do
                local k = suspended[i]
                suspended[i] = nil
                diversion.send_event(k.ty, k.code, k.value)
            end
        end
        local function reset(device)
            current_tree = tree
            revert()
            return false
        end
        return function(ty, code, value)
            if ty ~= EV_KEY then return false end
            if value == 2 then return false end
            if value == 0 then
                local node = current_tree[code]
                if node == nil or node.keys == nil then
                    return reset()
                end
                return false
            end
            local node = current_tree[code]
            if node == nil then 
                return reset()
            end
            
            if node.keys == nil then
                table.insert(suspended, { ty = ty, code = code, value = value })
                current_tree = node
                return true
            end
            
            node.action()
            suspended = {}
            return true
        end
    end

    local function receive_event(device, ty, code, value)
        local tree = trees[device]
        if tree == nil then return false end
        local driver = drivers[device]
        if driver == nil then
            drivers[device] = single_device_driver(tree)
            return receive_event(device, ty, code, value)
        end
        return driver(ty, code, value)
    end
    return receive_event
end

return { 
    driver = driver, 
    create = create_sequence
}
