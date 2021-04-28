#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <mc_core>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name		= "[Multi-Core] Player Models",
	author	  	= "iLoco",
	description = "",
	version	 	= "0.0.1",
	url			= "iLoco#7631"
};

/*
	TODO:
	- подсветка моделей при превью в зависимости от команды (красная или синяя)
		- выбор между неоном и аурой (маяк)

*/

#define PLUGIN_ID "PlayerModel"
#define TARGET_NAME "PlayerModel"
#define TARGET_NAME_PREVIEW "PlayerModel_Preview"

float g_fPreviewLastTime[MAXPLAYERS+1];
Handle g_hPreviewTimerHandle[MAXPLAYERS+1];
int g_iPreviewEntities[MAXPLAYERS+1][4];

char g_cPluginsUniques[][] = {"Any Player Models", "T Player Models", "CT Player Models"};

KeyValues g_kvMain;
MC_PluginIndex g_PluginIndex[sizeof(g_cPluginsUniques)];

float g_fPreviewTime;
float g_fDelayTime;

#include "multi_core/player_models/events.inc"
#include "multi_core/player_models/entity_work.inc"

public void OnPluginEnd()
{
	MC_UnRegisterMe();
}

public void OnPluginStart()
{
	g_kvMain = MC_GetModuleConfigKV("player_models.cfg", "Player Models");

	g_fPreviewTime = g_kvMain.GetFloat("Preview time", 5.0);
	g_fDelayTime = g_kvMain.GetFloat("Delay");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerSpawn);

	LoadTranslations("mc_player_models.phrases");

	if(MC_IsCoreLoaded(Core_MultiCore))
		MC_OnCoreChangeStatus("", Core_MultiCore, true);
}

public void MC_OnCoreChangeStatus(char[] core_name, MC_CoreTypeBits core_type, bool isLoaded)
{
	if(!isLoaded || core_type != Core_MultiCore)
		return;

	PrintToServer("load MC Core");

	char buffer[256];

	for(int id; id < sizeof(g_cPluginsUniques); id++)
	{
		g_kvMain.Rewind();
		MC_RegisterPlugin(g_cPluginsUniques[id]);
		MC_SetPluginCallBacks(CallBack_OnCategoryDisplay);

		if(g_kvMain.JumpToKey(g_cPluginsUniques[id]) && g_kvMain.GotoFirstSubKey())
		{
			do
			{
				g_kvMain.GetSectionName(buffer, sizeof(buffer));

				if(!MC_StartItem(buffer))
					continue;
				
				MC_SetItemCallBacks(CallBack_OnItemDisplay, CallBack_OnItemPreview);
				MC_EndItem();
			}
			while(g_kvMain.GotoNextKey());
		}

		g_PluginIndex[id] = MC_EndPlugin();
	}
}

public bool CallBack_OnCategoryDisplay(int client, const char[] plugin_id, MC_PluginIndex plugin_index, MC_CoreTypeBits core_type, char[] buffer, int maxlen)
{
	if(!TranslationPhraseExists(plugin_id))
		return false;

	FormatEx(buffer, maxlen, "%T", plugin_id, client);
	return true;
}

public bool CallBack_OnItemDisplay(int client, const char[] plugin_id, MC_PluginIndex plugin_index, const char[] item_unique, MC_CoreTypeBits core_type, char[] buffer, int maxlen)
{
	g_kvMain.Rewind();

	if(!g_kvMain.JumpToKey(plugin_id))
		return false;

	if(!g_kvMain.JumpToKey(item_unique))
		return false;

	g_kvMain.GetString("Name", buffer, maxlen, item_unique);

	if(buffer[0] == '#' && TranslationPhraseExists(buffer))
		FormatEx(buffer, maxlen, "%T", buffer, client);

	return true;
}

public void CallBack_OnItemPreview(int client, const char[] plugin_id, MC_PluginIndex plugin_index, const char[] item_unique, MC_CoreTypeBits core_type)
{
	g_kvMain.Rewind();

	if(g_kvMain.JumpToKey(plugin_id) && g_kvMain.JumpToKey(item_unique))
	{
		KeyValues kv = new KeyValues(item_unique);
		KvCopySubkeys(g_kvMain, kv);

		Stock_SetClientModel(client, kv, true);
	}
}

public void OnMapStart()
{
	g_kvMain.Rewind();
	if(!g_kvMain.GotoFirstSubKey())
		return;
		
	char file[256];

	do
	{
		g_kvMain.SavePosition();
		
		if(g_kvMain.GotoFirstSubKey())
		{
			do
			{
				g_kvMain.GetString("CT Model", file, sizeof(file));
				if(file[0])
					MC_PrecacheFile(file, Type_Model);

				g_kvMain.GetString("T Model", file, sizeof(file));
				if(file[0])
					MC_PrecacheFile(file, Type_Model);

				g_kvMain.GetString("CT Arms", file, sizeof(file));
				if(file[0])
					MC_PrecacheFile(file, Type_Model);
					
				g_kvMain.GetString("T Arms", file, sizeof(file));
				if(file[0])
					MC_PrecacheFile(file, Type_Model);
			}
			while(g_kvMain.GotoNextKey());
		
			g_kvMain.GoBack();
		}
	}
	while(g_kvMain.GotoNextKey());
}
