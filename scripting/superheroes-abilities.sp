#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_TAG_COLORED "{green}[Superheroes]{default}"

#define MAX_HERO_NAME_LENGTH 64
#define MAX_DATA_VALUE_LENGTH 64
#define MAX_ACTIVE_NAME_LENGTH 64

#define ACTIVE_CALLBACK_ONACTIVE	0

#include <sourcemod>
#include <sourcemod-misc>
#include <menus-stocks>
#include <colorvariables>

#include <superheroes/superheroes-core>
#include <superheroes/superheroes-heroes>
#include <superheroes/superheroes-actives>

ConVar convar_Status;

Handle g_hForward_ActiveRequests;

bool bLate;

ArrayList g_hArray_ActiveList;
StringMap g_hTrie_ActiveCalls;

StringMap g_hTrie_Bindings[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[CSGO] SuperHeroes: Actives",
	author = "Keith Warren (Drixevel)",
	description = "SuperHeroes for CSGO.",
	version = PLUGIN_VERSION,
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("superheroes-actives");

	CreateNative("SuperHeroes_RegisterNewActive", Native_RegisterNewActive);
	CreateNative("SuperHeroes_ShowSetBinds", Native_ShowSetBinds);

	g_hForward_ActiveRequests = CreateGlobalForward("SuperHeroes_OnActiveRequests", ET_Ignore);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	convar_Status = CreateConVar("sm_superheroes_actives_status", "1", "Status of the Actives module.\n(1 = on, 0 = off)", _, true, 0.0, true, 1.0);
	//AutoExecConfig();

	g_hArray_ActiveList = CreateArray(ByteCountToCells(MAX_ACTIVE_NAME_LENGTH));
	g_hTrie_ActiveCalls = CreateTrie();
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
	Call_StartForward(g_hForward_ActiveRequests);
	Call_Finish();
}

public void OnClientPutInServer(int client)
{
	delete g_hTrie_Bindings[client];
	g_hTrie_Bindings[client] = CreateTrie();
}

public void OnClientDisconnect(int client)
{
	delete g_hTrie_Bindings[client];
}

void ShowSetBindsMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_ShowBindsMenu);
	SetMenuTitle(menu, "SuperHeroes[%s]: Set Ability Binds", PLUGIN_VERSION);

	ArrayList hero_pool = SuperHeroes_GetClientHeroPool(client);

	if (hero_pool != null)
	{
		for (int i = 0; i < GetArraySize(hero_pool); i++)
		{
			char sHero[MAX_HERO_NAME_LENGTH];
			GetArrayString(hero_pool, i, sHero, sizeof(sHero));


		}
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_ShowBindsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{

		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public Action OnClientCommand(int client, int args)
{
	char sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));

	char sActive[MAX_ACTIVE_NAME_LENGTH];
	GetTrieString(g_hTrie_Bindings[client], sCommand, sActive, sizeof(sActive));

	CallActive(client, "", sActive);

	return Plugin_Continue;
}

int RegisterNewActive(const char[] name, Handle& plugin, float cooldown = 0.0, int charges = -1, Function on_active = INVALID_FUNCTION)
{
	if (FindStringInArray(g_hArray_ActiveList, name) != -1)
	{
		LogError("Error registering active '%s': name already taken", name);
		return 0;
	}

	PushArrayString(g_hArray_ActiveList, name);

	Handle callbacks[1];

	if (on_active != INVALID_FUNCTION)
	{
		callbacks[ACTIVE_CALLBACK_ONACTIVE] = CreateForward(ET_Event, Param_Cell, Param_String, Param_String, Param_Cell);
		AddToForward(callbacks[ACTIVE_CALLBACK_ONACTIVE], plugin, on_active);
	}

	SetTrieArray(g_hTrie_ActiveCalls, name, callbacks, sizeof(callbacks));
	return 0;
}

void CallActive(int client, const char[] hero, const char[] active)
{
	ArrayList actives; StringMap values;
	SuperHeroes_GetHeroActives(hero, actives, values);

	char sValues[MAX_DATA_VALUE_LENGTH];
	GetTrieString(values, active, sValues, sizeof(sValues));

	ExecuteActiveCallback(ACTIVE_CALLBACK_ONACTIVE, client, active, sValues);
}

Action ExecuteActiveCallback(int callback, int client, const char[] name, const char[] values)
{
	Handle callbacks[1];
	if (!GetTrieArray(g_hTrie_ActiveCalls, name, callbacks, sizeof(callbacks)))
	{
		return Plugin_Continue;
	}

	if (callbacks[callback] != null && GetForwardFunctionCount(callbacks[callback]) > 0)
	{
		Call_StartForward(callbacks[callback]);
		Call_PushCell(client);
		Call_PushString(name);
		Call_PushString(values);

		Action send;
		Call_Finish(send);

		return send;
	}

	return Plugin_Continue;
}

public int Native_RegisterNewActive(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sName = new char[size + 1];
	GetNativeString(1, sName, size + 1);

	if (strlen(sName) == 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Unable to register active: name string must be valid");
	}

	return RegisterNewActive(sName, plugin, GetNativeCell(2), GetNativeCell(3), GetNativeFunction(4));
}

public int Native_ShowSetBinds(Handle plugin, int numParams)
{
	ShowSetBindsMenu(GetNativeCell(1));
}
