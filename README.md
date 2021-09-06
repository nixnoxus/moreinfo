# MoreInfo

[![ContentDB](https://content.minetest.net/packages/nixnoxus/moreinfo/shields/title/)](https://content.minetest.net/packages/nixnoxus/moreinfo/)
[![ContentDB](https://content.minetest.net/packages/nixnoxus/moreinfo/shields/downloads/)](https://content.minetest.net/packages/nixnoxus/moreinfo/)



MoreInfo mod for [Minetest](http://minetest.net/) 5.4.1 or newer

![Screenshot](screenshot.png)

## Features

- make deaths public via chat message
- shows the direction and distance to
  - spawn point (position of the last used bed)
  - the last 3 bones
- shows infomation about the current player position
  - position
  - map block and offset in the map block
  - current and average speed
  - light level (min..max)
  - biome name, heat (T) and humidity (H)
- shows game infomation
  - game time and a countdown to the next morning or evening
  - player names and their connection time

All features are enabled by default.
The player can change his own settings with chat commands.

```
/moreinfo { + | - }{ any | waypoint | position | game | players | bed | bones }
```

The default values can be changed in `minetest.conf`.

```
moreinfo.public_death_messages = true
moreinfo.bones_limit = 3

moreinfo.display_game_info = true
moreinfo.display_players_info = true
moreinfo.display_position_info = true
moreinfo.display_waypoint_info = true

moreinfo.waypoint_bed = true
moreinfo.waypoint_bones = true
```

## Supported mods

 * `default`, `beds`, `bones` (contained in [Minetest Game](https://github.com/minetest/minetest_game/))
 * `mobs` [mobs_redo](https://notabug.org/TenPlus1/mobs_redo)

# Licencse

Copyright (C) 2021 nixnoxus

Licensed under the GNU LGPL version 2.1 or later.

See [LICENSE.txt](LICENSE.txt) and http://www.gnu.org/licenses/lgpl-2.1.txt

