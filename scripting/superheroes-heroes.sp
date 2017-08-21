#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_TAG_COLORED "{green}[Superheroes]{default}"

#define MAX_HERO_NAME_LENGTH 64
#define MAX_HERO_DESCRIPTION_LENGTH 255

#define MAX_PASSIVE_NAME_LENGTH 64
#define MAX_ACTIVE_NAME_LENGTH 64

#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

#include <superheroes/superheroes-core>
#include <superheroes/superheroes-heroes>

ConVar convar_Status;
ConVar convar_Configs;
ConVar convar_MaxHeroes;

Handle g_hForward_OnHeroEquip;
Handle g_hForward_OnHeroUnequip;

bool bLate;

ArrayList g_hArray_HeroPool[MAXPLAYERS + 1];

//Heroes Data
ArrayList g_hArray_HeroesList;
StringMap g_hTrie_Description;
StringMap g_hTrie_Model;
StringMap g_hTrie_ArmsModel;
StringMap g_hTrie_Health;
StringMap g_hTrie_Speed;
StringMap g_hTrie_Armor;
StringMap g_hTrie_Helmet;
StringMap g_hTrie_Information;
StringMap g_hTrie_Passives;
StringMap g_hTrie_PassiveValues;
StringMap g_hTrie_Actives;
StringMap g_hTrie_ActiveValues;

public Plugin myinfo =
{
	name = "[CSGO] SuperHeroes: Heroes",
	author = "Keith Warren (Drixevel)",
	description = "SuperHeroes for CSGO.",
	version = PLUGIN_VERSION,
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("superheroes-heroes");

	CreateNative("SuperHeroes_ShowHeroesList", Native_ShowHeroesList);
	CreateNative("SuperHeroes_ShowEquipHeroes", Native_ShowEquipHeroes);
	CreateNative("SuperHeroes_ShowUnequipHeroes", Native_ShowUnequipHeroes);
	CreateNative("SuperHeroes_GetHeroPassives", Native_GetHeroPassives);
	CreateNative("SuperHeroes_GetHeroActives", Native_GetHeroActives);
	CreateNative("SuperHeroes_GetClientHeroPool", Native_GetClientHeroPool);

	g_hForward_OnHeroEquip = CreateGlobalForward("SuperHeroes_OnHeroEquip", ET_Ignore, Param_Cell, Param_String);
	g_hForward_OnHeroUnequip = CreateGlobalForward("SuperHeroes_OnHeroUnequip", ET_Ignore, Param_Cell, Param_String);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	convar_Status = CreateConVar("sm_superheroes_heroes_status", "1", "Status of the Heroes module.\n(1 = on, 0 = off)", _, true, 0.0, true, 1.0);
	convar_Configs = CreateConVar("sm_superheroes_heroes_configs", "configs/superheroes/heroes/", "Location to find the hero configuration files.");
	convar_MaxHeroes = CreateConVar("sm_superheroes_heroes_max_limit", "3", "Maximum amount of heroes that players can equip.", _, true, 1.0);
	//AutoExecConfig();

	RegConsoleCmd("sm_listheroes", Command_ListHeroes, "Display the list of available Superheroes and what they do.");
	RegConsoleCmd("sm_equipheroes", Command_EquipHeroes, "Equip heroes to your hero pool.");

	g_hArray_HeroesList = CreateArray(ByteCountToCells(MAX_HERO_NAME_LENGTH));
	g_hTrie_Description = CreateTrie();
	g_hTrie_Model = CreateTrie();
	g_hTrie_ArmsModel = CreateTrie();
	g_hTrie_Health = CreateTrie();
	g_hTrie_Speed = CreateTrie();
	g_hTrie_Armor = CreateTrie();
	g_hTrie_Helmet = CreateTrie();
	g_hTrie_Information = CreateTrie();
	g_hTrie_Passives = CreateTrie();
	g_hTrie_PassiveValues = CreateTrie();
	g_hTrie_Actives = CreateTrie();
	g_hTrie_ActiveValues = CreateTrie();
}

public void OnConfigsExecuted()
{
	if (!GetConVarBool(convar_Status))
	{
		return;
	}

	char sConfigs[PLATFORM_MAX_PATH];
	GetConVarString(convar_Configs, sConfigs, sizeof(sConfigs));

	ParseHeroConfigs(sConfigs);

	if (bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}

		bLate = false;
	}
}

void ParseHeroConfigs(const char[] configs)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), configs);

	DirectoryListing dir = OpenDirectory(sPath);

	if (dir == null)
	{
		LogError("Error parsing hero configs at '%s': invalid location", sPath);
		return;
	}

	ClearArray(g_hArray_HeroesList);
	ClearTrie(g_hTrie_Description);
	ClearTrie(g_hTrie_Model);
	ClearTrie(g_hTrie_ArmsModel);
	ClearTrie(g_hTrie_Health);
	ClearTrie(g_hTrie_Speed);
	ClearTrie(g_hTrie_Armor);
	ClearTrie(g_hTrie_Helmet);
	ClearTrieSafe(g_hTrie_Information);
	ClearTrieSafe(g_hTrie_Passives);
	ClearTrieSafe(g_hTrie_PassiveValues);
	ClearTrieSafe(g_hTrie_Actives);
	ClearTrieSafe(g_hTrie_ActiveValues);

	char sFile[PLATFORM_MAX_PATH];
	FileType type;

	while (ReadDirEntry(dir, sFile, sizeof(sFile), type))
	{
		if (type != FileType_File)
		{
			continue;
		}

		Format(sFile, sizeof(sFile), "%s%s", sPath, sFile);
		ParseHeroConfig(sFile);
	}

	CloseHandle(dir);

	SortADTArray(g_hArray_HeroesList, Sort_Ascending, Sort_String);
	LogMessage("Hero configurations successfully parsed for '%i' heroes at '%s'.", GetArraySize(g_hArray_HeroesList), configs);
}

void ParseHeroConfig(const char[] hero_config)
{
	KeyValues kv = CreateKeyValues("heroes_config");

	if (!FileToKeyValues(kv, hero_config))
	{
		LogError("Error parsing hero config for '%s': missing file", hero_config);
		return;
	}

	char sName[MAX_HERO_NAME_LENGTH];
	KvGetString(kv, "name", sName, sizeof(sName));

	if (strlen(sName) == 0)
	{
		LogError("Error parsing hero config for '%s': name field is required", hero_config);
		return;
	}

	if (FindStringInArray(g_hArray_HeroesList, sName) != -1)
	{
		LogError("Error parsing hero config for '%s': hero name '%s' already taken", hero_config, sName);
		return;
	}

	PushArrayString(g_hArray_HeroesList, sName);

	//Description
	char sDescription[MAX_HERO_DESCRIPTION_LENGTH];
	KvGetString(kv, "description", sDescription, sizeof(sDescription));

	if (strlen(sDescription) > 0)
	{
		SetTrieString(g_hTrie_Description, sName, sDescription);
	}

	//Model
	char sModel[PLATFORM_MAX_PATH];
	KvGetString(kv, "model", sModel, sizeof(sModel));

	if (strlen(sModel) > 0)
	{
		SetTrieString(g_hTrie_Model, sName, sModel);
	}

	//Arms Model
	char sArmsModel[PLATFORM_MAX_PATH];
	KvGetString(kv, "arms_model", sArmsModel, sizeof(sArmsModel));

	if (strlen(sArmsModel) > 0)
	{
		SetTrieString(g_hTrie_ArmsModel, sName, sArmsModel);
	}

	//Health
	int iHealth = KvGetNum(kv, "health", 0);

	if (iHealth > 0)
	{
		SetTrieValue(g_hTrie_Health, sName, iHealth);
	}

	//Speed
	float fSpeed = KvGetFloat(kv, "speed", 1.0);

	if (fSpeed != 1.0)
	{
		SetTrieValue(g_hTrie_Speed, sName, fSpeed);
	}

	//Armor
	int iArmor = KvGetNum(kv, "armor", 0);

	if (iArmor > 0)
	{
		SetTrieValue(g_hTrie_Armor, sName, iArmor);
	}

	//Helmet
	bool bHelmet = KvGetBool(kv, "armor", false);
	SetTrieValue(g_hTrie_Helmet, sName, bHelmet);

	//Information
	if (KvJumpToKey(kv, "information") && KvGotoFirstSubKey(kv, false))
	{
		ArrayList array_information = CreateArray(ByteCountToCells(64));

		do
		{
			char sInformation[64];
			KvGetString(kv, NULL_STRING, sInformation, sizeof(sInformation));

			if (strlen(sInformation) > 0)
			{
				PushArrayString(array_information, sInformation);
			}
		}
		while(KvGotoNextKey(kv, false));

		SetTrieValue(g_hTrie_Information, sName, array_information);

		KvGoBack(kv); KvGoBack(kv);
	}

	//Passives
	if (KvJumpToKey(kv, "passives") && KvGotoFirstSubKey(kv, false))
	{
		ArrayList array_passives = CreateArray(ByteCountToCells(MAX_PASSIVE_NAME_LENGTH));
		StringMap trie_values = CreateTrie();

		do
		{
			char sPassive[MAX_PASSIVE_NAME_LENGTH];
			KvGetSectionName(kv, sPassive, sizeof(sPassive));

			if (strlen(sPassive) == 0 || FindStringInArray(array_passives, sPassive) != -1)
			{
				continue;
			}

			PushArrayString(array_passives, sPassive);

			char sValues[64];
			KvGetString(kv, NULL_STRING, sValues, sizeof(sValues));

			if (strlen(sValues) > 0)
			{
				SetTrieString(trie_values, sPassive, sValues);
			}
		}
		while(KvGotoNextKey(kv, false));

		SetTrieValue(g_hTrie_Passives, sName, array_passives);
		SetTrieValue(g_hTrie_PassiveValues, sName, trie_values);

		KvGoBack(kv); KvGoBack(kv);
	}

	//Actives
	if (KvJumpToKey(kv, "abilities") && KvGotoFirstSubKey(kv, false))
	{
		ArrayList array_actives = CreateArray(ByteCountToCells(MAX_ACTIVE_NAME_LENGTH));
		StringMap trie_values = CreateTrie();

		do
		{
			char sActive[MAX_ACTIVE_NAME_LENGTH];
			KvGetSectionName(kv, sActive, sizeof(sActive));

			if (strlen(sActive) == 0 || FindStringInArray(array_actives, sActive) != -1)
			{
				continue;
			}

			PushArrayString(array_actives, sActive);

			char sValues[64];
			KvGetString(kv, NULL_STRING, sValues, sizeof(sValues));

			if (strlen(sValues) > 0)
			{
				SetTrieString(trie_values, sActive, sValues);
			}
		}
		while(KvGotoNextKey(kv, false));

		SetTrieValue(g_hTrie_Actives, sName, array_actives);
		SetTrieValue(g_hTrie_ActiveValues, sName, trie_values);

		KvGoBack(kv); KvGoBack(kv);
	}

	CloseHandle(kv);
}

public void OnClientPutInServer(int client)
{
	if (!GetConVarBool(convar_Status) || IsFakeClient(client))
	{
		return;
	}

	delete g_hArray_HeroPool[client];
	g_hArray_HeroPool[client] = CreateArray(ByteCountToCells(MAX_HERO_NAME_LENGTH));
}

public void OnClientDisconnect(int client)
{
	if (!GetConVarBool(convar_Status) || IsFakeClient(client))
	{
		return;
	}

	char sName[MAX_HERO_NAME_LENGTH];

	for (int i = 0; i < GetArraySize(g_hArray_HeroPool[client]); i++)
	{
		GetArrayString(g_hArray_HeroPool[client], i, sName, sizeof(sName));

		Call_StartForward(g_hForward_OnHeroUnequip);
		Call_PushCell(client);
		Call_PushString(sName);
		Call_Finish();
	}

	delete g_hArray_HeroPool[client];
}

bool IsMaxHeroesReached(int client)
{
	return view_as<bool>(GetArraySize(g_hArray_HeroPool[client]) >= GetConVarInt(convar_MaxHeroes));
}

//List Heroes
public Action Command_ListHeroes(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ShowHeroesList(client);
	return Plugin_Handled;
}

void ShowHeroesList(int client)
{
	Menu menu = CreateMenu(MenuHandler_ListHeroes);
	SetMenuTitle(menu, "SuperHeroes[%s]: Heroes List", PLUGIN_VERSION);

	char sDisplay[128];
	char sName[MAX_HERO_NAME_LENGTH];
	char sDescription[MAX_HERO_DESCRIPTION_LENGTH];

	for (int i = 0; i < GetArraySize(g_hArray_HeroesList); i++)
	{
		GetArrayString(g_hArray_HeroesList, i, sName, sizeof(sName));

		FormatEx(sDisplay, sizeof(sDisplay), "%s", sName);

		if (GetTrieString(g_hTrie_Description, sName, sDescription, sizeof(sDescription)))
		{
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
		}

		AddMenuItem(menu, sName, sDisplay, ITEMDRAW_DEFAULT);
	}

	if (GetMenuItemCount(menu) == 0)
	{
		AddMenuItem(menu, "", "[No Heroes Available]", ITEMDRAW_DISABLED);
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_ListHeroes(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sName[MAX_HERO_NAME_LENGTH];
			GetMenuItem(menu, param2, sName, sizeof(sName));

			ArrayList array_information;
			if (GetTrieValue(g_hTrie_Information, sName, array_information) && array_information != null)
			{
				Panel panel = CreatePanel();

				for (int i = 0; i < GetArraySize(array_information); i++)
				{
					char sInformation[64];
					GetArrayString(array_information, i, sInformation, sizeof(sInformation));

					DrawPanelText(panel, sInformation);
				}

				DrawPanelItem(panel, "back");
				SendPanelToClient(panel, param1, PanelHandler_ListHeroes, MENU_TIME_FOREVER);
				CloseHandle(panel);
			}
			else
			{
				CPrintToChat(param1, "%s No information to give, sorry.", PLUGIN_TAG_COLORED);
				ShowHeroesList(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				SuperHeroes_ShowMainMenu(param1);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public int PanelHandler_ListHeroes(Menu menu, MenuAction action, int param1, int param2)
{
	ShowHeroesList(param1);
}

//Equip Heroes
public Action Command_EquipHeroes(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ShowEquipHeroesMenu(client);
	return Plugin_Handled;
}

void ShowEquipHeroesMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_EquipHeroes);
	SetMenuTitle(menu, "SuperHeroes[%s]: Equip Heroes", PLUGIN_VERSION);

	char sDisplay[128];
	char sName[MAX_HERO_NAME_LENGTH];
	char sDescription[MAX_HERO_DESCRIPTION_LENGTH];
	int itemdraw;

	for (int i = 0; i < GetArraySize(g_hArray_HeroesList); i++)
	{
		GetArrayString(g_hArray_HeroesList, i, sName, sizeof(sName));

		FormatEx(sDisplay, sizeof(sDisplay), "%s", sName);

		if (GetTrieString(g_hTrie_Description, sName, sDescription, sizeof(sDescription)))
		{
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sDescription);
		}

		itemdraw = FindStringInArray(g_hArray_HeroPool[client], sName) != -1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;

		AddMenuItem(menu, sName, sDisplay, itemdraw);
	}

	if (GetMenuItemCount(menu) == 0)
	{
		AddMenuItem(menu, "", "[No Heroes Available]", ITEMDRAW_DISABLED);
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_EquipHeroes(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sName[MAX_HERO_NAME_LENGTH];
			GetMenuItem(menu, param2, sName, sizeof(sName));

			if (IsMaxHeroesReached(param1))
			{
				CPrintToChat(param1, "%s You aren't allowed to equip more than %i heroes at a time.", PLUGIN_TAG_COLORED, GetConVarInt(convar_MaxHeroes));
				ShowEquipHeroesMenu(param1);
				return;
			}

			if (FindStringInArray(g_hArray_HeroPool[param1], sName) != -1)
			{
				CPrintToChat(param1, "%s You cannot equip '%s', you already have them equipped.", PLUGIN_TAG_COLORED, sName);
				ShowEquipHeroesMenu(param1);
				return;
			}

			PushArrayString(g_hArray_HeroPool[param1], sName);
			SortADTArray(g_hArray_HeroPool[param1], Sort_Ascending, Sort_String);
			CPrintToChat(param1, "%s Hero '%s' has been equipped.", PLUGIN_TAG_COLORED, sName);

			Call_StartForward(g_hForward_OnHeroEquip);
			Call_PushCell(param1);
			Call_PushString(sName);
			Call_Finish();

			ShowEquipHeroesMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				SuperHeroes_ShowMainMenu(param1);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

//Unequip Heroes
public Action Command_UnequipHeroes(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ShowUnequipHeroesMenu(client);
	return Plugin_Handled;
}

void ShowUnequipHeroesMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_UnequipHeroes);
	SetMenuTitle(menu, "SuperHeroes[%s]: Unequip Heroes", PLUGIN_VERSION);

	char sName[MAX_HERO_NAME_LENGTH];

	for (int i = 0; i < GetArraySize(g_hArray_HeroPool[client]); i++)
	{
		GetArrayString(g_hArray_HeroPool[client], i, sName, sizeof(sName));

		AddMenuItem(menu, sName, sName, ITEMDRAW_DEFAULT);
	}

	if (GetMenuItemCount(menu) == 0)
	{
		AddMenuItem(menu, "", "[No Heroes Equipped]", ITEMDRAW_DISABLED);
	}

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_UnequipHeroes(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sName[MAX_HERO_NAME_LENGTH];
			GetMenuItem(menu, param2, sName, sizeof(sName));

			int index = FindStringInArray(g_hArray_HeroPool[param1], sName);

			if (index == -1)
			{
				CPrintToChat(param1, "%s You cannot unequip '%s', you don't have them equipped.", PLUGIN_TAG_COLORED, sName);
				ShowEquipHeroesMenu(param1);
				return;
			}

			RemoveFromArray(g_hArray_HeroPool[param1], index);
			CPrintToChat(param1, "%s Hero '%s' has been unequipped.", PLUGIN_TAG_COLORED, sName);

			Call_StartForward(g_hForward_OnHeroUnequip);
			Call_PushCell(param1);
			Call_PushString(sName);
			Call_Finish();

			ShowUnequipHeroesMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				SuperHeroes_ShowMainMenu(param1);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

public int Native_ShowHeroesList(Handle plugin, int numParams)
{
	ShowHeroesList(GetNativeCell(1));
}

public int Native_ShowEquipHeroes(Handle plugin, int numParams)
{
	ShowEquipHeroesMenu(GetNativeCell(1));
}

public int Native_ShowUnequipHeroes(Handle plugin, int numParams)
{
	ShowUnequipHeroesMenu(GetNativeCell(1));
}

public int Native_GetHeroPassives(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sHero = new char[size + 1];
	GetNativeString(1, sHero, size + 1);

	if (strlen(sHero) == 0)
	{
		return false;
	}

	ArrayList array_passives;
	GetTrieValue(g_hTrie_Passives, sHero, array_passives);
	SetNativeCellRef(2, array_passives);

	StringMap trie_values;
	GetTrieValue(g_hTrie_PassiveValues, sHero, trie_values);
	SetNativeCellRef(3, trie_values);

	return true;
}

public int Native_GetHeroActives(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);

	char[] sHero = new char[size + 1];
	GetNativeString(1, sHero, size + 1);

	if (strlen(sHero) == 0)
	{
		return false;
	}

	ArrayList array_actives;
	GetTrieValue(g_hTrie_Actives, sHero, array_actives);
	SetNativeCellRef(2, array_actives);

	StringMap trie_values;
	GetTrieValue(g_hTrie_ActiveValues, sHero, trie_values);
	SetNativeCellRef(3, trie_values);

	return true;
}

public int Native_GetClientHeroPool(Handle plugin, int numParams)
{
	return g_hArray_HeroesList[GetNativeCell(1)];
}
