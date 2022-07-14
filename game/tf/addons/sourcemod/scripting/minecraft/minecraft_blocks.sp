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

/** @brief A block as it exists in the world. */
enum struct WorldBlock_t
{
	int		nEntityRef;
	int		nBlockIdx;
	bool	bProtected;
	float	vOrigin[ 3 ];
	int		nBuilderClientIdx;

	bool IsAtOrigin( float vInOrigin[ 3 ] )
	{
		return GetVectorDistance( this.vOrigin, vInOrigin ) <= 0.1;
	}
}

BlockDef_t	g_BlockDefs[ MAXBLOCKINDICES ];
ArrayList	g_WorldBlocks;
int			g_nSelectedBlock[ MAXPLAYERS + 1 ] = { 1, ... };

ConVar		sv_mc_block_limit;
ConVar		sv_mc_melee_break;
ConVar		sv_mc_remove_blocks_on_disconnect;
ConVar		sv_mc_dynamiclimit;
ConVar		sv_mc_dynamiclimit_bias;
ConVar		sv_mc_dynamiclimit_threshold;

int			g_nBlockLimit;

bool		g_bPluginDisabled = false;

void OnPluginStart_Blocks()
{
	sv_mc_block_limit = CreateConVar( "sv_mc_block_limit", "256", "Number of blocks that can exist in the map at a time.", FCVAR_NOTIFY );
	sv_mc_melee_break = CreateConVar( "sv_mc_melee_break", "1", "Allow players to break blocks by hitting them with melee weapons.", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	sv_mc_remove_blocks_on_disconnect = CreateConVar( "sv_mc_remove_blocks_on_disconnect", "0", "Remove all blocks built by a player when they leave the server.", FCVAR_NONE, true, 0.0, true, 1.0 );
	sv_mc_dynamiclimit = CreateConVar( "sv_mc_dynamiclimit", "0", "Use a dynamic block limit based on the number of edicts in the map and the servers sv_lowedict_threshold value.", FCVAR_NONE, true, 0.0, true, 1.0 );
	sv_mc_dynamiclimit_bias = CreateConVar( "sv_mc_dynamiclimit_bias", "500", "Constant amount to subtract from dynamic block limit.", FCVAR_NONE, true, 1.0, true, 2047.0 );
	sv_mc_dynamiclimit_threshold = CreateConVar( "sv_mc_dynamiclimit_threshold", "50", "If the resolved dynamic limit is less than this amount, disable the plugin until next mapchange." );

	RegConsoleCmd( "sm_mc_build", Cmd_MC_Build, "Build currently selected block." );
	RegConsoleCmd( "sm_mc_break", Cmd_MC_Break, "Break block under cursor." );
	RegConsoleCmd( "sm_mc_block", Cmd_MC_Block, "Select a block." );
	RegConsoleCmd( "sm_mc_blocks", Cmd_MC_Block, "Select a block." );
	RegConsoleCmd( "sm_mc_pick", Cmd_MC_Pick, "Select block under cursor." );
	RegConsoleCmd( "sm_mc_howmany", Cmd_MC_HowMany, "Print the current number of blocks in the world." );
	RegConsoleCmd( "sm_mc_builtby", Cmd_MC_BuiltBy, "Print the SteamID of the player that built the block under the calling players cursor." );
	RegConsoleCmd( "sm_mc_credits", Cmd_MC_Credits, "Print the credits for this plugin." );

	// Backwards compatible commands so people don't have to update their binds,
	// and staff on servers upgrading from the original plugin don't get inundated
	// with questions about "where the Minecraft plugin went".
	RegConsoleCmd( "sm_build", Cmd_MC_Build, "Build current selected block." );
	RegConsoleCmd( "sm_break", Cmd_MC_Break, "Break block under cursor." );
	RegConsoleCmd( "sm_block", Cmd_MC_Block, "Select a block." );
	RegConsoleCmd( "sm_blocks", Cmd_MC_Block, "Select a block." );
	RegConsoleCmd( "sm_limit", Cmd_MC_HowMany, "Display current number of blocks in the world." );

	RegAdminCmd( "sm_mc_clear", Cmd_MC_Clear, ADMFLAG_BAN, "Remove all Minecraft blocks, optionally of a specific type, from the world." );
	RegAdminCmd( "sm_mc_clear_player", Cmd_MC_ClearPlayer, ADMFLAG_BAN, "Remove all Minecraft blocks built by a particular player." );
	RegAdminCmd( "sm_mc_disable", Cmd_MC_Disable, ADMFLAG_BAN, "Disable the building and breaking of Minecraft blocks until the next mapchange." );
	RegAdminCmd( "sm_mc_protect", Cmd_MC_Protect, ADMFLAG_BAN, "Protect a block from being broken by any non-staff players if it's not already protected, remove protections otherwise." );

	LoadConfig();

	HookEvent( "teamplay_round_start", Event_TeamplayRoundStart, EventHookMode_PostNoCopy );

	g_WorldBlocks = new ArrayList( sizeof( WorldBlock_t ) );
}

void OnMapStart_Blocks()
{
	g_bPluginDisabled = false;
	g_WorldBlocks.Clear();

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

void OnClientDisconnect_Blocks( int nClientIdx )
{
	if ( sv_mc_remove_blocks_on_disconnect.BoolValue )
	{
		for ( int i = 0; i < g_WorldBlocks.Length; i++ )
		{
			if ( g_WorldBlocks.Get( i, WorldBlock_t::nBuilderClientIdx ) == nClientIdx )
			{
				AcceptEntityInput( EntRefToEntIndex( g_WorldBlocks.Get( i, WorldBlock_t::nEntityRef ) ), "Kill" );
				g_WorldBlocks.Erase( i );
				i--;
			}
		}
	}
}

void OnConfigsExecuted_Blocks()
{
	if ( sv_mc_dynamiclimit.BoolValue )
	{
		int nLowEdictThreshold = GetConVarInt( FindConVar( "sv_lowedict_threshold" ) );
		int nNumMapEnts = GetEntityCount();
		int nDynamicLimitBias = sv_mc_dynamiclimit_bias.IntValue;

		g_nBlockLimit = 2048 - nLowEdictThreshold - nNumMapEnts - nDynamicLimitBias;
		if ( g_nBlockLimit < sv_mc_dynamiclimit_threshold.IntValue )
		{
			g_bPluginDisabled = true;
			CPrintToChatAll( "%t", "MC_Disabled_DynamicLimitThreshold" );
		}
	}
	else
	{
		g_nBlockLimit = sv_mc_block_limit.IntValue;
	}
}

public void Event_TeamplayRoundStart( Event hEvent, const char[] szName, bool bDontBroadcast )
{
	g_WorldBlocks.Clear();
}

public Action Cmd_MC_Build( int nClientIdx, int nNumArgs )
{
	if( !( 0 < nClientIdx <= MaxClients ) )
	{
		return Plugin_Handled;
	}

	if ( !IsClientInGame( nClientIdx ) )
	{
		return Plugin_Handled;
	}

	if ( g_bPluginDisabled )
	{
		if ( !GetUserAdmin( nClientIdx ).HasFlag( Admin_Kick ) )
		{
			CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Disabled" );
			EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
			return Plugin_Handled;
		}
	}

	if ( !IsPlayerAlive( nClientIdx ) )
	{
		CPrintToChat( nClientIdx, "%t", "MC_MustBeAlive" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	if ( g_bIsBanned[ nClientIdx ] )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Banned" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	// Clamp selected block to valid range.
	if ( g_nSelectedBlock[ nClientIdx ] < 1 )	g_nSelectedBlock[ nClientIdx ] = 1;
	if ( g_nSelectedBlock[ nClientIdx ] > 128 )	g_nSelectedBlock[ nClientIdx ] = 128;

	if ( g_WorldBlocks.Length >= g_nBlockLimit )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_TooManyBlocks", g_nBlockLimit );
		return Plugin_Handled;
	}

	int nSelected = g_nSelectedBlock[ nClientIdx ];

	if( g_BlockDefs[ nSelected ].nLimit != -1 )
	{
		if ( Block_GetNumberOfTypeInWorld( nSelected ) >= g_BlockDefs[ nSelected ].nLimit )
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
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
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
			EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
			return Plugin_Handled;
		}
	}

	if ( Block_IsPlayerNear( vHitPoint ) )
	{
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return Plugin_Handled;
	}

	if ( Block_IsTeleporterNear( vHitPoint ) )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Teleporter" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
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

		char szClientAuthString[ 32 ];
		GetClientAuthId( nClientIdx, AuthId_Steam2, szClientAuthString, sizeof( szClientAuthString ) );

		DispatchKeyValue( nEnt, "targetname", szClientAuthString );

		SetEntityModel( nEnt, g_BlockDefs[ nSelected ].szModel );

		DispatchSpawn( nEnt );
		ActivateEntity( nEnt );

		WorldBlock_t NewWorldBlock;
		NewWorldBlock.nEntityRef = EntIndexToEntRef( nEnt );
		NewWorldBlock.nBlockIdx = nSelected;
		NewWorldBlock.bProtected = false;
		NewWorldBlock.vOrigin = vHitPoint;
		NewWorldBlock.nBuilderClientIdx = nClientIdx;

		g_WorldBlocks.PushArray( NewWorldBlock );

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

		SDKHook( nEnt, SDKHook_OnTakeDamage, Block_OnTakeDamage );
	}

	return Plugin_Handled;
}

public Action Cmd_MC_Break( int nClientIdx, int nNumArgs )
{
	if ( g_bPluginDisabled )
	{
		if ( !GetUserAdmin( nClientIdx ).HasFlag( Admin_Kick ) )
		{
			CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Disabled" );
			return Plugin_Handled;
		}
	}

	if ( g_bIsBanned[ nClientIdx ] )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Banned" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
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
		for ( int i = 0; i < MAXBLOCKINDICES; i++ )
		{
			if ( g_BlockDefs[ i ].nIndex <= 0 || g_BlockDefs[ i ].bHidden )
			{
				continue;
			}
			char szIndex[ 4 ];
			IntToString( i, szIndex, sizeof( szIndex ) );
			menu.AddItem( szIndex, g_BlockDefs[ i ].szPhrase );
		}
	}

	menu.ExitButton = true;
	menu.Display( nClientIdx, 32 );

	return Plugin_Handled;
}

public Action Cmd_MC_Pick( int nClientIdx, int nNumArgs )
{
	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( IsValidBlock( nTarget ) )
	{
		int nBlockArrayIdx = g_WorldBlocks.FindValue( EntIndexToEntRef( nTarget ), WorldBlock_t::nEntityRef );
		if ( nBlockArrayIdx == -1 )
		{
			return Plugin_Handled;
		}

		float vClientPos[ 3 ];
		GetEntPropVector( nClientIdx, Prop_Send, "m_vecOrigin", vClientPos );

		float vTargetPos[ 3 ];
		GetEntPropVector( nTarget, Prop_Send, "m_vecOrigin", vTargetPos );

		if ( GetVectorDistance( vClientPos, vTargetPos ) > 300 )
		{
			EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
			return Plugin_Handled;
		}

		int nBlockIdx = g_WorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::nBlockIdx );
		g_nSelectedBlock[ nClientIdx ] = nBlockIdx;

		CPrintToChat( nClientIdx, "%t", "MC_SelectedBlock", g_BlockDefs[ nBlockIdx ].szPhrase );
	}

	return Plugin_Handled;
}

public Action Cmd_MC_HowMany( int nClientIdx, int nNumArgs )
{
	CPrintToChat( nClientIdx, "%t", "MC_HowMany", g_WorldBlocks.Length, g_nBlockLimit - g_WorldBlocks.Length );
	return Plugin_Handled;
}

public Action Cmd_MC_BuiltBy( int nClientIdx, int nNumArgs )
{
	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( IsValidBlock( nTarget ) )
	{
		char szBuilderClientAuthID[ 32 ];
		GetEntPropString( nTarget, Prop_Data, "m_iName", szBuilderClientAuthID, sizeof( szBuilderClientAuthID ) );

		CPrintToChat( nClientIdx, "%t", "MC_BuiltBy", szBuilderClientAuthID );
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
		Block_ClearAll();
		CPrintToChatAll( "%t", "MC_ClearedAll" );
	}

	return Plugin_Handled;
}

public Action Cmd_MC_ClearPlayer( int nClientIdx, int nNumArgs )
{
	if ( nNumArgs < 1 )
	{
		CReplyToCommand( nClientIdx, "%t", "MC_ClearPlayer_Usage" );
		return Plugin_Handled;
	}

	char szArgs[ 256 ];
	GetCmdArgString( szArgs, sizeof( szArgs ) );

	char szTargetName[ 65 ];
	BreakString( szArgs, szTargetName, sizeof( szTargetName ) );

	int nTargetClientIdx = FindTarget( nClientIdx, szTargetName, true );
	if ( nTargetClientIdx == -1 )
	{
		return Plugin_Handled;
	}

	Block_ClearPlayer( nTargetClientIdx );
	CPrintToChat( nClientIdx, "%t", "MC_ClearedAllPlayer", szTargetName );

	return Plugin_Handled;
}

public Action Cmd_MC_Disable( int nClientIdx, int nNumArgs )
{
	g_bPluginDisabled = !g_bPluginDisabled;
	CPrintToChatAll( "%t", g_bPluginDisabled ? "MC_Plugin_Disabled" : "MC_Plugin_Enabled" );

	return Plugin_Handled;
}

public Action Cmd_MC_Protect( int nClientIdx, int nNumArgs )
{
	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( IsValidBlock( nTarget ) )
	{
		int nBlockArrayIndex = g_WorldBlocks.FindValue( EntIndexToEntRef( nTarget ), WorldBlock_t::nEntityRef );
		if ( nBlockArrayIndex == -1 )
		{
			return Plugin_Handled;
		}

		bool bIsBlockProtected = g_WorldBlocks.Get( nBlockArrayIndex, WorldBlock_t::bProtected );
		g_WorldBlocks.Set( nBlockArrayIndex, !bIsBlockProtected, WorldBlock_t::bProtected );
		CPrintToChat( nClientIdx, "%t", bIsBlockProtected ? "MC_Unprotected" : "MC_Protected", g_BlockDefs[ g_WorldBlocks.Get( nBlockArrayIndex, WorldBlock_t::nBlockIdx ) ].szPhrase );
	}

	return Plugin_Handled;
}

public void Block_TryBreak( int nClientIdx )
{
	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( IsValidBlock( nTarget ) )
	{
		int nBlockArrayIdx = g_WorldBlocks.FindValue( EntIndexToEntRef( nTarget ), WorldBlock_t::nEntityRef );
		if ( nBlockArrayIdx == -1 )
		{
			return;
		}

		bool bIsBlockProtected = g_WorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::bProtected );
		if ( bIsBlockProtected && !GetAdminFlag( GetUserAdmin( nClientIdx ), Admin_Ban ) )
		{
			CPrintToChat( nClientIdx, "%t", "MC_BlockProtected" );
			EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
			return;
		}

		float vClientPos[ 3 ];
		GetEntPropVector( nClientIdx, Prop_Send, "m_vecOrigin", vClientPos );

		float vTargetPos[ 3 ];
		GetEntPropVector( nTarget, Prop_Send, "m_vecOrigin", vTargetPos );

		if ( GetVectorDistance( vClientPos, vTargetPos ) > 300 )
		{
			EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
			return;
		}

		int nBlockIdx = g_WorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::nBlockIdx );
		EmitAmbientSound( g_BlockDefs[ nBlockIdx ].szBreakSound, vTargetPos, nTarget, SNDLEVEL_NORMAL );

		AcceptEntityInput( nTarget, "Kill" );
		SDKUnhook( nTarget, SDKHook_OnTakeDamage, Block_OnTakeDamage );

		g_WorldBlocks.Erase( nBlockArrayIdx );
	}
}

public void Block_ClearAll()
{
	for ( int i = g_WorldBlocks.Length - 1; i >= 0; --i )
	{
		AcceptEntityInput( EntRefToEntIndex( g_WorldBlocks.Get( i, WorldBlock_t::nEntityRef ) ), "Kill" );
		g_WorldBlocks.Erase( i );
	}
	g_WorldBlocks.Clear();
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

	for ( int i = 0; i < g_WorldBlocks.Length; i++ )
	{
		if ( g_WorldBlocks.Get( i, WorldBlock_t::nBlockIdx ) == nBlockIdx )
		{
			AcceptEntityInput( EntRefToEntIndex( g_WorldBlocks.Get( i, WorldBlock_t::nEntityRef ) ), "Kill" );
			g_WorldBlocks.Erase( i );
			i--;
		}
	}

	CPrintToChatAll( "%t", "MC_ClearedAllOfType", g_BlockDefs[ nBlockIdx ].szPhrase );
}

public void Block_ClearPlayer( int nClientIdx )
{
	if ( !IsClientInGame( nClientIdx ) )
	{
		return;
	}

	for ( int i = 0; i < g_WorldBlocks.Length; i++ )
	{
		if ( g_WorldBlocks.Get( i, WorldBlock_t::nBuilderClientIdx ) == nClientIdx )
		{
			AcceptEntityInput( EntRefToEntIndex( g_WorldBlocks.Get( i, WorldBlock_t::nEntityRef ) ), "Kill" );
			g_WorldBlocks.Erase( i );
			i--;
		}
	}
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
			Format( szBlockName, sizeof( szBlockName ), "%t [%d]", g_BlockDefs[ nBlockIdx ].szPhrase, nBlockIdx );

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
	for ( int i = 0; i < g_WorldBlocks.Length; i++ )
	{
		WorldBlock_t CurWorldBlock;
		g_WorldBlocks.GetArray( i, CurWorldBlock );
		if ( CurWorldBlock.IsAtOrigin( vOrigin ) )
		{
			return true;
		}
	}

	return false;
}

public bool Block_IsPlayerNear( float vOrigin[ 3 ] )
{
	// TODO(AndrewB): Check for players with TR_EnumerateEntitiesSphere() when SM 1.11 goes stable.

	for ( int i = 1; i < MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) )
		{
			float vPlayerOrigin[ 3 ];
			GetEntPropVector( i, Prop_Send, "m_vecOrigin", vPlayerOrigin, 0 );
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

	return TR_DidHit( INVALID_HANDLE ) && TR_GetEntityIndex( INVALID_HANDLE ) != 0;
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

public int Block_GetNumberOfTypeInWorld( int nBlockIdx )
{
	int nNumInWorld;

	for ( int i = 0; i < g_WorldBlocks.Length; i++ )
	{
		if ( g_WorldBlocks.Get( i, WorldBlock_t::nBlockIdx ) == nBlockIdx )
		{
			nNumInWorld++;
		}
	}

	return nNumInWorld;
}

public bool IsBlockOfType( int nEntity, int nBlockIdx )
{
	if ( nEntity > 0 )
	{
		int nBlockArrayIdx = g_WorldBlocks.FindValue( EntIndexToEntRef( nEntity ), WorldBlock_t::nEntityRef );
		return g_WorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::nBlockIdx ) == g_BlockDefs[ nBlockIdx ].nIndex;
	}

	return false;
}

public bool IsValidBlock( int nEntity )
{
	if ( nEntity > 0 )
	{
		return g_WorldBlocks.FindValue( EntIndexToEntRef( nEntity ), WorldBlock_t::nEntityRef ) != -1;
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
			int nBlockArrayIdx = g_WorldBlocks.FindValue( EntIndexToEntRef( nVictim ), WorldBlock_t::nEntityRef );
			if ( nBlockArrayIdx == -1 )
			{
				return Plugin_Continue;
			}

			bool bIsBlockProtected = g_WorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::bProtected );
			if ( bIsBlockProtected && !GetAdminFlag( GetUserAdmin( nAttacker ), Admin_Ban ) )
			{
				CPrintToChat( nAttacker, "%t", "MC_BlockProtected" );
				EmitSoundToClient( nAttacker, "common/wpn_denyselect.wav" );
				return Plugin_Continue;
			}

			float vBlockOrigin[ 3 ];
			GetEntPropVector( nVictim, Prop_Send, "m_vecOrigin", vBlockOrigin );

			int nBlockIdx = g_WorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::nBlockIdx );
			EmitAmbientSound( g_BlockDefs[ nBlockIdx ].szBreakSound, vBlockOrigin, nVictim, SNDLEVEL_NORMAL );

			AcceptEntityInput( nVictim, "Kill" );
			SDKUnhook( nVictim, SDKHook_OnTakeDamage, Block_OnTakeDamage );

			g_WorldBlocks.Erase( nBlockArrayIdx );
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

	for( int i = 1; i < MAXBLOCKINDICES; i++ )
	{
		char szIndex[ 4 ];
		IntToString( i, szIndex, sizeof( szIndex ) );
		if( KvJumpToKey( hKeyValues, szIndex, false ) )
		{
			g_BlockDefs[ i ].nIndex = i;
			KvGetString( hKeyValues, "phrase", g_BlockDefs[ i ].szPhrase, 32 );
			KvGetString( hKeyValues, "model", g_BlockDefs[ i ].szModel, 32 );
			KvGetString( hKeyValues, "material", g_BlockDefs[ i ].szMaterial, 32 );

			if ( KvJumpToKey( hKeyValues, "sounds" ) )
			{
				KvGetString( hKeyValues, "build", g_BlockDefs[ i ].szBuildSound, 64, "minecraft/stone_build.mp3" );
				KvGetString( hKeyValues, "break", g_BlockDefs[ i ].szBreakSound, 64, "minecraft/stone_break.mp3" );

				KvGoBack( hKeyValues );
			}
			else
			{
				g_BlockDefs[ i ].szBuildSound = "minecraft/stone_build.mp3";
				g_BlockDefs[ i ].szBreakSound = "minecraft/stone_break.mp3";
			}

			g_BlockDefs[ i ].nSkin = KvGetNum( hKeyValues, "skin", 0 );
			g_BlockDefs[ i ].nLimit = KvGetNum( hKeyValues, "limit", -1 );
			g_BlockDefs[ i ].bEmitsLight = KvGetNum( hKeyValues, "light", 0 ) == 0 ? false : true;
			g_BlockDefs[ i ].bOrientToPlayer = KvGetNum( hKeyValues, "orienttoplayer", 0 ) == 0 ? false : true;
			g_BlockDefs[ i ].bHidden = KvGetNum( hKeyValues, "hidden", 0 ) == 0 ? false : true;

			KvGoBack( hKeyValues );
		}
	}

	delete hKeyValues;
}

void PrecacheContent()
{
	for ( int i = 1; i < MAXBLOCKINDICES; i++ )
	{
		// Skip unused block indices.
		if ( StrEqual( g_BlockDefs[ i ].szModel, "" ) )
		{
			continue;
		}

		PrecacheModel( g_BlockDefs[ i ].szModel );
		PrecacheSound( g_BlockDefs[ i ].szBuildSound );
		PrecacheSound( g_BlockDefs[ i ].szBreakSound );
		PrecacheSound( "common/wpn_denyselect.wav" );

		char szModelBase[ 2 ][ 32 ];
		ExplodeString( g_BlockDefs[ i ].szModel, ".", szModelBase, 2, 32 );

		AddFileToDownloadsTable( g_BlockDefs[ i ].szModel );

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

		Format( szMaterial, 64, "materials/models/minecraft/%s.vmt", g_BlockDefs[ i ].szMaterial );
		AddFileToDownloadsTable( szMaterial );

		Format( szMaterial, 64, "materials/models/minecraft/%s.vtf", g_BlockDefs[ i ].szMaterial );
		AddFileToDownloadsTable( szMaterial );

		char szSound[ PLATFORM_MAX_PATH ];

		Format( szSound, PLATFORM_MAX_PATH, "sound/%s", g_BlockDefs[ i ].szBuildSound );
		AddFileToDownloadsTable( szSound );

		Format( szSound, PLATFORM_MAX_PATH, "sound/%s", g_BlockDefs[ i ].szBreakSound );
		AddFileToDownloadsTable( szSound );
	}
}
