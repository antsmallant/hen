local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local cluster_util = require "hen.cluster_util"
local logger = require "hen.logger"
local errors = require "common.errors"
local typeof = require "etcd.typeof"
local skynet_util = require "hen.skynet_util"
require "skynet.queue"
require "luaext"


local WATCHDOG
local host
local pack_request

local CMD = {}
local REQUEST = {}
local client_fd
local g_has_verify = false
local g_is_login = false
local on_verify_suc_q = skynet.queue()
--[[
{
    uid,
    plazasvr,    --登录的plazasvr
    plazaagent,
}
]]
local g_user = {}


local function on_verify_suc()
    local function do_login()
        assert(g_user.uid, "not verify yet")
        assert(g_has_verify, "not verify yet")
        if g_user.plazasvr then return end  --already login
        local uid = g_user.uid
        local plazasvr = cluster_util.get_rand_one("^plazaserver.*")
        if not plazasvr then
            logger.err("get plazasvr node fail")
        end
        logger.info("plazasvr:%s", plazasvr)
        local cluster_id = cluster_util.get_cluster_id()
        local ret = cluster_util.call(plazasvr, ".agent_mgr", "login", cluster_id, skynet.self(), uid)
        if not typeof.table(ret) then
            logger.err("login fail, ret:%s", tostring(ret))
        elseif ret.err == errors.ok then
            assert(ret.agent)
            g_user.plazasvr = plazasvr
            g_user.plazaagent = ret.agent
            logger.info("login suc, uid:%s, plazasvr:%s, plazaagent:%s",
                uid, plazasvr, ret.agent)
        elseif ret.err == errors.already_login then
            logger.info("already login, uid:%s, ret:%s", uid, tostring(ret))
            assert(ret.plazasvr)
            g_user.plazasvr = ret.plazasvr
            g_user.plazaagent = ret.agent
        else
            logger.err("login fail, unknown error, ret:%s", tostring(ret))
        end
    end

    on_verify_suc_q(do_login)
end

function REQUEST:verify()
    local ok, uid = cluster_util.call_rand_one("^loginserver.*", ".logind", "verify", self.username, self.pwd)
    if ok and uid then
        g_has_verify = true
        g_user.uid = uid
        skynet.fork(on_verify_suc)
        return {err = 0, uid = uid}
    end
    logger.info("verify fail, err:%s", uid)
    return {err = 1}
end

function REQUEST:transfer()
    assert(self.svrtype)
    if self.svrtype == "plazaserver" then
        if not g_user.plazasvr then
            return {err = errors.target_not_found}
        end
        cluster_util.send(g_user.plazasvr, g_user.plazaagent, "client_msg", self.package)
    else
        assert(false, "not support yet:"..self.svrtype)
    end
end

local function request(name, args, response)
    logger.info("client request: %s", name)
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
    logger.info("user disconnect, uid:%s", g_user.uid)
	skynet.exit()
end

--转发其他服务器的消息给客户端
function CMD.redirect_msg(svrname, svrtype, package)
    local pack = pack_request("redirect_msg", {
        svrname = svrname,
        svrtype = svrtype,
        package = package,
    })
    send_package(pack)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        return skynet_util.lua_docmd(CMD, session, cmd, ...)
	end)
end)
