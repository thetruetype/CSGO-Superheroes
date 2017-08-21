#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_TAG_COLORED "{green}[Superheroes]{default}"

#define MAX_HERO_NAME_LENGTH 64
#define MAX_DATA_VALUE_LENGTH 64
#define MAX_PASSIVE_NAME_LENGTH 64

#define PASSIVE_CALLBACK_ONEQUIP	0
#define PASSIVE_CALLBACK_ONUNEQUIP	1
#define PASSIVE_CALLBACK_ONSPAWN	2
#define PASSIVE_CALLBACK_ONDEATH	3

#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

#include <superheroes/superheroes-core>
#include <superheroes/superheroes-heroes>
#include <superheroes/superheroes-passives>

ConVar convar_Status;

Handle g_hForward_PassiveRequests;

bool bLate;

ArrayList g_hArray_PassiveList;
StringMap g_hTrie_PassiveCalls;

public Plugin myinfo =
{
	name = "[CSGO] SuperHeroes: Passives",
	author = "Keith Warren (Drixevel)",
	description = "SuperHeroes for CSGO.",
	version = PLUGIN_VERSION,
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("superheroes-passives");

	CreateNative("SuperHeroes_RegisterNewPassive", Native_RegisterNewPassive);

	g_hForward_PassiveRequests = CreateGlobalForward("SuperHeroes_OnPassiveRequests", ET_Ignore);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	convar_Status = CreateConVar("sm_superheroes_passives_status", "1", "Status of the Passives module.\n(1 = on, 0 = off)", _, true, 0.0, true, 1.0);
	//AutoExecConfig();

	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);

	g_hArray_PassiveList = CreateArray(ByteCountToCells(MAX_PASSIVE_NAME_LENGTH));
	g_hTrie_PassiveCalls = CreateTrie();
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	if (bLate)
	{
		bLate = false;
	}
}

public void OnAllPluginsLoaded()
{
	Call_StartForward(g_hForward_PassiveRequests);
	Call_Finish();
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client == 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	CallPassiveCallback(client, PASSIVE_CALLBACK_ONSPAWN);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client == 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	CallPassiveCallback(client, PASSIVE_CALLBACK_ONDEATH);
}

public void SuperHeroes_OnHeroEquip(int client, const char[] name)
{
	CallPassiveCallback(client, PASSIVE_CALLBACK_ONEQUIP, name);
}

public void SuperHeroes_OnHeroUnequip(int client, const char[] name)
{
	CallPassiveCallback(client, PASSIVE_CALLBACK_ONUNEQUIP, name);
}

int RegisterNewPassive(const char[] name, Handle& plugin, Function on_equip = INVALID_FUNCTION, Function on_unequip = INVALID_FUNCTION, Function on_spawn = INVALID_FUNCTION, Function on_death = INVALID_FUNCTION)
{
	if (FindStringInArray(g_hArray_PassiveList, name) != -1)
	{
		LogError("Error registering passive '%s': name already taken", name);
		return 0;
	}

	PushArrayString(g_hArray_PassiveList, name);

	Handle callbacks[4];

	if (on_equip != INVALID_FUNCTION)
	{
		callbacks[PASSIVE_CALLBACK_ONEQUIP] = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String);
		AddToForward(callbacks[PASSIVE_CALLBACK_ONEQUIP], plugin, on_equip);
	}

	if (on_unequip != INVALID_FUNCTION)
	{
		callbacks[PASSIVE_CALLBACK_ONUNEQUIP] = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String);
		AddToForward(callbacks[PASSIVE_CALLBACK_ONUNEQUIP], plugin, on_unequip);
	}

	if (on_spawn != INVALID_FUNCTION)
	{
		callbacks[PASSIVE_CALLBACK_ONSPAWN] = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String);
		AddToForward(callbacks[PASSIVE_CALLBACK_ONSPAWN], plugin, on_spawn);
	}

	if (on_death != INVALID_FUNCTION)
	{
		callbacks[PASSIVE_CALLBACK_ONDEATH] = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String);
		AddToForward(callbacks[PASSIVE_CALLBACK_ONDEATH], plugin, on_death);
	}

	SetTrieArray(g_hTrie_PassiveCalls, name, callbacks, sizeof(callbacks));
	return 0;
}

void CallPassiveCallback(int client, int callback, const char[] hero = "")
{
	if (strlen(hero) > 0)
	{
		CallPassiveCallbackHero(client, callback, hero);
		return;
	}

	ArrayList hero_pool = SuperHeroes_GetClientHeroPool(client);

	if (hero_pool != null)
	{
		for (int i = 0; i < GetArraySize(hero_pool); i++)
		{
			char sHero[MAX_HERO_NAME_LENGTH];
			GetArrayString(hero_pool, i, sHero, sizeof(sHero));

			CallPassiveCallbackHero(client, callback, sHero);
		}
	}
}

void CallPassiveCallbackHero(int client, int callback, const char[] hero)
{
	ArrayList passives; StringMap values;
	SuperHeroes_GetHeroPassives(hero, passives, values);

	if (passives == null || values == null)
	{
		return;
	}

	for (int x = 0; x < GetArraySize(passives); x++)
	{
		char sPassive[MAX_PASSIVE_NAME_LENGTH];
		GetArrayString(passives, x, sPassive, sizeof(sPassive));

		char sValues[MAX_DATA_VALUE_LENGTH];
		GetTrieString(values, sPassive, sValues, sizeof(sValues));

		ExecutePassiveCallback(callback, client, sPassive, sValues);
	}
}

void ExecutePassiveCallback(int callback, int client, const char[] name, const char[] values)
{
	Handle callbacks[4];
	if (!GetTrieArray(g_hTrie_PassiveCalls, name, callbacks, sizeof(callbacks)))
	{
		return;
	}

	if (callbacks[callback] != null && GetForwardFunctionCount(callbacks[callback]) > 0)
	{
		Call_StartForward(callbacks[callback]);
		Call_PushCell(client);
		Call_PushString(name);
		Call_PushString(values);
		Call_Finish();
	}
}

public int Native_RegisterNewPassive(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sName = new char[size + 1];
	GetNativeString(1, sName, size + 1);

	if (strlen(sName) == 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Unable to register passive: name string must be valid");
	}

	return RegisterNewPassive(sName, plugin, GetNativeFunction(2), GetNativeFunction(3), GetNativeFunction(4), GetNativeFunction(5));
}
