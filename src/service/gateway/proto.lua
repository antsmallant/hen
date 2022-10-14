local sprotoparser = require "sprotoparser"

local proto = {}
local protodir = "../../proto/"
local c2s_path = protodir .. "c2s.gateway.sproto"
local s2c_path = protodir .. "s2c.gateway.sproto"

proto.c2s = sprotoparser.parse(io.open(c2s_path):read("*a"))
proto.s2c = sprotoparser.parse(io.open(s2c_path):read("*a"))

return proto
