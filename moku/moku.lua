--- Moku Module
--@module Moku

local M = {}

--o=========================o
--o Moku Enums
--o=========================o

M.dir = {
    N = 1,
    E = 2,
    S = 3,
    W = 4,
    NE = 5,
    SE = 6,
    SW = 7,
    NW = 8
}

M.at_algorithm = {
    SIMPLE = 4,
    COMPLEX = 8
}

M.dir_tables = {
    ALL = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 }, { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } },
    CARDINAL = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } },
    DIAGONAL = { { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } }
}

M.heuristic = {
    NONE = function(a, b, h)
        return 0
    end,
    MANHATTAN = function(a, b)
        return math.abs(a.moku_x - b.moku_x) + math.abs(a.moku_y - b.moku_y)
    end,
    MAX_DXDY = function(a, b)
        return math.max(math.abs(a.moku_x - b.moku_x), math.abs(a.moku_y - b.moku_y))
    end,
    DIAGONAL_SHORTCUT = function(a, b)
        local h_diag = math.min(math.abs(a.moku_x - b.moku_x), math.abs(a.moku_y - b.moku_y))
        local h_straight = math.abs(a.moku_x - b.moku_x) + math.abs(a.moku_y - b.moku_y)
        return 2 * h_diag + (h_straight - 2 * h_diag)
    end,
    EUCLIDEAN = function(a, b)
        return math.sqrt(math.pow(a.moku_x - b.moku_x, 2) + math.pow(a.moku_y - b.moku_y, 2))
    end,
    EUCLIDEAN_NO_SQR = function(a, b)
        return math.pow(a.moku_x - b.moku_x, 2) + math.pow(a.moku_y - b.moku_y, 2)
    end
}

--o=========================o
--o Local Tables
--o=========================o

local reserved_ids = {
    NULL = 0,
    EDGE = -1
}

local id_conversions_simple = {
    [0] = 0,
    [1] = 12,
    [2] = 1,
    [3] = 13,
    [4] = 4,
    [5] = 8,
    [6] = 5,
    [7] = 9,
    [8] = 3,
    [9] = 15,
    [10] = 2,
    [11] = 14,
    [12] = 7,
    [13] = 11,
    [14] = 6,
    [15] = 10,
}

local id_conversions_complex = {
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

--o=========================o
--o Forward Declarations
--o=========================o

-- Constructors
local new_cell

-- Autotiling
local compute_complex_id
local compute_simple_id
local get_type

-- Pathfinder Utility
local pq_swim
local pq_sink
local pq_min_child
local pq_put
local pq_pop
local pq_init
local cl_init
local cl_add

--o=================================================o

--- Constructors.
-- Functions for creating new moku maps and cells
-- @section Constructors

--o=================================================o

--- Builds and returns a new moku map from a supplied defold tilemap.
-- Moku maps built this way are automatically linked to the passed
-- tilemap and layer, and are ready for auto-tiling.
-- @tparam url tilemap_url Tilemap url
-- @tparam string layer_name The name of the layer to build from
-- @tparam number tile_width Pixel width of your tiles
-- @tparam number tile_height Pixel height of your tiles
-- @tparam[opt] function on_new_cell A function called on cell creation
-- @return A new moku map
function M.new_from_tm(tilemap_url, layer_name, tile_width, tile_height, on_new_cell)
    local _x, _y, width, height = tilemap.get_bounds(tilemap_url)

    local world_width = width * tile_width
    local world_height = height * tile_height

    local new_map = {}

    new_map.bounds = {
        x = _x,
        y = _y,
        width = width,
        height = height
    }

    new_map.dimensions = {
        tile_width = tile_width,
        tile_height = tile_height,
        world_width = world_width,
        world_height = world_height,
    }

    local args = {
        cell = nil,
        x = nil,
        y = nil,
        on_edge = nil
    }

    for x = _x, _x + width - 1 do
        new_map[x] = {}
        for y = _y, _y + height - 1 do
            local this_id = tilemap.get_tile(tilemap_url, layer_name, x, y)
            new_map[x][y] = new_cell(x, y, this_id)
            if on_new_cell then
                args.cell = new_map[x][y]
                args.x = x
                args.y = y
                args.on_edge = M.on_edge(new_map, x, y)
                on_new_cell(args)
            end
        end
    end

    new_map.pathfinder = {
        search_limit = -1,
        allowed_directions = M.dir_tables.ALL,
        punish_direction_change = false,
        punish_direction_change_penalty = 5,
        heavy_diagonals = false,
        heavy_diagonals_mult = 2.41,
        heuristic = M.heuristic.MANHATTAN,
        heuristic_mult = 1
    }

    new_map.internal = {}
    new_map.internal.tilemap_url = tilemap_url
    new_map.internal.layer_name = layer_name
    new_map.internal.autotiles = nil
    -- ?? new_map.internal.pathfinder_weights = nil
    -- ?? new_map.internal.pathfinder_cached_paths -- (With option for max # cached)

    return new_map
end


--- Returns a new moku map from scratch.
-- @tparam number width Width in cells
-- @tparam number height Height in cells
-- @tparam number tile_width Pixel width of your tiles
-- @tparam number tile_height Pixel height of your tiles
-- @tparam[opt] function on_new_cell A function called on cell creation
-- @return A new moku map
function M.new(width, height, tile_width, tile_height, on_new_cell)
    local world_width = width * tile_width
    local world_height = height * tile_height

    local new_map = {}

    new_map.bounds = {
        x = 1,
        y = 1,
        width = width,
        height = height
    }

    new_map.dimensions = {
        tile_width = tile_width,
        tile_height = tile_height,
        world_width = world_width,
        world_height = world_height,
    }

    local args = {
        x = nil,
        y = nil,
        on_edge = nil
    }

    for x = 1, width do
        new_map[x] = {}
        for y = 1, height do
            new_map[x][y] = new_cell(x, y, reserved_ids.NULL)
            if on_new_cell then
                args.cell = new_map[x][y]
                args.x = x
                args.y = y
                args.on_edge = M.on_edge(new_map, x, y)
                on_new_cell(args)
            end
        end
    end

    new_map.pathfinder = {
        search_limit = -1,
        allowed_directions = M.dir_tables.ALL,
        punish_direction_change = false,
        punish_direction_change_penalty = 5,
        heavy_diagonals = false,
        heavy_diagonals_mult = 2.41,
        heuristic = M.heuristic.MANHATTAN,
        heuristic_mult = 1
    }

    new_map.internal = {}
    new_map.internal.tilemap_url = nil
    new_map.internal.layer_name = nil
    new_map.internal.autotiles = nil
    -- ?? new_map.internal.pathfinder_weights = nil
    -- ?? new_map.internal.pathfinder_cached_paths -- (With option for max # cached)

    return new_map
end

-- Returns a new moku cell
function new_cell(x, y, moku_id)
    return
    {
        moku_x = x,
        moku_y = y,
        moku_id = moku_id
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

--- Return whether or not a given map coordinate is within the map bounds.
-- @tparam map map A moku map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
-- @return True if in bounds, false otherwise
function M.within_bounds(map, x, y)
    return x >= map.bounds.x and x < map.bounds.x + map.bounds.width
            and y >= map.bounds.y and y < map.bounds.y + map.bounds.height
end

--- Return whether or not a given cell is an edge cell
-- @tparam map map A moku map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
-- @return True if on edge, false otherwise
function M.on_edge(map, x, y)
    return x == map.bounds.x or x == map.bounds.x + map.bounds.width - 1
            or y == map.bounds.y or y == map.bounds.y + map.bounds.height - 1
end

--- Return whether or not a given world coordinate is within the world dimensions of the map.
-- World dimensions being defined as the area that the map is taking up in world space.
-- @tparam map map A moku map
-- @tparam number map_world_x World x of the map
-- @tparam number map_world_y World y of the map
-- @tparam number test_world_x Given world x coordinate
-- @tparam number test_world_y Given world y coordinate
-- @return True if within bounds, false otherwise
function M.within_dimensions(map, map_world_x, map_world_y, test_world_x, test_world_y)
    local map_shift_x = map_world_x + (map.bounds.x - 1) * map.dimensions.tile_width
    local map_shift_y = map_world_y + (map.bounds.y - 1) * map.dimensions.tile_height
    return test_world_x >= map_shift_x and test_world_x < map_shift_x + map.dimensions.world_width
            and test_world_y >= map_shift_y and test_world_y < map_shift_y + map.dimensions.world_height
end

--- Return world coordinates of a given cells center.
-- @tparam map map A moku map
-- @tparam number map_world_x World x of the map
-- @tparam number map_world_y World y of the map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
-- @return World x of cells center
-- @return World y of cells center
function M.cell_center(map, map_world_x, map_world_y, x, y)
    local cx, cy
    cx = map_world_x + (x - 1) * map.dimensions.tile_width + map.dimensions.tile_width / 2
    cy = map_world_y + (y - 1) * map.dimensions.tile_height + map.dimensions.tile_height / 2
    return cx, cy
end

--- Return coordinates of a cell neighboring a given cell.
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @tparam moku.dir dir Direction of neighbor
-- @return The x coordinate of neighbor
-- @return The y coordinate of neighbor
function M.neighbor_coords(x, y, dir)
    return x + M.dir_tables.ALL[dir][1], y + M.dir_tables.ALL[dir][2]
end

--- Return a list of all coordinates neighboring a given cell.
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @return A list of neighbor coordinates in the form
-- { {Nx, Ny}, {Ex, Ey}, {Sx, Sy}, {Wx, Wy}, {NEx, NEy}, {SEx, SEy}, {SWx, SWy}, {NWx, NWy} }
function M.all_neighbor_coords(x, y)
    local nc = {}
    local nx
    local ny
    for i = 1, 8 do
        nx, ny = M.neighbor_coords(x, y, i)
        nc[i] = { x = nx, y = ny }
    end
    return nc
end

--- Return the neighbor cell of a given cell.
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @tparam moku.dir dir Direction of neighbor
-- @return Neighbor cell. Nil if outside of bounds (or the neighbor is nil)
function M.neighbor_cell(map, x, y, dir)
    local nx, ny = M.neighbor_coords(x, y, dir)
    if M.within_bounds(map, nx, ny) then
        return map[nx][ny]
    else
        return nil
    end
end

--- Return a list of all cells neighboring a given cell.
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @return A list of neighbor cells in the form
-- { N, E, S, W, NE, SE, SW, NW }
function M.all_neighbor_cells(map, x, y)
    local nc = {}
    for i = 1, 8 do
        nc[i] = M.neighbor_cell(map, x, y, i)
    end
    return nc
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
function M.pick_coords(map, map_world_x, map_world_y, pick_world_x, pick_world_y)
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

--- Returns the cell at given world coordinates
-- @tparam map map A moku map
-- @tparam number map_world_x World x of the map
-- @tparam number map_world_y World y of the map
-- @tparam number pick_world_x Given world x
-- @tparam number pick_world_y Given world y
-- @return Cell at given world coordinates. Nil if out of map bounds (or the cell is nil)
function M.pick_cell(map, map_world_x, map_world_y, pick_world_x, pick_world_y)
    local cx, cy = M.pick_coords(map, map_world_x, map_world_y, pick_world_x, pick_world_y)
    if cx and cy then
        return map[cx][cy]
    else
        return
    end
end

--o=========================================o

--- Auto-Tiling.
-- Functions related to moku auto-tiling
-- @section Auto-Tiling

--o=========================================o

--- Links a tilemap and layer to a moku map.
-- @tparam map map A moku map
-- @tparam url tilemap_url Tilemap url
-- @tparam string layer_name Name of layer
function M.link_tilemap(map, tilemap_url, layer_name)
    map.internal.tilemap_url = tilemap_url
    map.internal.layer_name = layer_name
end

--- Designates a tile id as as an auto-tile.
-- @tparam map map A moku map
-- @tparam number moku_id The tile id to be designated as an auto-tile
-- @tparam moku.at_algorithm algorithm The auto-tiling algorithm to be used
-- @tparam bool join_self Whether tiles of the same type act as joining tiles
-- @tparam bool join_edge Whether the edge of the map acts as a joining tile
-- @tparam bool join_nil Whether empty cells act as joining tiles
-- @tparam table joining_ids Additional tile id's to act as joining tiles
function M.set_autotile(map, moku_id, algorithm, join_self, join_edge, join_nil, joining_ids)
    if map.internal.autotiles == nil then
        map.internal.autotiles = {}
    end

    map.internal.autotiles[moku_id] = {}
    map.internal.autotiles[moku_id].algorithm = algorithm

    if join_self then
        map.internal.autotiles[moku_id][moku_id] = true
    end

    if join_edge then
        map.internal.autotiles[moku_id][reserved_ids.EDGE] = true
    end

    if join_nil then
        map.internal.autotiles[moku_id][reserved_ids.NULL] = true
    end

    if joining_ids then
        for i, v in ipairs(joining_ids) do
            map.internal.autotiles[moku_id][v] = true
        end
    end
end

--- Calculates a given cells auto-tile id/sum
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @return The auto-tile id
function M.calc_autotile_id(map, x, y)
    -- Tile id of this cell
    local moku_id = map[x][y].moku_id

    -- References the appropriate lookup table
    -- or returns the original type if not an
    -- auto-tile
    local lookup
    if map.internal.autotiles[moku_id] then
        lookup = map.internal.autotiles[moku_id]
    else
        return moku_id
    end

    local algorithm = lookup.algorithm
    local sum

    if algorithm == 4 then
        sum = compute_simple_id(map, x, y, moku_id, lookup)
    elseif algorithm == 8 then
        sum = compute_complex_id(map, x, y, moku_id, lookup)
    end

    -- Return sum
    return sum
end

--- Auto-tiles a given cell.
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
function M.autotile_cell(map, x, y)
    if map.internal.tilemap_url == nil or map.internal.layer_name == nil then
        print("MOKU ERROR: You must link a tilemap and a layer to use auto-tiling. " ..
                "Either call link_tilemap(map, tilemap_url, layer_name), or use a tiling matrix.")
        return
    end

    local sum = M.calc_autotile_id(map, x, y)
    tilemap.set_tile(map.internal.tilemap_url, map.internal.layer_name, x, y, sum)
end

--- Auto-tiles an entire moku map.
-- @tparam map map A moku map
function M.autotile_map(map)
    return M.autotile_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height)
end

--- Auto-tiles a rectangular region of a moku map.
-- @tparam map map A moku map
-- @tparam number x Lower left x coordinate of region
-- @tparam number y Lower left y coordinate of region
-- @tparam number width Width of the region
-- @tparam number height Height of the region
function M.autotile_region(map, x, y, width, height)
    if map.internal.tilemap_url == nil or map.internal.layer_name == nil then
        print("MOKU ERROR: You must link a tilemap and a layer to use auto-tiling. " ..
                "Either call link_tilemap(map, tilemap_url, layer_name), or use a tiling matrix.")
        return
    end

    for _x, _y, _v in M.iterate_region(map, x, y, width, height) do
        M.autotile_cell(map, _x, _y)
    end
end

--- Auto-tiles a given cell and its surrounding cells.
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

--- Returns a tiling matrix for an entire moku map.
-- @tparam map map A moku map
function M.tiling_matrix_map(map)
    return M.tiling_matrix_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height)
end

--- Returns a rectangular tiling matrix.
-- @tparam map map A moku map
-- @tparam number x Lower left x coordinate of region
-- @tparam number y Lower left y coordinate of region
-- @tparam number width Width of the region
-- @tparam number height Height of the region
function M.tiling_matrix_region(map, x, y, width, height)
    local tiling_matrix = {}
    for _x, _y, _v in M.iterate_region(map, x, y, width, height) do
        if tiling_matrix[_x] == nil then
            tiling_matrix[_x] = {}
        end
        tiling_matrix[_x][_y] = M.calc_autotile_id(map, _x, _y)
    end
    return tiling_matrix
end

--- Returns a tiling matrix for a given cell and its surrounding cells.
-- @tparam map map A moku map
-- @tparam number x The x coordinate of the given cell
-- @tparam number y The y coordinate of the given cell
function M.tiling_matrix_surrounding(map, x, y)
    return M.tiling_matrix_region(map, x - 1, y - 1, 3, 3)
end

--o===============================o
--o Local Auto-tiling Algorithms
--o===============================o

-- Simple (4bit) auto-tiling algorithm
function compute_simple_id(map, x, y, moku_id, lookup)
    local n = get_type(map, x, y + 1)
    local w = get_type(map, x - 1, y)
    local e = get_type(map, x + 1, y)
    local s = get_type(map, x, y - 1)

    local sum = 0

    if lookup[n] == true then
        sum = sum + 1
    end

    if lookup[e] == true then
        sum = sum + 2
    end

    if lookup[s] == true then
        sum = sum + 4
    end

    if lookup[w] == true then
        sum = sum + 8
    end

    return id_conversions_simple[sum] + moku_id
end

-- Complex (8bit) auto-tiling algorithm
function compute_complex_id(map, x, y, moku_id, lookup)
    local nw = get_type(map, x - 1, y + 1)
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

    return id_conversions_complex[sum] + moku_id
end

-- Gets the type at x, y, returns edge (-1) if outside of bounds
function get_type(map, x, y)
    if M.within_bounds(map, x, y) and map[x][y] then
        return map[x][y].moku_id
    else
        return reserved_ids.EDGE
    end
end

--o=========================================o

--- Path-finding.
-- Functions related to path-finding
-- @section Path-finding

--o=========================================o

--- Computes, and returns a path from a given start cell, to a given end cell.
-- Takes a cost function for tile weights. Negative weights designate the cell as
-- impassible. See example project or readme for details.
-- @tparam map map A moku map
-- @tparam cell start_cell Given start cell
-- @tparam cell end_cell Given end cell
-- @tparam function cost_fn Cost function
-- @tparam[opt] any cost_fn_arg Added to the cost_fn argument table under "user"
-- @return An array of cells, in order from start to end cell. Nil if no path found.
-- @return A table of cell costs. If no path is found a string is returned giving a reason.
function M.find_path(map, start_cell, end_cell, cost_fn, cost_fn_arg)
    if start_cell == end_cell then
        return nil, "Start and end cell must be different."
    end

    local options = map.pathfinder

    local open = {}
    local cost_lookup = {}
    local parent_lookup = {}

    pq_init(open)
    pq_put(open, start_cell, 0)

    cl_init(cost_lookup)
    cl_add(cost_lookup, start_cell, 0)

    parent_lookup[start_cell] = start_cell

    local default_cost_fn_args = {
        map = map,
        from_cell = nil,
        to_cell = nil,
        start_cell = start_cell,
        end_cell = end_cell,
        user = cost_fn_arg
    }

    local found = false

    local use_search_limit = options.search_limit > 0 or false
    local horiz

    -- Variable promotion for minuscule performance increase
    local current_cell
    local nx
    local ny
    local neighbor_cell
    local neighbor_cost
    local new_cost
    local priority

    while open.current_size > 0 do
        current_cell = pq_pop(open)

        -- Reached goal, break
        if current_cell == end_cell then
            found = true
            break
        end

        -- Check if we've exceeded the search limit
        if use_search_limit and cost_lookup.current_size > options.search_limit then
            -- Return nil and a reason
            return nil, "Search limit exceeded."
        end

        -- Handle direction change punishment
        if options.punish_direction_change then
            horiz = current_cell.moku_x - parent_lookup[current_cell].moku_x
        end

        -- Loop through valid neighbors
        for _, d in pairs(options.allowed_directions) do
            nx = current_cell.moku_x + d[1]
            ny = current_cell.moku_y + d[2]

            if map[nx] and map[nx][ny] then
                neighbor_cell = map[nx][ny]

                -- Update the cost argument table for use in the
                -- cost function
                default_cost_fn_args.from_cell = current_cell
                default_cost_fn_args.to_cell = neighbor_cell

                -- Get the cost of this cell from user
                neighbor_cost = cost_fn(default_cost_fn_args)

                if neighbor_cost >= 0 then
                    -- Handle heavy diagonals
                    if options.heavy_diagonals and (d[1] - d[2]) % 2 == 0 then
                        new_cost = cost_lookup[current_cell] + neighbor_cost * options.heavy_diagonals_mult
                    else
                        new_cost = cost_lookup[current_cell] + neighbor_cost
                    end

                    -- Handle direction change punishment
                    if options.punish_direction_change then
                        if nx - current_cell.moku_x ~= 0 then
                            if horiz == 0 then
                                new_cost = new_cost + options.punish_direction_change_penalty
                            end
                        end
                        if ny - current_cell.moku_y ~= 0 then
                            if horiz ~= 0 then
                                new_cost = new_cost + options.punish_direction_change_penalty
                            end
                        end
                    end

                    if not cost_lookup[neighbor_cell] or new_cost < cost_lookup[neighbor_cell] then
                        cl_add(cost_lookup, neighbor_cell, new_cost)

                        priority = new_cost + options.heuristic_mult * options.heuristic(end_cell, neighbor_cell)
                        pq_put(open, neighbor_cell, priority)

                        parent_lookup[neighbor_cell] = current_cell
                    end
                end
            end
        end
    end

    -- Follow the parent chain, and return a path
    -- in reversed order
    if found then
        local path = {}
        local path_length = 1
        local cell = end_cell

        while cell ~= start_cell do
            path_length = path_length + 1
            cell = parent_lookup[cell]
        end

        cell = end_cell

        for i = path_length, 1, -1 do
            path[i] = cell
            cell = parent_lookup[cell]
        end

        -- Return the cell as well as the cost_lookup table
        return path, cost_lookup
    end

    -- Return nil and a reason
    return nil, "No path to target cell."
end

--o=================================o
-- Pathfinder utility functions
-- (PQ based on: https://gist.github.com/LukeMS/89dc587abd786f92d60886f4977b1953)
--o=================================o

function pq_init(pq)
    pq.heap = {}
    pq.current_size = 0
end

function pq_swim(pq)
    local heap = pq.heap
    local floor = math.floor
    local i = pq.current_size

    while floor(i / 2) > 0 do
        local half = floor(i / 2)
        if heap[i][2] < heap[half][2] then
            heap[i], heap[half] = heap[half], heap[i]
        end
        i = half
    end
end

function pq_put(pq, v, p)
    pq.heap[pq.current_size + 1] = { v, p }
    pq.current_size = pq.current_size + 1
    pq_swim(pq)
end

function pq_sink(pq)
    local size = pq.current_size
    local heap = pq.heap
    local i = 1

    while (i * 2) <= size do
        local mc = pq_min_child(pq, i)
        if heap[i][2] > heap[mc][2] then
            heap[i], heap[mc] = heap[mc], heap[i]
        end
        i = mc
    end
end

function pq_min_child(pq, i)
    if (i * 2) + 1 > pq.current_size then
        return i * 2
    else
        if pq.heap[i * 2][2] < pq.heap[i * 2 + 1][2] then
            return i * 2
        else
            return i * 2 + 1
        end
    end
end

function pq_pop(pq)
    local heap = pq.heap
    local retval = heap[1][1]
    heap[1] = heap[pq.current_size]
    heap[pq.current_size] = nil
    pq.current_size = pq.current_size - 1
    pq_sink(pq)
    return retval
end

function cl_init(lc)
    lc.current_size = 0
end

function cl_add(lc, k, v)
    lc[k] = v
    lc.current_size = lc.current_size + 1
end

--o=========================================o

--- Debugging.
-- Debugging function
-- @section Debugging

--o=========================================o

-- -- Add a function for visualizing path
-- -- Add a function for showing the tile weights for the pathfinder,
-- -- as well as for the move distance calculator (when its added)
-- -- Add a function to iterate the map and make sure user is only using valid values?
--
-- local function get_digits(number)
--     if number == 0 then
--         return 1
--     end
--
--     local count = 0
--     while number >= 1 do
--         number = number / 10
--         count = count + 1
--     end
--     return count
-- end
--
-- --- Prints the maps layout to console.
-- -- @tparam map map A moku map
-- function M.print_map(map)
--
--     local max_digits = 1
--
--     -- Not only checking tile table, in case user entered a
--     -- non tile value
--     for _, y, v in M.iterate_map(map) do
--         if get_digits(v) > max_digits then
--             max_digits = v
--         end
--     end
--
--     local layout = ""
--
--     -- Add row numbers
--     -- Account for numbers with more digits
--     for y = map.bounds.y + map.bounds.height - 1, map.bounds.y - 1, - 1 do
--         if y ~= map.bounds.y - 1 then
--             layout = layout.."\n"..(y % 2 == 0 and "o: " or "e: ")
--         else
--             layout = layout.."\nx: "
--         end
--         for x = map.bounds.x, map.bounds.x + map.bounds.width - 1 do
--             if y ~= map.bounds.y - 1 then
--                 layout = layout..map[x][y]..", "
--             else
--                 layout = layout.."c"..x..", "
--             end
--         end
--     end
--
--     print(layout)
--
-- end

return M
