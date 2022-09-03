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

#define MAXBLOCKINDICES 129

ArrayList	g_hBlockCategories;
ArrayList	g_hBlockDefs;
ArrayList	g_hWorldBlocks;
int			g_nSelectedBlock[ MAXPLAYERS + 1 ] = { 1, ... };

ConVar		mc_block_limit;
ConVar		mc_melee_break;
ConVar		mc_remove_blocks_on_disconnect;
ConVar		mc_auto_protect_staff_blocks;
ConVar		mc_dynamiclimit;
ConVar		mc_dynamiclimit_bias;
ConVar		mc_dynamiclimit_threshold;

int			g_nBlockLimit;

bool		g_bPluginDisabled = false;

void OnPluginStart_Blocks()
{
	mc_block_limit = CreateConVar(
		"mc_block_limit",
		"256",
		"Number of blocks that can exist in the map at a time.",
		FCVAR_NOTIFY
	);
	mc_block_limit.AddChangeHook( ConVar_BlockLimit );

	mc_melee_break = CreateConVar(
		"mc_melee_break",
		"1",
		"Allow players to break blocks by hitting them with melee weapons.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 1.0
	);

	mc_remove_blocks_on_disconnect = CreateConVar(
		"mc_remove_blocks_on_disconnect",
		"0",
		"Remove all blocks built by a player when they leave the server.",
		FCVAR_NONE,
		true, 0.0,
		true, 1.0
	);

	mc_auto_protect_staff_blocks = CreateConVar(
		"mc_auto_protect_staff_blocks",
		"1",
		"Automatically protect blocks built by staff players.",
		FCVAR_NONE,
		true, 0.0,
		true, 1.0
	);

	mc_dynamiclimit = CreateConVar(
		"mc_dynamiclimit",
		"0",
		"Use a dynamic block limit based on the number of edicts in the map and the servers sv_lowedict_threshold value.",
		FCVAR_NOTIFY,
		true, 0.0,
		true, 1.0
	);
	mc_dynamiclimit.AddChangeHook( ConVar_DynamicBlockLimit );

	mc_dynamiclimit_bias = CreateConVar(
		"mc_dynamiclimit_bias",
		"500",
		"Constant amount to subtract from dynamic block limit.",
		FCVAR_NONE,
		true, 1.0,
		true, 2047.0
	);

	mc_dynamiclimit_threshold = CreateConVar(
		"mc_dynamiclimit_threshold",
		"50",
		"If the resolved dynamic limit is less than this amount, disable the plugin until next mapchange.",
		FCVAR_NONE,
		true, 1.0,
		true, 2047.0
	);

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

	HookEvent( "teamplay_round_start", Event_TeamplayRoundStart, EventHookMode_PostNoCopy );

	g_hBlockCategories = new ArrayList( sizeof( BlockCategory_t ) );
	g_hBlockDefs = new ArrayList( sizeof( BlockDef_t ) );
	g_hWorldBlocks = new ArrayList( sizeof( WorldBlock_t ) );

	LoadConfig();
}

void OnMapStart_Blocks()
{
	g_bPluginDisabled = false;
	g_hWorldBlocks.Clear();

	PrecacheContent();
}

void OnClientPostAdminCheck_Blocks( int nClientIdx )
{
	g_nSelectedBlock[ nClientIdx ] = 0;
	if ( g_bIsBanned[ nClientIdx ] )
	{
		CheckClientBan( nClientIdx );
	}
}

void OnClientDisconnect_Blocks( int nClientIdx )
{
	if ( mc_remove_blocks_on_disconnect.BoolValue )
	{
		for ( int i = 0; i < g_hWorldBlocks.Length; i++ )
		{
			if ( g_hWorldBlocks.Get( i, WorldBlock_t::nBuilderClientIdx ) == nClientIdx )
			{
				AcceptEntityInput( EntRefToEntIndex( g_hWorldBlocks.Get( i, WorldBlock_t::nEntityRef ) ), "Kill" );
				g_hWorldBlocks.Erase( i );
				i--;
			}
		}
	}
}

public void Event_TeamplayRoundStart( Event hEvent, const char[] szName, bool bDontBroadcast )
{
	g_hWorldBlocks.Clear();

	if ( mc_dynamiclimit.BoolValue )
	{
		int nLowEdictThreshold = GetConVarInt( FindConVar( "sv_lowedict_threshold" ) );
		int nNumMapEnts = GetEntityCount();
		int nDynamicLimitBias = mc_dynamiclimit_bias.IntValue;

		g_nBlockLimit = 2048 - nLowEdictThreshold - nNumMapEnts - nDynamicLimitBias;
		if ( g_nBlockLimit < mc_dynamiclimit_threshold.IntValue )
		{
			g_bPluginDisabled = true;
			CPrintToChatAll( "%t", "MC_Disabled_DynamicLimitThreshold" );
		}
	}
	else
	{
		g_nBlockLimit = mc_block_limit.IntValue;
	}
}

public void ConVar_BlockLimit( ConVar hConVar, const char[] szOldValue, const char[] szNewValue )
{
	if ( mc_dynamiclimit.BoolValue )
	{
		return;
	}

	int nNewLimit = StringToInt( szNewValue );
	if ( nNewLimit <= 0 )
	{
		g_bPluginDisabled = true;
		CPrintToChatAll( "%t", g_bPluginDisabled ? "MC_Plugin_Disabled" : "MC_Plugin_Enabled" );
	}

	g_nBlockLimit = StringToInt( szNewValue );
}

public void ConVar_DynamicBlockLimit( ConVar hConVar, const char[] szOldValue, const char[] szNewValue )
{
	bool bOldValue = view_as< bool >( StringToInt( szOldValue ) );
	bool bNewValue = view_as< bool >( StringToInt( szNewValue ) );

	if ( ( bOldValue && bNewValue ) || ( !bOldValue && !bNewValue ) )
	{
		// Someone changed it to either >1 or <0 for some reason. Don't do anything.
		return;
	}

	int nNewBlockLimit;
	if ( bNewValue )
	{
		nNewBlockLimit = Block_CalculateDynamicLimit();
		if ( nNewBlockLimit < mc_dynamiclimit_threshold.IntValue )
		{
			g_bPluginDisabled = true;
			CPrintToChatAll( "%t", "MC_Disabled_DynamicLimitThreshold" );
		}
	}
	else
	{
		nNewBlockLimit = mc_block_limit.IntValue;
	}

	g_nBlockLimit = nNewBlockLimit;
}

public Action Cmd_MC_Build( int nClientIdx, int nNumArgs )
{
	Block_TryBuild( nClientIdx );

	return Plugin_Handled;
}

public Action Cmd_MC_Break( int nClientIdx, int nNumArgs )
{
	Block_TryBreak( nClientIdx );

	return Plugin_Handled;
}

public Action Cmd_MC_Block( int nClientIdx, int nNumArgs )
{
	if( nNumArgs == 1 )
	{
		char szBlockIdx[ 4 ];
		GetCmdArg( 1, szBlockIdx, sizeof( szBlockIdx ) );
		int nBlockIdx = StringToInt( szBlockIdx );

		if ( nBlockIdx < 0 || nBlockIdx > g_hBlockDefs.Length )
		{
			CPrintToChat( nClientIdx, "%t", "MC_BlockIdxOutOfGlobalBounds", g_hBlockDefs.Length - 1 );
			return Plugin_Handled;
		}

		Block_Select( nClientIdx, StringToInt( szBlockIdx ) );
	}
	else if( nNumArgs >= 2 )
	{
		char szCategoryIdx[ 4 ];
		GetCmdArg( 1, szCategoryIdx, sizeof( szCategoryIdx ) );
		int nCategoryIdx = StringToInt( szCategoryIdx );

		if ( nCategoryIdx < 0 || nCategoryIdx > g_hBlockCategories.Length )
		{
			CPrintToChat( nClientIdx, "%t", "MC_CategoryIdxOutOfBounds", g_hBlockCategories.Length - 1 );
			return Plugin_Handled;
		}

		char szBlockIdx[ 4 ];
		GetCmdArg( 2, szBlockIdx, sizeof( szBlockIdx ) );
		int nBlockIdx = StringToInt( szBlockIdx );

		if ( nBlockIdx < 0 || nBlockIdx > g_hBlockCategories.Get( nCategoryIdx, BlockCategory_t::nNumBlockDefs ) )
		{
			CPrintToChat( nClientIdx, "%t", "MC_BlockIdxOutOfCategoryBounds", g_hBlockCategories.Get( nCategoryIdx, BlockCategory_t::nNumBlockDefs ) );
			return Plugin_Handled;
		}

		int nBlockArrayIdx = 0;
		for ( int i = 0; i < g_hBlockDefs.Length; i++ )
		{
			if (
				g_hBlockDefs.Get( i, BlockDef_t::nCategoryIdx ) == nCategoryIdx &&
				g_hBlockDefs.Get( i, BlockDef_t::nIndex ) == nBlockIdx
			)
			{
				nBlockArrayIdx = i;
			}
		}

		Block_Select( nClientIdx, nBlockArrayIdx );
	}
	else
	{
		Block_TryBlockCategoryMenu( nClientIdx );
	}

	return Plugin_Handled;
}

public Action Cmd_MC_Pick( int nClientIdx, int nNumArgs )
{
	Block_TryPick( nClientIdx );

	return Plugin_Handled;
}

public Action Cmd_MC_HowMany( int nClientIdx, int nNumArgs )
{
	CPrintToChat( nClientIdx, "%t", "MC_HowMany", g_hWorldBlocks.Length, g_nBlockLimit - g_hWorldBlocks.Length );
	return Plugin_Handled;
}

public Action Cmd_MC_BuiltBy( int nClientIdx, int nNumArgs )
{
	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( IsValidBlock( nTarget ) )
	{
		char szBuilderClientAuthID[ MAX_NAME_LENGTH + 64 + 4 ];
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
		int nBlockArrayIndex = g_hWorldBlocks.FindValue( EntIndexToEntRef( nTarget ), WorldBlock_t::nEntityRef );
		if ( nBlockArrayIndex == -1 )
		{
			return Plugin_Handled;
		}

		bool bIsBlockProtected = g_hWorldBlocks.Get( nBlockArrayIndex, WorldBlock_t::bProtected );
		g_hWorldBlocks.Set( nBlockArrayIndex, !bIsBlockProtected, WorldBlock_t::bProtected );
		CPrintToChat( nClientIdx, "%t", bIsBlockProtected ? "MC_Unprotected" : "MC_Protected" );
	}

	return Plugin_Handled;
}

public void Block_TryBuild( int nClientIdx )
{
	if( !( 0 < nClientIdx <= MaxClients ) )
	{
		return;
	}

	if ( !IsClientInGame( nClientIdx ) )
	{
		return;
	}

	bool bIsClientAdmin = GetUserAdmin( nClientIdx ).HasFlag( Admin_Ban );
	if ( g_bPluginDisabled )
	{
		// For some reason &&'ing this with g_bPluginDisabled doesn't work?
		if ( !bIsClientAdmin )
		{
			CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Disabled" );
			EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
			return;
		}
	}

#if defined _trustfactor_included
	if ( g_bHasTrustFactor && !g_bIsClientTrusted[ nClientIdx ] && mc_trustfactor_enable.BoolValue )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_NotTrusted" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return;
	}
#endif // defined _trustfactor_included

	if ( !IsPlayerAlive( nClientIdx ) )
	{
		if ( !bIsClientAdmin || TF2_GetClientTeam( nClientIdx ) != TFTeam_Spectator )
		{
			CPrintToChat( nClientIdx, "%t", "MC_MustBeAlive" );
			EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
			return;
		}
	}

	if ( g_bIsBanned[ nClientIdx ] )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Banned" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return;
	}

	if ( TF2_IsPlayerInCondition( nClientIdx, TFCond_Cloaked ) )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Cloaked" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav")
		return;
	}

	// Clamp selected block to valid range.
	if ( g_nSelectedBlock[ nClientIdx ] < 0 )					g_nSelectedBlock[ nClientIdx ] = 0;
	if ( g_nSelectedBlock[ nClientIdx ] > g_hBlockDefs.Length )	g_nSelectedBlock[ nClientIdx ] = g_hBlockDefs.Length;

	if ( g_hWorldBlocks.Length >= g_nBlockLimit )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_TooManyBlocks", g_nBlockLimit );
		return;
	}

	BlockDef_t hCurBlockDef;
	g_hBlockDefs.GetArray( g_nSelectedBlock[ nClientIdx ], hCurBlockDef, sizeof( BlockDef_t ) );

	if( !( hCurBlockDef.nLimit <= 0 ) )
	{
		if ( Block_GetNumberOfTypeInWorld( hCurBlockDef.nIndex ) >= hCurBlockDef.nLimit )
		{
			CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_TooManyOfType", hCurBlockDef.nLimit );
			return;
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
		return;
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
			return;
		}
	}

	// Not adding an exception for staff to this one
	// because this is a lot easier to do on accident
	// than building too close to a teleporter.
	if ( Block_IsPlayerNear( vHitPoint ) )
	{
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return;
	}

	if ( Block_IsTeleporterNear( vHitPoint ) && !bIsClientAdmin )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Teleporter" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return;
	}

	Action eForwardRes;
	Call_StartForward( g_fwdOnClientBuild );
	{
		Call_PushCell( nClientIdx );
		Call_PushCell( g_nSelectedBlock[ nClientIdx ] );
	}
	Call_Finish( eForwardRes );

	if ( eForwardRes == Plugin_Handled || eForwardRes == Plugin_Stop )
	{
		return;
	}

	int nEnt = CreateEntityByName( "prop_dynamic_override" );
	if ( !IsValidEdict( nEnt ) )
	{
		return;
	}

	float vBlockAngles[ 3 ];
	if ( hCurBlockDef.bOrientToPlayer )
	{
		vBlockAngles[ 1 ] = ( RoundToNearest( vClientEyeAngles[ 1 ] / 90.0 ) * 90.0 ) + 90.0;
	}
	TeleportEntity( nEnt, vHitPoint, vBlockAngles, NULL_VECTOR );

	SetEntProp( nEnt, Prop_Send, "m_nSkin", hCurBlockDef.nSkin );
	SetEntProp( nEnt, Prop_Send, "m_nSolidType", 6 );

	char szClientName[ MAX_NAME_LENGTH ];
	GetClientName( nClientIdx, szClientName, sizeof( szClientName ) );

	CRemoveTags( szClientName, sizeof( szClientName ) );

	char szClientAuthString[ 64 ];
	GetClientAuthId( nClientIdx, AuthId_Steam2, szClientAuthString, sizeof( szClientAuthString ) );

	// The extra 4 bytes are for the space, parentheses and null terminator.
	char szBlockTargetName[ MAX_NAME_LENGTH + 64 + 4 ];
	Format( szBlockTargetName, sizeof( szBlockTargetName ), "%s (%s)", szClientName, szClientAuthString );

	DispatchKeyValue( nEnt, "targetname", szBlockTargetName );

	SetEntityModel( nEnt, hCurBlockDef.szModel );

	DispatchSpawn( nEnt );
	ActivateEntity( nEnt );

	WorldBlock_t NewWorldBlock;
	NewWorldBlock.nEntityRef = EntIndexToEntRef( nEnt );
	NewWorldBlock.nBlockIdx = g_nSelectedBlock[ nClientIdx ];
	NewWorldBlock.bProtected = bIsClientAdmin && mc_auto_protect_staff_blocks.BoolValue ? true : false;
	NewWorldBlock.vOrigin = vHitPoint;
	NewWorldBlock.nBuilderClientIdx = nClientIdx;

	g_hWorldBlocks.PushArray( NewWorldBlock );

	if( hCurBlockDef.bEmitsLight )
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

	EmitAmbientSound( hCurBlockDef.szBuildSound, vHitPoint, nEnt, SNDLEVEL_NORMAL );

	SDKHook( nEnt, SDKHook_OnTakeDamage, Block_OnTakeDamage );
}

public void Block_TryBreak( int nClientIdx )
{
	if ( g_bPluginDisabled )
	{
		if ( !GetUserAdmin( nClientIdx ).HasFlag( Admin_Ban ) )
		{
			CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Disabled" );
			return;
		}
	}

#if defined _trustfactor_included
	if ( g_bHasTrustFactor && !g_bIsClientTrusted[ nClientIdx ] && mc_trustfactor_enable.BoolValue )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_NotTrusted" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return;
	}
#endif // defined _trustfactor_included

	if ( g_bIsBanned[ nClientIdx ] )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Banned" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return;
	}

	bool bIsClientAdmin = GetUserAdmin( nClientIdx ).HasFlag( Admin_Ban );
	if ( !IsPlayerAlive( nClientIdx ) && !bIsClientAdmin )
	{
		CPrintToChat( nClientIdx, "%t", "MC_MustBeAlive" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav" );
		return;
	}

	if ( TF2_IsPlayerInCondition( nClientIdx, TFCond_Cloaked ) )
	{
		CPrintToChat( nClientIdx, "%t", "MC_CannotBuild_Cloaked" );
		EmitSoundToClient( nClientIdx, "common/wpn_denyselect.wav")
		return;
	}

	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( IsValidBlock( nTarget ) )
	{
		int nBlockArrayIdx = g_hWorldBlocks.FindValue( EntIndexToEntRef( nTarget ), WorldBlock_t::nEntityRef );
		if ( nBlockArrayIdx == -1 )
		{
			return;
		}

		bool bIsBlockProtected = g_hWorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::bProtected );
		if ( bIsBlockProtected && !bIsClientAdmin )
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

		int nBlockIdx = g_hWorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::nBlockIdx );

		Action eForwardRes;
		Call_StartForward( g_fwdOnClientBreak );
		{
			Call_PushCell( nClientIdx );
			Call_PushCell( nBlockArrayIdx );
		}
		Call_Finish( eForwardRes );

		if ( eForwardRes == Plugin_Handled || eForwardRes == Plugin_Stop )
		{
			return;
		}

		BlockDef_t hCurBlockDef;
		g_hBlockDefs.GetArray( nBlockIdx, hCurBlockDef, sizeof( BlockDef_t ) );

		EmitAmbientSound( hCurBlockDef.szBreakSound, vTargetPos, nTarget, SNDLEVEL_NORMAL );

		AcceptEntityInput( nTarget, "Kill" );
		SDKUnhook( nTarget, SDKHook_OnTakeDamage, Block_OnTakeDamage );

		g_hWorldBlocks.Erase( nBlockArrayIdx );
	}
}

public void Block_TryPick( int nClientIdx )
{
	int nTarget = GetClientAimTarget( nClientIdx, false );
	if ( !IsValidBlock( nTarget ) )
	{
		return;
	}

	int nBlockArrayIdx = g_hWorldBlocks.FindValue( EntIndexToEntRef( nTarget ), WorldBlock_t::nEntityRef );
	if ( nBlockArrayIdx == -1 )
	{
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

	int nBlockIdx = g_hWorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::nBlockIdx );
	g_nSelectedBlock[ nClientIdx ] = nBlockIdx;

	BlockDef_t hCurBlockDef;
	g_hBlockDefs.GetArray( nBlockIdx, hCurBlockDef, sizeof( BlockDef_t ) );

	CPrintToChat( nClientIdx, "%t", "MC_SelectedBlock", hCurBlockDef.szPhrase );
}

public void Block_TryBlockCategoryMenu( int nClientIdx )
{
	Menu hBlockCategorySelect = new Menu( Menu_BlockCategorySelect, MENU_ACTIONS_ALL );
	hBlockCategorySelect.SetTitle( "%t", "MC_BlockCategoryMenu_Title" );

	for ( int i = 0; i < g_hBlockCategories.Length; i++ )
	{
		BlockCategory_t hCurCategory;
		g_hBlockCategories.GetArray( i, hCurCategory, sizeof( BlockCategory_t ) );

		char szIndex[ 4 ];
		IntToString( i, szIndex, sizeof( szIndex ) );

		hBlockCategorySelect.AddItem( szIndex, hCurCategory.szPhrase );
	}

	hBlockCategorySelect.ExitButton = true;
	hBlockCategorySelect.Display( nClientIdx, 32 );
}

public void Block_TryBlockMenu( int nClientIdx, int nCategoryIdx )
{
	Menu hBlockSelect = new Menu( Menu_BlockSelect, MENU_ACTIONS_ALL );
	hBlockSelect.SetTitle( "%t", "MC_BlockMenu_Title" );

	for ( int i = 0; i < g_hBlockDefs.Length; i++ )
	{
		BlockDef_t hCurBlockDef;
		g_hBlockDefs.GetArray( i, hCurBlockDef, sizeof( BlockDef_t ) );

		if ( hCurBlockDef.nCategoryIdx == nCategoryIdx )
		{
			char szBlockIdx[ 4 ];
			IntToString( i, szBlockIdx, sizeof( szBlockIdx ) );

			hBlockSelect.AddItem( szBlockIdx, hCurBlockDef.szPhrase );
		}
	}

	hBlockSelect.Display( nClientIdx, 32 );
}

public void Block_ClearAll()
{
	for ( int i = g_hWorldBlocks.Length - 1; i >= 0; --i )
	{
		AcceptEntityInput( EntRefToEntIndex( g_hWorldBlocks.Get( i, WorldBlock_t::nEntityRef ) ), "Kill" );
		g_hWorldBlocks.Erase( i );
	}
	g_hWorldBlocks.Clear();
}

public void Block_ClearType( int nClientIdx, int nBlockIdx )
{
	if( nBlockIdx < 0 )
	{
		CPrintToChat( nClientIdx, "%t", "MC_BlockIDOutOfBounds" );
		return;
	}

	BlockDef_t hCurBlockDef;
	g_hBlockDefs.GetArray( nBlockIdx, hCurBlockDef, sizeof( BlockDef_t ) );

	if( hCurBlockDef.nIndex != nBlockIdx )
	{
		CPrintToChat( nClientIdx, "%t", "MC_UndefinedBlockID" );
		return;
	}

	for ( int i = 0; i < g_hWorldBlocks.Length; i++ )
	{
		if ( g_hWorldBlocks.Get( i, WorldBlock_t::nBlockIdx ) == nBlockIdx )
		{
			AcceptEntityInput( EntRefToEntIndex( g_hWorldBlocks.Get( i, WorldBlock_t::nEntityRef ) ), "Kill" );
			g_hWorldBlocks.Erase( i );
			i--;
		}
	}

	CPrintToChatAll( "%t", "MC_ClearedAllOfType", hCurBlockDef.szPhrase );
}

public void Block_ClearPlayer( int nClientIdx )
{
	if ( !IsClientInGame( nClientIdx ) )
	{
		return;
	}

	for ( int i = 0; i < g_hWorldBlocks.Length; i++ )
	{
		if ( g_hWorldBlocks.Get( i, WorldBlock_t::nBuilderClientIdx ) == nClientIdx )
		{
			AcceptEntityInput( EntRefToEntIndex( g_hWorldBlocks.Get( i, WorldBlock_t::nEntityRef ) ), "Kill" );
			g_hWorldBlocks.Erase( i );
			i--;
		}
	}
}

public void Block_Select( int nClientIdx, int nBlockIdx )
{
	if ( nBlockIdx < 0 )
	{
		CPrintToChat( nClientIdx, "%t", "MC_BlockIDOutOfBounds" );
		return;
	}

	BlockDef_t hCurBlockDef;
	g_hBlockDefs.GetArray( nBlockIdx, hCurBlockDef, sizeof( BlockDef_t ) );

	if ( nBlockIdx < 0 || nBlockIdx > g_hBlockDefs.Length )
	{
		CPrintToChat(nClientIdx, "%t", "MC_UndefinedBlockID" );
		return;
	}

	g_nSelectedBlock[ nClientIdx ] = nBlockIdx;
	CPrintToChat( nClientIdx, "%t", "MC_SelectedBlock", hCurBlockDef.szPhrase );
}

public int Menu_BlockCategorySelect( Menu hMenu, MenuAction eAction, int nParam1, int nParam2 )
{
	switch ( eAction )
	{
		case MenuAction_Select:
		{
			char szSelectedCategory[ 4 ];
			hMenu.GetItem( nParam2, szSelectedCategory, sizeof( szSelectedCategory ) );
			int nSelectedCategory = StringToInt( szSelectedCategory );

			Block_TryBlockMenu( nParam1, nSelectedCategory );
		}
		case MenuAction_DisplayItem:
		{
			char szBlockIdx[ 4 ];
			hMenu.GetItem( nParam2, szBlockIdx, sizeof( szBlockIdx ) );
			int nBlockIdx = StringToInt( szBlockIdx );

			BlockCategory_t hCurBlockCategory;
			g_hBlockCategories.GetArray( nBlockIdx, hCurBlockCategory, sizeof( BlockCategory_t ) );

			char szCategoryName[ sizeof( BlockCategory_t::szPhrase ) ];
			Format( szCategoryName, sizeof( szCategoryName ), "%t [%d]", hCurBlockCategory.szPhrase, hCurBlockCategory.nIndex );

			return RedrawMenuItem( szCategoryName );
		}
		case MenuAction_End:
		{
			CloseHandle( hMenu );
		}
	}

	return 0;
}

public int Menu_BlockSelect( Menu hMenu, MenuAction eAction, int nParam1, int nParam2 )
{
	switch( eAction )
	{
		case MenuAction_DisplayItem:
		{
			char szBlockIdx[ 4 ];
			hMenu.GetItem( nParam2, szBlockIdx, sizeof( szBlockIdx ) );

			int nBlockIdx = StringToInt( szBlockIdx );

			BlockDef_t hCurBlockDef;
			g_hBlockDefs.GetArray( nBlockIdx, hCurBlockDef, sizeof( BlockDef_t ) );

			char szBlockName[ 32 ];
			Format( szBlockName, sizeof( szBlockName ), "%t [%d]", hCurBlockDef.szPhrase, hCurBlockDef.nIndex );

			return RedrawMenuItem( szBlockName );
		}
		case MenuAction_Select:
		{
			char szBlockIdx[ 4 ];
			hMenu.GetItem( nParam2, szBlockIdx, sizeof( szBlockIdx ) );

			int nBlockIdx = StringToInt( szBlockIdx );

			Block_Select( nParam1, nBlockIdx );
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
	for ( int i = 0; i < g_hWorldBlocks.Length; i++ )
	{
		WorldBlock_t hCurWorldBlock;
		g_hWorldBlocks.GetArray( i, hCurWorldBlock );
		if ( hCurWorldBlock.IsAtOrigin( vOrigin ) )
		{
			return true;
		}
	}

	return false;
}

public bool Block_IsPlayerNear( float vOrigin[ 3 ] )
{
	for ( int i = 1; i < MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && IsPlayerAlive( i ) )
		{
			float vPlayerOrigin[ 3 ];
			GetEntPropVector( i, Prop_Send, "m_vecOrigin", vPlayerOrigin, 0 );
			if ( GetVectorDistance( vOrigin, vPlayerOrigin ) < 64.0 )
			{
				return true;
			}
		}
	}

	return false;

/*	TODO(AndrewB): For some reason the entity filter method just *doesn't get called*, figure out why.

	float vStart[ 3 ];
	vStart[ 0 ] = vOrigin[ 0 ];
	vStart[ 1 ] = vOrigin[ 1 ];
	vStart[ 2 ] = vOrigin[ 2 ] + 50.0; // Trace from the top of the block.

	float vMins[ 3 ] = { -25.0, -25.0, 0.0 };
	float vMaxs[ 3 ] = { 25.0, 25.0, 0.0 };

	TR_TraceHullFilter( vStart, vOrigin, vMins, vMaxs, MASK_SOLID, TraceEntityFilter_Player );

	return TR_DidHit( INVALID_HANDLE ) && TR_GetEntityIndex( INVALID_HANDLE ) != 0;
*/
}

public bool Block_IsTeleporterNear( float vOrigin[ 3 ] )
{
	float vStart[ 3 ];
	vStart[ 0 ] = vOrigin[ 0 ];
	vStart[ 1 ] = vOrigin[ 1 ];
	vStart[ 2 ] = vOrigin[ 2 ] + 50.0; // Trace from the top of the block.

	float vEnd[ 3 ];
	vEnd[ 0 ] = vOrigin[ 0 ];
	vEnd[ 1 ] = vOrigin[ 1 ];
	vEnd[ 2 ] = vOrigin[ 2 ] - 95.0; // Teleporters require 95hu of space above them to not destroy themselves on use.

	float vMins[ 3 ] = { -25.0, -25.0, 0.0 };
	float vMaxs[ 3 ] = { 25.0, 25.0, 0.0 };

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

	for ( int i = 0; i < g_hWorldBlocks.Length; i++ )
	{
		if ( g_hWorldBlocks.Get( i, WorldBlock_t::nBlockIdx ) == nBlockIdx )
		{
			nNumInWorld++;
		}
	}

	return nNumInWorld;
}

public int Block_CalculateDynamicLimit()
{
	int nLowEdictThreshold = GetConVarInt( FindConVar( "sv_lowedict_threshold" ) );
	int nNumMapEnts = GetEntityCount();
	int nDynamicLimitBias = mc_dynamiclimit_bias.IntValue;

	return 2048 - nLowEdictThreshold - nNumMapEnts - nDynamicLimitBias;
}

public bool IsBlockOfType( int nEntity, int nBlockIdx )
{
	if ( nEntity > 0 )
	{
		int nBlockArrayIdx = g_hWorldBlocks.FindValue( EntIndexToEntRef( nEntity ), WorldBlock_t::nEntityRef );
		return g_hWorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::nBlockIdx ) == g_hBlockDefs.Get( nBlockArrayIdx, BlockDef_t::nIndex );
	}

	return false;
}

public bool IsValidBlock( int nEntity )
{
	if ( nEntity > 0 )
	{
		return g_hWorldBlocks.FindValue( EntIndexToEntRef( nEntity ), WorldBlock_t::nEntityRef ) != -1;
	}

	return false;
}

public Action Block_OnTakeDamage(
	int nVictim, int &nAttacker, int &nInflictor,
	float &flDamage, int &nDamageType, int &nWeaponID,
	float vDamageForce[ 3 ], float vDamagePosition[ 3 ], int nDamageCustom
)
{
	if ( mc_melee_break.BoolValue )
	{
		if ( nDamageType & DMG_CLUB )
		{
			int nBlockArrayIdx = g_hWorldBlocks.FindValue( EntIndexToEntRef( nVictim ), WorldBlock_t::nEntityRef );
			if ( nBlockArrayIdx == -1 )
			{
				return Plugin_Continue;
			}

		#if defined _trustfactor_included
			if ( g_bHasTrustFactor && !g_bIsClientTrusted[ nAttacker ] && mc_trustfactor_enable.BoolValue )
			{
				CPrintToChat( nAttacker, "%t", "MC_CannotBuild_NotTrusted" );
				EmitSoundToClient( nAttacker, "common/wpn_denyselect.wav" );
				return Plugin_Continue;
			}
		#endif // defined _trustfactor_included

			if ( g_bIsBanned[ nAttacker ] )
			{
				CPrintToChat( nAttacker, "%t", "MC_CannotBuild_Banned" );
				EmitSoundToClient( nAttacker, "common/wpn_denyselect.wav" );
				return Plugin_Continue;
			}

			bool bIsBlockProtected = g_hWorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::bProtected );
			if ( bIsBlockProtected && !GetAdminFlag( GetUserAdmin( nAttacker ), Admin_Ban ) )
			{
				CPrintToChat( nAttacker, "%t", "MC_BlockProtected" );
				EmitSoundToClient( nAttacker, "common/wpn_denyselect.wav" );
				return Plugin_Continue;
			}

			// Technically this should never be able to happen,
			// but I'm adding this in case someone finds a way.
			if ( TF2_IsPlayerInCondition( nAttacker, TFCond_Cloaked ) )
			{
				CPrintToChat( nAttacker, "%t", "MC_CannotBuild_Cloaked" );
				EmitSoundToClient( nAttacker, "common/wpn_denyselect.wav")
				return Plugin_Continue;
			}

			Action eForwardRes;
			Call_StartForward( g_fwdOnClientBreak );
			{
				Call_PushCell( nAttacker );
				Call_PushCell( nBlockArrayIdx );
			}
			Call_Finish( eForwardRes );

			if ( eForwardRes == Plugin_Handled || eForwardRes == Plugin_Stop )
			{
				return Plugin_Continue;
			}

			float vBlockOrigin[ 3 ];
			GetEntPropVector( nVictim, Prop_Send, "m_vecOrigin", vBlockOrigin );

			int nBlockIdx = g_hWorldBlocks.Get( nBlockArrayIdx, WorldBlock_t::nBlockIdx );

			BlockDef_t hCurBlockDef;
			g_hBlockDefs.GetArray( nBlockIdx, hCurBlockDef, sizeof( BlockDef_t ) );

			EmitAmbientSound( hCurBlockDef.szBreakSound, vBlockOrigin, nVictim, SNDLEVEL_NORMAL );

			SDKUnhook( nVictim, SDKHook_OnTakeDamage, Block_OnTakeDamage );
			AcceptEntityInput( nVictim, "Kill" );

			g_hWorldBlocks.Erase( nBlockArrayIdx );
		}
	}

	return Plugin_Continue;
}

void LoadConfig()
{
	char szCfgLocation[ 96 ];
	BuildPath( Path_SM, szCfgLocation, 96, "configs/minecraft_blocks.cfg" );

	KeyValues hKeyValues = CreateKeyValues( "Blocks" );
	FileToKeyValues( hKeyValues, szCfgLocation );
	hKeyValues.GotoFirstSubKey();

	int nNumKeys = 0;
	for( ;; )
	{
		BlockCategory_t hNewCategory;
		hNewCategory.nIndex = nNumKeys;
		hKeyValues.GetSectionName( hNewCategory.szPhrase, sizeof( BlockCategory_t::szPhrase ) );

		// Allow categories to define some defaults for contained block defs.

		char szDefaultModel[ sizeof( BlockDef_t::szModel ) ];
		hKeyValues.GetString( "model", szDefaultModel, sizeof( szDefaultModel ) );

		char szDefaultBuildSound[ sizeof( BlockDef_t::szBuildSound ) ];
		char szDefaultBreakSound[ sizeof( BlockDef_t::szBreakSound ) ];

		if ( hKeyValues.JumpToKey( "sounds" ) )
		{
			hKeyValues.GetString( "build", szDefaultBuildSound, sizeof( szDefaultBuildSound ), "minecraft/stone_build.mp3" );
			hKeyValues.GetString( "break", szDefaultBreakSound, sizeof( szDefaultBreakSound ), "minecraft/stone_break.mp3" );

			hKeyValues.GoBack();
		}
		else
		{
			strcopy( szDefaultBuildSound, sizeof( szDefaultBuildSound ), "minecraft/stone_build.mp3" );
			strcopy( szDefaultBreakSound, sizeof( szDefaultBreakSound ), "minecraft/stone_break.mp3" );
		}

		int nNumSubKeys = 0;
		hKeyValues.GotoFirstSubKey();
		for( ;; )
		{
			char szSectionName[ sizeof( BlockDef_t::szPhrase ) ];
			hKeyValues.GetSectionName( szSectionName, sizeof( szSectionName ) );

			if ( strcmp( szSectionName, "sounds" ) == 0 )
			{
				hKeyValues.GotoNextKey();
				continue;
			}

			BlockDef_t hNewBlockDef;
			hNewBlockDef.nCategoryIdx = nNumKeys;
			hNewBlockDef.nIndex = nNumSubKeys;
			strcopy( hNewBlockDef.szPhrase, sizeof( BlockDef_t::szPhrase ), szSectionName );
			hKeyValues.GetString( "model", hNewBlockDef.szModel, sizeof( BlockDef_t::szModel ), szDefaultModel );
			hKeyValues.GetString( "material", hNewBlockDef.szMaterial, sizeof( BlockDef_t::szMaterial ) );
			hNewBlockDef.nSkin = hKeyValues.GetNum( "skin" );
			hNewBlockDef.nLimit = hKeyValues.GetNum( "limit" );
			hNewBlockDef.bOrientToPlayer = view_as< bool >( hKeyValues.GetNum( "orienttoplayer" ) );
			hNewBlockDef.bEmitsLight = view_as< bool >( hKeyValues.GetNum( "light" ) );

			if ( hKeyValues.JumpToKey( "sounds" ) )
			{
				hKeyValues.GetString( "build", hNewBlockDef.szBuildSound, sizeof( BlockDef_t::szBuildSound ), szDefaultBuildSound );
				hKeyValues.GetString( "break", hNewBlockDef.szBreakSound, sizeof( BlockDef_t::szBreakSound ), szDefaultBreakSound );

				hKeyValues.GoBack();
			}
			else
			{
				strcopy( hNewBlockDef.szBuildSound, sizeof( BlockDef_t::szBuildSound ), szDefaultBuildSound );
				strcopy( hNewBlockDef.szBreakSound, sizeof( BlockDef_t::szBreakSound ), szDefaultBreakSound );
			}

			g_hBlockDefs.PushArray( hNewBlockDef );
			hNewCategory.nNumBlockDefs = nNumSubKeys;

			nNumSubKeys++;

			if ( !hKeyValues.GotoNextKey() )
			{
				hKeyValues.GoBack();
				break;
			}
		}

		g_hBlockCategories.PushArray( hNewCategory );
		nNumKeys++;

		if ( !hKeyValues.GotoNextKey() )
		{
			hKeyValues.GoBack();
			break;
		}
	}

	delete hKeyValues;
}

void PrecacheContent()
{
	for ( int i = 0; i < g_hBlockDefs.Length; i++ )
	{
		BlockDef_t CurBlockDef;
		g_hBlockDefs.GetArray( i, CurBlockDef, sizeof( BlockDef_t ) );

		PrecacheModel( CurBlockDef.szModel );
		PrecacheSound( CurBlockDef.szBuildSound );
		PrecacheSound( CurBlockDef.szBreakSound );
		PrecacheSound( "common/wpn_denyselect.wav" );

		char szModelBase[ 2 ][ 32 ];
		ExplodeString( CurBlockDef.szModel, ".", szModelBase, 2, 32 );

		AddFileToDownloadsTable( CurBlockDef.szModel );

		char szModel[ PLATFORM_MAX_PATH ];

		Format( szModel, PLATFORM_MAX_PATH, "%s.dx80.vtx", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		Format( szModel, PLATFORM_MAX_PATH, "%s.dx90.vtx", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		Format( szModel, PLATFORM_MAX_PATH, "%s.phy", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		Format( szModel, PLATFORM_MAX_PATH, "%s.sw.vtx", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		Format( szModel, PLATFORM_MAX_PATH, "%s.vvd", szModelBase[ 0 ] );
		AddFileToDownloadsTable( szModel );

		char szMaterial[ PLATFORM_MAX_PATH ];

		Format( szMaterial, PLATFORM_MAX_PATH, "materials/models/minecraft/%s.vmt", CurBlockDef.szMaterial );
		AddFileToDownloadsTable( szMaterial );

		Format( szMaterial, PLATFORM_MAX_PATH, "materials/models/minecraft/%s.vtf", CurBlockDef.szMaterial );
		AddFileToDownloadsTable( szMaterial );

		char szSound[ PLATFORM_MAX_PATH ];

		Format( szSound, PLATFORM_MAX_PATH, "sound/%s", CurBlockDef.szBuildSound );
		AddFileToDownloadsTable( szSound );

		Format( szSound, PLATFORM_MAX_PATH, "sound/%s", CurBlockDef.szBreakSound );
		AddFileToDownloadsTable( szSound );
	}
}
