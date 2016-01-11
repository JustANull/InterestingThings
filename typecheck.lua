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

local is_lua_type = function(s)
    return s == 'boolean' or s == 'function' or s == 'nil' or s == 'number'
        or s == 'string' or s == 'table' or s == 'thread' or s == 'userdata'
end

local mt = {
    __concat = function(t, f)
        return function(...)
            local nargs = select('#', ...)

            if t.rules[t.rules.n] == '*' then
                if nargs < t.rules.n - 2 then
                    errors.bad_argument(nargs + 1, string.format('at least %d argument(s)', t.rules.n - 2), string.format('%d argument(s)', nargs))
                end
            elseif t.rules[t.rules.n] == '+' then
                if nargs < t.rules.n - 1 then
                    errors.bad_argument(nargs + 1, string.format('at least %d argument(s)', t.rules.n - 1), string.format('%d argument(s)', nargs))
                end
            else
                if nargs < t.rules.n then
                    errors.bad_argument(nargs + 1, string.format('%d argument(s)', t.rules.n), string.format('%d argument(s)', nargs))
                elseif nargs > t.rules.n then
                    errors.bad_argument(t.rules.n + 1, string.format('%d argument(s)', t.rules.n), string.format('%d argument(s)', nargs))
                end
            end

            local current_rule = 1

            for i = 1, nargs do
                local arg = select(i, ...)
                local arg_type = type(arg)

                ::begin_check::

                local rule = t.rules[current_rule]
                local ty = type(rule)

                if ty == 'function' then
                    local success, expected, got = rule(arg, i, nargs)

                    if not success then
                        errors.bad_argument(i, expected, got)
                    end
                elseif ty == 'string' then
                    if rule == '*' or rule == '+' then
                        current_rule = current_rule - 1
                        goto begin_check
                    elseif rule ~= 'any' then
                        if arg_type ~= rule then
                            errors.bad_argument(i, rule, arg_type)
                        end
                    end
                else --ty == 'table'
                    local passed = false
                    local expectations = {}

                    for j, subrule in ipairs(rule) do
                        if type(subrule) == 'function' then
                            local success, expected = subrule(arg, i, nargs)

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

    local check = function(rule, i, nargs)
        local ty = type(rule)

        if ty == 'string' then
            if rule == '*' or rule == '+' then
                if i == 1 or i ~= nargs then
                    return false, 'repetition after arguments', 'it before'
                end
            elseif not is_lua_type(rule) and rule ~= 'any' then
                return false, 'lua type or repetition', rule
            end
        elseif ty == 'table' then
            if #rule < 1 then
                return false, 'table with 1 or more elements', 'table with 0 elements'
            end

            for j, subrule in ipairs(rule) do

                local ty = type(subrule)
                if ty == 'string' then
                    if not is_lua_type(subrule) then
                        return false, string.format('lua type at index %d', j), subrule
                    end
                elseif ty ~= 'function' then
                    return false, string.format('function or string at index %d', j), ty
                end
            end
        elseif ty ~= 'function' then
            return false, 'function or string or table', ty
        end

        return true
    end

    return f(check, '*') .. f
end)(function(...)
    return setmetatable({
        rules = {n = select('#', ...), ...},
    }, mt)
end)
