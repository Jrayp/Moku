# Moku
Map utility &amp; auto-tile module for the Defold game engine. Partially based on the method outlined here: https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673

## State
Currently in very early, untested alpha. Missing features, probably a bit unwieldy, unintuitive, and busted. Will be made PERFECT.. maybe.

## Moku Functions

### Constructor Functions

#### moku.new(width, height, tile_width, tile_height, tile_types, fill_type, [tilemap_url])
Creates a new moku map from scratch. The `tile_types` argument must be of a specific form as shown in the example. The keys are chosen by the user, and should be descriptive names of the tiles that your moku map uses. Their associated values are the integer positions of that tiles base tile image in a tile source.

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

#### moku.new_from_tilemap(tilemap_url, tile_width, tile_height, tile_types)
Creates a new moku map from a defold tilemap. When drawing your tilemap in the editor, use only the tiles base image for auto tiles.

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

### Iterator Functions

#### moku.iterate_region(map, x, y, width, height, [fn])
Iterates a rectangular region of the supplied moku map, using `x`, `y`, `width`, and `height` as bounds. An optional function `fn` can be supplied to filter results.

Example (assuming a `tile_types` table has been constructed and declared):

```lua
local function is_plains(v)
    return v == tile_types.PLAINS
end

for x, y, v in moku.iterate(my_map, 5, 5, 3, 3, is_plains) do
    -- Change all plains tiles in the supplied rectangle to ocean tiles.
    map[x][y] = tile_types.OCEAN
end
```
