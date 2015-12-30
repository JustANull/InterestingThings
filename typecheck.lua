if _G.TYPECHECK_DISABLE then
    local t = setmetatable({}, {
        __concat = function(t, f)
            return f
        end
    })

    return function()
        return t
    end
end

local errors = assert(require('errors'))

local lua_types = {
    ['boolean'] = true,
    ['function'] = true,
    ['nil'] = true,
    ['number'] = true,
    ['string'] = true,
    ['table'] = true,
    ['thread'] = true,
    ['userdata'] = true
}

local mt = {
    __concat = function(t, f)
        return function(...)
            local nargs = select('#', ...)

            if t.rules[t.rules.n] == '...' then
                if nargs < t.rules.n - 1 then
                    errors.bad_argument(nargs + 1, string.format('at least %d argument(s)', t.rules.n - 1), string.format('%d argument(s)', nargs))
                end
            else
                if nargs < t.rules.n then
                    errors.bad_argument(nargs + 1, string.format('%d argument(s)', t.rules.n), string.format('%d argument(s)', nargs))
                end
            end

            local current_rule = 1

            for i = 1, nargs do
                local arg = select(i, ...)
                local arg_type = type(arg)

                ::begin_check::

                local rule = t.rules[current_rule]

                if rule == nil then
                    errors.bad_argument(i, string.format('%d argument(s)', current_rule - 1), string.format('%d argument(s)', nargs))
                end

                if type(rule) == 'function' then
                    local success, expected, got = rule(arg)

                    if not success then
                        errors.bad_argument(i, expected, got)
                    end
                elseif type(rule) == 'string' then
                    if rule == '...' then
                        current_rule = current_rule - 1
                        goto begin_check
                    elseif rule ~= 'any' then
                        if arg_type ~= rule then
                            errors.bad_argument(i, rule, arg_type)
                        end
                    end
                else --type(rule) == 'table'
                    local passed = false
                    local expectations = {}

                    for j, subrule in ipairs(rule) do
                        if type(subrule) == 'function' then
                            local success, expected, got = subrule(arg)

                            if success then
                                passed = true
                                break
                            else
                                expectations[j] = expected
                            end
                        else --type(subrule) == 'string'
                            if arg_type == subrule then
                                passed = true
                                break
                            else
                                expectations[j] = subrule
                            end
                        end
                    end

                    if not passed then
                        errors.bad_argument(i, table.concat(expectations, ' or '), arg_type)
                    end
                end

                current_rule = current_rule + 1
            end

            return f(...)
        end
    end
}

return (function(f)
    mt.__concat = f('table', 'function') .. mt.__concat
    return f({'function', 'string', 'table'}, '...') .. f
end)(function(...)
    local rules = {n = select('#', ...), ...}

    for i, rule in ipairs(rules) do
        if type(rule) == 'function' then
            --We can only assume their function is conformant.
        elseif type(rule) == 'string' then
            if rule == '...' then
                if i == 1 or i ~= rules.n then
                    errors.bad_argument(i, '... after arguments', 'it before')
                end
            elseif not lua_types[rule] and rule ~= 'any' then
                errors.bad_argument(i, 'lua type', rule)
            end
        else --type(rule) == 'table'
            if #rule < 1 then
                errors.bad_argument(i, 'table with 1 or more elements', string.format('table with %d element(s)', #rule))
            end

            for j, check in ipairs(rule) do
                if type(check) == 'function' then
                    --As above, we can only assume they programmed correctly.
                elseif type(check) == 'string' then
                    if not lua_types[check] then
                        errors.bad_argument(i, string.format('lua type at index %d', j), check)
                    end
                else --type(check) is something we don't want...
                    errors.bad_argument(i, string.format('function or string at index %d', j), type(check))
                end
            end
        end
    end

    return setmetatable({
        rules = rules,
    }, mt)
end)
