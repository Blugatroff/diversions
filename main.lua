dofile './util.lua'
dofile './codes.lua'
local Promise = require 'promise'

local key_sequence = require 'key_sequence'
local diversion = require 'diversion'
local util = require 'util'

local execute = diversion.execute
local send_event = diversion.send_event

KEYS_DOWN = {}

function notify_send(msg)
    execute("notify-send", { msg }):next(function(output) 
        print(output.stdout) 
    end)
end
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

CORSAIR = 0
PUGIO = 1
KEYS_DOWN[CORSAIR] = {}
KEYS_DOWN[PUGIO] = {}

OVERRIDES = {
    [CORSAIR] = {
        [EV_KEY] = {
            [R_FN] = DISABLED,
            [L_PIPE] = DISABLED,
            [MENU] = DISABLED,
            [D] = function(value)
                if not KEYS_DOWN[CORSAIR][L_PIPE] then
                    send_event(EV_KEY, D, value)
                end
            end,
            [F] = function(value)
                if not KEYS_DOWN[CORSAIR][L_PIPE] then
                    send_event(EV_KEY, F, value)
                end
            end,
            [SPACE] = function(value)
                if KEYS_DOWN[CORSAIR][L_PIPE] then
                    send_event(EV_KEY, L_BUTTON, value)
                else
                    send_event(EV_KEY, SPACE, value)
                end
            end,
            [N] = function(value)
                if KEYS_DOWN[CORSAIR][L_PIPE] then
                    send_event(EV_KEY, R_BUTTON, value)
                else
                    send_event(EV_KEY, N, value)
                end
            end,
            [M] = function(value)
                if KEYS_DOWN[CORSAIR][L_PIPE] then
                    send_event(EV_KEY, M_BUTTON, value)
                else
                    send_event(EV_KEY, M, value)
                end
            end,
            [P] = function(value)
                if KEYS_DOWN[CORSAIR][L_PIPE] then
                    if value == 1 or value == 2 then
                        send_event(EV_REL, WHEEL, 100)
                    end
                else
                    send_event(EV_KEY, P, value)
                end
            end,
            [Z] = function(value)
                if not KEYS_DOWN[CORSAIR][L_PIPE] then
                    send_event(EV_KEY, Z, value)
                end
            end,
            [X] = function(value)
                if not KEYS_DOWN[CORSAIR][L_PIPE] then
                    send_event(EV_KEY, X, value)
                end
            end,
            [SEMICOLON] = function(value)
                if KEYS_DOWN[CORSAIR][L_PIPE] then
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
            [H] = create_mouse_callback(CORSAIR, H, X_AXIS, -1),
            [J] = create_mouse_callback(CORSAIR, J, Y_AXIS, 1),
            [L] = create_mouse_callback(CORSAIR, L, X_AXIS, 1),
            [K] = create_mouse_callback(CORSAIR, K, Y_AXIS, -1),
            [VOL_DOWN] = function(value)
                if KEYS_DOWN[CORSAIR][L_CTRL] then
                    util.change_sink_volume("Spotify", '-5%')
                else
                    send_event(EV_KEY, VOL_DOWN, value)
                end
            end,
            [VOL_UP] = function(value)
                if KEYS_DOWN[CORSAIR][L_CTRL] then
                    util.change_sink_volume("Spotify", '+5%')
                else
                    send_event(EV_KEY, VOL_UP, value)
                end
            end,
            [PAUSE_BREAK] = function(value)
                if KEYS_DOWN[CORSAIR][L_CTRL] then
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
                if KEYS_DOWN[CORSAIR][L_PIPE] and KEYS_DOWN[CORSAIR][Z] then
                else
                    send_event(EV_REL, X_AXIS, value)
                end
            end,
            [Y_AXIS] = function(value)
                if KEYS_DOWN[CORSAIR][L_PIPE] and KEYS_DOWN[CORSAIR][X] then
                else
                    send_event(EV_REL, Y_AXIS, value)
                end
            end,
            [WHEEL_PIXEL] = function(value)
                if not KEYS_DOWN[CORSAIR][L_PIPE] then
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
    if KEYS_DOWN[CORSAIR][L_SHIFT] then
        util.change_sink_volume("Spotify", "+2%")
    else
        send_event(EV_KEY, VOL_UP, 1)
        send_event(EV_KEY, VOL_UP, 0)
    end
end)
local vol_down_seq = key_sequence.create({ G, J }, function()
    if KEYS_DOWN[CORSAIR][L_SHIFT] then
        util.change_sink_volume("Spotify", "-2%")
    else
        send_event(EV_KEY, VOL_DOWN, 1)
        send_event(EV_KEY, VOL_DOWN, 0)
    end
end)

local sequences = {
    [CORSAIR] = { vol_down_seq, vol_up_seq },
}
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
notify_send("Diversion started!")
