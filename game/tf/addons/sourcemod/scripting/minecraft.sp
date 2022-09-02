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

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <menus>
#include <clientprefs>
#include <tf2>
#include <tf2_stocks>

#include <minecraft>
#include <morecolors>
#include <tf2hudmsg>

#undef REQUIRE_PLUGIN
#tryinclude <trustfactor>
#tryinclude <tf2gravihands>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name		= "[TF2] Minecraft",
	description	= "Minecraft, but in TF2.",
	author		= "Moonly Days; overhauled by Andrew \"andrewb\" Betson",
	version		= "2.5.0",
	url			= "https://www.github.com/AndrewBetson/TF-Minecraft/"
};

#if defined _trustfactor_included

bool			g_bHasTrustFactor;
TrustCondition	g_hTrustCond;

ConVar			mc_trustfactor_enable;
ConVar			mc_trustfactor_flags;

bool			g_bIsClientTrusted[ MAXPLAYERS + 1 ];

#endif // defined _trustfactor_included

GlobalForward	g_fwdOnClientBuild;
GlobalForward	g_fwdOnClientBreak;

#include "minecraft/minecraft_bans.sp"
#include "minecraft/minecraft_blocks.sp"
#include "minecraft/minecraft_buildmode.sp"

public APLRes AskPluginLoad2( Handle hThisPlugin, bool bLateLoad, char[] szError, int nErrorLen )
{
	CreateNative( "MC_GetBlockDef", MC_GetBlockDef_Impl );
	CreateNative( "MC_GetWorldBlock", MC_GetWorldBlock_Impl );

	RegPluginLibrary( "minecraft" );

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations( "common.phrases" );
	LoadTranslations( "minecraft.phrases" );
	LoadTranslations( "minecraft_blocks.phrases" );

	OnPluginStart_Bans();
	OnPluginStart_Blocks();
	OnPluginStart_BuildMode();

#if defined _trustfactor_included
	mc_trustfactor_enable = CreateConVar(
		"mc_trustfactor_enable",
		"1",
		"Whether or not to make use of the TrustFactor plugin by reBane/DosMike if it is detected.",
		FCVAR_NONE,
		true, 0.0,
		true, 1.0
	);

	mc_trustfactor_flags = CreateConVar(
		"mc_trustfactor_flags",
		"t",
		"Which trust factor flag(s) to use. See the TrustFactor plugin documentation for a list of flags and their effects.",
		FCVAR_NONE,
		true, 0.0,
		true, 1.0
	);
	mc_trustfactor_flags.AddChangeHook( ConVar_TrustFactor_Flags );
#endif // defined _trustfactor_included

	AutoExecConfig( true, "minecraft" );

	// Late-load/reload support.
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && !IsFakeClient( i ) )
		{
			// Going to assume that IsClientInGame returning true implies that said client has also been authenticated.
			OnClientPostAdminCheck( i );

			if ( AreClientCookiesCached( i ) )
			{
				OnClientCookiesCached( i );
			}

		#if defined _trustfactor_included
			if ( g_bHasTrustFactor )
			{
				OnClientTrustFactorLoaded( i, GetClientTrustFactors( i ) );
			}
		#endif // defined _trustfactor_included
		}
	}

	g_fwdOnClientBuild	= CreateGlobalForward( "MC_OnClientBuildBlock", ET_Event, Param_Cell, Param_Cell );
	g_fwdOnClientBreak	= CreateGlobalForward( "MC_OnClientBreakBlock", ET_Event, Param_Cell, Param_Cell );
}

public void OnClientPostAdminCheck( int nClientIdx )
{
	OnClientPostAdminCheck_Blocks( nClientIdx );
}

public void OnClientCookiesCached( int nClientIdx )
{
	OnClientCookiesCached_Bans( nClientIdx );
	OnClientCookiesCached_BuildMode( nClientIdx );
}

public void OnClientDisconnect( int nClientIdx )
{
#if defined _trustfactor_included
	g_bIsClientTrusted[ nClientIdx ] = false;
#endif // defined _trustfactor_included

	OnClientDisconnect_Bans( nClientIdx );
	OnClientDisconnect_Blocks( nClientIdx );
	OnClientDisconnect_BuildMode( nClientIdx );
}

public void OnMapStart()
{
	OnMapStart_Blocks();
}

#if defined _trustfactor_included

public void OnAllPluginsLoaded()
{
	g_bHasTrustFactor = LibraryExists( "trustfactor" );
	if ( g_bHasTrustFactor )
	{
		char szBuf[ 32 ];
		mc_trustfactor_flags.GetString( szBuf, sizeof( szBuf ) );

		g_hTrustCond.Parse( szBuf );
	}
}

public void OnLibraryAdded( const char[] szName )
{
	if ( StrEqual( szName, "trustfactor" ) ) g_bHasTrustFactor = true;
}

public void OnLibraryRemoved( const char[] szName )
{
	if ( StrEqual( szName, "trustfactor" ) ) g_bHasTrustFactor = false;
}

public void OnClientTrustFactorLoaded( int nClientIdx, TrustFactors eFactors )
{
	if ( g_bHasTrustFactor )
	{
		g_bIsClientTrusted[ nClientIdx ] = g_hTrustCond.Test( nClientIdx );
	}
}

public void OnClientTrustFactorChanged( int nClientIdx, TrustFactors eOldFactors, TrustFactors eNewFactors )
{
	if ( g_bHasTrustFactor )
	{
		// NOTE(AndrewB):	As of the time of writing this comment,
		//					the TrustFactor plugin does not broadcast
		//					this forward when a players servertime updates.
		//					I am leaving this here in the event that the
		//					TrustFactor plugin is updated to do so.
		g_bIsClientTrusted[ nClientIdx ] = g_hTrustCond.Test( nClientIdx );
	}
}

public void ConVar_TrustFactor_Flags( ConVar hConVar, char[] szOldValue, char[] szNewValue )
{
	if ( !g_bHasTrustFactor )
	{
		return;
	}

	g_hTrustCond.Parse( szNewValue );
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && !IsFakeClient( i ) )
		{
			g_bIsClientTrusted[ i ] = g_hTrustCond.Test( i );
		}
	}
}

#endif // _trustfactor_included

#if defined _tf2_gravihands

public Action TF2GH_OnClientHolsterWeapon( int nClientIdx, int nWeaponID )
{
	// This plugin uses the same input (+attack3)
	// for picking blocks while in buildmode
	// that GraviHands uses for holstering with a melee
	// weapon out, which could cause problems.
	if ( g_bIsClientInBuildMode[ nClientIdx ] )
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

#endif // defined _tf2_gravihands

public any MC_GetBlockDef_Impl( Handle hPlugin, int nNumParams )
{
	int nBlockDefIdx = GetNativeCell( 1 );

	int nSizeOfBlockDef = GetNativeCell( 3 );
	if ( nSizeOfBlockDef != sizeof( BlockDef_t ) )
	{
		char szBuf[ 64 ];
		GetPluginFilename( hPlugin, szBuf, sizeof( szBuf ) );

		return ThrowNativeError( SP_ERROR_ARRAY_BOUNDS, "Plugin \"%s\" has incorrectly sized BlockDef_t. Expected %d but got %d.", szBuf, sizeof( WorldBlock_t ), nSizeOfBlockDef );
	}

	BlockDef_t hOutBlockDef;
	g_hBlockDefs.GetArray( nBlockDefIdx, hOutBlockDef );

	return SetNativeArray( 2, hOutBlockDef, nSizeOfBlockDef );
}

public any MC_GetWorldBlock_Impl( Handle hPlugin, int nNumParams )
{
	int nWorldBlockIdx = GetNativeCell( 1 );

	int nSizeOfWorldBlock = GetNativeCell( 3 );
	if ( nSizeOfWorldBlock != sizeof( WorldBlock_t ) )
	{
		char szBuf[ 64 ];
		GetPluginFilename( hPlugin, szBuf, sizeof( szBuf ) );

		return ThrowNativeError( SP_ERROR_ARRAY_BOUNDS, "Plugin \"%s\" has incorrectly sized WorldBlock_t. Expected %d but got %d.", szBuf, sizeof( WorldBlock_t ), nSizeOfWorldBlock );
	}

	WorldBlock_t hOutWorldBlock;
	g_hWorldBlocks.GetArray( nWorldBlockIdx, hOutWorldBlock );

	return SetNativeArray( 2, hOutWorldBlock, nSizeOfWorldBlock );
}
