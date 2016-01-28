local
    assert, ipairs, loadstring, math_floor, pairs, pcall, string_dump, string_format, string_match, table_concat, tostring, type =
    assert, ipairs, loadstring, math.floor, pairs, pcall, string.dump, string.format, string.match, table.concat, tostring, type

local genName = nil
do
    local buffer = {'_.'}
    local symbols = {'_', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'}
    local symbolsSize = #symbols
    genName = function(n)
        local buffern = 2

        while n >= 0 do
            buffer[buffern] = symbols[(n % symbolsSize) + 1]
            buffern = buffern + 1
            n = math_floor(n / symbolsSize) - 1
        end

        return table_concat(buffer)
    end
end

local genSymbol, genSymbolReset = nil, nil
do
    local symbol = -1
    genSymbol = function()
        symbol = symbol + 1
        return genName(symbol)
    end
    genSymbolReset = function()
        symbol = -1
    end
end

local simpleReference = function(ref)
    return type(ref) == 'string' and string_match(ref, '^"([%a_][%w_]*)"$')
end

local dumpFuncs = {}
for i, v in ipairs({'_G', 'coroutine', 'debug', 'io', 'math', 'os', 'package', 'string', 'table'}) do
    if _G[v] then
        for k, v2 in pairs(_G[v]) do
            if type(v2) == 'function' and not pcall(string_dump, v2) then
                local reference = string_format('%q', tostring(k))
                local simple = simpleReference(reference)

                if simple then
                    dumpFuncs[v2] = v .. '.' .. simple
                else
                    dumpFuncs[v2] = v .. '[' .. reference .. ']'
                end
            end
        end
    end
end

local dump = nil
dump = function(given, seen, data)
    local type = type(data)

    if type == 'boolean' then
        return data and 'true' or 'false'
    elseif type == 'function' then
        if seen[data] then
            return seen[data]
        end

        local name = genSymbol()
        seen[data] = name
        local representation = string_format('%s=%s;', name, given[data] or string_format('loadstring(%q)', string_dump(data)))
        return name, representation
    elseif type == 'nil' then
        return 'nil'
    elseif type == 'number' then
        return tostring(data)
    elseif type == 'string' then
        return string_format('%q', data)
    elseif type == 'table' then
        if seen[data] then
            return seen[data]
        end

        local name = genSymbol()
        seen[data] = name
        local buffer, idx = {name, '={}'}, 3

        for k, v in pairs(data) do
            local keyReference, keyRepresentation = dump(given, seen, k)
            local valReference, valRepresentation = dump(given, seen, v)
            local simpleKey = simpleReference(keyReference)

            if keyRepresentation then
                buffer[idx] = keyRepresentation
                idx = idx + 1
            end
            if valRepresentation then
                buffer[idx] = valRepresentation
                idx = idx + 1
            end

            buffer[idx] = name

            if simpleKey then
                buffer[idx + 1] = '.'
                buffer[idx + 2] = simpleKey
                buffer[idx + 3] = '='
            else
                buffer[idx + 1] = '['
                buffer[idx + 2] = keyReference
                buffer[idx + 3] = ']='
            end

            buffer[idx + 4] = valReference
            buffer[idx + 5] = ';'
            idx = idx + 6
        end

        return name, table_concat(buffer)
    else
        error('unable to serialize ' .. type)
    end
end

return {
    deserialize = function(data)
        return assert(loadstring(data))()
    end,
    serialize = function(data, given)
        genSymbolReset()
        local reference, representation = dump(given or dumpFuncs, {}, data)

        if representation then
            return string_format('local _={}%sreturn %s', representation, reference)
        end

        return string_format('return %s', reference)
    end
}
