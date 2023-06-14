dofile './util.lua'
dofile './codes.lua'
local Promise = require 'promise'

local key_sequence = require 'key_sequence'
local diversion = require 'diversion'
local util = require 'util'
local remote = require('remote')

local execute = diversion.execute
local send_event = diversion.send_event

local secrets = nil
execute("cat", { "./secrets.lua" }):next(function(output)
    if (output.code == 0) then
        secrets = require('secrets')
    else
        util.notify_send("failed to read './secrets.lua'")
        diversion.exit()
    end
end)

KEYS_DOWN = {}

rev_mouse = false

function create_mouse_callback(device, key, axis, direction)
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
            [ESCAPE] = function(value)
                send_event(EV_KEY, CAPS_LOCK, value)
            end,
            [CAPS_LOCK] = function(value)
                send_event(EV_KEY, ESCAPE, value)
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
            [PAUSE_BREAK] = function(value)
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
local rev_mouse_toggle_seq = key_sequence.create({ R_ALT, R, E }, function()
    rev_mouse = not rev_mouse
end)
local sequences = {
    [KEYBOARD] = { vol_down_seq, vol_up_seq, rev_mouse_toggle_seq },
}

local send_to_remote = nil
local use_remote = false
local sequence_driver = key_sequence.driver(sequences)
local function on_event(device, ty, code, value, from_remote)
    local keys_down = KEYS_DOWN[device]
    if not from_remote and ty == EV_KEY and (
        (code == R_CTRL and value == 1 and keys_down[L_CTRL] ) or 
        (code == L_CTRL and value == 1 and keys_down[R_CTRL] ))
    then
        if use_remote then
            use_remote = false
        else
            if send_to_remote == nil then
                send_to_remote = remote.connect(secrets.remote, function()
                    send_to_remote = nil
                    use_remote = false
                end)
            end
            use_remote = true
        end
    end
    if use_remote then
        send_to_remote(ty, code, value)
        return
    end
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

local separator = string.pack("B", 255)
function listen_for_connection()
    local remaining = ""
    local port = 7431
    print("listening on port " .. port)
    diversion.spawn(
        "nc",
        { "-l", "-p", tostring(port) },
        function(data)
            for block in util.split(remaining .. data, separator) do
                if block:len() == 6 then
                    local ty, code, value = string.unpack("HHh", block)
                    on_event(KEYBOARD, ty, code, value, true)
                    diversion.send_event(EV_SYN, 0, 0)
                else
                    remaining = block
                end
            end
        end,
        function(data)
            print(data)
        end,
        function(code)
            local message = "Remote Connection Closed (" .. code .. ")\nRestarting listener in 1s"
            print(message)
            util.notify_send(message)
            execute("sleep", { "1" }):next(listen_for_connection)
        end
    )
end
listen_for_connection()

diversion.listen(on_event)
print("started at", os.date("%Y-%m-%d %H:%M:%S"))
execute("whoami", {}):next(function(output)
    print("running as user", output.stdout)
end)
util.notify_send("Diversion started!")
