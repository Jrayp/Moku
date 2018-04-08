# Moku
Map utility/module for the Defold game engine. 

### Documentation

[LDoc generated module documentation](http://htmlpreview.github.io/?https://github.com/Jrayp/Moku/blob/master/doc/index.html)

### Features: 

* Bitmask autotiling partially based on the method outlined here: [How to Use Tile Bitmasking to Auto-Tile Your Level Layouts](https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673). Supports both 4 and 8-bit tiling. Can be used in conjuction with defold tilemaps, or your own custom maps.
* AStar pathfinding with support for options such as heavy diagonals, different heuristics, etc
* Assorted convience functions including cell picking

### Planned features

* Ability to calculate "move distance/area" based on tile weights 

### State

Currently in alpha. Missing some features, and probably buggy. Things are still bound to change.

## Basics

A Moku map is nothing but a two-dimensional table of moku cells. A moku cell is a table of the form

```lua
moku_cell = {
    moku_x = i, -- x coordinate of cell
    moku_y = j, -- y coordinate of cell
    moku_id = k -- tile id of cell
}
```

Of course there is nothing stopping you from adding elements to this table. Just be sure to not overwrite the coordinates or bad things will happen. 

### Creating a new Moku map

A new moku map can be created from scratch using `moku.new(width, height, tile_width, tile_height, on_new_cell)` or built from a Defold tilemap using `new_from_tm(tilemap_url, layer_name, tile_width, tile_height, on_new_cell)`. 

### Moku Id's

The `moku_id` element of a moku cell is a reference to that cells tile "type" (ie walls, floors, forests, mountains). It is good practice to create a bookkeeping table of your tile types, as such:

```lua
local moku_ids = {
    WALL = 1,
    FLOOR = 2,
    WATER = 3,
    -- etc
}
```

Where the `number` value should correspond to that tiles tile sheet image id (In the above example, the tilesheets first image would be a wall, and so on). When working with auto-tiles, it is important you use the correct image id. This is explained in the auto-tiling section, below.

**NOTE: Your Moku maps cells should generally only have moku_id values that are also found in your moku_ids table!**

That is, given the above set of Moku id's, no cell in a moku map should have `moku_id` other than 1, 2 or 3.

By the way, it may also be good practice to keep a reference of the `moku_ids` table on your moku map: `my_moku_map.moku_ids = moku_ids`.

This allows one to easily and safely change Moku id's as such:

```lua
-- Moku cells are accessable using indexers
moku_map[i][j].moku_id = moku_map.moku_ids.WALL
```

### Bounds and Dimensions

Moku keeps track of "bounds" and "dimensional" data. Bounds here, is referring to a maps bottom left corner cell coordinate (negative coordinates are fully supported) and the maps width and height in cells. Dimensions on the other hand refer to world space dimensions in pixels, calculated from the bounds data and your entered tile sizes. Dimensional data is used for things such as cell picking etc. 

```lua
-- Prints the bottom left cells x, y coordinates
print(moku_map.bounds.x, moku_map.bounds.y)

-- Prints the maps width and height in cells
print(moku_map.bounds.width, moku_map.bounds.height)

-- Prints the tile width and height in pixels, as passed in the constructor
print(moku_map.dimensions.tile_width, moku_map.dimensions.tile_height)

-- Prints the maps total width and height in pixels
print(moku_map.dimensions.world_width, moku_map.dimensions.world_height)
```

### Internal data

Lastly Moku maps have an element 'moku_map.internal' which is meant for internal use (duh). Don't mess with it :P

## Using the auto tiler

![](doc/transition.png)

Moku auto-tiling can be very easy to use, depending on use case. More involved needs will require more involved setup. However, for simple defold tilemap autotiling, very little work is required. Please refer to [How to Use Tile Bitmasking to Auto-Tile Your Level Layouts](https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673) if in doubt, as mokus autotiler is based on that article. For this guide we will use 8-bit (Complex) tiling, but 4-bit (Simple) tiling works mostly the same way.

### Tile sheet layout

First, your sprite sheet containing your maps tile images must be in a specific layout. In the following tile sheet from the demo project, we have three base tile types: Plains, plateau, and ocean. (This is a modified version of the tile sheet used in the article linked above.) 

![](main/images/autotiles_8bit.png)

Since the plains and plateau types will be designated 8-bit autotiles, they consist of a total of 48 individual images, each corresponding to a particular border configuration. Any tile you wish to designate a complex autotile must have 48 images reserved on your tile sheet in _exactly_ this order, beginning with what I will call the tiles "base image" (the image of a completely surrounded tile).

Note that you may place your autotiles anywhere on your tilesheet, as long as the following 47 images are in the correct order. Mokus incredibly advanced AI can handle this. 

The ocean tile does not require autotile functionality, and can be freely placed anywhere on your tile sheet.

Also note that if we were using simple tiling that everything would work the same, except that we would only require a much more managable 16 images per autotile. Following is the (much nicer) layout of a simple autotile tilesheet:

![](main/images/simple_layout.png)

### Auto tiling a tilemap

In defold, add a tilemap to your collection that references a tilesource derived from your tile sheet. Go ahead and draw on it, but be sure to use only the above mentioned base tiles for drawing (that is the first image related to the tile type). 

![](doc/before.PNG)

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

Create a Moku map from your defold tilemap. Assuming your tilemap is named `my_tilemap` and is attached to the gameobject `map_go`:

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
7. An optional list of other tile types that the autotile will interact/join to 

So in our example, the `PLAINS` type will interact/join with everything except `OCEAN` tiles; and the `PLATEAU` type will interact with everything except `OCEAN` and `PLAINS` tiles.

And now we can tell moku to tile the map:

```lua
moku.autotile_map(my_new_map)
```

![](doc/after.PNG)

Thats it. Much more can be done, but this guide should be enough to at least get an idea of how Moku autotiling works, and should be sufficient for the vast majority of use cases. Following is the complete example code:

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
