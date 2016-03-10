-- Returns a single function, `typecheck`, that acts as a decorator to add type
-- checking to other functions.
-- `typecheck`'s parameters are a list describing the types accepted by the
-- decorated function, and may be:
--   * A string of a Lua type, to match that type, or 'any', to match anything
--   * A function taking the value, argument position, and argument count, with
--     the last two provided for formatting errors, expecting the function to
--     return success, a description of the expected value, and a description of
--     the received value
--   * A table to check a set of the above two
--   * '*' or '+' in the last position to indicate 0-or-more or 1-or-more
--     repetition of the previous argument, respectively
-- For example:
--     local addAsNumber = typecheck('number', 'string') .. function(a, b)
--         return a + tonumber(b)
--     end
-- Obviously that is a bit trivial, but it becomes more useful when you want to
-- detect type errors at the edge of an API rather than in the middle of a call
-- `typecheck` is bootstrapped onto itself if you want to see an example of a
-- function to check arguments

-- Typechecking can be disabled into a no-op by setting TYPECHECK_DISABLE to a
-- truthy value. There will then be no overhead to function calls which are
-- otherwise decorated.
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

-- True if the argument is a value that `type(x)` can return for any x.
local is_lua_type = function(s)
    return s == 'boolean' or s == 'function' or s == 'nil' or s == 'number'
        or s == 'string' or s == 'table' or s == 'thread' or s == 'userdata'
end

local mt = {
    __concat = function(t, f)
        -- Wrap the function we just received
        return function(...)
            local nargs = select('#', ...)

            if t.rules[t.rules.n] == '*' then
                -- If the rule is a star, it can be zero or more of the last type, so subtract 2 for the star and last type
                if nargs < t.rules.n - 2 then
                    errors.bad_argument(nargs + 1, string.format('at least %d argument(s)', t.rules.n - 2), string.format('%d argument(s)', nargs))
                end
            elseif t.rules[t.rules.n] == '+' then
                -- If the rule is a plus, it can be one or more of the last type, so subtract 1 for the plus
                if nargs < t.rules.n - 1 then
                    errors.bad_argument(nargs + 1, string.format('at least %d argument(s)', t.rules.n - 1), string.format('%d argument(s)', nargs))
                end
            else
                -- The last rule is a regular one, so check both sides
                if nargs < t.rules.n then
                    -- If we have too few arguments, the error is on the argument we didn't provide
                    errors.bad_argument(nargs + 1, string.format('%d argument(s)', t.rules.n), string.format('%d argument(s)', nargs))
                elseif nargs > t.rules.n then
                    -- If we have too many argument, the error is on the argument after the last rule
                    errors.bad_argument(t.rules.n + 1, string.format('%d argument(s)', t.rules.n), string.format('%d argument(s)', nargs))
                end
            end

            -- We iterate the rules separately to allow repetition
            local current_rule = 1

            -- Iterate over the arguments we received in the wrapped call
            for i = 1, nargs do
                local arg = select(i, ...)
                local arg_type = type(arg)

                -- This goto is used for repetition at the end, allowing us to check the same argument by backing up and repeating a rule check
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
                        -- These exist only at the end, back up the rule we're looking at and repeat
                        current_rule = current_rule - 1
                        goto begin_check
                    elseif rule ~= 'any' then
                        -- If we don't allow anything,
                        if arg_type ~= rule then
                            -- Then it has to be a Lua type
                            errors.bad_argument(i, rule, arg_type)
                        end
                    end
                else --ty == 'table'
                    -- We'll build up a list of failed items to use in the case of everything failing
                    local passed = false
                    local expectations = {}

                    for j, subrule in ipairs(rule) do
                        -- The internal rules are pretty much like above, but this time as elements of the table,
                        -- so we'll iterate over those independently
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

            -- Everything passed, finally return the result of the function call
            return f(...)
        end
    end
}

return (function(f)
    -- `f` is the function which constructs rules tables for the validator

    -- Bootstrap typechecking onto these functions which are an API,
    -- had to wait
    mt.__concat = f('table', 'function') .. mt.__concat
    errors.bad_argument = f('number', 'string', 'string') .. errors.bad_argument

    -- Validates the arguments to typecheck
    local check = function(rule, i, nargs)
        local ty = type(rule)

        if ty == 'string' then
            if rule == '*' or rule == '+' then
                -- Repetition has to come at the end
                if i == 1 or i ~= nargs then
                    return false, 'repetition after arguments', 'it before'
                end
            elseif not is_lua_type(rule) and rule ~= 'any' then
                -- Or has to be a Lua type or any
                return false, 'lua type or repetition', rule
            end
        elseif ty == 'table' then
            if #rule < 1 then
                return false, 'table with 1 or more elements', 'table with 0 elements'
            end

            for j, subrule in ipairs(rule) do
                -- Tables act mostly like above, but no repetition since they're a set
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

        -- Everything passed
        return true
    end

    -- And now wrap the rules construction function (`typecheck`) itself
    return f(check, '*') .. f
end)(function(...)
    -- Construct the structure used by the verification function
    return setmetatable({
        rules = {n = select('#', ...), ...},
    }, mt)
end)
