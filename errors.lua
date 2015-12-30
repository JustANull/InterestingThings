local debug = assert(require('debug'))

return {
    bad_argument = function(number, expected, got)
        local funcName = debug.getinfo(2, 'n').name

        if funcName then
            error(string.format('bad argument #%d to \'%s\' (%s expected, got %s)', number, funcName, expected, got), 3)
        else
            error(string.format('bad argument #%d to function (%s expected, got %s)', number, expected, got), 3)
        end
    end
}
