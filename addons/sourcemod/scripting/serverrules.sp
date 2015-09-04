#include <sourcemod>
#include <cstrike>

public Plugin myinfo = 
{
	name = "Server Rules",
	author = "stretch",
	description = "Displays server rules to new clients when they join the server.",
	version = "1.1",
	url = "http://sourcemod.net/"
};

// Global Connected Client List
bool g_players[MAXPLAYERS+1];

public void OnPluginStart()
{
	// Get Plugin Version, and report successful load to console.
	char version[32];
	GetPluginInfo(INVALID_HANDLE, PlInfo_Version, version, sizeof(version));
	PrintToServer("[SERVER RULES]: Version %s loaded.", version);

	HookEvent("player_spawn", Event_PlayerSpawnInit, EventHookMode_Post);

	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_rules", RulesMenu);
}

// Remove disconnected clients from the g_players array.
public void OnClientDisconnect_Post(client)
{
	if (g_players[client]) 
	{
		g_players[client] = false;
		PrintToServer("[SERVER RULES]: Disconnecting client has been removed from the list.");
	}
}

public Action RulesMenu(int client, int args)
{
	// If there is an argument to the command
	if (args > 0)
	{
		// If the client isn't console, and has the ability to kick
		if (CheckCommandAccess(client, "sm_rules_target", ADMFLAG_KICK, true))
		{
			char argString[32];
			GetCmdArg(1, argString, sizeof(argString));

			// Find the target of the argument string
			int targetedClient = FindTarget(client, argString, true, false);

			if (targetedClient > 0)
			{
				// If the target is the client that called the command, just show them the rules:
				if (targetedClient == client)
				{
					RulesMenu(client, 0);
					return Plugin_Handled;
				}

				RulesMenu(targetedClient, 0);
				return Plugin_Handled;
			}
		}
		else
		{
			PrintToChat(client, "[SERVER RULES]: Only Admins can send the rules menu to other players.")
		}

		return Plugin_Handled;
	}

	// Only run the rule menu logic for actual clients.
	if (client)
	{
		char rulesFilePath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, rulesFilePath, sizeof(rulesFilePath), "configs/ServerRules.txt");

		File rulesFile = OpenFile(rulesFilePath, "r");

		int sizeOfRules = FileSize(rulesFilePath);
		sizeOfRules += 1;
		char[] rules = new char[sizeOfRules];

		rulesFile.ReadString(rules, sizeOfRules);
		rulesFile.Close();

		Menu rulesMenu = new Menu(RulesMenuHandler);
		rulesMenu.ExitButton = false;
		rulesMenu.SetTitle("%s\n ", rules);
		rulesMenu.AddItem("#accept", "I agree to these rules.");
		rulesMenu.AddItem("#deny", "I disagree with these rules.");
		rulesMenu.Display(client, 45);
	}
}

public int RulesMenuHandler(Menu rulesMenu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if (param2 == 1) 
			{
				// User disagreed to the server rules.
				KickClient(param1, "You failed to agree to the server rules");
			}
		}

		case MenuAction_Cancel:
		{
			// Menu reached timeout.
			KickClient(param1, "You failed to agree to the server rules in time");
		}

		case MenuAction_End:
		{
			delete rulesMenu;
		}
	}
}

public void Event_PlayerSpawnInit(Event event, const char[] name, bool dontBroadcast)
{
	// Get spawned client info.
	int client = GetClientOfUserId(event.GetInt("userid"));
	int clientTeam = GetClientTeam(client);

	bool isClientAdmin = CheckCommandAccess(client, "sm_rules_target", ADMFLAG_GENERIC, true);

	// Make sure the client is a real client, actually on a team, and not an admin/mod.
	if (!g_players[client] && !IsFakeClient(client) && clientTeam != CS_TEAM_NONE && !isClientAdmin) 
	{
		// Timer solved an issue where replay bots were being kicked, causing a loop of respawning bots.
		CreateTimer(2.0, ShowRulesOnJoin, event.GetInt("userid"));
	}
}

public Action ShowRulesOnJoin(Handle timer, int userId)
{
	// Get spawned client info.
	int client = GetClientOfUserId(userId);
	int clientTeam = GetClientTeam(client);
	char clientName[32];
	GetClientName(client, clientName, 32);

	bool isClientAdmin = CheckCommandAccess(client, "sm_rules_target", ADMFLAG_GENERIC, true);

	// Recheck that the client is a real client, still on a team, and not an admin/mod.
	if (!g_players[client] && !IsFakeClient(client) && clientTeam != CS_TEAM_NONE && !isClientAdmin) 
	{
		// Set client to true so they won't see menu on respawns.
		g_players[client] = true;

		// Welcome the new player to the server, and log their spawn to the server.
		PrintToChat(client, "===============================================", clientName);
		PrintToChat(client, "Thanks for joining, %s! Please take the time to read the rules.", clientName);
		PrintToChat(client, "===============================================", clientName);

		//Show them the menu.
		RulesMenu(client, 0);
	}
}

