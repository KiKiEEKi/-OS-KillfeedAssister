#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools_functions>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "[OS] KillFeed Assister",
	author = "KiKiEEKi ( DS: kikieeki | vk.com/kikieeki )",
	version = "( 1.2 )"
};

enum struct KillFeed
{
	int userid;
	int attacker;
	char weapon[32];
	bool headshot;
	int dominated;
	int revenge;
	int assister;
}
KillFeed g_esKillFeed[MAXPLAYERS+1];

float g_iEventTime = 0.5; //Через сколько сек. создать евент с ассистом

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	switch(GetEngineVersion())
	{
		case Engine_CSS: HookEvent("player_connect_client", Player_MsgBlock, EventHookMode_Pre);
	}
	HookEvent("player_connect", Player_MsgBlock, EventHookMode_Pre);
	HookEvent("player_disconnect", Player_MsgBlock, EventHookMode_Pre);
	UserMsg msg = GetUserMessageId("SayText2");
	if(msg != INVALID_MESSAGE_ID) HookUserMessage(msg, Hook_SayText2, true);
	msg = GetUserMessageId("TextMsg");
	if(msg != INVALID_MESSAGE_ID) HookUserMessage(msg, Hook_SayText2, true);
}

Action Hook_SayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	int iClient;

	if((iClient = BfReadByte(msg)) && IsClientInGame(iClient) && IsFakeClient(iClient)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action Player_MsgBlock(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	if(hEvent.GetBool("bot")) return Plugin_Handled;
	return Plugin_Continue;
}

void Event_PlayerHurt(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!(0 < iAttacker <= MaxClients)) return;
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if(iAttacker == iClient) return;

	if(hEvent.GetInt("health") > 0) {
		if(g_esKillFeed[iClient].assister == 0) {
			g_esKillFeed[iClient].assister = iAttacker;
		}
	}
}

Action Event_PlayerDeath(Event hEvent, const char[] sEvName, bool bDontBroadcast)
{
	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!(0 < iAttacker <= MaxClients)) return Plugin_Continue;
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if(iAttacker == iClient) return Plugin_Continue;
	if(g_esKillFeed[iClient].assister < 1 || g_esKillFeed[iClient].assister == iAttacker) return Plugin_Continue;

	hEvent.BroadcastDisabled = true;

	g_esKillFeed[iClient].userid = hEvent.GetInt("userid");
	hEvent.GetString("weapon", g_esKillFeed[iClient].weapon, sizeof(g_esKillFeed[].weapon));
	g_esKillFeed[iClient].headshot = hEvent.GetBool("headshot");
	g_esKillFeed[iClient].dominated = hEvent.GetInt("dominated");
	g_esKillFeed[iClient].revenge = hEvent.GetInt("revenge");

	g_esKillFeed[iClient].attacker = CreateFakeClient("●");
	ChangeClientTeam(g_esKillFeed[iClient].attacker, GetClientTeam(iAttacker));

	char sName[32];
	FormatEx(sName, sizeof(sName), "%N + %N", iAttacker, g_esKillFeed[iClient].assister);
	SetClientName(g_esKillFeed[iClient].attacker, sName);

	CreateTimer(g_iEventTime, Timer_KillFeed, hEvent.GetInt("userid"), (1<<1)); //TIMER_FLAG_NO_MAPCHANGE
	return Plugin_Changed;
}

Action Timer_KillFeed(Handle timer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if(!(0 < iClient <= MaxClients) || !IsClientInGame(iClient)) return Plugin_Continue;

	Event eEvent = CreateEvent("player_death", true);
	eEvent.SetInt("userid", g_esKillFeed[iClient].userid);
	eEvent.SetInt("attacker", GetClientUserId(g_esKillFeed[iClient].attacker));
	eEvent.SetString("weapon", g_esKillFeed[iClient].weapon);
	eEvent.SetBool("headshot", g_esKillFeed[iClient].headshot);
	eEvent.SetInt("dominated", g_esKillFeed[iClient].dominated);
	eEvent.SetInt("revenge", g_esKillFeed[iClient].revenge);

	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && !IsFakeClient(i)) {
			eEvent.FireToClient(i);
		}
	}
	eEvent.Cancel();

	g_esKillFeed[iClient].assister = 0;

	CreateTimer(g_iEventTime, Timer_KillFeed2, iUserId, (1<<1));

	return Plugin_Continue;
}

Action Timer_KillFeed2(Handle timer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if(!(0 < iClient <= MaxClients) || !IsClientInGame(iClient)) return Plugin_Continue;

	KickClient(g_esKillFeed[iClient].attacker);

	return Plugin_Continue;
}
