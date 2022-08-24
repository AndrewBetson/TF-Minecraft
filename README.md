An overhaul of the [TF2_Minecraft](https://github.com/MoonlyDays/TF2_MinecraftBlocks) plugin by [MoonlyDays](https://github.com/MoonlyDays) that adds several pages of new blocks, per-block build/break sound fx, and more.

New Features
==================
- Over 132 new blocks.
- Blocks can now have unique build/break sound fx.
- Build/break sound fx are now played as world sounds that nearby players can hear, instead of just the builder/breaker.
- Non-staff players can no longer grief teleporters by building blocks near or above them.
- Blocks can now be broken with *all* melee weapons, not just ones that use hit sounds with a specific naming scheme.
- Breaking blocks with melee attacks can now be toggled via the `sv_mc_melee_break` convar.
- Blocks can now be built on the bottom of other blocks.
- Blocks now store the name and Steam2 ID of the player that built them, allowing both staff and non-staff players alike to more easily figure out who built something rule-breaking.
- Previously hard-coded messages are now translatable.
- Block names are now translatable.
- A rudimentary, clientpref-based ban system.
- Staff can now mark blocks as "protected", making them unbreakable to any non-staff players.
- Texture sizes have been reduced across the board from 512x256 to 16x16 or 64x32, depending on the block type.
- Optional integration with [TrustFactor](https://github.com/DosMike/SM-TrustFactor) by reBane/DosMike.

Console Elements
==================
This plugin exposes the following console elements:
| Name | Description | Default | Notes |
|------|------|------|------|
| `sv_mc_block_limit` | Number of blocks that can exist in the world at a time. | 256 | Consider using map configs to raise/lower this per-map. |
| `sv_mc_melee_break` | Allow players to break blocks by hitting them with melee weapons. | 1 | None |
| `sv_mc_remove_blocks_on_disconnect` | Remove blocks built by players when they leave the server. | 0 | None |
| `sv_mc_auto_protect_staff_blocks` | Automatically protect blocks built by staff players. | 1 | None |
| `sv_mc_dynamiclimit` | Enable the use of a dynamic block limit based on the number of entities in the map and the servers `sv_lowedict_threshold` value. | 0 | None |
| `sv_mc_dynamiclimit_bias` | Constant number to subtract from resolved dynamic limit to account for post-map load edicts such as players. | 500 | Servers with lower maxplayer counts may want to lower this. |
| `sv_mc_dynamiclimit_threshold` | If the resolved limit is lower than this number, disable the plugin until the next mapchange. | 50 | None |
| `sv_mc_trustfactor_enable` | Whether or not to make use of the TrustFactor plugin by reBane/DosMike if it is detected. | 1 | Requires the TrustFactor plugin be installed. |
| `sv_mc_trustfactor_flags` | Which trust factor flag(s) to use. | "t" | See the TrustFactor documentation for a list of flags and their effects. |
| `sm_mc_build`/`sm_build` | Builds a block under the calling players crosshair. | N/A | Calling player must not be block-banned |
| `sm_mc_break`/`sm_break` | Breaks the block under the calling players crosshair. | N/A | Calling player must not be block-banned |
| `sm_mc_block(s)`/`sm_block(s)` | Allows the calling player to select a block. | N/A | None |
| `sm_mc_pick` | Select the block under the calling players cursor. | N/A | None |
| `sm_mc_buildmode` | Enable buildmode on the calling player. | N/A | None |
| `sm_mc_howmany`/`sm_limit` | Print the current number of blocks in the world to the calling player. | N/A | None |
| `sm_mc_builtby` | Print the SteamID of the player that built the block under the calling players cursor. | N/A | None |
| `sm_mc_credits` | Print the credits for this plugin to the calling players chat. | N/A | None |
| `sm_mc_banstatus` | Tell the calling player whether they are block-banned or not. | N/A | None |
| `sm_mc_ban` | Ban a player from being able to build and break blocks. | N/A | Requires >= ADMFLAG_BAN command privilege |
| `sm_mc_unban` | Allow a player to build and break blocks again. | N/A | Requires >= ADMFLAG_UNBAN command privilege |
| `sm_mc_clear` | Clear all blocks, optionally of a specific type (by index), from the world. | N/A | Requires >= ADMFLAG_BAN command privilege. |
| `sm_mc_clear_player` | Clear all blocks built by a specific player. | N/A | Required >= ADMFLAG_BAN command privilege. |
| `sm_mc_disable` | Disable the building and breaking of blocks until the next mapchange. | N/A | Requires >= ADMFLAG_BAN command privilege. |
| `sm_mc_protect` | Protect a block from being broken by any non-staff players if it's not already protected, remove protections otherwise. | N/A | Requires >= ADMFLAG_BAN command privilege. |

Dependencies
==================

- [TrustFactor](https://github.com/DosMike/SM-TrustFactor) (*optional*)
- [GraviHands](https://github.com/DosMike/TF2-GraviHands) (*optional, only recommended if compiling for a server that uses it*)
- [morecolors](https://raw.githubusercontent.com/DoctorMcKay/sourcemod-plugins/master/scripting/include/morecolors.inc) (*compilation only*)

License
==================
This plugin is released under version 3 of the GNU Affero General Public License. For more info, see `LICENSE.md`.
The Minecraft content included in this repo is released under the terms of the "hope neither Mojang nor Microsoft notice or care" license.

TODO
==================
- Expand plugin API to allow other plugins to define new categories and blocks.
- Find a way to allow players to use the grappling hook while in buildmode.
- Look into `TR_GetPlaneNormal` for more robust block-on-block building.
- Document the arduous process of adding a new block type.

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
