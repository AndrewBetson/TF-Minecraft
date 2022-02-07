An overhaul of the [TF2_Minecraft](https://github.com/MoonlyDays/TF2_MinecraftBlocks) plugin by [MoonlyDays](https://github.com/MoonlyDays) that adds several pages of new blocks, per-block build/break sound fx, and more.

New Features
==================
- New blocks, such as: every color of concrete, mushroom stem, red/brown mushroom block, and a new (*very* unfunny) secret block.
- Blocks can now have unique build/break sound fx.
- Build/break sound fx are now played as (quiet) world sounds that *every* nearby player can hear, instead of just the builder/breaker.
- Players can no longer grief teleporters by building blocks near or above them.
- Blocks can now be broken with *all* melee weapons, not just ones that use hit sounds with a specific naming scheme.
- Breaking blocks with melee attacks can now be toggled via the `sv_mc_melee_break` convar.
- Blocks can now be built on the bottom of other blocks.
- Blocks now store the Steam2 ID of the player that built them, allowing both staff and players alike to more easily figure out who built something rule-breaking.
- Previously hard-coded messages are now translatable.
- Block names are now translatable.
- A rudimentary, clientpref-based ban system has been implemented.
- Texture sizes have been reduced across the board from 512x256 to 16x16 or 64x32, depending on the block type.

Console Elements
==================
This plugin exposes the following console elements:
| Name | Description | Default | Notes |
|------|------|------|------|
| `sv_mc_block_limit` | Number of blocks that can exist in the world at a time. | 256 | Shouldn't be raised higher than 256, unless you want your server to be on the brink of crashing 24/7 |
| `sv_mc_melee_break` | Allow players to break blocks by hitting them with melee weapons. | 1 | None |
| `sm_mc_build`/`sm_build` | Builds a block under the calling players crosshair. | N/A | Calling player must not be block-banned |
| `sm_mc_break`/`sm_break` | Breaks the block under the calling players crosshair. | N/A | Calling player must not be block-banned |
| `sm_mc_block`/`sm_block` | Allows the calling player to select a block. | N/A | None |
| `sm_mc_howmany`/`sm_limit` | Print the current number of blocks in the world to the calling player. | N/A | None |
| `sm_mc_builtby` | Print the SteamID of the player that built the block under the calling players cursor. | N/A | None |
| `sm_mc_credits` | Print the credits for this plugin to the calling players chat. | N/A | None |
| `sm_mc_ban` | Ban a player from being able to build and break blocks. | N/A | Requires >= ADMFLAG_BAN command privilege |
| `sm_mc_unban` | Allow a player to build and break blocks again. | N/A | Requires >= ADMFLAG_UNBAN command privilege |

License
==================
This plugin, for the time being, retains the original versions MIT licensing.  
The Minecraft content included in this repo is released under the terms of the "hope neither Mojang nor Microsoft notice or care" license.

Dependencies
==================
- [DHooks](https://forums.alliedmods.net/showthread.php?p=2588686#post2588686) (*SM <1.11.6820 only*)
- [morecolors](https://raw.githubusercontent.com/DoctorMcKay/sourcemod-plugins/master/scripting/include/morecolors.inc) (*compilation only*)

Original README
==================

# Minecraft Blocks in Team Fortress 2
### Commands
- sm_block [id] - Selects a block to build with
- sm_build - Builds selected block
- sm_break - Break a block under the crosshair
- sm_limit - Displays current block amount on map
- sm_clearblocks (Ban Flag) - Clears all blocks on map

### ConVars
- sm_minecraft_block_limit (256 default) - Maximum amount of blocks per map

### Features
- You can build with variety of blocks
- Break blocks with melees
- Due to the edict limit maximum amount of concurrent build blocks is 256

### Installation
- minecraft.smx in addons/sourcemod/plugins
- minecraft.sp in addons/sourcemod/scripting
- blocks.cfg in addons/sourcemod/configs
- upload models, materials and sound to your fastdl and server root tf folders
- sm plugins load minecraft or restart the server

### About limiting
Source engine can handle a maximum amount of 2048 blocks in total. If entities will overflow this limit the server will crash.

Every block is a single prop, but every prop itself is an entity. This plugin allows you to freely spawn any amount of entities so its really easy to crash your server.

That's why limit exists. It prevents crashing your server due to edict/entity overflow. 
