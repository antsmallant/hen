local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local etcdcli = require "etcd.etcd_v3api"
local lua_util = require "lua_util"
local skynet_util = require "skynet_util"
local lfs = require"lfs"

local function attrdir (path)
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..'/'..file
            print ("\t "..f)
            local attr = lfs.attributes (f)
            assert (type(attr) == "table")
            if attr.mode == "directory" then
                attrdir (f)
            else
                for name, value in pairs(attr) do
                    print (name, value)
                end
            end
        end
    end
end

skynet.start(function()
    attrdir(".")
end)

