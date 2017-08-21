#if defined _superheroes_heroes_included
  #endinput
#endif
#define _superheroes_heroes_included

//////////////////////////////////////////////
//Natives
native void SuperHeroes_ShowHeroesList(int client);
native void SuperHeroes_ShowEquipHeroes(int client);
native void SuperHeroes_ShowUnequipHeroes(int client);
native bool SuperHeroes_GetHeroPassives(const char[] hero, ArrayList passives, StringMap values);
native bool SuperHeroes_GetHeroActives(const char[] hero, ArrayList passives, StringMap values);
native ArrayList SuperHeroes_GetClientHeroPool(int client);

//////////////////////////////////////////////
//Forwards
forward void SuperHeroes_OnHeroEquip(int client, const char[] name);
forward void SuperHeroes_OnHeroUnequip(int client, const char[] name);

//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_superheroes_heroes_SetNTVOptional()
{
	MarkNativeAsOptional("SuperHeroes_ShowHeroesList");
	MarkNativeAsOptional("SuperHeroes_ShowEquipHeroes");
	MarkNativeAsOptional("SuperHeroes_ShowUnequipHeroes");
	MarkNativeAsOptional("SuperHeroes_GetHeroPassives");
	MarkNativeAsOptional("SuperHeroes_GetHeroActives");
	MarkNativeAsOptional("SuperHeroes_GetClientHeroPool");
}
#endif

public SharedPlugin __pl_superheroes_heroes =
{
	name = "superheroes-heroes",
	file = "superheroes-heroes.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
