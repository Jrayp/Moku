# Moku
Map utility &amp; auto-tile module for the Defold game engine. Partially based on the method outlined here: https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673

## State
Currently in very early, untested alpha. Missing features, probably a bit unwieldy, unintuitive, and busted. Will be made PERFECT.. maybe.

## Usage
This is just a quick, semi-useless guide to get started. I will add individual function descriptions later. For now refer to the demo project.

To use moku, first require the module.

```lua
local moku = require "moku/moku"
```

To create a new map use either 

```lua
moku.new(width, height, tile_width, tile_height, tile_types, fill_type, tilemap_url)
```

or 

```lua
moku.new_from_tilemap(tilemap_url, tile_width, tile_height, tile_types)
```

The latter will automatically build a moku map from a supplied tilemap, created in the defold editor. I will assume that this is the option used for the remainder of this brief guide. (For now)

Here, `tile_width` and `tile_height` refer to the pixel dimensions of your supplied tiles. This is needed for cell picking and other size/dimension related functionality. 

`tile_types` is a table of the form:

 ```lua
     local tile_types = {
        AUTO_TILE_1 = 1,
        AUTO_TILE_2 = 49,

        NORMAL_TILE = 97
    }
```
    
Where the keys are decided on by the user, and the values refer to the id of the associated base tile in the tilesource containing your map tiles. I'll explain what I mean by base tile at a later date.

To use the auto tiler, you must tell moku which tile types should use the functionality. You do this by using

```lua
moku.add_auto_tile(map, tile_type, bits, include_self, include_border, include_nil, additional_types)
```
Where `map` is the map you created earlier and `tile_type` is the tile type youre designating an auto tile. `bits` tells moku whether to use 4 or 8-bit directional values as outlined in the above link (as such it takes 4 or 8 as an argument, anything else will implode the universe). Setting `include_self`, `include_border`, or `include_nil` to true will instruct moku to treat tiles of its own type, "borders" (the edge of the map) and "nil tiles" (empty cells of the map) respectively, as valid neighbor types to attach too. Further tile types can be made to act as valid neighbor types by passing a table of them via `additional_types`.

Now to autotile your map, simply call

```lua
moku.auto_tile_map(map)
```

There is more functionality, and a lot of nuances, but for now, this is the usage guide you get. :P

(Oh, you should probably make sure that your tilesheet follows the same format as those in the demo project. Again this will be explained later.)

## Functions

### moku.new(width, height, tile_width, tile_height, tile_types, fill_type, [tilemap_url])
Creates a new moku map from scratch. The `tile_types` argument must be of a specific form as shown in the example. The keys are chosen by the user, and should be descriptive names of the tiles that your moku map uses. Thier associated values are the integer positions of that tile types base tile image in a tile source.

Example:

 ```lua
 local tile_types = {
    WALL = 1,
    YELLOW_WALL = 17,
    FLOOR = 16
 }
 
local my_map = moku.new(8, 8, 32, 32, tile_types, tile_types.FLOOR)
```

_PARAMETERS_
* __width__ <kbd>Integer</kbd> - Width of the new map in cells.
* __height__ <kbd>Integer</kbd> - Height of the new map in cells.
* __tile_width__ <kbd>Integer</kbd> - Width of individual tiles/cells in pixels.
* __tile_height__ <kbd>Integer</kbd> - Width of individual tiles/cells in pixels.
* __tile_types__ <kbd>Table</kbd> - A table of keys and integer values representing different tile types.
* __fill_type__ <kbd>Integer</kbd> - The initial tile type (defined in the previous table) of the cells in the new map.  
* __tilemap_url__ <kbd>String</kbd> - Optional path to a defold tilemap. Required for auto-tiling, but not required for creating tiling matrices, explained below. 
