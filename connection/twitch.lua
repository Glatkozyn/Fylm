
local socket = require("connection.ljsocket")

local M = {}

local client

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

	return true
end

function M.disconnect()
	if client then
		client:send("QUIT\r\n")
		client:close()
		client = nil
	end
end

function M.listen()
	if not client then
		return nil, "not connected"
	end

	while true do
		local message, err = client:receive(4096)

		if not message then
			return nil, err
		end

		if message:sub(1, 4) == "PING" then
			client:send("PONG :tmi.twitch.tv\r\n")
		else
			local user, msg = message:match("^:([^!]+)!.- PRIVMSG #[^ ]+ :(.+)$")

			if user and msg then
				return user, msg
			end
		end
	end
end

return M
