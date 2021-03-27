#include <sourcemod>
// #include <cstrike>
#include <clientprefs>
#include <sdktools>
#include <sdkhooks>
#include <mc_core>
// #include <csgo_colors>

#undef REQUIRE_PLUGIN
// #tryinclude <shop>
// #tryinclude <vip_core>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name		= "[Multi-Core] Dance Bomb",
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

static const char g_cPluginsUniques[][] = {"Any Player Models", "T Player Models", "CT Player Models"};

KeyValues g_kvMain;
PluginId g_PluginId[sizeof(g_cPluginsUniques)];

float g_fPreviewTime;
float g_fDelayTime;

// #include "multi_core/player_models/entity_work.inc"
#include "multi_core/player_models/events.inc"

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

	char buffer[256];

	for(int id; id < sizeof(g_cPluginsUniques); id++)
	{
		g_kvMain.Rewind();
		MC_RegisterPlugin(g_cPluginsUniques[id], CallBack_OnCategoryDisplay);


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

		g_PluginId[id] = MC_EndPlugin();
	}
}

public bool CallBack_OnCategoryDisplay(int client, const char[] plugin_unique, PluginId plugin_id, MC_CoreTypeBits core_type, char[] buffer, int maxlen)
{
	if(!TranslationPhraseExists(plugin_unique))
		return false;

	FormatEx(buffer, maxlen, "%T", plugin_unique, client);
	return true;
}

public bool CallBack_OnItemDisplay(int client, const char[] plugin_unique, PluginId plugin_id, const char[] item_unique, MC_CoreTypeBits core_type, char[] buffer, int maxlen)
{
	g_kvMain.Rewind();

	if(!g_kvMain.JumpToKey(plugin_unique))
		return false;

	if(!g_kvMain.JumpToKey(item_unique))
		return false;

	g_kvMain.GetString("Name", buffer, maxlen, item_unique);

	if(buffer[0] == '#' && TranslationPhraseExists(buffer))
		FormatEx(buffer, maxlen, "%T", buffer, client);

	return true;
}

public void CallBack_OnItemPreview(int client, const char[] plugin_unique, PluginId plugin_id, const char[] item_unique, MC_CoreTypeBits core_type)
{
	g_kvMain.Rewind();

	if(g_kvMain.JumpToKey(plugin_unique) && g_kvMain.JumpToKey(item_unique))
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

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	int team = GetClientTeam(client);

	if(client <= 0 || team <= 1)
		return;

	char item[64], buff[1];
	g_kvMain.Rewind();

	for(int id; id < sizeof(g_cPluginsUniques); id++)
	{
		if((id == 1 && team != 2) || (id == 2 && team != 3))
			continue;

		if(!MC_GetClientActiveItem(client, g_PluginId[id], item, sizeof(item)))
			continue;
		
		g_kvMain.Rewind();
		g_kvMain.JumpToKey(g_cPluginsUniques[id]);
		g_kvMain.JumpToKey(item);

		g_kvMain.GetString(team == 3 ? "CT Model" : "T Model", buff, sizeof(buff));
		if(!buff[0])
			continue;

		KeyValues kv = new KeyValues(item);
		KvCopySubkeys(g_kvMain, kv);

		DataPack data = new DataPack();
		data.WriteCell(userid);
		data.WriteCell(kv);

		CreateTimer(kv.GetFloat("delay", g_fDelayTime), Timer_Delay_CreateBombDance, data, TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE);

		break;
	}
}

public Action Timer_Delay_CreateBombDance(Handle timer, DataPack data)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	KeyValues kv = data.ReadCell();

	Stock_SetClientModel(client, kv, false);

	return Plugin_Stop;
}

stock void Stock_SetClientModel(int client, KeyValues kv, bool isPreview)
{
	if(isPreview && !IsPlayerAlive(client))
	{
		delete kv;
		return;
	}

	if(client && IsClientInGame(client))
	{
		int team = GetClientTeam(client);
		char buff[256];

		if(isPreview)
		{
			float ang[3], pos[3], origin[3];
		
			GetClientEyePosition(client, pos);
			GetClientEyeAngles(client, ang);

			TR_TraceRayFilter(pos, ang, MASK_SOLID, RayType_Infinite, TraceRayFilter_NoPlayers);
			TR_GetEndPosition(origin);

			origin[2] -= 50.0;

			for(int id; id < 4; id++)
				Stock_KillEntity(g_iPreviewEntities[client][id]);

			g_iPreviewEntities[client][0] = EntIndexToEntRef( Create_PreviewEntity_Model(client, team, kv, origin, ang));
			g_iPreviewEntities[client][1] = EntIndexToEntRef( Create_PreviewEntity_Light(client, team, origin));

			origin[2] += 100.0;

			g_iPreviewEntities[client][2] = EntIndexToEntRef( Create_PreviewEntity_Model(client, team, kv, origin, ang));
			g_iPreviewEntities[client][3] = EntIndexToEntRef( Create_PreviewEntity_Light(client, team, origin));

			g_fPreviewLastTime[client] = kv.GetFloat("Preview time", g_fPreviewTime);
			g_hPreviewTimerHandle[client] = CreateTimer(0.1, Timer_Preview, GetClientUserId(client), TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}
		else
		{	
			kv.GetString(team == 3 ? "CT Model" : "T Model", buff, sizeof(buff));
			SetEntityModel(client, buff);
			
			kv.GetString(team == 3 ? "CT Arms" : "T Arms", buff, sizeof(buff));
			if(buff[0] && strcmp(buff[FindCharInString(buff, '.', true) + 1], "mdl", false) == 0) 
				SetEntPropString(client, Prop_Send, "m_szArmsModel", buff);
			
			Set_Color(client, team == 3 ? "CT Color" : "T Color", kv);
		}
	}

	delete kv;
}

int Create_PreviewEntity_Model(int client, int team, KeyValues kv, float origin[3], float ang[3])
{
	int model;

	if((model = CreateEntityByName("prop_dynamic_override")))
	{
		char buff[256];
		kv.GetString(team == 3 ? "CT Model" : "T Model", buff, sizeof(buff));
		SetEntityModel(model, buff);
		
		Set_Color(model, team == 3 ? "CT Color" : "T Color", kv);

		DispatchKeyValue(model, "targetname", TARGET_NAME_PREVIEW); 
		SetEntProp(model, Prop_Send, "m_CollisionGroup", 0);
		SetEntProp(model, Prop_Send, "m_nSolidType", 0);
		DispatchKeyValue(model, "solid", "1");
			
		SetEntityMoveType(model, MOVETYPE_VPHYSICS);
		
		TeleportEntity(model, origin, ang, NULL_VECTOR);	// TODO: в DanceBomb тоже добавить ang
		DispatchSpawn(model);

		SetEntPropEnt(model, Prop_Send, "m_hOwnerEntity", client);
		SDKHook(model, SDKHook_SetTransmit, Hook_SetTransmit);
	}

	return model;
}

int Create_PreviewEntity_Light(int client, int team, float origin[3])
{
	int light;

	if((light = CreateEntityByName("light_dynamic")))
	{
		DispatchKeyValue(light, "targetname", TARGET_NAME_PREVIEW);
		DispatchKeyValue(light, "brightness", "5");
		DispatchKeyValue(light, "_light", team == 3 ? "0 0 255 255" : "255 0 0 255");
		DispatchKeyValue(light, "spotlight_radius", "50");
		DispatchKeyValue(light, "distance", "150");
		DispatchKeyValue(light, "style", "0");

		DispatchSpawn(light);
		AcceptEntityInput(light, "TurnOn");
		TeleportEntity(light, origin, NULL_VECTOR, NULL_VECTOR);

		SetEntPropEnt(light, Prop_Send, "m_hOwnerEntity", client);
		SDKHook(light, SDKHook_SetTransmit, Hook_SetTransmit);
	}

	return light;
}

void Set_Color(int entity, char[] color_key, KeyValues kv)
{
	char buff[16];
	kv.GetString(color_key, buff, sizeof(buff));

	if(strlen(buff) > 7)
	{
		int color[4];
		kv.GetColor4("color", color);

		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, color[0], color[1], color[2], color[3]);
	}
}

public Action Timer_Preview(Handle timer, int client)
{
	client = GetClientOfUserId(client);

	PrintHintText(client, "%T", "Hint. Draw Preview Time", client, g_fPreviewLastTime[client]);

	if((g_fPreviewLastTime[client] -= 0.1) > 0.0 && g_hPreviewTimerHandle[client] == timer && client > 0 && client <= MaxClients && IsPlayerAlive(client) && IsClientInGame(client))
		return Plugin_Continue; 

	for(int id; id < 4; id++)
		Stock_KillEntity(g_iPreviewEntities[client][id]);

	return Plugin_Stop;
}

public Action Hook_SetTransmit(int ent, int client)
{
	static int owner;
	
	if((owner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity")) == -1)
		owner = 0;

	if(client != owner)
		return Plugin_Handled;

	return Plugin_Continue;
}

public bool TraceRayFilter_NoPlayers(int ent, int mask)
{
	if(ent > MaxClients)
		return true;

	return false;
}

stock void Stock_KillEntity(int ent_ref)
{
	int ent = EntRefToEntIndex(ent_ref);
	if(IsValidEntity(ent) && ent > 0 && ent < 2048)
		AcceptEntityInput(ent, "kill");
}
