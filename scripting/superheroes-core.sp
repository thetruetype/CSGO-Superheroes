#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_TAG_COLORED "{green}[Superheroes]{default}"

#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

#include <superheroes/superheroes-core>
#include <superheroes/superheroes-heroes>
#include <superheroes/superheroes-actives>

ConVar convar_Status;

bool bLate;

public Plugin myinfo =
{
	name = "[CSGO] SuperHeroes: Core",
	author = "Keith Warren (Drixevel)",
	description = "SuperHeroes for CSGO.",
	version = PLUGIN_VERSION,
	url = "http://www.drixevel.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("superheroes-core");

	CreateNative("SuperHeroes_ShowMainMenu", Native_ShowMainMenu);

	bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	convar_Status = CreateConVar("sm_superheroes_status", "1", "Status of the Superheroes mod.\n(1 = on, 0 = off)", _, true, 0.0, true, 1.0);
	//AutoExecConfig();

	RegConsoleCmd("sm_mainmenu", Command_MainMenu, "Display the main menu for Superheroes.");
}

public void OnConfigsExecuted()
{
	if (bLate)
	{
		bLate = false;
	}
}

public Action Command_MainMenu(int client, int args)
{
	if (!GetConVarBool(convar_Status) || client == 0)
	{
		return Plugin_Handled;
	}

	ShowMainMenu(client);
	return Plugin_Handled;
}

void ShowMainMenu(int client)
{
	Menu menu = CreateMenu(MenuHandler_MainMenu);
	SetMenuTitle(menu, "SuperHeroes[%s]: Main Menu", PLUGIN_VERSION);

	AddMenuItem(menu, "info", "information");
	AddMenuItem(menu, "list", "list heroes");
	AddMenuItem(menu, "equip", "equip heroes");
	AddMenuItem(menu, "unequip", "unequip heroes");
	AddMenuItem(menu, "setbinds", "set active binds");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "info"))
			{
				ShowModInformation(param1);
			}
			else if (StrEqual(sInfo, "list"))
			{
				SuperHeroes_ShowHeroesList(param1);
			}
			else if (StrEqual(sInfo, "equip"))
			{
				SuperHeroes_ShowEquipHeroes(param1);
			}
			else if (StrEqual(sInfo, "unequip"))
			{
				SuperHeroes_ShowUnequipHeroes(param1);
			}
			else if (StrEqual(sInfo, "setbinds"))
			{
				SuperHeroes_ShowSetBinds(param1);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
}

void ShowModInformation(int client)
{
	Panel panel = CreatePanel();
	DrawPanelText(panel, "tldr; isgudmod");
	DrawPanelItem(panel, "back");
	SendPanelToClient(panel, client, PanelHandler_ModInformation, MENU_TIME_FOREVER);
	CloseHandle(panel);
}

public int PanelHandler_ModInformation(Menu menu, MenuAction action, int param1, int param2)
{
	ShowMainMenu(param1);
}

public int Native_ShowMainMenu(Handle plugin, int numParams)
{
	ShowMainMenu(GetNativeCell(1));
}
