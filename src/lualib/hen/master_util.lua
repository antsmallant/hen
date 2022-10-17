local skynet = require "skynet"
local etcd_util = require "hen.etcd_util"
local typeof = require "etcd.typeof"
local logger = require "hen.logger"
local cluster_util = require "hen.cluster_util"
local skynet_util = require "hen.skynet_util"
require "luaext"

local _M = {}
local _mt = {}
local k_key_prefix = "/master"
local k_key_sep = "/"
local k_master_ttl = assert(tonumber(skynet.getenv "master_ttl"))

assert(k_master_ttl > 0, tostring(k_master_ttl))

function _mt:run()
    if self.is_running then return end
    self.is_running = true

    local etcdcli = etcd_util.create_etcdcli(k_key_prefix)
    if not etcdcli then
        error("create etcdcli fail")
    end
    self.etcdcli = etcdcli


    local function master_keepalive()
        assert(self.is_master)
        assert(self.lease)

        local res = etcdcli:keepalive(self.lease)

        if res and res.result and res.result.TTL then
            logger.info("master_keepalive suc, lease:%s, TTL:%s",
                self.lease, res.result.TTL)
            return res.result.TTL
        else
            logger.info("master_keepalive fail, lease:%s, res:%s",
                self.lease, tostring(res))
            self.is_master = false
            self.lease = nil
            skynet.fork(self.handler.retire)
        end
    end

    local function try_2_be_master()
        local grantres = etcdcli:grant(k_master_ttl)
        local lease = grantres and grantres.ID
        if not lease then
            error(string.format("try_2_be_master fail get nil lease, grantres:%s",
                tostring(grantres)))
        end
        local opts = {}
        local etcd_key = k_key_sep..self.master_key
        local etcd_val = self.master_val
        local setres = etcdcli:setnx(etcd_key, etcd_val, lease, opts)
        logger.info("try_2_be_master, lease:%s, setres: %s", lease, tostring(setres))
        if setres and setres.succeeded == true then
            logger.info("become master")
            self.is_master = true
            self.lease = lease
            skynet.fork(self.handler.become)
        end
    end

    local function cycle()
        if self.is_master then
            master_keepalive()
        else
            try_2_be_master()
        end
    end

    skynet.fork(function()
        while true do
            xpcall(cycle, skynet_util.handle_err)
            local sleep_inv = math.ceil(k_master_ttl/3.0)
            skynet.sleep(5*100)
        end
    end)
end

function _mt:is_master()
    return self.is_master
end

function _M.new(master_key, master_val, handler)
    assert(master_key)
    assert(typeof.table(handler))

    local obj = {
        master_key = master_key,
        master_val = master_val,
        handler = handler,
        is_master = false,
        is_running = false,
    }
    return setmetatable(obj, {__index = _mt})
end

return _M