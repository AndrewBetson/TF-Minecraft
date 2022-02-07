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

#define MAXBLOCKINDICES 129

char g_szBaseMaterialVMT[]	= "materials/models/minecraft/%s.vmt";
char g_szBaseMaterialVTF[]	= "materials/models/minecraft/%s.vtf";

/** @brief A block as defined in minecraft_blocks.cfg */
enum struct BlockDef_t
{
	/** @brief Index of this block in the block menu. */
	int		nIndex;

	/**
	 * @brief Translation phrase for the name of this block.
	 *
	 * @note See minecraft_blocks.phrases.txt
	 */
	char	szPhrase[ 32 ];

	/** @brief Model used for this block. */
	char	szModel[ 32 ];

	/**
	 * @brief Material used for this block.
	 *
	 * @note Relative to materials/models/minecraft/
	 */
	char	szMaterial[ 32 ];

	/** @brief Sound to play when a player builds this block. */
	char	szBuildSound[ 64 ];

	/** @brief Sound to play when a player breaks this block. */
	char	szBreakSound[ 64 ];

	/** @brief Skin index to use for this block. */
	int		nSkin;

	/**
	 * @brief Maximum number of blocks of this type that can exist at a time.
	 *
	 * @note Setting this to -1 or not defining it = no limit.
	 */
	int		nLimit;

	/** @brief Rotate this block to face the player. (furnace, chest, Steve head, etc.) */
	bool	bOrientToPlayer;

	/** @brief Spawn a light_dynamic entity in the center of this block. */
	bool	bEmitsLight;

	/** @brief Don't display this block in the block select menu. */
	bool	bHidden;
}

BlockDef_t	g_BlockDefs[ MAXBLOCKINDICES ];
int			g_nNumBlocksInWorld;
int			g_nSelectedBlock[ MAXPLAYERS + 1 ] = { 1, ... };

ConVar		sv_mc_block_limit;
ConVar		sv_mc_melee_break;

bool		g_bPluginDisabled = false;

void OnPluginStart_Blocks()
{
	sv_mc_block_limit = CreateConVar( "sv_mc_block_limit", "256", "Number of blocks that can exist in the map at a time.", FCVAR_NOTIFY );
	sv_mc_melee_break = CreateConVar( "sv_mc_melee_break", "1", "Allow players to break blocks by hitting them with melee weapons.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );

	RegConsoleCmd( "sm_mc_build", Cmd_MC_Build, "Build currently selected block." );
	RegConsoleCmd( "sm_mc_break", Cmd_MC_Break, "Break block under cursor." );
	RegConsoleCmd( "sm_mc_block", Cmd_MC_Block, "Select a block." );
	RegConsoleCmd( "sm_mc_howmany", Cmd_MC_HowMany, "Print the current number of blocks in the world." );
	RegConsoleCmd( "sm_mc_builtby", Cmd_MC_BuiltBy, "Print the SteamID of the player that built the block under the calling players cursor." );
	RegConsoleCmd( "sm_mc_credits", Cmd_MC_Credits, "Print the credits for this plugin." );

	// Backwards compatible commands so people don't have to update their binds,
	// and staff on servers upgrading from the original plugin don't get inundated
	// with questions about "where the Minecraft plugin went".
	RegConsoleCmd( "sm_build", Cmd_MC_Build, "Build current selected block." );
	RegConsoleCmd( "sm_break", Cmd_MC_Break, "Break block under cursor." );
	RegConsoleCmd( "sm_block", Cmd_MC_Block, "Select a block." );
	RegConsoleCmd( "sm_limit", Cmd_MC_HowMany, "Display current number of blocks in the world." );

	RegAdminCmd( "sm_mc_clear", Cmd_MC_Clear, ADMFLAG_BAN, "Remove all Minecraft blocks, optionally of a specific type, from the world." );
	RegAdminCmd( "sm_mc_disable", Cmd_MC_Disable, ADMFLAG_BAN, "Disable the building and breaking of Minecraft blocks until the next mapchange." );

	LoadConfig();
}

void OnMapStart_Blocks()
{
	g_bPluginDisabled = false;
	g_nNumBlocksInWorld = 0;

	int nBlock;
	while ( ( nBlock = FindEntityByClassname( nBlock, "prop_dynamic" ) ) != INVALID_ENT_REFERENCE )
	{
		if ( IsValidBlock( nBlock ) )
		{
			AcceptEntityInput( nBlock, "Kill", -1, -1 );
		}
	}
	g_nNumBlocksInWorld = 0;

	PrecacheContent();
}

void OnClientPostAdminCheck_Blocks( int nClientIdx )
{
	g_nSelectedBlock[ nClientIdx ] = 1;
	if ( g_bIsBanned[ nClientIdx ] )
	{
		CheckClientBan( nClientIdx );
	}
}

public Action Cmd_MC_Build( int nClientIdx, int nNumArgs )
{
	if( !( 0 < nClientIdx <= MaxClients ) )
	{
		return Plugin_Handled;
	}

	// Check if player is alive and in-game
	if ( !IsClientInGame( nClientIdx ) )
	{
		return Plugin_Handled;
	}

	if ( g_bPluginDisabled )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Disabled" );
		ClientCommand( nClientIdx, "playgamesound common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	if ( !IsPlayerAlive( nClientIdx ) )
	{
		CPrintToChat( nClientIdx, "%t", "MC_MustBeAlive" );
		ClientCommand( nClientIdx, "playgamesound common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	if ( g_bIsBanned[ nClientIdx ] )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Banned" );
		ClientCommand( nClientIdx, "playgamesound common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	// Clamp selected block to valid range.
	if ( g_nSelectedBlock[ nClientIdx ] < 1 )	g_nSelectedBlock[ nClientIdx ] = 1;
	if ( g_nSelectedBlock[ nClientIdx ] > 128 )	g_nSelectedBlock[ nClientIdx ] = 128;

	if ( g_nNumBlocksInWorld >= sv_mc_block_limit.IntValue )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_TooManyBlocks", sv_mc_block_limit.IntValue );
		return Plugin_Handled;
	}

	int nSelected = g_nSelectedBlock[ nClientIdx ];

	if( g_BlockDefs[ nSelected ].nLimit != -1 )
	{
		if ( Block_GetLimitForType( nSelected ) >= g_BlockDefs[ nSelected ].nLimit )
		{
			CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_TooManyOfType", g_BlockDefs[ nSelected ].nLimit );
			return Plugin_Handled;
		}
	}

	// Try to find a valid location to build the block at.

	float vClientEyeOrigin[ 3 ];
	float vClientEyeAngles[ 3 ];
	float vHitPoint[ 3 ];
	GetClientEyePosition( nClientIdx, vClientEyeOrigin );
	GetClientEyeAngles( nClientIdx, vClientEyeAngles );

	TR_TraceRayFilter( vClientEyeOrigin, vClientEyeAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_NotPlayer );

	if ( TR_DidHit( INVALID_HANDLE ) )
	{
		TR_GetEndPosition( vHitPoint, INVALID_HANDLE );
	}

	// Snap the blocks location to a 50x50x50 grid.

	vHitPoint[ 0 ] = RoundToNearest( vHitPoint[ 0 ] / 50.0 ) * 50.0;
	vHitPoint[ 1 ] = RoundToNearest( vHitPoint[ 1 ] / 50.0 ) * 50.0;
	vHitPoint[ 2 ] = RoundToNearest( vHitPoint[ 2 ] / 50.0 ) * 50.0;

	if ( GetVectorDistance( vClientEyeOrigin, vHitPoint ) > 300.0 )
	{
		ClientCommand( nClientIdx, "playgamesound common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	if ( Block_IsBlockAtOrigin( vHitPoint ) )
	{
		// Player is likely trying to build on the bottom of another block,
		// so just shift the z-coord down by the height of a block.
		vHitPoint[ 2 ] -= 50.0;

		// Check new end point to handle edge cases.
		if ( Block_IsBlockAtOrigin( vHitPoint ) )
		{
			ClientCommand( nClientIdx, "playgamesound common/wpn_denyselect.wav" );
			return Plugin_Handled;
		}
	}

	if ( Block_IsPlayerNear( vHitPoint ) )
	{
		ClientCommand( nClientIdx, "playgamesound common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	if ( Block_IsTeleporterNear( vHitPoint ) )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Teleporter" );
		ClientCommand( nClientIdx, "playgamesound common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	int nEnt = CreateEntityByName( "prop_dynamic_override" );
	if ( IsValidEdict( nEnt ) )
	{
		float vBlockAngles[ 3 ];
		if ( g_BlockDefs[ nSelected ].bOrientToPlayer )
		{
			vBlockAngles[ 1 ] = ( RoundToNearest( vClientEyeAngles[ 1 ] / 90.0 ) * 90.0 ) + 90.0;
		}
		TeleportEntity( nEnt, vHitPoint, vBlockAngles, NULL_VECTOR );

		SetEntProp( nEnt, Prop_Send, "m_nSkin", g_BlockDefs[ nSelected ].nSkin );
		SetEntProp( nEnt, Prop_Send, "m_nSolidType", 6 );

		char szClientAuthString[ MAX_NAME_LENGTH ];
		GetClientAuthId( nClientIdx, AuthId_Steam2, szClientAuthString, sizeof( szClientAuthString ) );

		DispatchKeyValue( nEnt, "built_by", szClientAuthString );

		char szBlockIdx[ 4 ];
		IntToString( nSelected, szBlockIdx, sizeof( szBlockIdx ) );

		DispatchKeyValue( nEnt, "block_id", szBlockIdx );

		SetEntityModel( nEnt, g_BlockDefs[ nSelected ].szModel );

		DispatchSpawn( nEnt );
		ActivateEntity( nEnt );

		if( g_BlockDefs[ nSelected ].bEmitsLight )
		{
			int nEntLight = CreateEntityByName( "light_dynamic" );
			if ( IsValidEdict( nEntLight ) )
		    {
		        DispatchKeyValue( nEntLight, "_light", "250 250 200" );
		        DispatchKeyValue( nEntLight, "brightness", "5" );
		        DispatchKeyValueFloat( nEntLight, "spotlight_radius", 280.0 );
		        DispatchKeyValueFloat( nEntLight, "distance", 180.0 );
		        DispatchKeyValue( nEntLight, "style", "0" );
		        DispatchSpawn( nEntLight );
		        ActivateEntity( nEntLight );

		        float vLightPos[ 3 ];
		        vLightPos[ 0 ] = vHitPoint[ 0 ];
		        vLightPos[ 1 ] = vHitPoint[ 1 ];
		        vLightPos[ 2 ] = vHitPoint[ 2 ] + 25.0;

		        TeleportEntity( nEntLight, vLightPos, NULL_VECTOR, NULL_VECTOR );

		        SetVariantString( "!activator" );
		        AcceptEntityInput( nEntLight, "SetParent", nEnt, nEntLight );
		        AcceptEntityInput( nEntLight, "TurnOn" );
		    }
		}

		EmitAmbientSound( g_BlockDefs[ nSelected ].szBuildSound, vHitPoint, nEnt, SNDLEVEL_NORMAL );
		g_nNumBlocksInWorld++;

		SDKHook( nEnt, SDKHook_OnTakeDamage, Block_OnTakeDamage );
	}

	return Plugin_Handled;
}

public Action Cmd_MC_Break( int nClientIdx, int nNumArgs )
{
	if ( g_bPluginDisabled )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Disabled" );
		return Plugin_Handled;
	}

	if ( g_bIsBanned[ nClientIdx ] )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Banned" );
		ClientCommand( nClientIdx, "playgamesound common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	if ( IsPlayerAlive( nClientIdx ) )
	{
		Block_TryBreak( nClientIdx );
	}

	return Plugin_Handled;
}

public Action Cmd_MC_Block( int nClientIdx, int nNumArgs )
{
	Menu menu = new Menu( Menu_BlockSelect, MENU_ACTIONS_ALL );
	menu.SetTitle( "%t", "MC_BlockMenu_Title" );

	if( nNumArgs >= 1 )
	{
		char szIndex[ 4 ];
		GetCmdArg( 1, szIndex, sizeof( szIndex ) );
		Block_Select( nClientIdx, StringToInt( szIndex ) );
	}
	else
	{
		for ( int nIdx = 0; nIdx < MAXBLOCKINDICES; nIdx++ )
		{
			if ( g_BlockDefs[ nIdx ].nIndex <= 0 || g_BlockDefs[ nIdx ].bHidden )
			{
				continue;
			}
			char szIndex[ 4 ];
			IntToString( nIdx, szIndex, sizeof( szIndex ) );
			menu.AddItem( szIndex, g_BlockDefs[ nIdx ].szPhrase );
		}
	}

	menu.ExitButton = true;
	menu.Display( nClientIdx, 32 );

	return Plugin_Handled;
}

public Action Cmd_MC_HowMany( int nClientIdx, int nNumArgs )
{
	CPrintToChat( nClientIdx, "%t", "MC_HowMany", g_nNumBlocksInWorld, sv_mc_block_limit.IntValue - g_nNumBlocksInWorld );
	return Plugin_Handled;
}

public Action Cmd_MC_BuiltBy( int nClientIdx, int nNumArgs )
{
	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( IsValidBlock( nTarget ) )
	{
		char szBuiltByKey[ 32 ];
		GetCustomKeyValue( nTarget, "built_by", szBuiltByKey, sizeof( szBuiltByKey ) );

		CPrintToChat( nClientIdx, "%t", "MC_BuiltBy", szBuiltByKey );
	}

	return Plugin_Handled;
}

public Action Cmd_MC_Credits( int nClientIdx, int nNumArgs )
{
	CPrintToChat( nClientIdx, "%t", "MC_Credits" );
	return Plugin_Handled;
}

public Action Cmd_MC_Clear( int nClientIdx, int nNumArgs )
{
	if ( nNumArgs >= 1 )
	{
		char szBlockIdx[ 4 ];
		GetCmdArg( 1, szBlockIdx, sizeof( szBlockIdx ) );
		Block_ClearType( nClientIdx, StringToInt( szBlockIdx ) );
	}
	else
	{
		int nBlock;
		while ( ( nBlock = FindEntityByClassname( nBlock, "prop_dynamic" ) ) != INVALID_ENT_REFERENCE )
		{
			if ( IsValidBlock( nBlock ) )
			{
				AcceptEntityInput( nBlock, "Kill", -1, -1 );
			}
		}
		CPrintToChatAll( "%t", "MC_ClearedAll" );
		g_nNumBlocksInWorld = 0;
	}

	return Plugin_Handled;
}

public Action Cmd_MC_Disable( int nClientIdx, int nNumArgs )
{
	g_bPluginDisabled = !g_bPluginDisabled;
	CPrintToChatAll( "%t", g_bPluginDisabled ? "MC_Plugin_Disabled" : "MC_Plugin_Enabled" );

	return Plugin_Handled;
}

public void Block_TryBreak( int nClientIdx )
{
	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( IsValidBlock( nTarget ) )
	{
		float vClientPos[ 3 ];
		GetEntPropVector( nClientIdx, Prop_Send, "m_vecOrigin", vClientPos );

		float vTargetPos[ 3 ];
		GetEntPropVector( nTarget, Prop_Send, "m_vecOrigin", vTargetPos );

		if ( GetVectorDistance( vClientPos, vTargetPos ) > 300 )
		{
			return;
		}

		char szBlockIdx[ 4 ];
		GetCustomKeyValue( nTarget, "block_id", szBlockIdx, sizeof( szBlockIdx ) );
		int nBlockIdx = StringToInt( szBlockIdx );

		EmitAmbientSound( g_BlockDefs[ nBlockIdx ].szBreakSound, vTargetPos, nTarget, SNDLEVEL_NORMAL );
		AcceptEntityInput( nTarget, "Kill" );

		g_nNumBlocksInWorld--;

		SDKUnhook( nTarget, SDKHook_OnTakeDamage, Block_OnTakeDamage );
	}
}

public void Block_ClearType( int nClientIdx, int nBlockIdx )
{
	if( nBlockIdx <= 0 || nBlockIdx >= MAXBLOCKINDICES )
	{
		CPrintToChat( nClientIdx, "%t", "MC_BlockIDOutOfBounds" );
		return;
	}

	if( g_BlockDefs[ nBlockIdx ].nIndex != nBlockIdx )
	{
		CPrintToChat( nClientIdx, "%t", "MC_UndefinedBlockID" );
		return;
	}

	int nBlockEnt;
	while ( ( nBlockEnt = FindEntityByClassname( nBlockEnt, "prop_dynamic" ) ) != INVALID_ENT_REFERENCE )
	{
		if ( IsBlockOfType( nBlockEnt, nBlockIdx ) )
		{
			AcceptEntityInput( nBlockEnt, "Kill" );
			g_nNumBlocksInWorld--;
		}
	}

	CPrintToChatAll( "%t", "MC_ClearedAllOfType", g_BlockDefs[ nBlockIdx ].szPhrase );
}

public void Block_Select( int nClientIdx, int nBlockIdx )
{
	if ( nBlockIdx <= 0 || nBlockIdx >= MAXBLOCKINDICES )
	{
		CPrintToChat( nClientIdx, "%t", "MC_BlockIDOutOfBounds" );
		return;
	}

	if ( g_BlockDefs[ nBlockIdx ].nIndex != nBlockIdx )
	{
		CPrintToChat(nClientIdx, "%t", "MC_UndefinedBlockID" );
		return;
	}

	g_nSelectedBlock[ nClientIdx ] = nBlockIdx;
	CPrintToChat( nClientIdx, "%t", "MC_SelectedBlock", g_BlockDefs[ nBlockIdx ].szPhrase );
}

public int Menu_BlockSelect( Menu hMenu, MenuAction eAction, int nParam1, int nParam2 )
{
	switch ( eAction )
	{
		case MenuAction_Select:
		{
			char szBlockIdx[ 4 ];
			hMenu.GetItem( nParam2, szBlockIdx, sizeof( szBlockIdx ) );
			int nBlockIdx = StringToInt( szBlockIdx );
			Block_Select( nParam1, nBlockIdx );
		}
		case MenuAction_DisplayItem:
		{
			char szBlockIdx[ 4 ];
			hMenu.GetItem( nParam2, szBlockIdx, sizeof( szBlockIdx ) );
			int nBlockIdx = StringToInt( szBlockIdx );

			char szBlockName[ 32 ];
			Format( szBlockName, sizeof( szBlockName ), "%t [%d]", g_BlockDefs[ nBlockIdx ].szPhrase, nParam2 + 1 );

			return RedrawMenuItem( szBlockName );
		}
		case MenuAction_End:
		{
			CloseHandle( hMenu );
		}
	}

	return 0;
}

public bool Block_IsBlockAtOrigin( float vOrigin[ 3 ] )
{
	int nBlock;
	while( ( nBlock = FindEntityByClassname( nBlock, "prop_dynamic" ) ) != INVALID_ENT_REFERENCE )
	{
		if ( IsValidBlock( nBlock ) )
		{
			float vBlockOrigin[ 3 ];
			GetEntPropVector( nBlock, Prop_Send, "m_vecOrigin", vBlockOrigin );
			if ( GetVectorDistance( vOrigin, vBlockOrigin ) <= 0.1 )
			{
				return true;
			}
		}
	}

	return false;
}

public bool Block_IsPlayerNear( float vOrigin[ 3 ] )
{
	// TODO(AndrewB): Check for players with TR_EnumerateEntitiesSphere() when SM 1.11 goes stable.

	for ( int nIdx = 1; nIdx < MaxClients; nIdx++ )
	{
		if ( IsClientInGame( nIdx ) && IsPlayerAlive( nIdx ) )
		{
			float vPlayerOrigin[ 3 ];
			GetEntPropVector( nIdx, Prop_Send, "m_vecOrigin", vPlayerOrigin, 0 );
			if ( GetVectorDistance( vOrigin, vPlayerOrigin ) < 60.0 )
			{
				return true;
			}
		}
	}

	return false;

/** TODO(AndrewB): This has a few problems, but would be way better than the above method. Get it working.

	float vStart[ 3 ];
	vStart[ 0 ] = vOrigin[ 0 ];
	vStart[ 1 ] = vOrigin[ 1 ];
	vStart[ 2 ] = vOrigin[ 2 ] + 50.0; // Trace from the top of the block.

	float vMins[ 3 ] = { -25.0, -25.0, 0.0 };
	float vMaxs[ 3 ] = { 25.0, 25.0, 50.0 };

	TR_TraceHullFilter( vStart, vOrigin, vMins, vMaxs, MASK_SOLID, TraceEntityFilter_Player );

	return
		TR_DidHit( INVALID_HANDLE ) &&
		TR_GetEntityIndex( INVALID_HANDLE ) != 0;
*/
}

public bool Block_IsTeleporterNear( float vOrigin[ 3 ] )
{
	float vStart[ 3 ];
	vStart[ 0 ] = vOrigin[ 0 ];
	vStart[ 1 ] = vOrigin[ 1 ];
	vStart[ 2 ] = vOrigin[ 2 ] + 25.0; // Trace from the center of the block.

	float vEnd[ 3 ];
	vEnd[ 0 ] = vOrigin[ 0 ];
	vEnd[ 1 ] = vOrigin[ 1 ];
	vEnd[ 2 ] = vOrigin[ 2 ] - 120.0; // Teleporters require 95hu (+ 25hu to account for the trace start point) of space above them to not destroy themselves on use.

	float vMins[ 3 ] = { -25.0, -25.0, 0.0 };
	float vMaxs[ 3 ] = { 25.0, 25.0, 50.0 };

	TR_TraceHullFilter( vStart, vEnd, vMins, vMaxs, MASK_SOLID, TraceEntityFilter_Teleporter );

	return 
		TR_DidHit( INVALID_HANDLE ) &&
		TR_GetEntityIndex( INVALID_HANDLE ) != 0;
}

public bool TraceEntityFilter_NotPlayer( int nEntityIdx, int nContentsMask )
{
	return nEntityIdx > MaxClients;
}

public bool TraceEntityFilter_Player( int nEntityIdx, int nContentsMask )
{
	if ( nEntityIdx < MaxClients )
	{
		return IsClientInGame( nEntityIdx ) && IsPlayerAlive( nEntityIdx );
	}
	return false;
}

public bool TraceEntityFilter_Teleporter( int nEntityIdx, int nContentsMask )
{
	if ( !IsValidEdict( nEntityIdx ) )
	{
		return false;
	}

	char szClassname[ MAX_NAME_LENGTH ];
	if ( !GetEdictClassname( nEntityIdx, szClassname, sizeof( szClassname ) ) )
	{
		return false;
	}

	return StrEqual( szClassname, "obj_teleporter", false );
}

public int Block_GetLimitForType( int nBlockIdx )
{
	int nLimit;
	int nBlockEnt;
	
	while( ( nBlockEnt = FindEntityByClassname( nBlockEnt, "prop_dynamic" ) ) != INVALID_ENT_REFERENCE )
	{
		if ( IsBlockOfType( nBlockEnt, nBlockIdx ) )
		{
			nLimit++;
		}
	}

	return nLimit;
}

public bool IsBlockOfType( int nEntity, int nBlockIdx )
{
	if ( nEntity > 0 )
	{
		char szBlockIdx[ 4 ];
		GetCustomKeyValue( nEntity, "block_id", szBlockIdx, sizeof( szBlockIdx ) );

		return StringToInt( szBlockIdx ) == g_BlockDefs[ nBlockIdx ].nIndex;
	}

	return false;
}

public bool IsValidBlock( int nEntity )
{
	if ( nEntity > 0 )
	{
		return GetCustomKeyValue( nEntity, "block_id", "", 0 );
	}

	return false;
}

public Action Block_OnTakeDamage(
	int nVictim, int &nAttacker, int &nInflictor,
	float &flDamage, int &nDamageType, int &nWeaponID,
	float vDamageForce[ 3 ], float vDamagePosition[ 3 ], int nDamageCustom
)
{
	if ( sv_mc_melee_break.BoolValue )
	{
		if ( nDamageType & DMG_CLUB )
		{
			float vBlockOrigin[ 3 ];
			GetEntPropVector( nVictim, Prop_Send, "m_vecOrigin", vBlockOrigin );

			char szBlockIdx[ 4 ];
			GetCustomKeyValue( nVictim, "block_id", szBlockIdx, sizeof( szBlockIdx ) );
			int nBlockIdx = StringToInt( szBlockIdx );

			EmitAmbientSound( g_BlockDefs[ nBlockIdx ].szBreakSound, vBlockOrigin, nVictim, SNDLEVEL_NORMAL );

			AcceptEntityInput( nVictim, "Kill" );
			g_nNumBlocksInWorld--;
		}
	}

	return Plugin_Continue;
}

void LoadConfig()
{
	char szCfgLocation[ 96 ];
	BuildPath( Path_SM, szCfgLocation, 96, "configs/minecraft_blocks.cfg" );
	Handle hKeyValues = CreateKeyValues( "Blocks" );
	FileToKeyValues( hKeyValues, szCfgLocation );

	for( int nIdx = 1; nIdx < MAXBLOCKINDICES; nIdx++ )
	{
		char szIndex[ 4 ];
		IntToString( nIdx, szIndex, sizeof( szIndex ) );
		if( KvJumpToKey( hKeyValues, szIndex, false ) )
		{
			g_BlockDefs[ nIdx ].nIndex = nIdx;
			KvGetString( hKeyValues, "phrase", g_BlockDefs[ nIdx ].szPhrase, 32 );
			KvGetString( hKeyValues, "model", g_BlockDefs[ nIdx ].szModel, 32 );
			KvGetString( hKeyValues, "material", g_BlockDefs[ nIdx ].szMaterial, 32 );

			if ( KvJumpToKey( hKeyValues, "sounds" ) )
			{
				KvGetString( hKeyValues, "build", g_BlockDefs[ nIdx ].szBuildSound, 64, "minecraft/stone_build.mp3" );
				KvGetString( hKeyValues, "break", g_BlockDefs[ nIdx ].szBreakSound, 64, "minecraft/stone_break.mp3" );

				KvGoBack( hKeyValues );
			}
			else
			{
				g_BlockDefs[ nIdx ].szBuildSound = "minecraft/stone_build.mp3";
				g_BlockDefs[ nIdx ].szBreakSound = "minecraft/stone_break.mp3";
			}

			g_BlockDefs[ nIdx ].nSkin = KvGetNum( hKeyValues, "skin", 0 );
			g_BlockDefs[ nIdx ].nLimit = KvGetNum( hKeyValues, "limit", -1 );
			g_BlockDefs[ nIdx ].bEmitsLight = KvGetNum( hKeyValues, "light", 0 ) == 0 ? false : true;
			g_BlockDefs[ nIdx ].bOrientToPlayer = KvGetNum( hKeyValues, "orienttoplayer", 0 ) == 0 ? false : true;
			g_BlockDefs[ nIdx ].bHidden = KvGetNum( hKeyValues, "hidden", 0 ) == 0 ? false : true;

			KvGoBack( hKeyValues );
		}
	}

	delete hKeyValues;
}

void PrecacheContent()
{
	for ( int nIdx = 1; nIdx < MAXBLOCKINDICES; nIdx++ )
	{
		// Skip unused block indices.
		if ( StrEqual( g_BlockDefs[ nIdx ].szModel, "" ) )
		{
			continue;
		}

		char szModelBase[ 2 ][ 32 ];
		ExplodeString( g_BlockDefs[ nIdx ].szModel, ".", szModelBase, 2, 32 );

		AddFileToDownloadsTable( g_BlockDefs[ nIdx ].szModel );
		PrecacheModel( g_BlockDefs[ nIdx ].szModel );

		char szModel[ 64 ];

		Format( szModel, 64, "%s.dx80.vtx", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		Format( szModel, 64, "%s.dx90.vtx", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		Format( szModel, 64, "%s.phy", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		Format( szModel, 64, "%s.sw.vtx", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		Format( szModel, 64, "%s.vvd", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		char szMaterial[ 64 ];

		Format( szMaterial, 64, g_szBaseMaterialVMT, g_BlockDefs[ nIdx ].szMaterial );
		AddFileToDownloadsTable( szMaterial );

		Format( szMaterial, 64, g_szBaseMaterialVTF, g_BlockDefs[ nIdx ].szMaterial );
		AddFileToDownloadsTable( szMaterial );

		char szSound[ PLATFORM_MAX_PATH ];

		Format( szSound, PLATFORM_MAX_PATH, "sound/%s", g_BlockDefs[ nIdx ].szBuildSound );
		AddFileToDownloadsTable( szSound );

		Format( szSound, PLATFORM_MAX_PATH, "sound/%s", g_BlockDefs[ nIdx ].szBreakSound );
		AddFileToDownloadsTable( szSound );

		PrecacheSound( g_BlockDefs[ nIdx ].szBuildSound );
		PrecacheSound( g_BlockDefs[ nIdx ].szBreakSound );
	}
}
