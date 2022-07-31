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
