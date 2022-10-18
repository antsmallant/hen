local sprotoparser = require "sprotoparser"

local proto = {}
local protodir = "../../proto/"
local c2s_plaza = protodir .. "c2s.plaza.sproto"
local s2c_plaza = protodir .. "s2c.plaza.sproto"

--game proto
local game_protodir = "../../../assets/src/games/"
local c2s_chatting = game_protodir .. "chatting/proto/c2s.chatting.sproto"
local s2c_chatting = game_protodir .. "chatting/proto/s2c.chatting.sproto"


proto.c2s_plaza = sprotoparser.parse(io.open(c2s_plaza):read("*a"))
proto.s2c_plaza = sprotoparser.parse(io.open(s2c_plaza):read("*a"))
proto.c2s_chatting = sprotoparser.parse(io.open(c2s_chatting):read("*a"))
proto.s2c_chatting = sprotoparser.parse(io.open(s2c_chatting):read("*a"))

return proto
