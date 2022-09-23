local _M = {}

--var_tostring copy from https://raw.githubusercontent.com/tianve/lua-tostring/main/tostring.lua
local var_tostring
var_tostring = function(var, tab)
    tab = tab or ""

    local t = type(var)
    if t == "string" then
        return string.format("%q", var)
    elseif t == "number" then
        return tostring(var)
    elseif t == "boolean" then
        return var and "true" or "false"
    elseif t == "table" then
        local keys = {}
        for k,v in pairs(var) do
            table.insert(keys, k)
        end
        table.sort(keys)

        local strs = {"{\n"}
        for i,k in ipairs(keys) do
            table.insert(strs, tab)
            table.insert(strs, "    [")

            local tt = type(k)
            if tt == "string" then
                table.insert(strs, string.format("%q", k))
            elseif tt == "number" then
                table.insert(strs, k)
            else
                --k not supported
                table.insert(strs, string.format("%q", tostring(k)))
            end
            table.insert(strs, "] = ")
            table.insert(strs, var_tostring(var[k], tab.."    "))
            table.insert(strs, ",\n")
        end
        table.insert(strs, tab)
        table.insert(strs, "}")
        return table.concat(strs)
    elseif t == "nil" then
        return "nil"
    else
        return t
    end
end






_M.tostring = var_tostring

return _M