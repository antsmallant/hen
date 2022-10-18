local skynet = require "skynet"

local prefix = "mysql_"
local dbs = {"gamedb"}
local _M = {}

for _, db in ipairs(dbs) do
    local realname = assert(skynet.getenv(prefix..db), db)
    _M[db] = realname
end

return _M