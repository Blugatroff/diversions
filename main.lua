---@diagnostic disable: undefined-global

SLASH = 53

local key_sequence = require 'key_sequence'
local util = require 'util'

local execute = diversion.execute
local send_event = diversion.send_event

SECRETS = nil
execute("cat", { "./secrets.lua" }):next(function(output)
    if (output.code == 0) then
        SECRETS = require('secrets')
    else
        util.notify_send("failed to read './secrets.lua'")
        diversion.exit()
    end
end)

KEYS_DOWN = {}

local rev_mouse = false

local function create_mouse_callback(device, key, axis, direction)
    return function(value)
        if KEYS_DOWN[device][L_PIPE] then
            if value == 1 or value == 2 then
                if KEYS_DOWN[device][D] and KEYS_DOWN[device][F] then
                    send_event(EV_REL, axis, 10 * direction)
                elseif KEYS_DOWN[device][D] then
                    send_event(EV_REL, axis, 50 * direction)
                elseif KEYS_DOWN[device][F] then
                    send_event(EV_REL, axis, 4 * direction)
                else
                    send_event(EV_REL, axis, 200 * direction)
                end
            end
        else
            send_event(EV_KEY, key, value)
        end
    end
end

DISABLED = function() end

KEYBOARD = 0
PUGIO = 1
KEYS_DOWN[KEYBOARD] = {}
KEYS_DOWN[PUGIO] = {}

OVERRIDES = {
    [KEYBOARD] = {
        [EV_KEY] = {
            [R_FN] = DISABLED,
            [L_PIPE] = DISABLED,
            [MENU] = DISABLED,
            [D] = function(value)
                if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                    send_event(EV_KEY, D, value)
                end
            end,
            [F] = function(value)
                if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                    send_event(EV_KEY, F, value)
                end
            end,
            [SPACE] = function(value)
                if KEYS_DOWN[KEYBOARD][L_PIPE] then
                    send_event(EV_KEY, L_BUTTON, value)
                else
                    send_event(EV_KEY, SPACE, value)
                end
            end,
            [N] = function(value)
                if KEYS_DOWN[KEYBOARD][L_PIPE] then
                    send_event(EV_KEY, R_BUTTON, value)
                else
                    send_event(EV_KEY, N, value)
                end
            end,
            [M] = function(value)
                if KEYS_DOWN[KEYBOARD][L_PIPE] then
                    send_event(EV_KEY, M_BUTTON, value)
                else
                    send_event(EV_KEY, M, value)
                end
            end,
            [P] = function(value)
                if KEYS_DOWN[KEYBOARD][L_PIPE] then
                    if value == 1 or value == 2 then
                        send_event(EV_REL, WHEEL, 100)
                    end
                else
                    send_event(EV_KEY, P, value)
                end
            end,
            [Z] = function(value)
                if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                    send_event(EV_KEY, Z, value)
                end
            end,
            [X] = function(value)
                if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                    send_event(EV_KEY, X, value)
                end
            end,
            [SEMICOLON] = function(value)
                if KEYS_DOWN[KEYBOARD][L_PIPE] then
                    if value == 1 or value == 2 then
                        send_event(EV_REL, WHEEL, -100)
                    end
                else
                    send_event(EV_KEY, SEMICOLON, value)
                end
            end,
            [L_ALT] = function(value)
                send_event(EV_KEY, L_ALT, value)
            end,
            [H] = create_mouse_callback(KEYBOARD, H, X_AXIS, -1),
            [J] = create_mouse_callback(KEYBOARD, J, Y_AXIS, 1),
            [L] = create_mouse_callback(KEYBOARD, L, X_AXIS, 1),
            [K] = create_mouse_callback(KEYBOARD, K, Y_AXIS, -1),
            [VOL_DOWN] = function(value)
                if KEYS_DOWN[KEYBOARD][L_CTRL] then
                    util.change_sink_volume("Spotify", '-5%')
                else
                    send_event(EV_KEY, VOL_DOWN, value)
                end
            end,
            [VOL_UP] = function(value)
                if KEYS_DOWN[KEYBOARD][L_CTRL] then
                    util.change_sink_volume("Spotify", '+5%')
                else
                    send_event(EV_KEY, VOL_UP, value)
                end
            end,
            [INSERT] = function(value)
                if KEYS_DOWN[KEYBOARD][L_CTRL] then
                    diversion.reload()
                else
                    send_event(EV_KEY, PAUSE_BREAK, value)
                end
            end
        }
    },
    [PUGIO] = {
        [EV_REL] = {
            [X_AXIS] = function(value)
                if KEYS_DOWN[KEYBOARD][L_PIPE] and KEYS_DOWN[KEYBOARD][Z] then
                else
                    if rev_mouse then
                        send_event(EV_REL, X_AXIS, -value)
                    else
                        send_event(EV_REL, X_AXIS, value)
                    end
                end
            end,
            [Y_AXIS] = function(value)
                if KEYS_DOWN[KEYBOARD][L_PIPE] and KEYS_DOWN[KEYBOARD][X] then
                else
                    if rev_mouse then
                        send_event(EV_REL, Y_AXIS, -value)
                    else
                        send_event(EV_REL, Y_AXIS, value)
                    end
                end
            end,
            [WHEEL_PIXEL] = function(value)
                if not KEYS_DOWN[KEYBOARD][L_PIPE] then
                    send_event(EV_REL, WHEEL_PIXEL, value)
                end
            end
        },
        [EV_KEY] = {
            [L_BUTTON] = function(value)
                send_event(EV_KEY, L_BUTTON, value)
            end
        }
    }
}

local function swap_keys(device, a, b)
    local function swap(event)
        if not OVERRIDES[device] then return end
        if not OVERRIDES[device][event] then return end
        local prev_a = OVERRIDES[device][event][a]
        local prev_b = OVERRIDES[device][event][b]
        if prev_b ~= nil then
            OVERRIDES[device][event][a] = prev_b
        else
            OVERRIDES[device][event][a] = function(value) send_event(event, b, value) end
        end
        if prev_a ~= nil then
            OVERRIDES[device][event][b] = prev_a
        else
            OVERRIDES[device][event][b] = function(value) send_event(event, a, value) end
        end
    end
    swap(EV_KEY)
    swap(EV_REL)
end

local vol_up_seq = key_sequence.create({ G, K }, function()
    if KEYS_DOWN[KEYBOARD][L_SHIFT] then
        util.change_sink_volume("Spotify", "+2%")
    else
        send_event(EV_KEY, VOL_UP, 1)
        send_event(EV_KEY, VOL_UP, 0)
    end
end)
local vol_down_seq = key_sequence.create({ G, J }, function()
    if KEYS_DOWN[KEYBOARD][L_SHIFT] then
        util.change_sink_volume("Spotify", "-2%")
    else
        send_event(EV_KEY, VOL_DOWN, 1)
        send_event(EV_KEY, VOL_DOWN, 0)
    end
end)
local deskpi = "deskpi"
local light_off_seq = key_sequence.create({ G, LT }, function()
    execute("curl", { "http://" .. deskpi .. ":8000/off" })
end)
local light_on_seq = key_sequence.create({ G, GT }, function()
    execute("curl", { "http://" .. deskpi .. ":8000/on" })
end)
local rev_mouse_toggle_seq = key_sequence.create({ R_ALT, R, E }, function()
    rev_mouse = not rev_mouse
end)
local repeat_command_seq = key_sequence.create({ G, MINUS }, function ()
    diversion.spawn("nc", { "127.0.0.1", "7821" })("run")
end)
local switch_audio_output_seq = key_sequence.create({ G, SLASH }, (function()
    local ports = { "analog-output-lineout", "analog-output-headphones" }
    local current = ports[1]
    return function()
        local port = ports[current == ports[1] and 2 or 1]
        print("switching to " .. port)
        execute("pactl", { "set-sink-port", "alsa_output.pci-0000_09_00.4.analog-stereo", port }, function(output) print(output.code, output.stderr, output.stdout) end)
        current = port
    end
end)())
local sequences = {
    [KEYBOARD] = {
        vol_down_seq,
        vol_up_seq,
        rev_mouse_toggle_seq,
        light_off_seq,
        light_on_seq,
        switch_audio_output_seq,
        repeat_command_seq,
    },
}

-- swap_keys(KEYBOARD, L_SHIFT, L_ALT)
swap_keys(KEYBOARD, ESCAPE, CAPS_LOCK)

local sequence_driver = key_sequence.driver(sequences)
local function on_event(device, ty, code, value)
    local keys_down = KEYS_DOWN[device]
    if ty == EV_KEY then
        keys_down[code] = value ~= 0
    end
    if keys_down[INSERT] then
        print(ty, code, value)
        return
    end
    if sequence_driver(device, ty, code, value) then return end
    local device_override = OVERRIDES[device]
    if device_override ~= nil then
        local ty_override = device_override[ty]
        if ty_override ~= nil then
            local override = ty_override[code]
            if override ~= nil then
                override(value)
                return
            end
        end
    end
    send_event(ty, code, value)
end

diversion.listen(on_event)
print("started at", os.date("%Y-%m-%d %H:%M:%S"))
execute("whoami", {}):next(function(output)
    print("running as user", output.stdout)
end)
util.notify_send("Diversion started!")
