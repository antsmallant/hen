local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local Etcd = require "etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "skynet_util"
local json = require "json"


local function test_json()
    local function _json_en_de(v)
        local e = json.encode(v)
        local d = json.decode(e)
        skynet.error(lua_util.tostring(v), e, lua_util.tostring(d))
    end
    
    skynet.error(string.rep("-", 15).."test_json begin"..string.rep("-", 15))

    _json_en_de("127.0.0.1")
    _json_en_de({1,2,3})
    _json_en_de(123)
    _json_en_de(127.0323)

    skynet.error(string.rep("-", 15).."test_json   end"..string.rep("-", 15))
end


local function etcd_get_cfg()
    local hosts = json.decode(skynet.getenv "etcd_hosts")
    local user = skynet.getenv "etcd_user"
    local password = skynet.getenv "etcd_password"
    assert(hosts, [[invalid etcd_hosts, check config please, config should looks like etcd_hosts = "[\"127.0.0.1:2379\"]"]])

    return {
        hosts = hosts,
        user = user,
        password = password,
    }    
end


local function test_etcd_kv()
    skynet.error(string.rep("-", 15).."test_etcd_kv begin"..string.rep("-", 15))

    local opts = etcd_get_cfg()
    opts.key_prefix = "/etc"
    local etcd_cli = Etcd.new(opts)

    etcd_cli:set("/server1", "127.0.0.1:8001")
    etcd_cli:set("/server2", "127.0.0.1:8002")
    etcd_cli:set("/server3", "127.0.0.1:8003")

    local getret = etcd_cli:get("/server1")
    skynet.error("getret:", lua_util.tostring(getret))    

    local readdirret = etcd_cli:readdir("/")
    skynet.error("readdirret:", lua_util.tostring(readdirret))

    skynet.error(string.rep("-", 15).."test_etcd_kv   end"..string.rep("-", 15))
end


local function test_etcd_watch()
    skynet.error(string.rep("-", 15).."test_etcd_watch begin"..string.rep("-", 15))

    local opts = etcd_get_cfg()
    opts.key_prefix = "/etc"
    local etcd_cli = Etcd.new(opts)

    local etcd_ttl = 10
    local prefix = "/"
    local node_id = "server1"
    local node_data = "192.168.0.1:8993"

    local grant = etcd_cli:grant(etcd_ttl)
    local grant_id = grant.ID
    skynet.error("grant_id", lua_util.tostring(grant_id))

    local attr = {
        lease = grant_id
    }
	local setret = etcd_cli:set(prefix..node_id, node_data, attr)
    skynet.error("setret", lua_util.tostring(setret))

    --续约
    local time_interval = etcd_ttl/2-1
    skynet.fork(function()
        while true do
            xpcall(
                function()
                    skynet.sleep(time_interval*100)
                    local keepret = etcd_cli:keepalive(grant_id)
                    skynet.error("keepret:", lua_util.tostring(keepret))                
                end, 
                skynet_util.handle_err
            )
        end
    end)

    --监听
    skynet.fork(function ()
        local version
        local function reset_watch()
            local opts = {
                start_revision = version
            }
            local reader, stream = etcd_cli:watchdir(prefix, opts)
            if not reader then
                return false
            end
            while true do
                local data = reader()
                if not data then
                    break
                else
                    skynet.error("recv:", lua_util.tostring(data))
                    version = data.result.header.revision + 1
                end
            end
            --连接异常
            etcd_cli:watchcancel(stream)
        end

        while true do
            reset_watch()
            skynet.sleep(500)
        end
    end)

    skynet.error(string.rep("-", 15).."test_etcd_watch   end"..string.rep("-", 15))
end

local Log = setmetatable({}, {__index = function(self, k) return function(...) skynet.error("[etcd "..k.."]", ...) end end})

skynet.start(function()
    test_etcd_watch()
end)


--[[


local Skynet = require "znet"
local Env = require "global"
local Command = require "command"
local EtcdClient = require "etcd_v3api"
local util = require "util"
local TimerObj = require "timer_obj"

local serverid = assert(Skynet.getenv("serverid"))
local login_port = assert(Skynet.getenv("login_port"))
local root = '/nodes'
local prefix = '/'
local etcd_ttl = 10									--etcd的TTL
local user = "root"
local password = "123456"

local function __init__()
    Skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = assert(Command[cmd], cmd)
        f(...)
    end)
    Skynet.register "etcd"

    --注册
    local hosts = {"127.0.0.1:2379",}
    local opts = {
        hosts = hosts,
        key_prefix = root,
        user = user,
        password = password,
    }
    Env.etcd_client = EtcdClient.new(opts)

    local grant = Env.etcd_client:grant(etcd_ttl, 0)
    local grant_id = grant.ID

    local node_data = {
		cid = serverid,
        login_port = login_port,
	}
    local attr = {
        lease = grant_id
    }
	Env.etcd_client:set(prefix..serverid, node_data, attr)

    --续约
    local time_interval = etcd_ttl/2-1
    Env.timers = TimerObj.new(time_interval)
    Env.timers:add_timer(time_interval, function()
        Env.etcd_client:keepalive(grant_id)
    end)
    Env.timers:start()

    --监听
    Skynet.fork(function ()
        local version
        local function reset_watch()
            local opts = {
                start_revision = version
            }
            local reader, stream = Env.etcd_client:watchdir(prefix, opts)
            if not reader then
                return false
            end
            while true do
                local data = reader()
                if not data then
                    break
                else
                    util.Table.print(data or {})
                    version = data.result.header.revision + 1
                end
            end
            --连接异常
            Env.etcd_client:watchcancel(stream)
        end

        while true do
            reset_watch()
            Skynet.sleep(500)
        end
    end)
end

Skynet.start(__init__)

]]