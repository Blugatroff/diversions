local util = require('util')
local diversion = require('diversion')

local function connect(remote, on_close)
    local send_remote = diversion.spawn(
        "nc", 
        { remote.host, tostring(remote.port) },
        function() end, 
        function(data) 
            print(data)
        end, 
        function(code) 
            local message = "Remote Connection Closed (" .. code .. ")"
            print(message)
            util.notify_send(message)
            on_close()
        end
    )

    return function(ty, code, value)
        print(ty, code, value)
        local bytes = string.pack("HHhB", ty, code, value, 255)
        send_remote(bytes)
    end
end

return {
    connect = connect,
}
