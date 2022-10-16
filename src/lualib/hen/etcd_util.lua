local skynet = require "skynet"
local json = require "cjson.safe"
local etcd_v3api = require "etcd.etcd_v3api"


local _M = {}

local function get_etcd_cfg()
    local hosts = json.decode(skynet.getenv "etcd_hosts")
    local user = skynet.getenv "etcd_user"
    local password = skynet.getenv "etcd_password"
    assert(hosts, [[invalid etcd_hosts, check config please, config should looks like etcd_hosts = "[\"127.0.0.1:2379\"]"]])

    return {
        hosts = hosts,
        user = user,
        password = password,
        serializer = "raw",
    }
end
_M.get_etcd_cfg = get_etcd_cfg

function _M.create_etcdcli(key_prefix)
    local cfg = get_etcd_cfg()
    cfg.key_prefix = key_prefix
    local etcdcli = etcd_v3api.new(cfg)
    return etcdcli
end

return _M