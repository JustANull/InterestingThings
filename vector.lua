local typecheck = assert(require('typecheck'))
local vector = assert(require('vector-light'))

local Vector
local mt = {}

local isVector = function(arg)
	return getmetatable(arg) == mt, 'vector', type(arg)
end

mt.__index = {
	angle = typecheck(isVector) .. function(self)
		return vector.angle(self.x, self.y)
	end,
	approxEqual = typecheck(isVector, isVector) .. function(self, other)
		return vector.approxEqual(self.x, self.y, other.x, other.y)
	end,
	components = typecheck(isVector) .. function(self)
		return self.x, self.y
	end,
	cross = typecheck(isVector) .. function(self)
		return Vector(vector.cross(self.x, self.y))
	end,
	distance = typecheck(isVector, isVector) .. function(self, other)
		return vector.distance(self.x, self.y, other.x, other.y)
	end,
	distanceSquared = typecheck(isVector, isVector) .. function(self, other)
		return vector.distanceSquared(self.x, self.y, other.x, other.y)
	end,
	dot = typecheck(isVector, isVector) .. function(self, other)
		return vector.dot(self.x, self.y, other.x, other.y)
	end,
	length = typecheck(isVector) .. function(self)
		return vector.length(self.x, self.y)
	end,
	lengthSquared = typecheck(isVector) .. function(self)
		return vector.lengthSquared(self.x, self.y)
	end,
	normalized = typecheck(isVector) .. function(self)
		return Vector(vector.normalized(self.x, self.y))
	end,
	projectedOnto = typecheck(isVector, isVector) .. function(self, other)
		return Vector(vector.projectedOnto(self.x, self.y, other.x, other.y))
	end,
	rotate = typecheck(isVector, 'number') .. function(self, angle)
		return Vector(vector.rotate(self.x, self.y, angle))
	end
}
--For some reason, Lua also gives us a second arg...
mt.__unm = typecheck(isVector, isVector) .. function(self)
	return Vector(vector.unm(self.x, self.y))
end
mt.__add = typecheck({isVector, 'number'}, {isVector, 'number'}) .. function(self, other)
	if isVector(self) then
		if isVector(other) then
			return Vector(vector.add(self.x, self.y, other.x, other.y))
		end

		return Vector(vector.add(self.x, self.y, b, other))
	end

	return Vector(vector.add(self, self, other.x, other.y))
end
mt.__sub = typecheck({isVector, 'number'}, {isVector, 'number'}) .. function(self, other)
	if isVector(self) then
		if isVector(other) then
			return Vector(vector.sub(self.x, self.y, other.x, other.y))
		end

		return Vector(vector.sub(self.x, self.y, b, other))
	end

	return Vector(vector.sub(self, self, other.x, other.y))
end
mt.__mul = typecheck({isVector, 'number'}, {isVector, 'number'}) .. function(self, other)
	if isVector(self) then
		if isVector(other) then
			return Vector(vector.mul(self.x, self.y, other.x, other.y))
		end

		return Vector(vector.mul(self.x, self.y, b, other))
	end

	return Vector(vector.mul(self, self, other.x, other.y))
end
mt.__div = typecheck({isVector, 'number'}, {isVector, 'number'}) .. function(self, other)
	if isVector(self) then
		if isVector(other) then
			return Vector(vector.div(self.x, self.y, other.x, other.y))
		end

		return Vector(vector.div(self.x, self.y, b, other))
	end

	return Vector(vector.div(self, self, other.x, other.y))
end
mt.__eq = typecheck({isVector, 'number'}, {isVector, 'number'}) .. function(self, other)
	if isVector(self) then
		if isVector(other) then
			return vector.eq(self.x, self.y, other.x, other.y)
		end

		return vector.eq(self.x, self.y, b, other)
	end

	return vector.eq(self, self, other.x, other.y)
end
mt.__tostring = typecheck(isVector) .. function(self)
	return string.format('<%.4f, %.4f>', self.x, self.y)
end

Vector = setmetatable({
	new = typecheck('table', 'number', 'number') .. function(self, x, y)
		return setmetatable({
			x = x or 0,
			y = y or 0
		}, mt)
	end,
	isVector = function(_, arg)
		return isVector(arg)
	end
}, {
	__call = typecheck('table', 'number', 'number') .. function(self, x, y)
		return self:new(x, y)
	end
})

return Vector
