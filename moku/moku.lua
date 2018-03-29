--- Moku Module
--@module Moku

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

--o=========================================o

--- Constructors.
-- Functions for creating new moku maps
-- @section Constructors

--o=========================================o


--- Returns a new moku map from scratch.
-- @tparam number width Width in cells
-- @tparam number height Height in cells
-- @tparam number tile_width Pixel width of your tiles
-- @tparam number tile_height Pixel height of your tiles
-- @tparam table tile_types A table of tile types
-- @tparam number fill_type Initial tile type of new cells
-- @tparam[opt] url tilemap_url Tilemap url
-- @return A new moku map
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

--- Builds and returns a new moku map from a supplied defold tilemap.
-- @tparam url tilemap_url Tilemap url
-- @tparam number tile_width Pixel width of your tiles
-- @tparam number tile_height Pixel height of your tiles
-- @tparam table tile_types A table of tile types
-- @return A new moku map
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
    new_map.autotiles = {}
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

--o=========================================o

--- Iterators.
-- Iterator functions
-- @section Iterators

--o=========================================o

--- Iterates through all moku map cells.
-- An optional filter function can be applied
-- @tparam map map A moku map
-- @tparam[opt] function fn Filter function
function M.iterate_map(map, fn)
    return M.iterate_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height, fn)
end

--- Iterates through a rectangular region of a moku maps cells.
-- An optional filter function can be applied
-- @tparam map map A moku map
-- @tparam number x Lower left x coordinate of region
-- @tparam number y Lower left y coordinate of region
-- @tparam number width Width of the region
-- @tparam number height Height of the region
-- @tparam[opt] function fn Filter function
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

--- Iterates through a given cell and its surrounding cells.
-- An optional filter function can be applied
-- @tparam map map A moku map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
-- @tparam[opt] function fn Filter function
function M.iterate_surrounding(map, x, y, fn)
    return M.iterate_region(map, x - 1, y - 1, 3, 3, fn)
end

--o=========================================o

--- General.
-- Assorted moku map functions
-- @section General

--o=========================================o

--- Return whether or not a given cell is within the map bounds.
-- @tparam map map A moku map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
-- @return True if in bounds, false otherwise
function M.within_bounds(map, x, y)
    return x >= map.bounds.x and x < map.bounds.x + map.bounds.width
    and y >= map.bounds.y and y < map.bounds.y + map.bounds.height
end


--- Return whether or not a given cell is a border cell
-- @tparam map map A moku map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
-- @return True if on border, false otherwise
function M.on_border(map, x, y)
    return x == map.bounds.x or x == map.bounds.x + map.bounds.width - 1
    or y == map.bounds.y or y == map.bounds.y + map.bounds.height - 1
end


--- Return whether or not some world coordinate is within the world dimensions of the map.
-- @tparam map map A moku map
-- @tparam number map_world_x World x of the map
-- @tparam number map_world_y World y of the map
-- @tparam number test_world_x World x to test
-- @tparam number test_world_y World y to test
-- @return True if within bounds, false otherwise
function M.within_dimensions(map, map_world_x, map_world_y, test_world_x, test_world_y)

    local map_shift_x = map_world_x + (map.bounds.x - 1) * map.dimensions.tile_width
    local map_shift_y = map_world_y + (map.bounds.y - 1) * map.dimensions.tile_height

    return test_world_x >= map_shift_x and test_world_x < map_shift_x + map.dimensions.world_width
    and test_world_y >= map_shift_y and test_world_y < map_shift_y + map.dimensions.world_height

end

--- Return pixel coordinates of a given cells center.
-- @tparam map map A moku map
-- @tparam number map_world_x World x of the map
-- @tparam number map_world_y World y of the map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
-- @return Pixel x of cells center
-- @return Pixel y of cells center
function M.cell_center(map, map_world_x, map_world_y, x, y)

    local ox, oy

    ox = map_world_x + (x - 1) * map.dimensions.tile_width + map.dimensions.tile_width / 2
    oy = map_world_y + (y - 1) * map.dimensions.tile_height + map.dimensions.tile_height / 2

    return ox, oy

end


--- Return coordinates of a cell neighboring a given cell.
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @tparam moku.dir dir Direction of neighbor coordinates to return
-- @return The x coordinate of neighbor
-- @return The y coordinate of neighbor
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

--- Return a list of all coordinates neighboring a given cell.
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @return A list of neighbor coordinates in the form { {n1x, n1y}, {n2x, n2y}, ... }
function M.all_neighbor_coords(x, y)

    local nc = {}
    local nx
    local ny

    for i = 1, 8 do
        nx, ny = M.neighbor_coords(x, y, i)
        nc[i] = {nx, ny}
    end

    return nc

end

--- Return the value of a cell neighboring a given cell.
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @tparam moku.dir dir Direction of neighbor value to return
-- @return The value. Nil if outside of bounds
function M.neighbor_value(map, x, y, dir)

    local nv = M.neighbor_coords(x, y, dir)

    if M.within_bounds(map, nv.x, nv.y) then
        return map[nv.x][nv.y]
    else return nil
    end

end

--- Return a list of all values contained in cells neighboring a given cell.
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @return A list of neighbor values
function M.all_neighbor_values(map, x, y)

    local nv = {}

    for i = 1, 8 do
        nv[i] = M.neighbor_value(map, x, y, i)
    end

    return nv

end

--o=========================================o

--- Cell Picking.
-- Functions related to cell picking
-- @section Cell-Picking

--o=========================================o

--- Returns the coordinates of the cell at given world coordinates
-- @tparam map map A moku map
-- @tparam number map_world_x World x of the map
-- @tparam number map_world_y World y of the map
-- @tparam number pick_world_x Given world x
-- @tparam number pick_world_y Given world y
-- @return x coordinate of cell at given world coordinates. Nil if out of map bounds
-- @return y coordinate of cell at given world coordinates. Nil if out of map bounds
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

--o=========================================o

--- Auto-Tiling.
-- Functions related to moku auto-tiling
-- @section Auto-Tiling

--o=========================================o

--- Designates a tile type as as an autotile.
-- @tparam map map A moku map
-- @tparam number tile_type The tile type to be designated as an autotile
-- @tparam moku.bits bits The autotiling algorithm to be used
-- @tparam bool join_self Whether tiles of the same type act as joining tiles
-- @tparam bool join_edge Whether the edge ofthe map acts as a joining tile
-- @tparam bool join_nil Whether empty cells act as joining tiles
-- @tparam table joining_types Additional tile types to act as joining tiles
function M.set_autotile(map, tile_type, bits, join_self, join_edge, join_nil, joining_types)

    map.autotiles[tile_type] = {}
    map.autotiles[tile_type].bits = bits

    if join_self then
        map.autotiles[tile_type][tile_type] = true
    end

    if join_edge then
        map.autotiles[tile_type][border] = true
    end

    if join_nil then
        map.autotiles[tile_type][null] = true
    end

    if joining_types then
        for i, v in ipairs(joining_types) do
            map.autotiles[tile_type][v] = true
        end
    end

end

--- Calculates a given cells autotile id
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @return The autotile id
function M.autotile_id(map, x, y)

    -- Tile type of this cell
    local tile_type = map[x][y]

    -- References the appropriate lookup table
    -- or returns null (0) if not a tilable type
    local lookup
    if map.autotiles[tile_type] then
        lookup = map.autotiles[tile_type]
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

--- Autotiles a given cell. Returns the cells autotile id
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @return The autotile id
function M.autotile_cell(map, x, y)

    local sum = M.autotile_id(map, x, y)
    tilemap.set_tile(map.tilemap_url, M.layer_name, x, y, sum)

    return sum

end

--- Autotiles a rectangular region of a moku map.
-- @tparam map map A moku map
-- @tparam number x Lower left x coordinate of region
-- @tparam number y Lower left y coordinate of region
-- @tparam number width Width of the region
-- @tparam number height Height of the region
function M.autotile_region(map, x, y, width, height)

    for _x, _y, _v in M.iterate_map(map) do
        if map.autotiles[_v] then
            M.autotile_cell(map, _x, _y)
        end
    end

end

--- Autotiles an entire moku map.
-- @tparam map map A moku map
function M.autotile_map(map)
    return M.autotile_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height)
end

--- Autotiles a given cell and its surrounding cells.
-- @tparam map map A moku map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
function M.autotile_surrounding(map, x, y)
    return M.autotile_region(map, x - 1, y - 1, 3, 3)
end


--o=========================================o

--- Tiling Matrices.
-- Functions that return tiling matrices
-- @section Tiling-matrices

--o=========================================o

--- Returns a rectangular tiling matrix.
-- @tparam map map A moku map
-- @tparam number x Lower left x coordinate of region
-- @tparam number y Lower left y coordinate of region
-- @tparam number width Width of the region
-- @tparam number height Height of the region
function M.tiling_matrix_region(map, x, y, width, height)

    local tiling_matrix = {}

    for _x, _y, _v in M.iterate_map(map) do

        if tiling_matrix[_x] == nil then
            tiling_matrix[_x] = {}
        end

        if map.autotiles[_v] then
            tiling_matrix[_x][_y] = M.autotile_id(map, _x, _y)
        else
            tiling_matrix[_x][_y] = null
        end

    end

    return tiling_matrix

end

--- Returns a tiling matrix for an entire moku map.
-- @tparam map map A moku map
function M.tiling_matrix_map(map)
    return M.tiling_matrix_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height)
end

--- Returns a tiling matrix for a given cell and its surrounding cells.
-- @tparam map map A moku map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
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
