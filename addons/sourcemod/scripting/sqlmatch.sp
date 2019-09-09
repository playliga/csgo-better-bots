#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

Handle db;

public void OnPluginStart()
{
	char buffer[1024];

	if ((db = SQL_Connect("sql_matches", true, buffer, sizeof(buffer))) == null)
	{
		SetFailState(buffer);
	}

	Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS sql_matches_scoretotal (");
	Format(buffer, sizeof(buffer), "%s match_id bigint(20) unsigned NOT NULL AUTO_INCREMENT,", buffer);
	Format(buffer, sizeof(buffer), "%s timestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,", buffer);
	Format(buffer, sizeof(buffer), "%s team_0 int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s team_1 int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s team_2 int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s team_2_name varchar(128) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s team_3 int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s team_3_name varchar(128) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s map varchar(128) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s PRIMARY KEY (match_id),", buffer);
	Format(buffer, sizeof(buffer), "%s UNIQUE KEY match_id (match_id));", buffer);

	if (!SQL_FastQuery(db, buffer))
	{
		SQL_GetError(db, buffer, sizeof(buffer));
		SetFailState(buffer);
	}

	Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS sql_matches (");
	Format(buffer, sizeof(buffer), "%s match_id bigint(20) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s name varchar(65) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s team int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s kills int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s deaths int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s 5k int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s 4k int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s 3k int(11) NOT NULL,", buffer);
	Format(buffer, sizeof(buffer), "%s damage int(11) NOT NULL);", buffer);

	if (!SQL_FastQuery(db, buffer))
	{
		SQL_GetError(db, buffer, sizeof(buffer));
		SetFailState(buffer);
	}
	
	HookEventEx("cs_win_panel_match", cs_win_panel_match);
}

public void cs_win_panel_match(Handle event, const char[] eventname, bool dontBroadcast)
{
	CreateTimer(0.1, delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action delay(Handle timer)
{
	Transaction txn = SQL_CreateTransaction();

	char mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));

	char buffer[512];
	
	char ctname[64];
	char tname[64];

	GetConVarString(FindConVar("mp_teamname_1"), ctname, sizeof(ctname));
	GetConVarString(FindConVar("mp_teamname_2"), tname, sizeof(tname));
	

	Format(buffer, sizeof(buffer), "INSERT INTO sql_matches_scoretotal (team_0, team_1, team_2, team_2_name, team_3, team_3_name, map) VALUES (0, 0, 0, '%s', 0, '%s', '%s');", ctname, tname, mapname);
	SQL_AddQuery(txn, buffer);

	int ent = MaxClients+1;
	
	while ((ent = FindEntityByClassname(ent, "cs_team_manager")) != -1)
	{
		Format(buffer, sizeof(buffer), "UPDATE sql_matches_scoretotal SET team_%i = %i WHERE match_id = LAST_INSERT_ID();", GetEntProp(ent, Prop_Send, "m_iTeamNum"), GetEntProp(ent, Prop_Send, "m_scoreTotal"));
		SQL_AddQuery(txn, buffer);
	}

	char name[MAX_NAME_LENGTH];

	int m_iTeam;
	int m_iKills;
	int m_iDeaths;
	int m_iMatchStats_5k_Total;
	int m_iMatchStats_4k_Total;
	int m_iMatchStats_3k_Total;
	int m_iMatchStats_Damage_Total;

	if ((ent = FindEntityByClassname(-1, "cs_player_manager")) != -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
			{
				continue;
			}

			m_iTeam = GetEntProp(ent, Prop_Send, "m_iTeam", _, i);
			
			if((m_iTeam == 0) || (m_iTeam == 1))
			{
				continue;
			}
			
			m_iKills = GetEntProp(ent, Prop_Send, "m_iKills", _, i);
			m_iDeaths = GetEntProp(ent, Prop_Send, "m_iDeaths", _, i);
			m_iMatchStats_5k_Total = GetEntProp(ent, Prop_Send, "m_iMatchStats_5k_Total", _, i);
			m_iMatchStats_4k_Total = GetEntProp(ent, Prop_Send, "m_iMatchStats_4k_Total", _, i);
			m_iMatchStats_3k_Total = GetEntProp(ent, Prop_Send, "m_iMatchStats_3k_Total", _, i);
			m_iMatchStats_Damage_Total = GetEntProp(ent, Prop_Send, "m_iMatchStats_Damage_Total", _, i);
			
			Format(name, MAX_NAME_LENGTH, "%N", i);
			SQL_EscapeString(db, name, name, sizeof(name));

			Format(buffer, sizeof(buffer), "INSERT INTO sql_matches");
			Format(buffer, sizeof(buffer), "%s (match_id, team, name, kills, deaths, 5k, 4k, 3k, damage)", buffer);
			Format(buffer, sizeof(buffer), "%s VALUES (LAST_INSERT_ID(), '%i', '%s', '%i', '%i', '%i', '%i', '%i', '%i');", buffer, m_iTeam, name, m_iKills, m_iDeaths, m_iMatchStats_5k_Total, m_iMatchStats_4k_Total, m_iMatchStats_3k_Total, m_iMatchStats_Damage_Total);
			SQL_AddQuery(txn, buffer);
		}
	}

	SQL_ExecuteTransaction(db, txn);

}

public void onSuccess(Database database, any data, int numQueries, Handle[] results, any[] bufferData)
{
	PrintToServer("onSuccess");
}

public void onError(Database database, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	PrintToServer("onError");
}
