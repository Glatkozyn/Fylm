
local socket = require("connection.ljsocket")

local M = {}
local client
local buffer

function M.connect(channel)
	channel = channel:gsub("^#", ""):lower()

	local sock, err = socket.create("inet", "stream", "tcp")
	if not sock then
		return nil, err
	end

	local ok, err = sock:connect("irc.chat.twitch.tv", 6667)
	if not ok then
		sock:close()
		return nil, err
	end

	sock:set_blocking(false)

	local nick = "justinfan" .. math.random(999)

	sock:send("NICK " .. nick .. "\r\n")
	sock:send("USER " .. nick .. " 8 * :" .. nick .. "\r\n")
	sock:send("JOIN #" .. channel .. "\r\n")

	client = sock
	buffer = ""

	return true
end

function M.disconnect()
	if client then
		client:send("QUIT\r\n")
		client:close()
		client = nil
		buffer = nil
		return true
	end
	return false
end

function M.listen()
	if not client then
		return nil, "not connected"
	end

	local data, err = client:receive(4096)

    if data then
        buffer = buffer .. data
    elseif err ~= "timeout" then
        return nil, err
    end

	while true do
        local line_end = buffer:find("\r\n", 1, true)

        if not line_end then
            break
        end

        local line = buffer:sub(1, line_end - 1)
        buffer = buffer:sub(line_end + 2)

        if line:sub(1, 4) == "PING" then
            client:send("PONG :tmi.twitch.tv\r\n")
        else
            local user, msg = line:match("^:([^!]+)!.- PRIVMSG #[^ ]+ :(.+)$")

            if user and msg then
                return user, msg
            end
        end
    end

    return nil, "timeout"
end

return M
