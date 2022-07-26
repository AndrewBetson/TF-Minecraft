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

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <menus>
#include <clientprefs>
#include <tf2>
#include <tf2_stocks>

#include <morecolors>

#undef REQUIRE_PLUGIN
#tryinclude <trustfactor>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name		= "[TF2] Minecraft",
	description	= "Minecraft, but in TF2.",
	author		= "Moonly Days; overhauled by Andrew \"andrewb\" Betson",
	version		= "2.3.0",
	url			= "https://www.github.com/AndrewBetson/TF-Minecraft/"
};

#if defined _trustfactor_included

bool			g_bHasTrustFactor;
TrustCondition	g_hTrustCond;

ConVar			sv_mc_trustfactor_enable;
ConVar			sv_mc_trustfactor_flags;

bool			g_bIsClientTrusted[ MAXPLAYERS + 1 ];

#endif // defined _trustfactor_included

#include "minecraft/minecraft_bans.sp"
#include "minecraft/minecraft_blocks.sp"

public void OnPluginStart()
{
	LoadTranslations( "common.phrases" );
	LoadTranslations( "minecraft.phrases" );
	LoadTranslations( "minecraft_blocks.phrases" );

	OnPluginStart_Bans();
	OnPluginStart_Blocks();

#if defined _trustfactor_included
	sv_mc_trustfactor_enable = CreateConVar(
		"sv_mc_trustfactor_enable",
		"1",
		"Whether or not to make use of the TrustFactor plugin by reBane/DosMike if it is detected.",
		FCVAR_NONE,
		true, 0.0,
		true, 1.0
	);

	sv_mc_trustfactor_flags = CreateConVar(
		"sv_mc_trustfactor_flags",
		"t",
		"Which trust factor flag(s) to use. See the TrustFactor plugin documentation for a list of flags and their effects.",
		FCVAR_NONE,
		true, 0.0,
		true, 1.0
	);
	sv_mc_trustfactor_flags.AddChangeHook( ConVar_TrustFactor_Flags );
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
			OnClientTrustFactorLoaded( i, GetClientTrustFactors( i ) );
		#endif // defined _trustfactor_included
		}
	}

#if defined _trustfactor_included
	char szBuf[ 32 ];
	sv_mc_trustfactor_flags.GetString( szBuf, sizeof( szBuf ) );

	g_hTrustCond.Parse( szBuf );
#endif // defined _trustfactor_included
}

public void OnClientPostAdminCheck( int nClientIdx )
{
	OnClientPostAdminCheck_Blocks( nClientIdx );
}

public void OnClientCookiesCached( int nClientIdx )
{
	OnClientCookiesCached_Bans( nClientIdx );
}

public void OnClientDisconnect( int nClientIdx )
{
#if defined _trustfactor_included
	g_bIsClientTrusted[ nClientIdx ] = false;
#endif // defined _trustfactor_included

	OnClientDisconnect_Bans( nClientIdx );
	OnClientDisconnect_Blocks( nClientIdx );
}

public void OnMapStart()
{
	OnMapStart_Blocks();
}

public void OnConfigsExecuted()
{
	OnConfigsExecuted_Blocks();
}

#if defined _trustfactor_included

public void OnAllPluginsLoaded()
{
	g_bHasTrustFactor = LibraryExists( "trustfactor" );
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
	g_bIsClientTrusted[ nClientIdx ] = g_hTrustCond.Test( nClientIdx );
}

public void OnClientTrustFactorChanged( int nClientIdx, TrustFactors eOldFactors, TrustFactors eNewFactors )
{
	// BUG(AndrewB): For some reason this callback doesn't seem to get called when it's supposed to...
	g_bIsClientTrusted[ nClientIdx ] = g_hTrustCond.Test( nClientIdx );
}

public void ConVar_TrustFactor_Flags( ConVar hConVar, char[] szOldValue, char[] szNewValue )
{
	g_hTrustCond.Parse( szNewValue );
	for ( int i = 0; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) && !IsFakeClient( i ) )
		{
			g_bIsClientTrusted[ i ] = g_hTrustCond.Test( i );
		}
	}
}

#endif // _trustfactor_included
