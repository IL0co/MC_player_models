#include <sourcemod>

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

			g_iPreviewEntities[client][0] = EntIndexToEntRef(Create_PreviewEntity_Model(client, team, kv, origin, ang));
			g_iPreviewEntities[client][1] = EntIndexToEntRef(Create_PreviewEntity_Light(client, team, origin));

			origin[2] += 100.0;

			g_iPreviewEntities[client][2] = EntIndexToEntRef(Create_PreviewEntity_Model(client, team, kv, origin, ang));
			g_iPreviewEntities[client][3] = EntIndexToEntRef(Create_PreviewEntity_Light(client, team, origin));

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

	PrintHintText(client, "%T", "HINT DRAW PREVIEW TIME", client, g_fPreviewLastTime[client]);

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
