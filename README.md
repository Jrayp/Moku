# Moku
Map utility/module for the Defold game engine. 

### Documentation

[LDoc generated module documentation](http://htmlpreview.github.io/?https://github.com/Jrayp/Moku/blob/master/doc/index.html)

### Features: 

* Bitmask autotiling partially based on the method outlined here: [How to Use Tile Bitmasking to Auto-Tile Your Level Layouts](https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673). Supports both 4 and 8-bit tiling. Can be used in conjuction with defold tilemaps, or your own custom maps.
* Cell Picking
* Assorted convience functions

### Planned features

* Efficient AStar pathfinding with support for options such as heavy diagonals etc
* Other things I haven't put too much thought into yet

### State
Currently in very early, untested alpha. Missing features, probably a bit unwieldy, unintuitive, and busted. 

## Basic auto-tiling guide

Moku auto-tiling can be very easy to use, depending on use case. More involved needs will require more involved setup. However, for simple defold tilemap autotiling, very little work is required. Please refer to [How to Use Tile Bitmasking to Auto-Tile Your Level Layouts](https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673) if in doubt, as mokus autotiler is based on that article. For this guide we will use 8-bit tiling, but 4-bit tiling works the same way.

### Tile sheet layout

First, your sprite sheet containing your maps tile images must be in a specific layout. In the following tile sheet from the demo project, we have three base tile types: Plains, plateau, and ocean.  

![alt text](https://github.com/Jrayp/Moku/blob/master/main/images/autotiles_8bit.png "Logo Title Text 1")

Since the plains and plateau types will be designated 8-bit autotiles, they consist of a total of 48 individual images, each corresponding to a particular border configuration. Any tile you wish to designate an autotile must have 48 images reserved on your tile sheet in EXACTLY this order, beginning with what I will call the tiles "base image" (the image of a completely surrounded tile).

Note that you may place your autotiles anywhere on your tilesheet, as long as the following 47 images are in the correct order. Mokus incredibly advanced AI can handle this. Also note that if we were using 4-bit tiling that everything would work the same, except that we would only require a much more managable 16 images per autotile.

The ocean tile does not require autotile functionality, and can be freely placed anywhere on your tile sheet.

### Auto tiling a tilemap

In defold, add a tilemap to your collection that references a tilesource derived from your tile sheet. Go ahead and draw on it, but be sure to use only the above mentioned base tiles for drawing (that is the first image related to the tile type). 

Now, after importing moku in script, create a table of your tile types as such:

```lua
local moku = require "moku.moku"    

local tile_types = {
      
    -- Autotiles
    PLAINS = 1,
    PLATEAU = 49,
        
    -- Normal Tiles
    OCEAN = 97
}
```

It is recommended to give your tile types simple descriptive names (keys). The value associated with the type is a reference to that types base tile position on the tile sheet. Here the `PLAINS` types base tile occupies position `1` on the tile sheet, the `PLATEAU` type position `49`, and the `OCEAN` type position `97`. 

Create a moku map from your defold tilemap. Assuming your tilemap is named `my_tilemap` and is attached to the gameobject `map_go`:

```lua
my_new_map = moku.new_from_tilemap("map_go#my_tilemap", 32, 32, tile_types)
```

Where `32` is the pixel width and height of the individual tile images. (This is used in calculations such as cell picking etc.)

Now we tell moku to designate the `PLAINS` and `PLATEAU` types as autotiles:

```lua
moku.set_autotile(my_new_map, tile_types.PLAINS, moku.bits.EIGHT, true, true, true, {tile_types.PLATEAU})
moku.set_autotile(my_new_map, tile_types.PLATEAU, moku.bits.EIGHT, true, true, true)
```

Lets take a look at this functions parameters
1. Just takes a moku map
2. The type you want to designate an autotile
3. What tiling algorithm to use, in this case we use 8-bit
4. Whether or not this tile interacts/joins with tiles of its own type, usually true
5. Whether or not this tile interacts/joins with the edge of the map
6. Whether or not this tile interacts/joins with empty cells (these are supported)
7. A list of other tile types that the autotile will interact/join to 

So in our example, the `PLAINS` type will interact/join with everything except `OCEAN` tiles; and the `PLATEAU` type will interact with everything except `OCEAN` and `PLAINS` tiles.

And now we can tell moku to tile the map:

```lua
moku.autotile_map(my_new_map)
```

Thats it. Much more can be done, but this guide should be enough to at least get an idea of how Moku works, and should be sufficient for the vast majority of use cases. Following is the complete example code:

```lua
local moku = require "moku.moku"    

local tile_types = {
      
    -- Autotiles
    PLAINS = 1,
    PLATEAU = 49,
        
    -- Normal Tiles
    OCEAN = 97
}

my_new_map = moku.new_from_tilemap("map_go#my_tilemap", 32, 32, tile_types)

moku.set_autotile(my_new_map, tile_types.PLAINS, moku.bits.EIGHT, true, true, true, {tile_types.PLATEAU})
moku.set_autotile(my_new_map, tile_types.PLATEAU, moku.bits.EIGHT, true, true, true)

moku.autotile_map(my_new_map)
```
<!---

# Moku Functions

Following are the functions offered by Moku. The majority require the user to supply a moku map.

## Constructor Functions

These functions return new moku maps. Moku maps are tables of tile values, and other relevant data.

### moku.new(width, height, tile_width, tile_height, tile_types, fill_type, [tilemap_url])
Creates and returns a new moku map from scratch. The `tile_types` argument must be of a specific form as shown in the example. The keys are chosen by the user, and should be descriptive names of the tiles that your moku map uses. Their associated values are the integer positions of that tiles base tile image in a tile source.

Example:

 ```lua
 local tile_types = {
    PLAINS = 1,
    FOREST = 49,
    OCEAN = 97
 }

local my_map = moku.new(8, 8, 32, 32, tile_types, tile_types.FLOOR)
```

_PARAMETERS_
* __width__ <kbd>Integer</kbd> - Width of the new map in cells.
* __height__ <kbd>Integer</kbd> - Height of the new map in cells.
* __tile_width__ <kbd>Integer</kbd> - Width of individual tiles/cells in pixels.
* __tile_height__ <kbd>Integer</kbd> - Width of individual tiles/cells in pixels.
* __tile_types__ <kbd>Table</kbd> - A table of keys and integer values representing different tile types, and their associated base tile id.
* __fill_type__ <kbd>Integer</kbd> - The initial tile type (defined in the previous table) of the cells in the new map.  
* __tilemap_url__ <kbd>String</kbd> - Optional path to a defold tilemap. Required for auto-tiling, but not required for creating tiling matrices, explained below.

_RETURNS_
* __moku_map__ <kbd>table</kbd> - A new moku map.

### moku.new_from_tilemap(tilemap_url, tile_width, tile_height, tile_types)
Creates and returns a new moku map from a defold tilemap. When drawing your tilemap in the editor, use only the tiles base image for auto tiles.

Example:

 ```lua
 local tile_types = {
    PLAINS = 1,
    FOREST = 49,
    OCEAN = 97
 }

local my_map = moku.new_from_tilemap("my_map_go#my_tilemap", 32, 32, tile_types)
```

_PARAMETERS_
* __tilemap_url__ <kbd>String</kbd> - Required path to a defold tilemap.
* __tile_width__ <kbd>Integer</kbd> - Width of individual tiles/cells in pixels.
* __tile_height__ <kbd>Integer</kbd> - Width of individual tiles/cells in pixels.
* __tile_types__ <kbd>Table</kbd> - A table of keys and integer values representing different tile types, and their associated base tile id.

_RETURNS_
* __moku_map__ <kbd>table</kbd> - A new moku map.

## Iterator Functions

These functions are convienience functions for iterating through a specified region of a moku map. If you need custom iteration, you can of course iterate using a nested for loop. Just be aware that the moku map table also contains non coordinate data. It is therefore advised that you do not use a forp loop to avoid errors.

### moku.iterate_region(map, x, y, width, height, [fn])
Iterates a rectangular region of the supplied moku map, using `x`, `y`, `width`, and `height` as bounds. An optional function `fn` can be supplied to filter results.

Example:

```lua
local function is_plains(v)
    return v == tile_types.PLAINS
end

for x, y, v in moku.iterate_region(my_map, 5, 5, 3, 3, is_plains) do
    -- Change all plains tiles in the supplied rectangle to ocean tiles.
    map[x][y] = tile_types.OCEAN
end
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __x__ <kbd>Integer</kbd> - x coordinate of bottom left cell of region.
* __y__ <kbd>Integer</kbd> - y coordinate of bottom left cell of region.
* __width__ <kbd>Integer</kbd> - Width of the region.
* __width__ <kbd>Integer</kbd> - Height of the region.
* __fn__ <kbd>Function</kbd> - Optional filter function.

### moku.iterate(map, [fn])
Convinience/wrapper function for `moku.iterate_region(...)`. Iterates the entire moku map. A filter function can be supplied.

Example:

```lua
local function is_plains(v)
    return v == tile_types.PLAINS
end

for x, y, v in moku.iterate(my_map, is_plains) do
    -- Change all plains tiles of the map to ocean tiles.
    map[x][y] = tile_types.OCEAN
end
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __fn__ <kbd>Function</kbd> - Optional filter function.

### moku.iterate_surrounding(map, x, y, [fn])
Convinience/wrapper function for `moku.iterate_region(...)`. Iterates a 3x3 surrounding region of central cell. A filter function can be supplied.

Example:

```lua
local function is_plains(v)
    return v == tile_types.PLAINS
end

for x, y, v in moku.iterate_surrounding(my_map, 5, 5, is_plains) do
    -- Change all plains tiles of the supplied cell + its 8 surrounding neighbors, to ocean.
    map[x][y] = tile_types.OCEAN
end
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __x__ <kbd>Integer</kbd> - x coordinate of center cell.
* __y__ <kbd>Integer</kbd> - y coordinate of center cell.
* __fn__ <kbd>Function</kbd> - Optional filter function.

## General Functions

These are general functions that do not fit into any specific category. For now they are mostly related to simple cell/coordinate uses, such as determining the value of a neighboring cell.

### moku.within_bounds(map, x, y)
Tests whether a given coordinate is within the bounds of a supplied moku map.

Example:

```lua
if moku.within_bounds(my_map, i,j) then
    -- Do something at my_map[i][j] (probably)
else
    -- Don't do anything (probably)
end
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __x__ <kbd>Integer</kbd> - x coordinate we want to test for.
* __y__ <kbd>Integer</kbd> - y coordinate we want to test for.

_RETURNS_
* __within_bounds_flag__ <kbd>Boolean</kbd> - True if within bounds, false otherwise.

### moku.on_border(map, x, y)
Tests whether a given coordinate is a border cell, that is if (x,y) lies on the outer edge of the supplied moku map.

Example:

```lua
for x, y, value in moku.iterate(my_map) do
    if moku.on_border(my_map, x,y) then
        my_map[x][y] == tile_types.WALL
    else
        my_map[x][y] == tile_types.FLOOR
    end
end
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __x__ <kbd>Integer</kbd> - x coordinate you want to test for.
* __y__ <kbd>Integer</kbd> - y coordinate you want to test for.

_RETURNS_
* __on_border_flag__ <kbd>Boolean</kbd> - True if border cell, false otherwise.

### moku.within_dimensions(map, map_world_x, map_world_y, test_world_x, test_world_y)
Tests whether a given world/pixel coordinate is within the world dimensions of the supplied moku map, as calculated by the map and tile dimensions. Moku maps do not (currently) store current world position, so the user must supply this information.

Example:

```lua
if moku.within_dimensions(my_map, 0, 0, i, j) then
    print("The world position (i, j) is within the world dimensions of my_map!)
else
    print("The world position (i, j) is outside the world dimensions of my_map!)
end
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __map_world_x__ <kbd>Integer</kbd> - Current pixel x in world cooridnates of maps lower left corner.
* __map_world_y__ <kbd>Integer</kbd> - Current pixel y in world cooridnates of maps lower left corner.
* __test_world_x__ <kbd>Integer</kbd> - Pixel x in world coordinates we are testing for.
* __test_world_y__ <kbd>Integer</kbd> - Pixel y in world coordinates we are testing for

_RETURNS_
* __within_dimensions_flag__ <kbd>Boolean</kbd> - True if within dimensions, false otherwise.

### moku.neighbor_coords(x, y, dir)
Returns the coordinates of a supplied origin cells neighbor. The neighbor is specified by use of the `dir` argument. This argument is an integer that corresponds to one of the 8 directions on a (simple) compass, starting at 1 for north and continuing in clock-wise fashion to 8 for north-west. Moku provides an improvised "enum" table for direction, accessible with `moku.dir.[DIRECTION]`, for convinience.

Note that this calculation is independent of any moku map. It is not guarenteed that the returned value is within the bounds of whatever map you may be using it for.

Example:

```lua
local sw_x, sw_y = moku.neighbor_coords(5, 5, moku.dir.SOUTH_WEST)

-- Same thing
-- local sw_x, sw_y = moku.neighbor_coords(5, 5, 6)

print(sw_x, sw_y) -- Prints "4, 4"
```

_PARAMETERS_
* __x__ <kbd>Integer</kbd> - x coordinate of origin cell.
* __y__ <kbd>Integer</kbd> - y coordinate of origin cell.
* __dir__ <kbd>Integer</kbd> - Direction of coordinate we want. Range: 1-8

_RETURNS_
* __nx__ <kbd>Integer</kbd> - Neighbors x coordinate.
* __ny__ <kbd>Integer</kbd> - Neighbors y coordinate.

## Picking Functions

These functions handle cell picking, and take world position and map dimensions into account.

### moku.pick_cell(map, map_world_x, map_world_y, pick_world_x, pick_world_y)
Returns the coordinates of a moku map cell given the supplied world coordinates. Moku maps do not (currently) store current world position, so the user must supply this information. Returns nil if the world coordinates fall outside the world dimensions of the supplied moku map.

Example:

```lua
function on_input(self, action_id, action)
    if action_id == hash("left_click") then
        local cam_pos = go.get_position("camera")
        local wx = action.screen_x + cam_pos.x
        local wy = action.screen_y + cam_pos.y
        tx, ty = moku.pick_cell(my_map, my_map_pos_x, my_map_pos_y, wx, wy)

        if tx and ty then
            print("You clicked on the tile at (tx, ty). Good job!)
        else
            print("You clicked outside of the map! Reported.)
        end
    end
end
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __map_world_x__ <kbd>Integer</kbd> - Current pixel x in world cooridnates of maps lower left corner.
* __map_world_y__ <kbd>Integer</kbd> - Current pixel y in world cooridnates of maps lower left corner.
* __pick_world_x__ <kbd>Integer</kbd> - Pixel x in world coordinates we are testing for.
* __pick_world_y__ <kbd>Integer</kbd> - Pixel y in world coordinates we are testing for

_RETURNS_
* __cx__ <kbd>Integer</kbd> - x coordinate of picked tile, nil if none.
* __cy__ <kbd>Integer</kbd> - y coordinate of picked tile, nil if none.

## Auto-tiling functions

These functions handle auto-tiling and the creation of tiling matrices. Currently, to use auto tiling you must supply a tilemap url to your moku map. If you are not using a defold tilemap, you may use the somewhat more cumbersome and expensive, but equally effective, tiling matrices.

### moku.add_auto_tile(map, tile_type, bits, join_self, join_edge, join_nil, joining_types)
This function tells a moku map which `tile_type` should be treated as an auto tile. Once added this tile type will be taken into consideration when using any of the other functions listed under this section. Tile types that have not been added using this function are ignored completely.

You must supply a moku map and a `tile_type` as defined in your `tile_types` table.

You must then decide on which autotiling algorithm you will use. 4-bit or 8-bit. 4-bit autotiling does not take corners into account, and requires only 16 images to work correctly. 8-bit autotiling does take corners into account but requires a whopping 48 images to work correctly. This decision is clearly dependent in your use case. I recommend using 4-bit tiling when possible.

The three joining flags tell moku how this autotile should respond to tiles of its own type, the maps edge, and empty cells in your map, respectively. If set to true the autotiler will consider these cases as "joining tiles" during the autotiling process.

Any additional tile types that should act as valid joining tiles to the original autotile can be added in a list under the `joining_types` argument.

Note that you will not necessarily be using auto tiling for every tile type. Think walls (require auto-tiling) and floors (usually do not).  

Example:

```lua
local tile_types = {
    -- Autotiles
    PLAINS = 1,
    PLATEAU = 49,
    -- Normal Tiles
    OCEAN = 97
}

my_map = moku.new_from_tilemap("map_go#tilemap", 32, 32, tile_types)

-- Adds the PLAINS tile type as an autotile, sets it to use 8-bit autotiling, and instructs moku to treat other PLAINS tiles and the maps edges as joining tiles. Empty tiles will not act as joining tiles. Furthermore, PLATEAU tiles will act as additional joining tiles.
moku.add_auto_tile(my_map, tile_types.PLAINS, 8, true, true, false, {tile_types.PLATEAU})

-- Similar to PLAINS we now add PLATEAU tiles. These act similar to plains, but do not treat PLAINS as joining tiles.
moku.add_auto_tile(my_map, tile_types.PLATEAU, 8, true, true, false)
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __tile_type__ <kbd>Integer</kbd> - Tile type to add as an auto tile.
* __bits__ <kbd>Integer</kbd> - Autotiling algorithm. 4 or 8.
* __join_self__ <kbd>Boolean</kbd> - Whether or not this autotile will join to tiles of its own type.
* __join_edge__ <kbd>Boolean</kbd> - Whether or not this autotile will join to the edge of the map.
* __join_nil__ <kbd>Boolean</kbd> - Whether or not this autotile will join to empty cells of the map.
* __joining_types__ <kbd>Table</kbd> - Further tile types to act as joining tiles, supplied in list form.

### moku.tile_sum(map, x, y)
Returns the calculated binary sum of a supplied tile. This sum corresponds to the correct position of the image within your maps tilesource, after autotiling.

This function is of limited practical use on its own, but is used extensively by other functions in this section.

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __x__ <kbd>Integer</kbd> - x coordinate of cell you want to autotile.
* __y__ <kbd>Integer</kbd> - y coordinate of cell you want to autotile.

_RETURNS_
* __sum__ <kbd>Table</kbd> - Calculated binary sum of this cell.

### moku.auto_tile_cell(map, x, y)
Autotiles the supplied cell. Returns the calculated binary sum of the tile. This sum corresponds to the correct position of the image within your maps tilesource, after autotiling. Probably of limited practical use on its own, but is used extensively by other functions in this section.

Note that your supplied map must have been given a valid `tilemap_url` for this to work, and you must have added at least one auto tile with `moku.add_auto_tile(..)` to see any difference.

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __x__ <kbd>Integer</kbd> - x coordinate of cell you want to autotile.
* __y__ <kbd>Integer</kbd> - y coordinate of cell you want to autotile.

_RETURNS_
* __sum__ <kbd>Table</kbd> - Calculated binary sum of this cell.

### moku.auto_tile_region(map, x, y, width, height)
Autotiles a rectangular region of the supplied moku map, using `x`, `y`, `width`, and `height` as bounds. Probably of limited practical use, but used by other functions in this section.

Note that your supplied map must have been given a valid `tilemap_url` for this to work, and you must have added at least one auto tile with `moku.add_auto_tile(..)` to see any difference.

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __x__ <kbd>Integer</kbd> - x coordinate of bottom left cell of region.
* __y__ <kbd>Integer</kbd> - y coordinate of bottom left cell of region.
* __width__ <kbd>Integer</kbd> - Width of the region.
* __width__ <kbd>Integer</kbd> - Height of the region.

### moku.auto_tile_map(map)
Autotiles the entire supplied moku map.

Note that your supplied map must have been given a valid `tilemap_url` for this to work, and you must have added at least one auto tile with `moku.add_auto_tile(..)` to see any difference.

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.

### moku.auto_tile_surrounding(map, x, y)
Convinience/wrapper function for `moku.auto_tile_region(...)`. Autotiles a 3x3 surrounding region of a supplied central cell. Very useful for real time autotiling!

Note that your supplied map must have been given a valid `tilemap_url` for this to work, and you must have added at least one auto tile with `moku.add_auto_tile(..)` to see any difference.

Example:

```lua
-- This will quickly autotile the changed cell, as well as the surrounding tiles that are affected by the change.
my_map[i][j] = tile_types.WALL
moku.auto_tile_surrounding(my_map, i, j)
```

_PARAMETERS_
* __map__ <kbd>Table</kbd> - A moku map.
* __x__ <kbd>Integer</kbd> - x coordinate of center cell.
* __y__ <kbd>Integer</kbd> - y coordinate of center cell.
--->
