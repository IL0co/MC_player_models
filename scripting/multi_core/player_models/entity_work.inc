#include <sourcemod>


stock void Stock_Preview(int client, const char[] item)
{
	g_kvMain.Rewind();
	if(!g_kvMain.JumpToKey(item))
		return;

	Stock_SpawnDanceBomb(client, _, GetSubKV(), true);
}
