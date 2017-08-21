#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_TAG_COLORED "{green}[Superheroes]{default}"

#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>
#include <sdkhooks>

#include <superheroes/superheroes-core>
#include <superheroes/superheroes-heroes>
#include <superheroes/superheroes-actives>

ConVar convar_Cooldown;
ConVar convar_Charges;

public Plugin myinfo =
{
	name = "[CSGO] SuperHeroes-Active: Optic Blast",
	author = "Keith Warren (Drixevel)",
	description = "SuperHeroes for CSGO.",
	version = PLUGIN_VERSION,
	url = "http://www.drixevel.com/"
};

public void OnPluginStart()
{
	convar_Cooldown = CreateConVar("sm_superheroes_active_opticblast_cooldown", "0.20", "Cooldown for this ability. (0.0 = no cooldown)");
	convar_Charges = CreateConVar("sm_superheroes_active_opticblast_charges", "20", "Charges for this ability, presumably the max charges available. (-1 = unlimited)");
}

public void SuperHeroes_OnActiveRequests()
{
	SuperHeroes_RegisterNewActive("optic blast", GetConVarFloat(convar_Cooldown), GetConVarInt(convar_Charges), OnActiveUse);
}

public Action OnActiveUse(int client, const char[] name, const char[] values)
{
	int target = GetClientAimTarget(client, true);

	if (!IsPlayerIndex(client))
	{
		CPrintToChat(client, "Target not found.");
		return Plugin_Handled;
	}

	FireOpticBlast(client, target);
	return Plugin_Continue;
}

void FireOpticBlast(int client, int target)
{
	SDKHooks_TakeDamage(target, client, client, 56.0, DMG_ENERGYBEAM);
}
