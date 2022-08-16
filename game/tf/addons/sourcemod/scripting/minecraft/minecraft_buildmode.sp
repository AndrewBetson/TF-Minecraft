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

bool		g_bIsClientInBuildMode[ MAXPLAYERS + 1 ]			= { false, ... };
bool		g_bClientHasSeenBuildModeTutorial[ MAXPLAYERS + 1 ]	= { false, ... };
int			g_nLastFrameButtonMask[ MAXPLAYERS + 1 ]			= { 0, ... };

Handle		g_hCookie_SawBuildModeTutorial;

void OnPluginStart_BuildMode()
{
	RegConsoleCmd( "sm_mc_buildmode", Cmd_MC_BuildMode, "Enter build mode." );

	g_hCookie_SawBuildModeTutorial = RegClientCookie( "mc_buildmode_tutorial", "Player has seen buildmode tutorial", CookieAccess_Protected );
}

void OnClientCookiesCached_BuildMode( int nClientIdx )
{
	char szCookieValue[ 4 ];
	GetClientCookie( nClientIdx, g_hCookie_SawBuildModeTutorial, szCookieValue, sizeof( szCookieValue ) );

	g_bClientHasSeenBuildModeTutorial[ nClientIdx ] = ( szCookieValue[ 0 ] != '\0' && StringToInt( szCookieValue ) );
}

void OnClientDisconnect_BuildMode( int nClientIdx )
{
	g_bIsClientInBuildMode[ nClientIdx ] = false;
	g_bClientHasSeenBuildModeTutorial[ nClientIdx ] = false;
	g_nLastFrameButtonMask[ nClientIdx ] = 0;
}

Action Cmd_MC_BuildMode( int nClientIdx, int nNumArgs )
{
	g_bIsClientInBuildMode[ nClientIdx ] = !g_bIsClientInBuildMode[ nClientIdx ];

	if ( g_bIsClientInBuildMode[ nClientIdx ] )
	{
		TF2_HudNotificationCustom( nClientIdx, "ico_build", -1, false, "%t", "MC_BuildMode_Activated" );
		if ( !g_bClientHasSeenBuildModeTutorial[ nClientIdx ] )
		{
			DataPack hData;
			CreateDataTimer( 3.0, Timer_BuildModeTutorial, hData, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );

			hData.WriteCell( nClientIdx );
			hData.WriteCell( 0 );
		}
	}
	else
	{
		TF2_HudNotificationCustom( nClientIdx, "ico_demolish", -1, false, "%t", "MC_BuildMode_Deactivated" );
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(
	int nClientIdx, int &nButtonMask, int &nImpulse,
	float vDesiredVelocity[ 3 ], float vDesiredViewAngles[ 3 ],
	int &nWeapon, int &nSubtype,
	int &nCmdNum, int &nTickCount,
	int &nSeed, int vMousePos[ 2  ]
)
{
	if ( !g_bIsClientInBuildMode[ nClientIdx ] || !IsClientInGame( nClientIdx ) )
	{
		return Plugin_Continue;
	}

	SetEntPropFloat( nClientIdx, Prop_Send, "m_flNextAttack", GetGameTime() + 1.0 );

	if ( nButtonMask & IN_ATTACK && !( g_nLastFrameButtonMask[ nClientIdx ] & IN_ATTACK ) )			Block_TryBreak( nClientIdx );
	else if ( nButtonMask & IN_ATTACK2 && !( g_nLastFrameButtonMask[ nClientIdx ] & IN_ATTACK2 ) )	Block_TryBuild( nClientIdx );
	else if ( nButtonMask & IN_ATTACK3 && !( g_nLastFrameButtonMask[ nClientIdx ] & IN_ATTACK3 ) )	Block_TryPick( nClientIdx );
	else if ( nButtonMask & IN_RELOAD && !( g_nLastFrameButtonMask[ nClientIdx ] & IN_RELOAD ) )	Block_TryBlockMenu( nClientIdx );

	g_nLastFrameButtonMask[ nClientIdx ] = nButtonMask;
	nButtonMask &= ~( IN_ATTACK | IN_ATTACK2 | IN_ATTACK3 | IN_RELOAD );

	return Plugin_Changed;
}

Action Timer_BuildModeTutorial( Handle hTimer, DataPack hData )
{
	hData.Reset();

	int nClientIdx = hData.ReadCell();
	int nTutorialNum = hData.ReadCell();

	switch( nTutorialNum )
	{
		case 0:	TF2_HudNotificationCustom( nClientIdx, "ico_build", -1, false, "%t", "MC_BuildMode_Tutorial_Build" );
		case 1:	TF2_HudNotificationCustom( nClientIdx, "ico_demolish", -1, false, "%t", "MC_BuildMode_Tutorial_Break" );
		case 2:	TF2_HudNotificationCustom( nClientIdx, "ico_build", -1, false, "%t", "MC_BuildMode_Tutorial_Pick" );
		case 3:
		{
			TF2_HudNotificationCustom( nClientIdx, "ico_build", -1, false, "%t", "MC_BuildMode_Tutorial_Menu" );

			SetClientCookie( nClientIdx, g_hCookie_SawBuildModeTutorial, "1" );
			g_bClientHasSeenBuildModeTutorial[ nClientIdx ] = true;

			return Plugin_Stop;
		}
	}

	hData.Position = view_as< DataPackPos >( 1 );
	hData.WriteCell( nTutorialNum + 1 );

	return Plugin_Continue;
}
