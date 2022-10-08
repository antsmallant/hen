local skynet = require "skynet.manager"
local cluster = require "skynet.cluster"
local json = require "cjson.safe"
local etcd_v3api = require "etcd.etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "skynet_util"

local command = {}
local g_servertype = assert(skynet.getenv("servertype"), "invalid servertype")
local g_clustercfg
local g_etcdcli


local function get_cluster_cfg()
    local cfg = {}
    cfg.ip = skynet.getenv("cluster_ip")
    if cfg.ip then
        cfg.ttl = assert(tonumber(skynet.getenv("cluster_ttl")), "invalid cluster_ttl")
        cfg.port = assert(tonumber(skynet.getenv("cluster_port")), "invalid cluster_port")
        cfg.listenip = skynet.getenv("cluster_listenip") or "0.0.0.0" --用于 listen 的 ip 可能会与 cluster_ip 一致，所以支持单独配置
    end
    return cfg
end

local function gen_etcd_kv()
    cfg.etcd_key = string.format("%s_%s_%s", servertype, cfg.ip, cfg.port)
    cfg.etcd_value = string.format("%s:%s", cfg.ip, cfg.port)    
end

local function get_etcd_cfg()
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

local function create_etcdcli()
    local cfg = get_etcd_cfg()
    cfg.serializer = "raw"
    cfg.key_prefix = "/cluster"
    local etcdcli = etcd_v3api.new(cfg)
    return etcdcli
end

local function reg_self(etcdcli, servertype, clustercfg)
    local lease

    local function do_reg()
        local grantres = etcdcli:grant(clustercfg.ttl)
        lease = grantres.ID
        skynet.error("reg_self grantres:", lua_util.tostring(grantres))        
        local cluster_key = string.format("/%s_%s_%s", servertype, clustercfg.ip, clustercfg.port)
        local cluster_value = string.format("%s:%s", clustercfg.ip, clustercfg.port)    
        local attr = {lease = lease}
        local setres = etcdcli:set(cluster_key, cluster_value, attr)
        skynet.error("reg_self setres:", lua_util.tostring(setres))        
    end

    --注册自己
    do_reg()


    --续约
    local function do_keepalive()
        local keepaliveres = etcdcli:keepalive(lease)
        skynet.error("reg_self keepaliveres:", lua_util.tostring(keepaliveres))

        if keepaliveres and keepaliveres.result and keepaliveres.result.TTL then
            --success
            skynet.error("reg_self keepalive suc, TTL:", keepaliveres.result.TTL)
            return keepaliveres.result.TTL
        else
            --fail
            skynet.error("reg_self keepalive fail, do_reg again")
            do_reg()           
        end
    end

    skynet.fork(function()
        local inv = math.ceil(clustercfg.ttl/2.0)
        while true do
            skynet.sleep(inv*100)
            local ok, ttl = xpcall(do_keepalive, skynet_util.handle_err)
            if ok and ttl then
                inv = math.ceil(ttl/2.0)
            else
                inv = math.ceil(clustercfg.ttl/2.0)
            end
        end
    end)
end

--拉取所有节点信息
local function fetch_cluster(etcdcli)
    local ret = etcdcli:readdir("/")
    skynet.error("fetch_cluster ret:", lua_util.tostring(ret))
    return ret and ret.header and ret.header.revision
end

--监听节点变化
local function watch_cluster(etcdcli, start_rev)
    skynet.fork(function ()
        local rev = start_rev
        local function reset_watch()
            skynet.error("reset_watch begin")
            local opts = {start_revision = rev}
            local reader, stream = etcdcli:watchdir("/", opts)
            if not reader then
                return false
            end
            while true do
                local data = reader()
                if not data then
                    break
                else
                    skynet.error("watch_cluster recv:", lua_util.tostring(data))
                    rev = data.result.header.revision + 1
                end
            end
            --连接异常
            etcdcli:watchcancel(stream)
            skynet.error("reset_watch end fail, cancel")
        end

        while true do
            reset_watch()
            skynet.sleep(5*100)
        end
    end)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		return assert(command[string.lower(cmd)])(...)
	end)

    g_clustercfg = get_cluster_cfg()

    --create etcd client
    g_etcdcli = create_etcdcli()
    if not g_etcdcli then
        error("create etcd conn fail")
    end

	--start as a cluster node
	if g_clustercfg.ip then
        assert(g_clustercfg.listenip and g_clustercfg.port, "cluster cfg invalid")
		local clusterd = skynet.uniqueservice("clusterd")
		skynet.call(clusterd, "lua", "listen", g_clustercfg.listenip, g_clustercfg.port)
		reg_self(g_etcdcli, g_servertype, g_clustercfg)
	end

    --fetch and watch cluster info
    skynet.fork(function ()
        local latest_rev = fetch_cluster(g_etcdcli)
        watch_cluster(g_etcdcli, latest_rev+1)
    end)

    skynet.register ".cluster_mgr"

    skynet.error("cluster_mgr started")
end)