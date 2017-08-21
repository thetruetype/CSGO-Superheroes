#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_TAG_COLORED "{green}[Superheroes]{default}"

#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

#include <superheroes/superheroes-core>
#include <superheroes/superheroes-heroes>
#include <superheroes/superheroes-passives>

float g_fManageSpeed[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[CSGO] SuperHeroes-Passive: Speed",
	author = "Keith Warren (Drixevel)",
	description = "SuperHeroes for CSGO.",
	version = PLUGIN_VERSION,
	url = "http://www.drixevel.com/"
};

public void OnPluginStart()
{

}

public void SuperHeroes_OnPassiveRequests()
{
	SuperHeroes_RegisterNewPassive("speed", OnPassiveEquip, OnPassiveUnequip, OnPassiveSpawn, OnPassiveDeath);
}

public void OnPassiveEquip(int client, const char[] name, const char[] values)
{

}

public void OnPassiveUnequip(int client, const char[] name, const char[] values)
{

}

public void OnPassiveSpawn(int client, const char[] name, const char[] values)
{
	g_fManageSpeed[client] = GetClientSpeed(client);

	float fSpeed = StringToFloat(values);

	SetClientSpeed(client, g_fManageSpeed[client] + fSpeed);
}

public void OnPassiveDeath(int client, const char[] name, const char[] values)
{
	float fSpeed = StringToFloat(values);

	g_fManageSpeed[client] -= fSpeed;

	SetClientSpeed(client, 	g_fManageSpeed[client]);
}

float GetClientSpeed(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
}

void SetClientSpeed(int client, float speed)
{
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", speed);
}
