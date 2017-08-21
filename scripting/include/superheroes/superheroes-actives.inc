#if defined _superheroes_actives_included
  #endinput
#endif
#define _superheroes_actives_included

typedef Passive_OnActive = function Action (int client, const char[] name, const char[] values);

//////////////////////////////////////////////
//Natives
native void SuperHeroes_RegisterNewActive(const char[] name, float cooldown = 0.0, int charges = -1, Passive_OnActive on_active = INVALID_FUNCTION);
native void SuperHeroes_ShowSetBinds(int client);

//////////////////////////////////////////////
//Forwards
forward void SuperHeroes_OnActiveRequests();

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_superheroes_actives_SetNTVOptional()
{
	MarkNativeAsOptional("SuperHeroes_RegisterNewActive");
	MarkNativeAsOptional("SuperHeroes_ShowSetBinds");
}
#endif

public SharedPlugin __pl_superheroes_actives =
{
	name = "superheroes-actives",
	file = "superheroes-actives.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
