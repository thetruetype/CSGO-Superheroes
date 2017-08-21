#if defined _superheroes_passives_included
  #endinput
#endif
#define _superheroes_passives_included

typedef Passive_OnEquip = function void (int client, const char[] name, const char[] values);
typedef Passive_OnUnequip = function void (int client, const char[] name, const char[] values);
typedef Passive_OnSpawn = function void (int client, const char[] name, const char[] values);
typedef Passive_OnDeath = function void (int client, const char[] name, const char[] values);

//////////////////////////////////////////////
//Natives
native void SuperHeroes_RegisterNewPassive(const char[] name, Passive_OnEquip on_equip = INVALID_FUNCTION, Passive_OnUnequip on_unequip = INVALID_FUNCTION, Passive_OnSpawn on_spawn = INVALID_FUNCTION, Passive_OnDeath on_death = INVALID_FUNCTION);

//////////////////////////////////////////////
//Forwards
forward void SuperHeroes_OnPassiveRequests();

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_superheroes_passives_SetNTVOptional()
{
	MarkNativeAsOptional("SuperHeroes_RegisterNewPassive");
}
#endif

public SharedPlugin __pl_superheroes_passives =
{
	name = "superheroes-passives",
	file = "superheroes-passives.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
