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

#include <minecraft>
#include <morecolors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name		= "[TF2] Minecraft API Tests",
	description	= "Test plugin to ensure Minecraft natives and forwards are working correctly.",
	author		= "Andrew \"andrewb\" Betson",
	version		= "1.0.0",
	url			= "https://www.github.com/AndrewBetson/TF-Minecraft/"
};

bool g_bTestsEnabled;

public void OnPluginStart()
{
	LoadTranslations( "common.phrases" );
	LoadTranslations( "minecraft_blocks.phrases" );

	RegConsoleCmd( "sm_mcapi_enable_tests", Cmd_MCAPI_EnableTests, "Enable Minecraft API tests." );
}

public Action Cmd_MCAPI_EnableTests( int nClientIdx, int nNumArgs )
{
	g_bTestsEnabled = !g_bTestsEnabled;
	PrintToServer( g_bTestsEnabled ? "Tests Enabled" : "Tests Disabled" );

	return Plugin_Handled;
}

public Action MC_OnClientBuildBlock( int nBuilderClientIdx, int nBlockDefIdx )
{
	if ( !g_bTestsEnabled )
	{
		return Plugin_Continue;
	}

	PrintToServer( "Received OnClientBuildBlock Forward" );

	BlockDef_t hBlockDef;
	MC_GetBlockDef( nBlockDefIdx, hBlockDef );

	PrintToServer( "Block: %t", hBlockDef.szPhrase );

	return Plugin_Continue;
}

public Action MC_OnClientBreakBlock( int nBuilderClientIdx, int nWorldBlockIdx )
{
	if ( !g_bTestsEnabled )
	{
		return Plugin_Continue;
	}

	PrintToServer( "Received OnClientBreakBlock Forward" );

	WorldBlock_t hWorldBlock;
	MC_GetWorldBlock( nWorldBlockIdx, hWorldBlock );

	PrintToServer( "Block: %d", hWorldBlock.nBlockIdx );

	return Plugin_Continue;
}
