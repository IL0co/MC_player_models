#include <sourcemod>

stock void Stock_SetClientModel(int client, KeyValues kv, bool isPreview, MC_PluginIndex plugin_index = INVALID_PLUGIN_INDEX)
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
			if(g_hPreviewTimerHandle[client])
			{
				delete g_hPreviewTimerHandle[client];
				g_hPreviewTimerHandle[client] = null;
			}
			
			for(int id; id < 4; id++)
				Stock_KillEntity(g_iPreviewEntities[client][id]);

			float ang[3], pos[3], origin[3], angle[3];
		
			GetClientEyePosition(client, pos);
			GetClientEyeAngles(client, ang);
			
			angle[1] = ang[1] - 180.0;
			ang[0] = 30.0;

			if(g_PluginIndex[0] == plugin_index)
			{
				ang[1] -= 20.0;
				angle[1] -= 20.0;
				TR_TraceRayFilter(pos, ang, MASK_SOLID, RayType_Infinite, TraceRayFilter_NoPlayers);
				TR_GetEndPosition(origin);

				g_iPreviewEntities[client][0] = EntIndexToEntRef(Create_PreviewEntity_Model(client, 2, kv, origin, angle));
				g_iPreviewEntities[client][1] = EntIndexToEntRef(Create_PreviewEntity_Light(client, 2, origin));

				ang[1] += 40.0;
				angle[1] += 40.0;
				TR_TraceRayFilter(pos, ang, MASK_SOLID, RayType_Infinite, TraceRayFilter_NoPlayers);
				TR_GetEndPosition(origin);

				g_iPreviewEntities[client][2] = EntIndexToEntRef(Create_PreviewEntity_Model(client, 3, kv, origin, angle));
				g_iPreviewEntities[client][3] = EntIndexToEntRef(Create_PreviewEntity_Light(client, 3, origin));
			}
			else
			{
				bool is_t_skin = view_as<bool>(g_PluginIndex[1] == plugin_index);
				
				TR_TraceRayFilter(pos, ang, MASK_SOLID, RayType_Infinite, TraceRayFilter_NoPlayers);
				TR_GetEndPosition(origin);

				g_iPreviewEntities[client][0] = EntIndexToEntRef(Create_PreviewEntity_Model(client, is_t_skin ? 2 : 3, kv, origin, angle));
				g_iPreviewEntities[client][1] = EntIndexToEntRef(Create_PreviewEntity_Light(client, is_t_skin ? 2 : 3, origin));
			}

			g_fPreviewLastTime[client] = kv.GetFloat("Preview time", g_fPreviewTime);
			g_hPreviewTimerHandle[client] = CreateTimer(0.1, Timer_Preview, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
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

int Create_PreviewEntity_Model(int client, int team, KeyValues kv, float origin[3], float angle[3])
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
		DispatchKeyValue(model, "solid", "0");
			
		SetEntityMoveType(model, MOVETYPE_VPHYSICS);
		
		TeleportEntity(model, origin, angle, NULL_VECTOR);	// TODO: в DanceBomb тоже добавить ang
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

		origin[2] += 5.0;
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

	PrintHintText(client, "%T", "HINT DRAW PREVIEW TIME", client, g_fPreviewLastTime[client]);

	if((g_fPreviewLastTime[client] -= 0.1) > 0.0 && g_hPreviewTimerHandle[client] == timer && client > 0 && client <= MaxClients && IsPlayerAlive(client) && IsClientInGame(client))
		return Plugin_Continue; 

	for(int id; id < 4; id++)
		Stock_KillEntity(g_iPreviewEntities[client][id]);

	g_hPreviewTimerHandle[client] = null;

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
