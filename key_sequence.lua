local diversion = require 'diversion'

function create_sequence(keys, action)
    local i = 1
    local starting_key_pressed = false
    local function reset()
        if starting_key_pressed then
            i = 2
        else
            i = 1
        end
    end
    local receive = function(ty, code, value)
        if ty ~= EV_KEY then return false, false end
        if code == keys[1] then
            starting_key_pressed = value ~= 0
        end
        if keys[i] == code and value == 1 then
            -- the pressed key was the one expected by the sequence
            i = i + 1
            if i > #keys then
                action()
                return true, true
            end
            return true, false
        end
        if keys[1] == code then
            -- event is from the starting key
            if value == 0 then
                -- reset because starting key was released
                i = 1
                return false, false
            else
                return true, false
            end
        end
        if i > 1 then
            -- a sequence was in progress
            if value == 1 then
                -- a non-matching key was pressed down therefore reset
                i = 1
                return false, false
            else
                -- a key was released or repeated
                return true, false
            end
        end
        return false, false
    end
    return { receive = receive, reset = reset }
end

local suspended = {}
local driver = function(sequences)
    return function(device, ty, code, value)
        if ty ~= EV_KEY then return false end
        local function suspend()
            table.insert(suspended, { ty = ty, code = code, value = value })
        end
        local function revert()
            for i = 1, #suspended do
                local k = suspended[i]
                diversion.send_event(EV_KEY, k.code, k.value)
                diversion.send_event(EV_KEY, k.code, k.value)
            end
            suspended = {}
        end

        local device_sequences = sequences[device]
        if device_sequences then
            local was_captured = false
            for _, sequence in pairs(device_sequences) do
                local captured, completed = sequence.receive(ty, code, value)
                was_captured = was_captured or captured
                if completed then 
                    for _, sequence in pairs(device_sequences) do 
                        sequence.reset()
                    end
                    suspended = {}
                    return true
                end
            end
            if was_captured then
                suspend()
                return true
            end
            revert()
        end
        return false
    end
end

return { 
    driver = driver, 
    create = create_sequence
}

