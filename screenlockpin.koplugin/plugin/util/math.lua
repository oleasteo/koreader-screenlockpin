local function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

local function isOutside(pos, rect)
    return pos.x < rect.x or pos.x > rect.x + rect.w or
            pos.y < rect.y or pos.y > rect.y + rect.h
end

return {
    clamp = clamp,
    isOutside = isOutside,
}
