#if defined _superheroes_core_included
  #endinput
#endif
#define _superheroes_core_included

//////////////////////////////////////////////
//Natives
native void SuperHeroes_ShowMainMenu(int client);

//////////////////////////////////////////////
//Forwards


//////////////////////////////////////////////
//Info

#if !defined REQUIRE_PLUGIN
public void __pl_superheroes_core_SetNTVOptional()
{
	MarkNativeAsOptional("SuperHeroes_ShowMainMenu");
}
#endif

public SharedPlugin __pl_superheroes_core =
{
	name = "superheroes-core",
	file = "superheroes-core.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
