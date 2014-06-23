local typecheck = require('typecheck')

local unm, add, sub, mul, div, eq

unm = typecheck('number', 'number') .. function(x, y)
	return -x, -y
end
add = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	return ax + bx, ay + by
end
sub = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	return ax - bx, ay - by
end
mul = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	return ax * bx, ay * by
end
div = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	return ax / bx, ay / by
end
eq = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	return ax == bx and ay == by
end

local angle, approxEqual, cross, distance, distanceSquared, dot, length, lengthSquared, normalized, projectedOnto, rotate

angle = typecheck('number', 'number') .. function(x, y)
	return math.atan2(y, x)
end
approxEqual = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	local x, y = sub(ax, ay, bx, by)
	return lengthSquared(x, y) < 0.00000001
end
cross = typecheck('number', 'number') .. function(x, y)
	return -y, x
end
distance = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	return length(sub(ax, ay, bx, by))
end
distanceSquared = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	return lengthSquared(sub(ax, ay, bx, by))
end
dot = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	return ax * bx + ay * by
end
length = typecheck('number', 'number') .. function(x, y)
	return math.sqrt(lengthSquared(x, y))
end
lengthSquared = typecheck('number', 'number') .. function(x, y)
	return dot(x, y, x, y)
end
normalized = typecheck('number', 'number') .. function(x, y)
	if x == 0 and y == 0 then
		return 0, 0
	else
		local invLen = 1 / length(x, y)
		return mul(x, y, invLen, invLen)
	end
end
projectedOnto = typecheck('number', 'number', 'number', 'number') .. function(ax, ay, bx, by)
	local factor = dot(ax, ay, bx, by) / lengthSquared(bx, by)
	return mul(bx, by, factor, factor)
end
rotate = typecheck('number', 'number', 'number') .. function(x, y, delta)
	local cs = math.cos(delta)
	local sn = math.sin(delta)

	return x * cs - y * sn, x * sn + y * cs
end

return {
	unm =            	unm,
	add =            	add,
	sub =            	sub,
	mul =            	mul,
	div =            	div,
	eq =             	eq,
	angle =          	angle,
	approxEqual =    	approxEqual,
	cross =          	cross,
	distance =       	distance,
	distanceSquared =	distanceSquared,
	dot =            	dot,
	length =         	length,
	lengthSquared =  	lengthSquared,
	normalized =     	normalized,
	projectedOnto =  	projectedOnto,
	rotate =         	rotate
}
