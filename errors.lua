local debug = assert(require('debug'))

return {
    -- errors in a way that looks like Lua does it
    bad_argument = function(number, expected, got)
        local funcName = debug.getinfo(2, 'n').name

        -- Error not inside the caller, but one level up, as a bad argument is
        -- the fault of the function that called the caller
        if funcName then
            error(string.format('bad argument #%d to \'%s\' (%s expected, got %s)', number, funcName, expected, got), 3)
        else
            error(string.format('bad argument #%d to function (%s expected, got %s)', number, expected, got), 3)
        end
    end
}
