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
//#include <customkeyvalues>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name		= "[TF2] Minecraft",
	description	= "Minecraft, but in TF2.",
	author		= "Moonly Days; overhauled by Andrew \"andrewb\" Betson",
	version		= "2.1.1",
	url			= "https://www.github.com/AndrewBetson/TF-Minecraft/"
};

#include "minecraft/minecraft_bans.sp"
#include "minecraft/minecraft_blocks.sp"

public void OnPluginStart()
{
	LoadTranslations( "common.phrases" );
	LoadTranslations( "minecraft.phrases" );
	LoadTranslations( "minecraft_blocks.phrases" );

	OnPluginStart_Bans();
	OnPluginStart_Blocks();

	AutoExecConfig( true, "minecraft" );

	// Late-load/reload support.
	for ( int nIdx = 1; nIdx <= MaxClients; nIdx++ )
	{
		if ( IsClientInGame( nIdx ) )
		{
			// Going to assume that IsClientInGame returning true implies that said client has also been authenticated.
			OnClientPostAdminCheck( nIdx );

			if ( AreClientCookiesCached( nIdx ) )
			{
				OnClientCookiesCached( nIdx );
			}
		}
	}
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
	OnClientDisconnect_Bans( nClientIdx );
}

public void OnMapStart()
{
	OnMapStart_Blocks();
}
