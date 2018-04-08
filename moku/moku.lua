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
    ALL = {{0, 1}, {1, 0}, {0, - 1}, { - 1, 0}, {1, 1}, {1, - 1}, { - 1, - 1}, { - 1, 1}},
    CARDINAL = {{0, 1}, {1, 0}, {0, - 1}, { - 1, 0}},
    DIAGONAL = {{1, 1}, {1, - 1}, { - 1, - 1}, { - 1, 1}}
}

--o=========================o
--o Local Tables
--o=========================o

local reserved_ids = {
    NULL = 0,
    EDGE = -1
}

local id_conversions_4bit = {
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

local id_conversions_8bit = {
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

-- Priority Queue
local pq_contains
local pq_swim
local pq_sink
local pq_min_child
local pq_put
local pq_pop
local pq_init

--o=================================================o

--- Constructors.
-- Functions for creating new moku maps and cells
-- @section Constructors

--o=================================================o

--- Builds and returns a new moku map from a supplied defold tilemap.
-- Moku maps built this way are automatically linked to the passed
-- tilemap and layer, and are ready for autotiling.
-- @tparam url tilemap_url Tilemap url
-- @tparam string layer_name The name of the layer to build from
-- @tparam number tile_width Pixel width of your tiles
-- @tparam number tile_height Pixel height of your tiles
-- @tparam function on_new_cell A function called on cell creation
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
            new_map[x][y] = new_cell(this_id)
            if on_new_cell then
                args.cell = new_map[x][y]
                args.x = x
                args.y = y
                args.on_edge = M.on_edge(new_map, x, y)
                on_new_cell(args)
            end
        end
    end

    new_map.pathfinder = nil

    new_map.internal = {}
    new_map.internal.tilemap_url = tilemap_url
    new_map.internal.layer_name = layer_name
    new_map.internal.autotiles = nil
    new_map.internal.pathfinder_weights = nil
    -- ?? new_map.internal.pathfinder_cached_paths -- (With option for max # cached)

    return new_map
end


--- Returns a new moku map from scratch.
-- @tparam number width Width in cells
-- @tparam number height Height in cells
-- @tparam number tile_width Pixel width of your tiles
-- @tparam number tile_height Pixel height of your tiles
-- @tparam function on_new_cell A function called on cell creation
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
            new_map[x][y] = new_cell(reserved_ids.NULL)
            if on_new_cell then
                args.cell = new_map[x][y]
                args.x = x
                args.y = y
                args.on_edge = M.on_edge(new_map, x, y)
                on_new_cell(args)
            end
        end
    end

    new_map.pathfinder = nil

    new_map.internal = {}
    new_map.internal.tilemap_url = nil
    new_map.internal.layer_name = nil
    new_map.internal.autotiles = nil
    new_map.internal.pathfinder_weights = nil
    -- ?? new_map.internal.pathfinder_cached_paths -- (With option for max # cached)

    return new_map
end

-- Returns a new moku cell
function new_cell(tile_id)
    return { tile_id = tile_id }
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
        nc[i] = {x = nx, y = ny}
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
    else return nil
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

--- Designates a tile id as as an autotile.
-- @tparam map map A moku map
-- @tparam number tile_id The tile id to be designated as an autotile
-- @tparam moku.at_algorithm algorithm The autotiling algorithm to be used
-- @tparam bool join_self Whether tiles of the same type act as joining tiles
-- @tparam bool join_edge Whether the edge ofthe map acts as a joining tile
-- @tparam bool join_nil Whether empty cells act as joining tiles
-- @tparam table joining_ids Additional tile id's to act as joining tiles
function M.set_autotile(map, tile_id, algorithm, join_self, join_edge, join_nil, joining_ids)
    if map.internal.autotiles == nil then
        map.internal.autotiles = {}
    end

    map.internal.autotiles[tile_id] = {}
    map.internal.autotiles[tile_id].algorithm = algorithm

    if join_self then
        map.internal.autotiles[tile_id][tile_id] = true
    end

    if join_edge then
        map.internal.autotiles[tile_id][reserved_ids.EDGE] = true
    end

    if join_nil then
        map.internal.autotiles[tile_id][reserved_ids.NULL] = true
    end

    if joining_ids then
        for i, v in ipairs(joining_ids) do
            map.internal.autotiles[tile_id][v] = true
        end
    end
end

--- Calculates a given cells autotile id/sum
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
-- @return The autotile id
function M.calc_autotile_id(map, x, y)
    -- Tile id of this cell
    local tile_id = map[x][y].tile_id

    -- References the appropriate lookup table
    -- or returns the original type if not an
    -- autotile
    local lookup
    if map.internal.autotiles[tile_id] then
        lookup = map.internal.autotiles[tile_id]
    else
        return tile_id
    end

    local algorithm = lookup.algorithm
    local sum

    if algorithm == 4 then
        sum = compute_simple_id(map, x, y, tile_id, lookup)
    elseif algorithm == 8 then
        sum = compute_complex_id(map, x, y, tile_id, lookup)
    end

    -- Return sum
    return sum
end

--- Autotiles a given cell.
-- @tparam map map A moku map
-- @tparam number x The y coordinate of the given cell
-- @tparam number y The x coordinate of the given cell
function M.autotile_cell(map, x, y)
    if map.internal.tilemap_url == nil or map.internal.layer_name == nil then
        print("MOKU ERROR: You must link a tilemap and a layer to use autotiling. "..
        "Either call link_tilemap(map, tilemap_url, layer_name), or use a tiling matrix.")
        return
    end

    local sum = M.calc_autotile_id(map, x, y)
    tilemap.set_tile(map.internal.tilemap_url, map.internal.layer_name, x, y, sum)
end

--- Autotiles an entire moku map.
-- @tparam map map A moku map
function M.autotile_map(map)
    return M.autotile_region(map, map.bounds.x, map.bounds.y, map.bounds.width, map.bounds.height)
end

--- Autotiles a rectangular region of a moku map.
-- @tparam map map A moku map
-- @tparam number x Lower left x coordinate of region
-- @tparam number y Lower left y coordinate of region
-- @tparam number width Width of the region
-- @tparam number height Height of the region
function M.autotile_region(map, x, y, width, height)
    if map.internal.tilemap_url == nil or map.internal.layer_name == nil then
        print("MOKU ERROR: You must link a tilemap and a layer to use autotiling. "..
        "Either call link_tilemap(map, tilemap_url, layer_name), or use a tiling matrix.")
        return
    end

    for _x, _y, _v in M.iterate_region(map, x, y, width, height) do
        M.autotile_cell(map, _x, _y)
    end
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

--o=========================o
--o Local Autotiling Algs
--o=========================o

-- Simple (4bit) autotiling algorithm
function compute_simple_id(map, x, y, tile_type, lookup)
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

    return id_conversions_4bit[sum] + tile_type
end

-- Complex (8bit) autotiling algorithm
function compute_complex_id(map, x, y, tile_type, lookup)
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

    return id_conversions_8bit[sum] + tile_type
end

-- Gets the type at x, y, returns border (-1) if outside of bounds
function get_type(map, x, y)
    if M.within_bounds(map, x, y) and map[x][y] then
        return map[x][y].tile_id
    else
        return reserved_ids.EDGE
    end
end

--o=========================================o

--- Pathfinding.
-- Functions related to pathfinding
-- @section Pathfinding

--o=========================================o

-------------------------------------------------------------------------------------
-- IMPORTANT!!!
-- MUST ALSO BE ABLE TO MANIPULATE COSTS ARBITRARILY! THINK MONSTERS OR SPELL EFFECTS!
-------------------------------------------------------------------------------------

function M.init_pathfinder(map)
    for x, y, v in M.iterate_map(map) do
        v.moku_x = x
        v.moku_y = y
    end

    map.pathfinder = {
        search_limit = -1,
        allowed_directions = M.dir_tables.ALL,
        punish_direction_change = false,
        punish_direction_change_penalty = 20


    }

    map.internal.pathfinder_weights = {
        [1] = -1,
        [17] = 10,
        [33] = 1
    }
end

local function manhatten(a, b)
    return math.abs(a.moku_x - b.moku_x) + math.abs(a.moku_y - b.moku_y)
end

function M.find_path_coords(map, start_x, start_y, end_x, end_y)
    return M.find_path(map, map[start_x][start_y], map[end_x][end_y])
end

local function cl_init(lc)
    lc.current_size = 0
end

local function cl_add(lc, k, v)
    lc[k] = v
    lc.current_size = lc.current_size + 1
end

function M.find_path(map, start_cell, end_cell)
    assert(start_cell ~= end_cell, "Start and end cell must be different.")

    local options = map.pathfinder
    local weights = map.internal.pathfinder_weights

    local open = {}
    local cost_lookup = {} -- Doubles as closed, I think
    local parent_lookup = {}

    pq_init(open)
    pq_put(open, start_cell, 0)

    cl_init(cost_lookup)
    cl_add(cost_lookup, start_cell, 0)

    parent_lookup[start_cell] = start_cell

    local found = false
    local use_search_limit = options.search_limit > 0 or false
    local horiz

    -- Variable promotion for the miniscule performance increase
    local current_cell
    local nx
    local ny
    local neighbor_cell
    local neighbor_cost
    local new_cost
    local priority

    while open.current_size > 0 do
        current_cell = pq_pop(open)

        if current_cell == end_cell then
            found = true
            break
        end

        if use_search_limit and cost_lookup.current_size > options.search_limit then
            found = false
            print("Search limit exceeded")
            break
        end

        if options.punish_direction_change then
            horiz = current_cell.moku_x - parent_lookup[current_cell].moku_x
        end

        for _, d in pairs(options.allowed_directions) do
            nx = current_cell.moku_x + d[1]
            ny = current_cell.moku_y + d[2]

            if map[nx] and map[nx][ny] then
                neighbor_cell = map[nx][ny]

                -- Does this act as a substitute for removing from open?
                if not pq_contains(open, neighbor_cell) then

                    neighbor_cost = weights[neighbor_cell.tile_id]

                    if neighbor_cost >= 0 then
                        new_cost = cost_lookup[current_cell] + neighbor_cost

                        -- Handle punish direction change
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
                            priority = new_cost + manhatten(end_cell, neighbor_cell)
                            pq_put(open, neighbor_cell, priority)
                            parent_lookup[neighbor_cell] = current_cell
                        end
                    end
                end
            end
        end
    end

    if found then
        local path_length = 1
        local cell = end_cell
        while cell ~= start_cell do
            path_length = path_length + 1
            cell = parent_lookup[cell]
        end

        local path = {}

        cell = end_cell
        for i = path_length, 1, - 1 do
            path[i] = cell
            cell = parent_lookup[cell]
        end
        print(path_length)
        return path
    end

    return nil

    -- Maybe use messaging system:
    -- "found", path
    -- "search limit exceeded", nil
    -- "no path", nil

    -- Return total cost
    -- cost_lookup[end_cell]

    -- Or just the cost table
    -- return path, cost_lookup

end





--o=================================o
-- Pathfinder utility functions
-- (PQ based on: https://gist.github.com/LukeMS/89dc587abd786f92d60886f4977b1953)
--o=================================o

function pq_init(pq)
    pq.heap = {}
    pq.contains = {}
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

function pq_contains(pq, v)
    return pq.contains[v]
end

function pq_put(pq, v, p)
    pq.heap[pq.current_size + 1] = {v, p}
    pq.current_size = pq.current_size + 1
    pq.contains[v] = true
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
    pq.contains[retval] = nil
    return retval
end

--o=========================================o

--- Debugging.
-- Debugging function
-- @section Debugging

--o=========================================o

-- Add a function for visualizing path
-- Add a function for showing the tile weights for the pathfinder,
-- as well as for the move distance calculator (when its added)
-- Add a function to iterate the map and make sure user is only using valid values?

local function get_digits(number)
    if number == 0 then
        return 1
    end

    local count = 0
    while number >= 1 do
        number = number / 10
        count = count + 1
    end
    return count
end

--- Prints the maps layout to console.
-- @tparam map map A moku map
function M.print_map(map)

    local max_digits = 1

    -- Not only checking tile table, in case user entered a
    -- non tile value
    for _, y, v in M.iterate_map(map) do
        if get_digits(v) > max_digits then
            max_digits = v
        end
    end

    local layout = ""

    -- Add row numbers
    -- Account for numbers with more digits
    for y = map.bounds.y + map.bounds.height - 1, map.bounds.y - 1, - 1 do
        if y ~= map.bounds.y - 1 then
            layout = layout.."\n"..(y % 2 == 0 and "o: " or "e: ")
        else
            layout = layout.."\nx: "
        end
        for x = map.bounds.x, map.bounds.x + map.bounds.width - 1 do
            if y ~= map.bounds.y - 1 then
                layout = layout..map[x][y]..", "
            else
                layout = layout.."c"..x..", "
            end
        end
    end

    print(layout)

end

return M

-- local function new_node()
--     return
--     {
--         F = 0,
--         G = 0,
--         H = 0,
--         x = 0,
--         y = 0,
--         px = 0,
--         py = 0
--     }
-- end
--
-- --- Initializes the Moku pathfinder
-- -- @tparam map map A moku map
-- -- @tparam table tile_weights A table of tile weights
-- function M.init_pathfinder(map, tile_weights)
--
--     map.pf_options = {
--         allow_diagonals = true,
--         heavy_diagonals = false,
--         hvy_diag_mult = 2.41,
--         punish_direction_change = false,
--         punish_dir_penalty = 20,
--         tie_breaker = false,
--         heuristic_estimate = 1,
--         search_limit = 2000
--     }
--
--     -- *Maybe* allow for unentered values, but probably not
--     map.pf_weights = {}
--     for k, v in pairs(tile_weights) do
--         map.pf_weights[k] = v
--     end
--
--     for k, v in pairs(map.tile_types) do
--         if not map.pf_weights[v] then
--             print("No weight entered for: "..k)
--         end
--     end
--
-- end
--
-- --- Finds a path from a starting cell to an ending cell.
-- -- Must call init_pathfinder(...) once before using this function.
-- -- @tparam map map A moku map
-- -- @tparam number start_x x coordinate of starting cell
-- -- @tparam number start_y y coordinate of starting cell
-- -- @tparam number end_x x coordinate of ending cell
-- -- @tparam number end_y y coordinate of ending cell
-- -- @return A path from the starting cell to the ending cell,
-- -- in the form of a list of nodes
-- function M.find_path(map, start_x, start_y, end_x, end_y)
--
--     if map.pf_options == nil or map.pf_weights == nil then
--         print("Call init_pathfinder once before calling this function.")
--     end
--
--     if not M.within_bounds(map, start_x, start_y) or not M.within_bounds(map, end_x, end_y) then
--         print("Start and end points must be within map bounds, duh.")
--         return nil
--     end
--
--     local found = false
--     local neighbor_checks = map.pf_options.allow_diagonals and 8 or 4
--
--     local direction
--     if map.pf_options.allow_diagonals then
--         direction = dir_all
--     else
--         direction = dir_cardinal
--     end
--
--     -- Unneeded i believe
--     local reopen_close_nodes = false
--     local horiz = 0
--
--     local priority_queue = {}
--     local close = {}
--
--     local p_node = new_node()
--
--     p_node.G = 0
--     p_node.H = map.pf_options.heuristic_estimate
--     p_node.F = p_node.G + p_node.H
--     p_node.x = start_x
--     p_node.y = start_y
--     p_node.px = start_x
--     p_node.py = start_y
--
--     push(priority_queue, p_node)
--
--     while #priority_queue > 0 do
--         p_node = pop(priority_queue)
--
--         if p_node.x == end_x and p_node.y == end_y then
--             table.insert(close, p_node)
--             found = true
--             break
--         end
--
--         if #close > map.pf_options.search_limit then
--             print("Exceeded search limit.")
--             return nil
--         end
--
--         if map.pf_options.punish_direction_change then
--             horiz = p_node.x - p_node.px
--         end
--
--         for i = 1, neighbor_checks do
--
--             local n_node = new_node()
--             n_node.x = p_node.x + direction[i][1]
--             n_node.y = p_node.y + direction[i][2]
--
--             if M.within_bounds(map, n_node.x, n_node.y) then
--
--                 local new_g
--                 -- *Maybe* allow for unentered values, but probably not
--                 if map.pf_options.heavy_diagonals and i > 4 then
--                     new_g = p_node.G + map.pf_weights[map[n_node.x][n_node.y]] * map.pf_options.hvy_diag_mult
--                 else
--                     new_g = p_node.G + map.pf_weights[map[n_node.x][n_node.y]]
--                 end
--
--                 if new_g ~= p_node.G then
--
--                     if map.pf_options.punish_direction_change then
--                         if n_node.x - p_node.x ~= 0 then
--                             if horiz == 0 then
--                                 new_g = new_g + map.pf_options.punish_dir_penalty
--                             end
--                         end
--
--                         if n_node.y - p_node.y ~= 0 then
--                             if horiz ~= 0 then
--                                 new_g = new_g + map.pf_options.punish_dir_penalty
--                             end
--                         end
--                     end
--
--                     local found_in_pq_index = -1
--                     for j = 1, #priority_queue do
--                         if priority_queue[j].x == n_node.x and priority_queue[j].y == n_node.y then
--                             found_in_pq_index = j
--                             break
--                         end
--                     end
--
--                     -- Invert instead
--                     if not (found_in_pq_index ~= -1 and priority_queue[found_in_pq_index].G <= new_g) then
--
--                         local found_in_close_index = -1
--                         for j = 1, #close do
--                             if close[j].x == n_node.x and close[j].y == n_node.y then
--                                 found_in_close_index = j
--                                 break
--                             end
--                         end
--
--                         -- Invert instead
--                         if not (found_in_close_index ~= -1
--                         and (reopen_close_nodes or close[found_in_close_index].G <= new_g)) then
--
--                             n_node.px = p_node.x
--                             n_node.py = p_node.y
--                             n_node.G = new_g
--
--                             -- Heuristic
--                             n_node.H = map.pf_options.heuristic_estimate * (math.abs(n_node.x - end_x)
--                              + math.abs(n_node.y - end_y))
--
--                             if (map.pf_options.tie_breaker) then
--                                 local dx1 = p_node.x - end_x
--                                 local dy1 = p_node.y - end_y
--                                 local dx2 = start_x - end_x
--                                 local dy2 = start_y - end_y
--                                 local cross = math.abs(dx1 * dy2 - dx2 * dy1)
--                                 -- May need to be floored
--                                 n_node.H = n_node.H + cross * 0.001
--                             end
--
--                             n_node.F = n_node.G + n_node.H
--
--                             push(priority_queue, n_node)
--                         end
--                     end
--                 end
--             end
--         end
--
--         if p_node ~= close[1] then
--             table.insert(close, p_node)
--         end
--
--     end
--
--     if (found) then
--         local count = #close
--         local f_node = close[count]
--         for i = count, 1, - 1 do
--             if f_node.px == close[i].x and f_node.py == close[i].y or i == count then
--                 f_node = close[i]
--             else
--                 table.remove(close, i)
--             end
--         end
--         return close
--     end
--
--     return nil
--
-- end
