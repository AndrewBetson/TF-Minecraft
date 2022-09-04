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

bool		g_bIsClientInBuildMode[ MAXPLAYERS + 1 ]			= { false, ... };
bool		g_bClientHasSeenBuildModeTutorial[ MAXPLAYERS + 1 ]	= { false, ... };
int			g_nLastFrameButtonMask[ MAXPLAYERS + 1 ]			= { 0, ... };
bool		g_bWantsToUseGrapplingHook[ MAXPLAYERS + 1 ]		= { false, ... };

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
	g_bWantsToUseGrapplingHook[ nClientIdx ] = false;
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
		SDKHook( nClientIdx, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon );
	}
	else
	{
		TF2_HudNotificationCustom( nClientIdx, "ico_demolish", -1, false, "%t", "MC_BuildMode_Deactivated" );
		SDKUnhook( nClientIdx, SDKHook_WeaponSwitch, OnPlayerSwitchWeapon );
		g_bWantsToUseGrapplingHook[ nClientIdx ] = false;
	}

	return Plugin_Handled;
}

public Action OnPlayerSwitchWeapon( int nClientIdx, int nWeaponEdictIdx )
{
	if ( !IsClientInGame( nClientIdx ) || !IsPlayerAlive( nClientIdx ) || !IsValidEdict( nWeaponEdictIdx ) )
	{
		return Plugin_Continue;
	}

	g_bWantsToUseGrapplingHook[ nClientIdx ] = GetEntProp( nWeaponEdictIdx, Prop_Send, "m_iItemDefinitionIndex" ) == 1152;

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(
	int nClientIdx, int &nButtonMask, int &nImpulse,
	float vDesiredVelocity[ 3 ], float vDesiredViewAngles[ 3 ],
	int &nWeapon, int &nSubtype,
	int &nCmdNum, int &nTickCount,
	int &nSeed, int vMousePos[ 2  ]
)
{
	if ( !g_bIsClientInBuildMode[ nClientIdx ] || !IsClientInGame( nClientIdx ) || g_bWantsToUseGrapplingHook[ nClientIdx ] )
	{
		return Plugin_Continue;
	}

	if ( nImpulse != 0 )
	{
		PrintToServer( "%d", nImpulse );
	}

	SetEntPropFloat( nClientIdx, Prop_Send, "m_flNextAttack", GetGameTime() + 1.0 );

	if ( nButtonMask & IN_ATTACK && !( g_nLastFrameButtonMask[ nClientIdx ] & IN_ATTACK ) )			Block_TryBreak( nClientIdx );
	else if ( nButtonMask & IN_ATTACK2 && !( g_nLastFrameButtonMask[ nClientIdx ] & IN_ATTACK2 ) )	Block_TryBuild( nClientIdx );
	else if ( nButtonMask & IN_ATTACK3 && !( g_nLastFrameButtonMask[ nClientIdx ] & IN_ATTACK3 ) )	Block_TryPick( nClientIdx );
	else if ( nButtonMask & IN_RELOAD && !( g_nLastFrameButtonMask[ nClientIdx ] & IN_RELOAD ) )	Block_TryBlockCategoryMenu( nClientIdx );

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
