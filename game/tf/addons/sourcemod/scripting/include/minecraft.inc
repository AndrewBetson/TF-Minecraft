/**
 * Copyright Andrew Betson.
 * Copyright Moonly Days.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#if defined _minecraft_included
	#endinput
#endif // defined _minecraft_included

#define _minecraft_included

/** A category of blocks as defined in minecraft_blocks.cfg */
enum struct BlockCategory_t
{
	int		nIndex;				/**< Index of this category in the block category menu. */
	int		nNumBlockDefs;		/**< Number of block definitions contained within this category. */
	char	szPhrase[ 64 ];		/**< Localization key used for the name of this category. */
}

/** A block as defined in minecraft_blocks.cfg */
enum struct BlockDef_t
{
	int		nCategoryIdx;		/**< Index of the category to display this block in. */
	int		nIndex;				/**< Index of this block in the block menu relative to its parent menu(s). */
	char	szPhrase[ 64 ];		/**< Localization key used for the name of this block. */
	char	szModel[ 64 ];		/**< Path to the model used for this block. */
	char	szMaterial[ 64 ];	/**< Path, relative to materials/models/minecraft/, to the material used for this block. */
	char	szBuildSound[ 64 ];	/**< Path to the sound to play when this block is built. */
	char	szBreakSound[ 64 ];	/**< Path to the sound to play when this block is broken. */
	int		nSkin;				/**< Skin index to use for this block. */
	int		nLimit;				/**< Maximum number of this block type that can exist in the world at a time. 0/-1 = no limit. */
	bool	bOrientToPlayer;	/**< Rotate this block in 90 degree increments to face the builder. */
	bool	bEmitsLight;		/**< Spawn a light_dynamic entity at this blocks origin. */
}

/** A block as it exists in the world. */
enum struct WorldBlock_t
{
	int		nEntityRef;			/**< Reference to the entity index used by this blocks model. */
	int		nBlockIdx;			/**< Block type index in g_hBlockDefs. */
	bool	bProtected;			/**< Whether this block is protected or not. */
	float	vOrigin[ 3 ];		/**< Location in the world. */
	int		nBuilderClientIdx;	/**< Client index of the player that built this block. */

	/** Check if this block is of a particular type. */
	bool IsOfType( const int nInBlockIdx )
	{
		return this.nBlockIdx == nInBlockIdx;
	}

	/** Check if this block is at a particular world origin. */
	bool IsAtOrigin( const float vInOrigin[ 3 ] )
	{
		return GetVectorDistance( this.vOrigin, vInOrigin ) <= 0.1;
	}
}

/**
 * Broadcast when a block is built by a client.
 *
 * @param nBuilderClientIdx	Client attempting to build a block.
 * @param hBlockDef			Index in the array of block defs of the block the client is attempting to build.
 *
 * @return Plugin_Handled or Plugin_Stop to prevent the block from being built, Plugin_Continue to allow it.
 */
forward Action MC_OnClientBuildBlock( int nBuilderClientIdx, int nBlockDefIdx );

/**
 * Broadcast when a block is broken by a client.
 *
 * @param nBreakerClientIdx	Client attempting to break a block.
 * @param nWorldBlockIdx	Index in the array of world blocks of the block the client is attempting to break.
 *
 * @note Use MC_GetWorldBlock to retrieve the actual block being broken.
 *
 * @return Plugin_Handled or Plugin_Stop to prevent the block from being broken, Plugin_Continue to allow it.
 */
forward Action MC_OnClientBreakBlock( int nBreakerClientIdx, int nWorldBlockIdx );

/**
 * Get a block definition from the array of block definitions by index.
 *
 * @param nBlockDefIdx	Index in the array of block defs to retrieve.
 * @param hBlockDef		Any array to store block def data in.
 *
 * @return SP_ERROR_NONE on success, anything else on failure.
 */
native int MC_GetBlockDef( int nBlockDefIdx, any[] hBlockDef, int nSizeOfBlockDef = sizeof( BlockDef_t ) );

/**
 * Get a world block from the array of world blocks by index.
 *
 * @param nWorldBlockIdx	Index in the array of world blocks to retrieve.
 * @param hWorldBlock		Any array to store world block data in.
 *
 * @return SP_ERROR_NONE on success, anything else on failure.
 */
native int MC_GetWorldBlock( int nWorldBlockIdx, any[] hWorldBlock, int nSizeOfWorldBlock = sizeof( WorldBlock_t ) );

public SharedPlugin __pl_minecraft =
{
	name		= "minecraft",
	file		= "minecraft.smx",
#if defined REQUIRE_PLUGIN
	required	= 1,
#else
	required	= 0,
#endif // defined REQUIRE_PLUGIN
}

#if !defined REQUIRE_PLUGIN
public void __pl_minecraft_SetNTVOptional()
{
	MarkNativeAsOptional( "MC_GetBlockDef" );
	MarkNativeAsOptional( "MC_GetWorldBlock" );
}
#endif // !defined REQUIRE_PLUGIN
