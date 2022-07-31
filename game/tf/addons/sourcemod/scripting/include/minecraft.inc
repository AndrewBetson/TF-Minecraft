/**
 * Copyright (c) 2019 Moonly Days.
 * Copyright Andrew Betson.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, and/or distribute copies of
 * the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#if defined _minecraft_included
	#endinput
#endif // defined _minecraft_included

#define _minecraft_included

/** A block as defined in minecraft_blocks.cfg */
enum struct BlockDef_t
{
	int		nIndex;				/**< Index of this block in the block menu. */
	char	szPhrase[ 32 ];		/**< Localization key used for the name of this block. */
	char	szModel[ 32 ];		/**< Path to the model used for this block. */
	char	szMaterial[ 32 ];	/**< Path, relative to materials/models/minecraft/, to the material used for this block. */
	char	szBuildSound[ 64 ];	/**< Path to the sound to play when this block is built. */
	char	szBreakSound[ 64 ];	/**< Path to the sound to play when this block is broken. */
	int		nSkin;				/**< Skin index to use for this block. */
	int		nLimit;				/**< Maximum number of this block type that can exist in the world at a time. 0/-1 = no limit. */
	bool	bOrientToPlayer;	/**< Rotate this block in 90 degree increments to face the builder. */
	bool	bEmitsLight;		/**< Spawn a light_dynamic entity at this blocks origin. */
	bool	bHidden;			/**< Don't display this block in the block menu. */
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
 * @param hBlockDef			Type of block the client is attempting to build.
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
 */
native int MC_GetBlockDef( int nBlockDefIdx, any[] hBlockDef, int nSizeOfBlockDef = sizeof( BlockDef_t ) );

/**
 * Get a world block from the array of world blocks by index.
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
