local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local cluster_util = require "hen.cluster_util"
local logger = require "hen.logger"

local WATCHDOG
local host
local pack_request

local CMD = {}
local REQUEST = {}
local client_fd
local g_has_verify = false
local g_user = {}

local mystore = {}

function REQUEST:get()
	skynet.error("get", self.what)
	local r = mystore[self.what]
	return { result = r }
end

function REQUEST:set()
	skynet.error("set", self.what, self.value)
    mystore[self.what] = self.value
end

function REQUEST:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

function REQUEST:verify()
    local ok, uid = cluster_util.call_rand_one("^loginserver.*", ".logind", "verify", self.username, self.pwd)
    if ok and uid then
        g_has_verify = true
        g_user.uid = uid
        return {err = 0, uid = uid}
    end
    logger.info("verify fail, err:%s", uid)
    return {err = 1}
end

local function request(name, args, response)
	local f = assert(REQUEST[name])
	local r = f(args)
	if response then
		return response(r)
	end
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(client_fd, package)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (fd, _, type, ...)
		assert(fd == client_fd)	-- You can use fd to reply message
		skynet.ignoreret()	-- session is fd, don't call skynet.ret
		--skynet.trace()
		if type == "REQUEST" then
			local ok, result  = pcall(request, ...)
			if ok then
				if result then
					send_package(result)
				end
			else
				skynet.error(result)
			end
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	pack_request = host:attach(sprotoloader.load(2))
	skynet.fork(function()
		while true do
			send_package(pack_request "heartbeat")
			skynet.sleep(500)
		end
	end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		--skynet.trace()
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
