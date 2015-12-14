/* 
 * AwesomeMod plugin for StSv Servers
 * Copyright (C) 2010-2015 Anarchy Steven
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 * 
 * For more info, see LICENSE file of this repository.
 */

#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>
#include <steamtools>

#define PLUGIN_PREFIX "\x07356AA0[ \x0744A8D9AwesomeMod \x07356AA0] \x01"

#define PLAYERBUILTOBJECT_ID_DISPENSER  0
#define PLAYERBUILTOBJECT_ID_TELENT     1
#define PLAYERBUILTOBJECT_ID_TELEXIT    2
#define PLAYERBUILTOBJECT_ID_SENTRY     3

public Plugin:myinfo = 
{
	name = "AwesomeMod",
	author = "Anarchy Steven",
	description = "A SourceMod plugin for Team Fortress 2 which really makes your server go crazy.",
	version = "1.0",
	url = "http://www.gemini.software/"
}

// ConVars
new Handle:g_hConVarIsEnabled = INVALID_HANDLE;
new Handle:g_hConVarRateOfFire = INVALID_HANDLE;

new Float:g_fRateOfFireMultiplier = 3.0;
new bool:g_bIsEnabled = true;

new g_iWeaponRateQueueLength;
new g_aWeaponRateQueue[MAXPLAYERS+1];

// Offsets
new g_oActiveWeapon;
new g_oAmmoRockets;
new g_oAmmoShells;
new g_oBuilder;
new g_oClip;
new g_oIsMiniBuilding;
new g_oMaxSpeed;
new g_oUpgradeLevel;

// PropInfo
new g_piActiveWeapon = -1;
new g_piAmmo = -1;
new g_piBroken = -1;
new g_piDetonated = -1;
new g_piNextPrimaryAttack = -1; 
new g_piNextSecondaryAttack = -1;
new g_piOwner = -1;

public OnPluginStart()
{
	g_hConVarIsEnabled = CreateConVar("tf_awesomemod_enabled", "1", "Is AwesomeMod enabled?", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hConVarRateOfFire = CreateConVar("tf_awesomemod_rof", "3.0", "Every weapon's rate-of-fire is multiplied by this value.", FCVAR_PLUGIN, true, 1.0, true, 100.0);
	
	HookConVarChange(g_hConVarIsEnabled, Event_ConVarChanged_IsEnabled);
	HookConVarChange(g_hConVarRateOfFire, Event_ConVarChanged_RateOfFire);

	g_oActiveWeapon = FindSendPropOffs("CTFPlayer", "m_hActiveWeapon");
	g_oAmmoRockets = FindSendPropOffs("CObjectSentrygun", "m_iAmmoRockets");
	g_oAmmoShells = FindSendPropOffs("CObjectSentrygun", "m_iAmmoShells");
	g_oBuilder = FindSendPropOffs("CObjectSentrygun", "m_hBuilder");
	g_oClip = FindSendPropOffs("CBaseCombatWeapon", "m_iClip1");
	g_oIsMiniBuilding = FindSendPropOffs("CObjectSentrygun", "m_bMiniBuilding");
	g_oUpgradeLevel = FindSendPropOffs("CObjectSentrygun", "m_iUpgradeLevel");
	
	g_piActiveWeapon = FindSendPropInfo("CTFPlayer", "m_hActiveWeapon");
	g_piAmmo = FindSendPropInfo("CTFPlayer", "m_iAmmo");
	g_piBroken = FindSendPropInfo("CTFStickBomb", "m_bBroken");
	g_piDetonated = FindSendPropInfo("CTFStickBomb", "m_iDetonated");
	g_oMaxSpeed = FindSendPropInfo("CTFPlayer", "m_flMaxspeed");
	g_piNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");
	g_piNextSecondaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack");
	g_piOwner = FindSendPropInfo("CBaseObject", "m_hBuilder");

	if (g_oActiveWeapon == -1) SetFailState("Could not find CTFPlayer::m_hActiveWeapon offset");	
	if (g_oAmmoRockets == -1) SetFailState("Could not find CObjectSentrygun::m_iAmmoRockets offset");
	if (g_oAmmoShells == -1) SetFailState("Could not find CObjectSentrygun::m_iAmmoShells offset");
	if (g_oBuilder == -1) SetFailState("Could not find CObjectSentrygun::m_hBuilder offset");
	if (g_oClip == -1) SetFailState("Could not find CBaseCombatWeapon::m_iClip1 offset");
	if (g_oIsMiniBuilding == -1) SetFailState("Could not find CObjectSentrygun::m_bMiniBuilding offset");
	if (g_oMaxSpeed == -1) SetFailState("Could not find CTFPlayer::m_flMaxspeed info");
	if (g_oUpgradeLevel == -1) SetFailState("Could not find CObjectSentrygun::m_iUpgradeLevel offset");

	if (g_piActiveWeapon == -1) SetFailState("Could not find CTFPlayer::m_hActiveWeapon prop info");
	if (g_piAmmo == -1) SetFailState("Could not find CTFPlayer::m_iAmmo prop info");
	if (g_piBroken == -1) SetFailState("Could not find CTFStickBomb::m_bBroken prop info");
	if (g_piDetonated == -1) SetFailState("Could not find CTFStickBomb::m_iDetonated prop info");
	if (g_piNextPrimaryAttack == -1) SetFailState("Could not find CBaseCombatWeapon::m_flNextPrimaryAttack prop info");
	if (g_piNextSecondaryAttack == -1) SetFailState("Could not find CBaseCombatWeapon::m_flNextSecondaryAttack prop info");
	if (g_piOwner == -1) SetFailState("Could not find CBaseObject::m_hBuilder prop info");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("post_inventory_application", Event_InventoryApplication, EventHookMode_Post);
	HookEvent("player_builtobject", Event_PlayerBuiltObject);

	SetGamemodeState(GetConVarBool(g_hConVarIsEnabled));
}

public OnPluginEnd()
{
	SetGamemodeState(false);
}

public Event_ConVarChanged_IsEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new bool:state = GetConVarBool(convar);

	SetGamemodeState(state);
}

public Event_ConVarChanged_RateOfFire(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new Float:newRateOfFire = GetConVarFloat(convar);

	g_fRateOfFireMultiplier = 1.0/newRateOfFire;
}

public SetGamemodeState(bool:active)
{
	if (active && g_bIsEnabled
		|| !active && !g_bIsEnabled)
	{
		return;
	}

	if (active)
	{
		g_fRateOfFireMultiplier = 1.0/GetConVarFloat(g_hConVarRateOfFire);
		
		SetConVarInt(FindConVar("tf_fastbuild"), 1);
		
		SetConVarInt(FindConVar("tf_sentrygun_damage"), 300);
		SetConVarInt(FindConVar("tf_sentrygun_metal_per_rocket"), 1);
		SetConVarInt(FindConVar("tf_sentrygun_metal_per_shell"), 1);
		SetConVarFloat(FindConVar("tf_max_health_boost"), 1.0);
			
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				CPrintToChat(i, "%sAwesomeMod enabled!", PLUGIN_PREFIX);
				
				if (IsPlayerAlive(i))
				{
					CreateTimer(0.1, Timer_PlayerSpawned, i);
				}
			}
		}

		Steam_SetGameDescription("AwesomeMod!");

		CreateTimer(0.0, Timer_HudHealth);
		g_bIsEnabled = true;
	}
	else 
	{
		SetConVarInt(FindConVar("tf_fastbuild"), 0);
		
		ResetConVar(FindConVar("tf_sentrygun_damage"));
		ResetConVar(FindConVar("tf_sentrygun_metal_per_rocket"));
		ResetConVar(FindConVar("tf_sentrygun_metal_per_shell"));
		ResetConVar(FindConVar("tf_max_health_boost"));
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				CPrintToChat(i, "%sAwesomeMod disabled!", PLUGIN_PREFIX);
				
				if (IsPlayerAlive(i))
				{
					TF2_RegeneratePlayer(i);
					ResetPlayerHealth(i);
				}
			}
		}

		Steam_SetGameDescription("Team Fortress");

		g_bIsEnabled = false;
	}
}

public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if (g_bIsEnabled)
	{
		new entity = GetEntDataEnt2(client, g_piActiveWeapon);
		
		if (entity != -1)
		{
			g_aWeaponRateQueue[g_iWeaponRateQueueLength++] = entity;
		}

		result = true;
	}
	
	return Plugin_Continue;
}

public OnGameFrame()
{
	if (!g_bIsEnabled)
	{
		return;
	}

	if (!g_iWeaponRateQueueLength)
	{
		return;
	}
	
	decl entity, Float:time;
	new Float:engineTime = GetGameTime();
	
	for (new i = 0; i < g_iWeaponRateQueueLength; i++)
	{
		entity = g_aWeaponRateQueue[i];
		
		if (IsValidEntity(entity))
		{
			time = (GetEntDataFloat(entity, g_piNextPrimaryAttack) - engineTime) * g_fRateOfFireMultiplier;
			SetEntDataFloat(entity, g_piNextPrimaryAttack, time + engineTime, true);
			
			time = (GetEntDataFloat(entity, g_piNextSecondaryAttack) - engineTime) * g_fRateOfFireMultiplier;
			SetEntDataFloat(entity, g_piNextSecondaryAttack, time + engineTime, true);
		}
	}
	
	g_iWeaponRateQueueLength = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			RefillAmmo(i);
			
			new Float:maxSpeed = 400.0;
			
			if (TF2_GetPlayerClass(i) == TFClass_Heavy) 
			{
				maxSpeed = 350.0;
			}
			
			SetEntDataFloat(i, g_oMaxSpeed, maxSpeed, true);
		}
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsEnabled)
	{
		return Plugin_Handled;
	}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsClientInGame(client))
	{
		CreateTimer(0.1, Timer_PlayerSpawned, client);
		
		TF2_AddCondition(client, TFCond_Ubercharged, 3.0);
		PrintCenterText(client, "Spawn protection for 3 seconds!");
	}

	return Plugin_Handled;
}

public Action:Timer_PlayerSpawned(Handle:timer, any:client)
{
	if (!g_bIsEnabled)
	{
		return Plugin_Handled;
	}

	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		new TFClassType:playerClass = TF2_GetPlayerClass(client);
		new playerHealth = 0;
		
		switch (playerClass)
		{
			case TFClass_Scout:
			{
				playerHealth = GetRandomInt(2000, 4000);
				TF2_RemoveWeaponSlot(client, 2);
			}

			case TFClass_Soldier: playerHealth = GetRandomInt(4000, 6000);
			case TFClass_Pyro: playerHealth = GetRandomInt(2750, 4500);
			case TFClass_DemoMan: playerHealth = GetRandomInt(2700, 4355);
			case TFClass_Heavy: playerHealth = GetRandomInt(4000, 6000);
			case TFClass_Engineer: playerHealth = GetRandomInt(2500, 4500);
			case TFClass_Medic: playerHealth = GetRandomInt(2300, 4400);
			case TFClass_Sniper: playerHealth = GetRandomInt(3000, 4500);
			case TFClass_Spy: playerHealth = GetRandomInt(2750, 3450);
		}

		SetEntityHealth(client, playerHealth);
	}

	return Plugin_Handled;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsEnabled)
	{
		return Plugin_Handled;
	}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	CreateTimer(5.0, Timer_PlayerDied, client);
	
	return Plugin_Handled;
}

public Action:Timer_PlayerDied(Handle:timer, any:client)
{
	if (IsClientInGame(client)) 
	{
		TF2_RespawnPlayer(client);
	}
	
	return Plugin_Handled;
}

public Action:Event_OnPlayerTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (!g_bIsEnabled)
	{
		return Plugin_Continue;
	}

	if (IsClientValid(client) && IsClientValid(attacker))
	{
		new activeWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
		
		if (TF2_GetPlayerClass(attacker) == TFClass_Spy 
			&& activeWeapon == GetPlayerWeaponSlot(attacker, 2) 
			&& damage > 1000.0)	
		{
			decl String:className[32];
			
			if (GetEdictClassname(activeWeapon, className, sizeof(className)) 
				&& strcmp(className, "tf_weapon_knife", false) == 0)
			{
				damage = 500.0;				
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

stock bool:IsClientValid(client)
{
	return client > 0 
		&& client <= MaxClients 
		&& IsClientInGame(client) 
		&& (GetClientTeam(client) == 2 || GetClientTeam(client) == 3) 
		&& !IsFakeClient(client) 
		&& IsPlayerAlive(client);
}


public Event_InventoryApplication(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsEnabled)
	{
		return;
	}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, Timer_PlayerSpawned, client);
}

public Action:Event_PlayerBuiltObject(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bIsEnabled)
	{
		return Plugin_Handled;
	}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new index = GetEventInt(event, "index");
	new objectTypeId = GetEventInt(event, "object");

	if (IsClientInGame(client))
	{
		switch (objectTypeId)
		{
			case PLAYERBUILTOBJECT_ID_DISPENSER:
			{
				SetEntProp(index, Prop_Send, "m_bDisabled", 1);
				SetEntProp(index, Prop_Send, "m_iMaxHealth", 2500);
			}

			case PLAYERBUILTOBJECT_ID_SENTRY:
			{
				SetEntProp(index, Prop_Send, "m_iMaxHealth", 2000);
				SetEntProp(index, Prop_Send, "m_bGlowEnabled", 1);
			}
		}
	}

	return Plugin_Continue;     
}

public Action:Timer_HudHealth(Handle:timer)
{
	if (g_bIsEnabled) 
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				TF2_AddCondition(i, TFCond_Kritzkrieged, 1.1);
			}
		}
	
		CreateTimer(1.0, Timer_HudHealth);
	}
}

stock RefillAmmo(i)
{
	new weapon = GetEntDataEnt2(i, g_oActiveWeapon);
	
	if (!IsValidEntity(weapon)) 
	{
		return;
	}

	new TFClassType:playerClass = TF2_GetPlayerClass(i);
	new weaponId = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	new ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1) * 4;
	new String:weaponClassname[32];
	
	GetEntityClassname(weapon, weaponClassname, sizeof(weaponClassname));

	switch (playerClass)
	{
		case TFClass_Scout:
		{
			if (weaponId == 448) 
			{
				SetEntPropFloat(i, Prop_Send, "m_flHypeMeter", 100.0);
			}
		}
		
		case TFClass_Soldier:
		{
			if (GetEntPropFloat(i, Prop_Send, "m_flRageMeter") == 0.00)
			{
				SetEntPropFloat(i, Prop_Send, "m_flRageMeter", 100.0);
			}
			
			// Credit to Tylerst - Full ammo is 100.0, 20.0 per shot
			if (weaponId == 441 || weaponId == 442) 
			{
				SetEntPropFloat(weapon, Prop_Send, "m_flEnergy", 100.0);
			}
		}
		
		case TFClass_DemoMan:
		{
			if (!TF2_IsPlayerInCondition(i, TFCond_Charging))
			{
				SetEntPropFloat(i, Prop_Send, "m_flChargeMeter", 100.0);
			}
			
			if (weaponId == 307)
			{
				SetEntData(weapon, g_piBroken, 0, 1, true);
				SetEntData(weapon, g_piDetonated, 0, 1, true);
			}
		}
		
		case TFClass_Engineer:
		{
			SetEntData(i, (FindDataMapOffs(i, "m_iAmmo") + (3 * 4)), 200, 4);
			SetInfiniteSentryAmmo(i);
		}

		case TFClass_Medic:
		{
			if ((StrEqual(weaponClassname, "tf_weapon_medigun", false)) && GetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel") == 0.00) 
			{
				SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", 1.00);
			}
		}
	
		case TFClass_Spy:
		{
			SetEntPropFloat(i, Prop_Send, "m_flCloakMeter", 100.0);
		}
	}

	SetEntData(weapon, g_oClip, 99, 4, true);
	SetEntData(i, ammoType+g_piAmmo, 99, 4, true);
}

stock SetInfiniteSentryAmmo(client)
{
	new entity = -1; 
	
	while ((entity = FindEntityByClassname(entity, "obj_sentrygun")) != INVALID_ENT_REFERENCE)
	{
		if (IsValidEntity(entity))
		{
			new builder = GetEntDataEnt2(entity, g_oBuilder);
			
			if (builder == client)
			{
				new isMiniBuilding = GetEntData(entity, g_oIsMiniBuilding, 1);
				
				if (isMiniBuilding)
				{
					SetEntData(entity, g_oAmmoShells, 150, 2, true); 
				}
				else
				{
					new upgradeLevel = GetEntData(entity, g_oUpgradeLevel, 1);
					
					switch (upgradeLevel)
					{
						case 1:
						{
							SetEntData(entity, g_oAmmoShells, 150, 2, true);
						}
						
						case 2:
						{
							SetEntData(entity, g_oAmmoShells, 200, 2, true);
						}
						
						case 3:
						{
							SetEntData(entity, g_oAmmoShells, 200, 2, true);
							SetEntData(entity, g_oAmmoRockets, 20, 1, true);
						}
					}
				}
			}
		}
	}
}

stock ResetPlayerHealth(client)
{
	new TFClassType:playerClass = TF2_GetPlayerClass(client);
	new health = 125;
	
	switch (playerClass)
	{
		case TFClass_Soldier:
			health = 200;
			
		case TFClass_Pyro, TFClass_DemoMan:
			health = 175;
			
		case TFClass_Heavy:
			health = 300;
			
		case TFClass_Medic:
			health = 150;
	}
	
	SetEntityHealth(client, health);
}
