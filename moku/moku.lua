local M = {}

--o  Local Variables  o--

local null = 0
local border = -1

-- Add a conversion table that accounts
-- for smaller spritesheets, without
-- symmetric tiles.

local id_conversions = {
    [2] = 1,
    [8] = 2,
    [10] = 3,
    [11] = 4,
    [16] = 5,
    [18] = 6,
    [22] = 7,
    [24] = 8,
    [26] = 9,
    [27] = 10,
    [30] = 11,
    [31] = 12,
    [64] = 13,
    [66] = 14,
    [72] = 15,
    [74] = 16,
    [75] = 17,
    [80] = 18,
    [82] = 19,
    [86] = 20,
    [88] = 21,
    [90] = 22,
    [91] = 23,
    [94] = 24,
    [95] = 25,
    [104] = 26,
    [106] = 27,
    [107] = 28,
    [120] = 29,
    [122] = 30,
    [123] = 31,
    [126] = 32,
    [127] = 33,
    [208] = 34,
    [210] = 35,
    [214] = 36,
    [216] = 37,
    [218] = 38,
    [219] = 39,
    [222] = 40,
    [223] = 41,
    [248] = 42,
    [250] = 43,
    [251] = 44,
    [254] = 45,
    [255] = 46,
    [0] = 47
}

--o  Module Variables  o--

M.layer_name = "layer1"

--o  Enums  o--

M.dir = {
    NORTH = 1,
    NORTH_EAST = 2,
    EAST = 3,
    SOUTH_EAST = 4,
    SOUTH = 5,
    SOUTH_WEST = 6,
    WEST = 7,
    NORTH_WEST = 8
}

M.bits = {
    FOUR = 4,
    EIGHT = 8
}

--o  Forward Declarations  o--

local constructor_helper
local binary_sum_8bit
local binary_sum_4bit
local get_type

--o=================o
--o  Constructors
--o=================o

function M.new(width, height, tile_width, tile_height, tile_types, fill_type, tilemap_url)

    local new_map = {}

    for x = 1, width do
        table.insert(new_map, {})
        for y = 1, height do
            table.insert(new_map[x], fill_type)
        end
    end

    constructor_helper(new_map, 1, 1, width, height, tile_width, tile_height, tile_types, tilemap_url)

    return new_map

end

function M.new_from_tilemap(tilemap_url, tile_width, tile_height, tile_types)

    local _x, _y, width, height = tilemap.get_bounds(tilemap_url)

    local new_map = {}

    for x = _x, _x + width - 1 do
        new_map[x] = {}
        for y = _y, _y + height - 1 do
            new_map[x][y] = tilemap.get_tile(tilemap_url, M.layer_name, x, y)
        end
    end

    constructor_helper(new_map, _x, _y, width, height, tile_width, tile_height, tile_types, tilemap_url)

    return new_map

end

--o  Constructor Locals  o--

function constructor_helper(new_map, x, y, width, height, tile_width, tile_height, tile_types, tilemap_url)

    local world_width = width * tile_width
    local world_height = height * tile_height

    new_map.tile_types = tile_types
    new_map.auto_tiles = {}
    new_map.tilemap_url = tilemap_url

    new_map.bounds = {
        x = x,
        y = y,
        width = width,
        height = height
    }

    new_map.dimensions = {
        tile_width = tile_width,
        tile_height = tile_height,
        world_width = world_width,
        world_height = world_height,
    }

end

--o=========================o
--o  Iterator Functions
--o=========================o


function M.iterate_region(map, x, y, width, height, fn)

    local _v

    return coroutine.wrap(
        function()
            for _x = x, x + width - 1 do
                for _y = y, y + height - 1 do

                    if map[_x] and map[_x][_y] then

                        _v = map[_x][_y]
                        if fn and fn(_v) or not fn then
                            coroutine.yield(_x, _y, _v)
                        end

                    end

                end
            end
        end
    )
end

function M.iterate(map, fn)
    return M.iterate_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height, fn)
end

function M.iterate_surrounding(map, x, y, fn)
    return M.iterate_region(map, x - 1, y - 1, 3, 3, fn)
end

--o=========================o
--o  General Map Functions
--o=========================o

function M.within_bounds(map, x, y)
    return x >= map.bounds.x and x < map.bounds.x + map.bounds.width
    and y >= map.bounds.y and y < map.bounds.y + map.bounds.height
end

function M.on_border(map, x, y)
    return x == map.bounds.x or x == map.bounds.x + map.bounds.width - 1
    or y == map.bounds.y or y == map.bounds.y + map.bounds.height - 1
end

function M.within_dimensions(map, map_world_x, map_world_y, test_world_x, test_world_y)

    local map_shift_x = map_world_x + (map.bounds.x - 1) * map.dimensions.tile_width
    local map_shift_y = map_world_y + (map.bounds.y - 1) * map.dimensions.tile_height

    return test_world_x >= map_shift_x and test_world_x < map_shift_x + map.dimensions.world_width
    and test_world_y >= map_shift_y and test_world_y < map_shift_y + map.dimensions.world_height

end

function M.neighbor_coords(x, y, dir)

    if dir == M.dir.NORTH then
        y = y + 1
    elseif dir == M.dir.NORTH_EAST then
        x = x + 1
        y = y + 1
    elseif dir == M.dir.EAST then
        x = x + 1
    elseif dir == M.dir.SOUTH_EAST then
        x = x + 1
        y = y - 1
    elseif dir == M.dir.SOUTH then
        y = y - 1
    elseif dir == M.dir.SOUTH_WEST then
        x = x - 1
        y = y - 1
    elseif dir == M.dir.WEST then
        x = x - 1
    elseif dir == M.dir.NORTH_WEST then
        x = x - 1
        y = y + 1
    end

    return x, y

end

--[[ Dont just copy over code from other projects without testing ;)
function M.all_neighbor_coords(x, y)

    local nc = {}

    for i = 1, 8 do
        nc[i] = M.neighbor_coords(x, y, i)
    end

    return nc

end

function M.neighbor_value(map, x, y, dir)

    local nc = M.neighbor_coords(x, y, dir)

    if M.within_bounds(map, nc.x, nc.y) then
        return map[nc.x][nc.y]
    else return nil
    end

end

function M.all_neighbor_values(map, x, y)

    local nv = {}

    for i = 1, 8 do
        nv[i] = M.neighbor_value(map, x, y, i)
    end

    return nv

end
--]]

--o====================o
--o  Picking Functions
--o====================o

function M.pick_cell(map, map_world_x, map_world_y, pick_world_x, pick_world_y)

    if M.within_dimensions(map, map_world_x, map_world_y, pick_world_x, pick_world_y) then
        pick_world_x = pick_world_x - map_world_x
        pick_world_y = pick_world_y - map_world_y
        local tile_x = math.floor(pick_world_x / map.dimensions.tile_width + 1)
        local tile_y = math.floor(pick_world_y / map.dimensions.tile_height + 1)
        return tile_x, tile_y
    else
        return
    end

end

--o=================o
--o  Auto-tiling
--o=================o

function M.add_auto_tile(map, tile_type, bits, include_self, include_border, include_nil, additional_types)

    map.auto_tiles[tile_type] = {}

    map.auto_tiles[tile_type].bits = bits

    if include_self then
        map.auto_tiles[tile_type][tile_type] = true
    end

    if include_border then
        map.auto_tiles[tile_type][border] = true
    end

    if include_nil then
        map.auto_tiles[tile_type][null] = true
    end

    if additional_types then
        for i, v in ipairs(additional_types) do
            map.auto_tiles[tile_type][v] = true
        end
    end

end

function M.tile_sum(map, x, y)

    -- Tile type of this cell
    local tile_type = map[x][y]

    -- References the appropriate lookup table
    -- or returns null (0) if not a tilable type
    local lookup
    if map.auto_tiles[tile_type] then
        lookup = map.auto_tiles[tile_type]
    else
        return null
    end

    local bits = lookup.bits
    local sum

    if bits == 4 then
        sum = binary_sum_4bit(map, x, y, tile_type, lookup)
    elseif bits == 8 then
        sum = binary_sum_8bit(map, x, y, tile_type, lookup)
    end

    -- Return sum
    return sum

end

function M.auto_tile_cell(map, x, y)

    local sum = M.tile_sum(map, x, y)
    tilemap.set_tile(map.tilemap_url, M.layer_name, x, y, sum)

    return sum

end

function M.auto_tile_region(map, x, y, width, height)

    for _x, _y, _v in M.iterate(map) do
        if map.auto_tiles[_v] then
            M.auto_tile_cell(map, _x, _y)
        end
    end

end

function M.auto_tile_map(map)
    return M.auto_tile_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height)
end

function M.auto_tile_surrounding(map, x, y)
    return M.auto_tile_region(map, x - 1, y - 1, 3, 3)
end

function M.tiling_matrix_region(map, x, y, width, height)

    local tiling_matrix = {}

    for _x, _y, _v in M.iterate(map) do

        if tiling_matrix[_x] == nil then
            tiling_matrix[_x] = {}
        end

        if map.auto_tiles[_v] then
            tiling_matrix[_x][_y] = M.tile_sum(map, _x, _y)
        else
            tiling_matrix[_x][_y] = null
        end

    end

    return tiling_matrix

end

function M.tiling_matrix_map(map)
    return M.tiling_matrix_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height)
end

function M.tiling_matrix_surrounding(map, x, y)
    return M.tiling_matrix_region(map, x - 1, y - 1, 3, 3)
end

--o  Autotile Locals  o--

function binary_sum_4bit(map, x, y, tile_type, lookup)

    local n = get_type(map, x, y + 1)
    local w = get_type(map, x - 1, y)
    local e = get_type(map, x + 1, y)
    local s = get_type(map, x, y - 1)

    local sum = 0

    if lookup[n] == true then
        sum = sum + 1
    end

    if lookup[w] == true then
        sum = sum + 2
    end

    if lookup[e] == true then
        sum = sum + 4
    end

    if lookup[s] == true then
        sum = sum + 8
    end

    return sum + tile_type

end

function binary_sum_8bit(map, x, y, tile_type, lookup)

    local nw = get_type(map, x - 1, y + 1 )
    local n = get_type(map, x, y + 1)
    local ne = get_type(map, x + 1, y + 1)
    local e = get_type(map, x + 1, y)
    local se = get_type(map, x + 1, y - 1)
    local s = get_type(map, x, y - 1)
    local sw = get_type(map, x - 1, y - 1)
    local w = get_type(map, x - 1, y)

    local sum = 0

    if lookup[nw] == true then
        if lookup[n] == true and lookup[w] == true then
            sum = sum + 1
        end
    end

    if lookup[n] == true then
        sum = sum + 2
    end

    if lookup[ne] == true then
        if lookup[n] == true and lookup[e] == true then
            sum = sum + 4
        end
    end

    if lookup[w] == true then
        sum = sum + 8
    end

    if lookup[e] == true then
        sum = sum + 16
    end

    if lookup[sw] == true then
        if lookup[s] == true and lookup[w] == true then
            sum = sum + 32
        end
    end

    if lookup[s] == true then
        sum = sum + 64
    end

    if lookup[se] == true then
        if lookup[s] == true and lookup[e] == true then
            sum = sum + 128
        end
    end

    -- Convert binary sum and add the tile types index.
    -- This allows for multiple tilable types on the same
    -- tile source, as long as the following 47 tiles are
    -- correctly ordered. There is a hidden +1 here as well
    -- since lua.
    -- converted_sum = (id_conversions[sum] + 1) + (tile_type - 1)
    return id_conversions[sum] + tile_type

end

function get_type(map, _x, _y)
    if M.within_bounds(map, _x, _y) and map[_x][_y] then
        return map[_x][_y]
    else
        return border
    end
end

return M
