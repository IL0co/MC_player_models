#include <sourcemod>

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if(!IsClientInGame(client) || IsFakeClient(client))
		return;

	int team = GetClientTeam(client);

	if(client <= 0 || team <= 1)
		return;

	char item[64], buff[1];
	g_kvMain.Rewind();

	for(int id; id < sizeof(g_cPluginsUniques); id++)
	{
		if((id == 1 && team != 2) || (id == 2 && team != 3))
			continue;

		if(!MC_GetClientActiveItem(client, g_cPluginsUniques[id], item, sizeof(item)))
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
		data.WriteString(g_cPluginsUniques[id]);

		CreateTimer(kv.GetFloat("delay", g_fDelayTime), Timer_Delay, data, TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE);

		break;
	}
}

public Action Timer_Delay(Handle timer, DataPack data)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	KeyValues kv = data.ReadCell();

	char plugin_id[MAX_UNIQUE_LENGTH];
	data.ReadString(plugin_id, sizeof(plugin_id));

	Stock_SetClientModel(client, kv, false, plugin_id);

	return Plugin_Stop;
}