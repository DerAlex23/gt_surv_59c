//////////////////////////////////////////////////////////////////////////////////////////
///
///	Author:	Alexander "AMrK" Mattis
///	Date:	29.05.2012
///
///	File:	survival/main.as
///	Descr.:	Contains main functions and global variables.
///
//////////////////////////////////////////////////////////////////////////////////////////



int prcYesIcon; // Ready icon
int prcNoIcon; // Not ready icon
int prcFlagIcon; // Flag icon (for minimap)
int numberOfCheckpoints; // Count of all checkpoints on the map
int numberOfCapturedCheckpoints; // Count of all captures checkpoints on the map

cCheckPoint   @latestCheckPoint; // Last captured checkpoint (respawn here)
cCheckPoint   @listHeadCheckPoint; // Top of stack for checkpoints (a spawning checkpoint will point to this and get "listHeadCheckPoint" itslef)
cFinish       @listHeadFinish; // Top of stack for finsih (a spawning checkpoint will point to this and get "listHeadCheckPoint" itslef)           

cSurvivalRound survival; // Object for the survial match
bool gravityTurned; // Global variable, needed for the "cGravityTurn" entity class

cVar voteContinues		("g_continues", "10", CVAR_ARCHIVE);	// Defines the number of retries for the players
cVar voteSwap			("g_allow_Swap", "0", CVAR_ARCHIVE);	// Defines if living players are allowed to change with dead players
cVar voteNoCap			("g_noCap", "0", CVAR_ARCHIVE);			// Defines if Checkpoints are avaiable
cVar voteSharedLifes	("g_sharedLifes", "0", CVAR_ARCHIVE);	// Defines if the players respawn in group (1 continue for group respawn) or each directly after death (1 continue for each single respawn)
cVar voteCaptureMinimum	("g_captureMinimum", "1", CVAR_ARCHIVE);// Defines the minimum number of players which is needed to activate a checkpoint or finish
cVar voteTournament		("g_tournament", "0", CVAR_ARCHIVE);	// Defines if the score is saved for every player

uint[] sl_respawnTimer	( maxClients );	// The timer for respawn (if not used player would directly spawn after death, otherwise he will wait some seconds)
bool[] sl_isDead		( maxClients ); // 
bool[] sl_allowRespawn	( maxClients ); // Are there continues left for respawning?

cSurvivor[] survivor	( maxClients ); // Contains the logged in username

uint lastLevelTime = 0; // Bancheck

bool[] playerAtCheckpoint	( maxClients ); // Is the player at a not captured checkpoint?

uint killVoteMsgTimer;


///*****************************************************************
///	Descr.:	Handles gametype commands and votes.
///*****************************************************************
bool GT_Command( cClient @client, cString &cmdString, cString &argsString, int argc )
{    
	
	if ( cmdString == "gametype" ) // gt-cmd "/gametype" (standard in every gametype): shows information about the gametype
	{
		cString response = "";
		cVar fs_game( "fs_game", "", 0 );
		cString manifest = gametype.getManifest();

		response += "\n";
		response += "Gametype " + gametype.getName() + " : " + gametype.getTitle() + "\n";
		response += "----------------\n";
		response += "Version: " + gametype.getVersion() + "\n";
		response += "Author: " + gametype.getAuthor() + "\n";
		response += "Mod: " + fs_game.getString() + (manifest.length() > 0 ? " (manifest: " + manifest + ")" : "") + "\n";
		response += "----------------\n";

		G_PrintMsg( client.getEnt(), response );
		return true;
	}
	else if ( ( cmdString == "cvarinfo" ) ) // cmd "cvarinfo": not in use
	{
		cString cvarName = argsString.getToken(0);
    	cString cvarValue = argsString.getToken(1);
        /*
        if( cvarName == "sv_banreason" && cvarValue != "not found"  )
			checkBan( client, cvarValue );
		*/
	}
	else if ( cmdString == "roll" ) // gt-cmd "/roll": generates a random number and send it to every player
	{
		int sides = argsString.toInt();
		if (sides <= 0)
		{
			G_PrintMsg( client.getEnt(), "You can use 'roll X' to roll a X-sided dice!\n" );
		}
		else
		{
			int diced = int(floor(brandom(1,sides+1)));
			G_PrintMsg( null, client.getName() + " rolled a dice (" + sides + " sides) and achieved " + diced + "!\n" );
		}
		return true;
	}
	else if ( cmdString == "tournament" ) // gt-cmd "/roll": generates a random number and send it to every player
	{
		if ( voteTournament.getInteger() == 1 )
		{
			if( survivor[client.playerNum()].isLoggedIn )
			G_PrintMsg( client.getEnt(), "^2Your score:\n^3Pyramid: ^1" + survivor[client.playerNum()].score[0] +
										 "\n^3Techfactoy: ^1" + survivor[client.playerNum()].score[1] +
										 "\n^3Majorjumpz: ^1" + survivor[client.playerNum()].score[2] +
										 "\n^3Gammastreet: ^1" + survivor[client.playerNum()].score[3] + "^7\n");
			else
				G_PrintMsg( client.getEnt(), "You need to be logged in (/login name pw)!\n" );
		}
		else
			G_PrintMsg( client.getEnt(), "This is not a tournament match!\n" );
		return true;
	}
	else if ( cmdString == "gameinfo" ) // gt-cmd "/gameinfo": show settings of the current survival match
	{
		cString info = "Gameinfo:\n";
		
		if ( survival.continues == -1 )
		{
			info += "Continues: No Limit\n";
		}
		else
		{
			info += "Continues: " + survival.continues + "\n";
		}
		
		if ( survival.noCap )
		{
			info += "Checkpoints: No Cap\n";
		}
		else
		{
			updateCheckpointCount();
			info += "Checkpoints: " + numberOfCapturedCheckpoints + "/" + numberOfCheckpoints + "\n";
		}
		
		if ( voteSwap.getInteger() == 1 )
		{
			info += "Swapping: Enabled\n";
		}
		else
		{
			info += "Swapping: Disabled\n";
		}
		
		if ( voteSharedLifes.getInteger() == 1 )
		{
			info += "Lifesharing: Enabled\n";
		}
		else
		{
			info += "Lifesharing: Disabled\n";
		}
		
		info += "Capture minimum: " + voteCaptureMinimum.getInteger() + "\n";
		
		if ( voteTournament.getInteger() == 1 )
		{
			info += "^1This is a tournament match!^7\n";
		}

		G_PrintMsg( client.getEnt(), info );
		return true;
	}
	else if ( cmdString == "regist" || cmdString == "register" ) // gt-cmd "/regist": regist a new tournament player
	{
		cString username = argsString.getToken( 0 );
		cString password = argsString.getToken( 1 );

		if( username.len() == 0 )
		{
			G_PrintMsg( client.getEnt(), "No username entered!\n" );
			return true;
		}

		if( password.len() == 0 )
		{
			G_PrintMsg( client.getEnt(), "No password entered!\n" );
			return true;
		}


		if( survivor[ client.playerNum() ].isLoggedIn )
		{
			G_PrintMsg( client.getEnt(), "You are allready logged in!\n" );
			return true;
		}

		int error = survivor[ client.playerNum() ].regist( username, password );
		if( error == -1 )
		{
			G_PrintMsg( client.getEnt(), "The username contains invalid characters!\n" );
		}
		else if( error == -2 )
		{
			G_PrintMsg( client.getEnt(), "The username is allready in use!\n" );
		}
		else if( error == 1 )
		{
			G_PrintMsg( client.getEnt(), "Registration succeeded! Now login via: /login " + username + " " + password + "\n" );
		}
		return true;
	}
	else if ( cmdString == "login" ) // gt-cmd "/login": login as a tournament player
	{
		cString username = argsString.getToken( 0 );
		cString password = argsString.getToken( 1 );

		if( username.len() == 0 )
		{
			G_PrintMsg( client.getEnt(), "No username entered!\n" );
			return true;
		}

		if( password.len() == 0 )
		{
			G_PrintMsg( client.getEnt(), "No password entered!\n" );
			return true;
		}

		if( voteTournament.getInteger() == 0)
		{
			G_PrintMsg( client.getEnt(), "Login is only allowed during a tournament!\n" );
			return true;
		}

		if( survivor[ client.playerNum() ].isLoggedIn )
		{
			G_PrintMsg( client.getEnt(), "You are allready logged in!\n" );
			return true;
		}

		int error = survivor[ client.playerNum() ].login( username, password );
		if( error == -1 )
		{
			G_PrintMsg( client.getEnt(), "The username contains invalid characters!\n" );
		}
		else if( error == -2 )
		{
			G_PrintMsg( client.getEnt(), "The username does not exist!\n" );
		}
		else if( error == -3 )
		{
			G_PrintMsg( client.getEnt(), "The password is invalid!\n" );
		}
		else if( error == 1 )
		{
			G_PrintMsg( client.getEnt(), "Login succeeded!\n" );
			G_PrintMsg( null, client.getName() + " ^7logged in!\n" );
			client.execGameCommand("cmd seta surv_autologin \"login " + username + " " + password + "\";\n");
		}
		return true;
	}
	else if ( cmdString == "ban" )
    {/*
        if( client.isOperator )
        {
            cString playerName, newTeam, reason, executeable;
            bool userFound;
            int i;
            cClient @searchedClient;
            
            playerName = argsString.getToken( 0 ).removeColorTokens().tolower();
            if ( playerName.len() == 0 )
            {
                client.printMessage( "Not enough parameter: /ban <playername> [reason]\n" );
            }
            else
            {
                reason = argsString.getToken( 1 ); 
                
                userFound = false;
                i = 0;
                
                while( i < maxClients && !userFound)
                {
                    @searchedClient = @G_GetClient( i );
                    if( searchedClient.getName().removeColorTokens().tolower() == playerName )
                    {
                        userFound = true;
                    }
                    else
                    {
                        i++;
                    }
                }
                
                if( userFound )
                {                                                         
                    banPlayer(searchedClient, reason);
                }
                else
                {
                    client.printMessage( "The user " + playerName + " was not found!\n" );
                }
            }
        }
        else
        {
            client.printMessage( "You are not authorized to use this command!\n" );
        }*/
    }
	else if ( cmdString == "callvotevalidate" ) // cmd "callvotevalidate": validates the custom votes
	{
		cString votename = argsString.getToken( 0 );

		if ( votename == "continues" ) // --- Continues ---
		{   
		
			if ( match.getState() == MATCH_STATE_PLAYTIME )
			{
				client.printMessage( "Callvote " + votename + " can not be voted during the game\n" );
				return false;
			}
			cString voteArg = argsString.getToken( 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				return false;
			}

			int value = voteArg.toInt();
			if ( value < 0 )
			{
				client.printMessage( "Callvote " + votename + " expects a value higher than 0 as argument\n" );
				return false;
			}

			if ( value == voteContinues.getInteger() )
			{
				client.printMessage( "Continues are allready set to " + value + "\n" );
				return false;
			}
		}
		else if ( votename == "captureminimum" ) // --- Capture minimum ---
		{   
		
			if ( match.getState() == MATCH_STATE_PLAYTIME )
			{
				client.printMessage( "Callvote " + votename + " can not be voted during the game\n" );
				return false;
			}
			cString voteArg = argsString.getToken( 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				return false;
			}

			int value = voteArg.toInt();
			if ( value <= 0 )
			{
				client.printMessage( "Callvote " + votename + " expects a value higher than 0 as argument\n" );
				return false;
			}

			if ( value == voteCaptureMinimum.getInteger() )
			{
				client.printMessage( "Capture minimum is allready set to " + value + "\n" );
				return false;
			}
		}
		else if ( votename == "allow_swap" ) // --- Allow swapping ---
		{   
			cString voteArg = argsString.getToken( 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				return false;
			}

			int value = voteArg.toInt();
			if ( value < 0 || value > 1 )
			{
				client.printMessage( "Callvote " + votename + " expects 1 or 0 as argument\n" );
				return false;
			}

			if ( value == voteSwap.getInteger() )
			{
				if ( value == 1 )
				{
					client.printMessage( "Swap is allready allowed\n" );
					return false;
				}
				else
				{
					client.printMessage( "Swap is allready forbidden\n" );
					return false;
				}
			}
		}
		else if ( votename == "tournament" ) // --- Enables/Disables tournament ---
		{   
			cString voteArg = argsString.getToken( 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				return false;
			}

			int value = voteArg.toInt();
			if ( value < 0 || value > 1 )
			{
				client.printMessage( "Callvote " + votename + " expects 1 or 0 as argument\n" );
				return false;
			}
			
			if( !client.isOperator )
			{
				client.printMessage( "Only OPs are allowed to vote this\n" );
				return false;
			}
				
			if ( value == voteTournament.getInteger() )
			{
				if ( value == 1 )
				{
					client.printMessage( "Tournament allready enabled\n" );
					return false;
				}
				else
				{
					client.printMessage( "Tournament allready disabled\n" );
					return false;
				}
			}
		}
		else if ( votename == "sharedlifes" ) // --- Enables/Disables shared lifes ---
		{   
			cString voteArg = argsString.getToken( 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				return false;
			}

			int value = voteArg.toInt();
			if ( value < 0 || value > 1 )
			{
				client.printMessage( "Callvote " + votename + " expects 1 or 0 as argument\n" );
				return false;
			}

			if ( value == voteSharedLifes.getInteger() )
			{
				if ( value == 1 )
				{
					client.printMessage( "Life sharing is allready enabled\n" );
					return false;
				}
				else
				{
					client.printMessage( "Life sharing is allready disabled\n" );
					return false;
				}
			}
		}
		else if ( votename == "nocap" ) // --- Enables/Disables checkpoints ---
		{   
			if ( match.getState() == MATCH_STATE_PLAYTIME )
			{
				client.printMessage( "Callvote " + votename + " can not be voted during the game\n" );
				return false;
			}
			
			cString voteArg = argsString.getToken( 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				return false;
			}

			int value = voteArg.toInt();
			if ( value < 0 || value > 1 )
			{
				client.printMessage( "Callvote " + votename + " expects 1 or 0 as argument\n" );
				return false;
			}

			if ( value == voteNoCap.getInteger() )
			{
				if ( value == 1 )
				{
					client.printMessage( "NoCap is allready enabled\n" );
					return false;
				}
				else
				{
					client.printMessage( "NoCap is allready disabled\n" );
					return false;
				}
			}
		}
		else if ( votename == "kill" )  // --- Kill a player ---
		{               
			cString voteArg = getArgumentLine(argsString, 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				client.execGameCommand("cmd players;\n");
				return false;
			}
			
			cClient @targetClient;
			@targetClient = @getClientViaNameOrId( voteArg );
			
			if ( @targetClient == null )
			{
				client.printMessage( "The player was not found\n" );
				client.execGameCommand("cmd players;\n");
				return false;
			}

			if ( targetClient.getEnt().isGhosting() )
			{
				client.printMessage( "The player is allready dead\n" );
				return false;
			}
			
			if( isID( voteArg ) && levelTime - killVoteMsgTimer >= 5000)
			{
				G_PrintMsg( null, "^7ID ^3" + voteArg + " ^7is player " + targetClient.getName() + "\n" );
				killVoteMsgTimer = levelTime;
			}
		}
		else if ( votename == "moveToProServer" ) // --- Move a player to another server --- (obsolete)
		{               
			cString voteArg = argsString.getToken( 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				return false;
			}
			
			cClient @targetClient;
			@targetClient = @getClientViaName( voteArg );
			if ( @targetClient == null )
			{
				@targetClient = getClientViaID( voteArg.toInt() );
				if( (voteArg.toInt() == 0 && voteArg != "0") || @targetClient == null )
				{ 
					client.printMessage( "The player was not found\n" );
					client.execGameCommand("cmd players;\n");
				}
				else
				{
					client.execGameCommand("callvote moveToProServer \"" + targetClient.getName() + "\";\n");
				}
				return false;
			}    
			else
			{
				G_PrintMsg( client.getEnt(), "^7You have to enter a ^3valid name ^7or ^3id^7!\n" );
				client.execGameCommand("cmd players;\n");
			}
		}
		else if ( votename == "moveToNormalServer" ) // --- Move a player to another server --- (obsolete)
		{               
			cString voteArg = argsString.getToken( 1 );
			if ( voteArg.len() < 1 )
			{
				client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
				return false;
			}
			
			cClient @targetClient;
			@targetClient = @getClientViaName( voteArg );
			if ( @targetClient == null )
			{
				@targetClient = getClientViaID( voteArg.toInt() );
				if( (voteArg.toInt() == 0 && voteArg != "0") || @targetClient == null )
				{ 
					client.printMessage( "The player was not found\n" );
					client.execGameCommand("cmd players;\n");
				}
				else
				{
					client.execGameCommand("callvote moveToNormalServer \"" + targetClient.getName() + "\";\n");
				}
				return false;
			}       
			else
			{
				G_PrintMsg( client.getEnt(), "^7You have to enter a ^3valid name ^7or ^3id^7!\n" );
				client.execGameCommand("cmd players;\n");
			}
		}
		
		return true;
	}
	else if ( cmdString == "callvotepassed" ) // cmd "callvotepassed": execute the custom votes
	{
		cString votename = argsString.getToken( 0 );

		if ( votename == "continues" ) // --- Continues ---
		{
			int cont = argsString.getToken( 1 ).toInt();
			if( cont == 0 )
				voteContinues.set( -1 );
			else
				voteContinues.set( cont );
		}
		else if ( votename == "tournament" ) // --- Enables/Disables tournament ---
		{
			int isTournament = argsString.getToken( 1 ).toInt();
			if( isTournament == 0 )
				voteTournament.set( 0 );
			else
				voteTournament.set( 1 );
		}
		else if ( votename == "captureminimum" ) // --- Capture minimum ---
		{
			int capMin = argsString.getToken( 1 ).toInt();
			voteCaptureMinimum.set( capMin );
		}
		else if ( votename == "allow_Swap" ) // --- Allow swapping ---
		{
			int allow = argsString.getToken( 1 ).toInt();
			if( allow == 0 )
				voteSwap.set( 0 );
			else
				voteSwap.set( 1 );
		}
		else if ( votename == "sharedlifes" ) // --- Enables/Disables shared lifes ---
		{
			int allow = argsString.getToken( 1 ).toInt();
			if( allow == 0 )
				voteSharedLifes.set( 0 );
			else
				voteSharedLifes.set( 1 );
		}
		else if ( votename == "kill" )  // --- Kill a player ---
		{
			cString killClientArgument = getArgumentLine( argsString, 1 );
			cClient @killClient;
			@killClient = @getClientViaNameOrId( killClientArgument );
			if ( @killClient != null )
			{
				killClient.getEnt().ghost();
			}       
		}
		else if ( votename == "nocap" ) // --- Enables/Disables checkpoints ---
		{
			int allow = argsString.getToken( 1 ).toInt();
			if( allow == 0 )
				voteNoCap.set( 0 );
			else
				voteNoCap.set( 1 );
		} 
		else if ( votename == "moveToProServer" ) // --- Move a player to another server --- (obsolete)
		{               
			cString targetClientName = getArgumentLine( argsString, 1 );
			
			cClient @targetClient;
			@targetClient = @getClientViaNameOrId( targetClientName );
			if ( @targetClient != null )
			{
				targetClient.execGameCommand("cmd echo \"You have been moved to SurvivalPro-Server\";\n");
				targetClient.execGameCommand("cmd connect 62.75.171.50:44800;\n");
				return false;
			}   
			else
			{
				G_PrintMsg( client.getEnt(), "^7You have to enter a ^3valid name ^7or ^3id^7!\n" );
				client.execGameCommand("cmd players;\n");
			}
		}
		else if ( votename == "moveToNormalServer" ) // --- Move a player to another server --- (obsolete)
		{               
			cString targetClientName = getArgumentLine( argsString, 1 );
			
			cClient @targetClient;
			@targetClient = @getClientViaNameOrId( targetClientName );
			if ( @targetClient != null )
			{
				targetClient.execGameCommand("cmd echo \"You have been moved to normal Survival-Server\";\n");
				targetClient.execGameCommand("cmd connect 62.75.171.50:44700;\n");
				return false;
			}
			else
			{
				G_PrintMsg( client.getEnt(), "^7You have to enter a ^3valid name ^7or ^3id^7!\n" );
				client.execGameCommand("cmd players;\n");
			}
		}

		return true;
	}
	else if ( cmdString == "swap" ) // gt-cmd "swap": swaps a living player with a dead player (only if swap is enabled!)
	{       
		if ( voteSwap.getInteger() == 0 )
		{
			G_PrintMsg( client.getEnt(), "^7Swap is ^3disabled ^7on this ^3server^7!\n" );
			return false;
		}
		
		cEntity @swapEnt;
		cEntity @deadEnt;
		cClient @deadClient;
		cString argument = argsString;      

		@swapEnt = @client.getEnt();
		
	 
		if ( match.getState() != MATCH_STATE_PLAYTIME )
		{
			G_PrintMsg( client.getEnt(), "^7You can ^3only ^7swap ^3ingame^7!\n" );
			return false;
		}
		
		if( swapEnt.isGhosting() == true )
		{
			G_PrintMsg( client.getEnt(), "^7You can ^3only ^7swap if you are ^3alive^7!\n" );
			return false;
		}
		
		if ( argument.len() < 1 )
		{
			G_PrintMsg( client.getEnt(), "^7You have to enter a ^3 name ^7or ^3id^7!\n" );
			client.execGameCommand("cmd players;\n");
			return false;
		}
		
		
		@deadClient = @getClientViaNameOrId( argument );
		if( @deadClient != null )
		{
			if ( deadClient.team != TEAM_PLAYERS )
			{
				G_PrintMsg( client.getEnt(), "^7" + deadClient.getName() + " ^7is ^3not ^7playing!\n" );
				return false;
			}
			
			@deadEnt = @deadClient.getEnt();
			if( deadEnt.isGhosting() == true )
			{
				swapEnts( swapEnt, deadEnt );
				return true;
			}
			else
			{
				G_PrintMsg( client.getEnt(), "^7" + deadClient.getName() + " ^7is ^3not ^7dead!\n" );
				return false;
			}
		}
		
		G_PrintMsg( client.getEnt(), "^7You have to enter a ^3valid name ^7or ^3id^7!\n" );
		client.execGameCommand("cmd players;\n");
		return false;
	}  
	return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( cEntity @ent )
{
	return true; // handled by the script
}

// select a spawning point for a player
cEntity @GT_SelectSpawnPoint( cEntity @self )
{
	return survival.getRespawnPoint( self );
}

cString @GT_ScoreboardMessage( int maxlen )
{
	cString scoreboardMessage = "";
	cString entry;
	cTeam @team;
	cEntity @ent;
	int i, readyIcon, aliveIcon;

	@team = @G_GetTeam( TEAM_PLAYERS );

	// &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
	entry = "&t " + int( TEAM_PLAYERS ) + " " + team.stats.score + " 0 ";
	if ( scoreboardMessage.len() + entry.len() < maxlen )
		scoreboardMessage += entry;

	for ( i = 0; @team.ent( i ) != null; i++ )
	{
		@ent = @team.ent( i );

		if ( ent.client.isReady() )
			readyIcon = prcYesIcon;
		else
			readyIcon = prcNoIcon;
		
		if ( !ent.isGhosting() )
			aliveIcon = prcYesIcon;
		else
			aliveIcon = prcNoIcon;
		
		int playerID = ent.isGhosting() ? -( ent.playerNum() + 1 ) : ent.playerNum();

		cString printCons;
		if ( survival.continues == -1 )
			printCons = "0";
		else
			printCons = survival.continues;


		// "Name Clan Caps Cons Alive Ping R"
		entry = "&p " + playerID + " " + 
				ent.client.getClanName() + " " +
				ent.client.stats.score + " " +
				printCons + " " +
				aliveIcon + " " +
				ent.client.ping + " " + 
				readyIcon + " ";

		if ( scoreboardMessage.len() + entry.len() < maxlen )
			scoreboardMessage += entry;
	}

	for ( i = 0; i < maxClients; i++ )
		playerAtCheckpoint[ i ] = false;

	return scoreboardMessage;
}

//
void GT_updateScore( cClient @client )
{
}

// Some game actions trigger score events. These are events not related to killing
// oponents, like capturing a flag
void GT_scoreEvent( cClient @client, cString &score_event, cString &args )
{
	if ( score_event == "dmg" )
	{
	}
	else if ( score_event == "kill" )
	{
	}
	else if ( score_event == "award" )
	{
	}
	else if ( score_event == "connect" )
	{
	}
	else if ( score_event == "entergame" )
	{
		// Spectators are not allowed to scout the map!
		client.setPMoveMaxSpeed( 0 );
		client.setPMoveJumpSpeed( 0 );
		client.setPMoveDashSpeed( 0 );

		// Set player as logged out
		survivor[client.playerNum()].logout();

		// Print motd
		printMOTD( @client );

		// autologin for tournament
		if( voteTournament.getInteger() == 1 )
			client.execGameCommand("cmd vstr surv_autologin;\n");
	}
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_playerRespawn( cEntity @ent, int old_team, int new_team )
{
	if ( new_team != TEAM_PLAYERS )
	{
		if ( new_team == TEAM_SPECTATOR )
		{
			// Spectators are not allowed to scout the map!
			ent.client.setPMoveMaxSpeed( 0 );
			ent.client.setPMoveJumpSpeed( 0 );
			ent.client.setPMoveDashSpeed( 0 );
		}                                 
		
		return;
	}
	
	// Allow movements again...
	ent.client.setPMoveMaxSpeed( -1 );
	ent.client.setPMoveJumpSpeed( -1 );
	ent.client.setPMoveDashSpeed( -1 );

  ent.client.setPMoveFeatures( uint(-33) );

	if( survival.needToRespawn && !survival.sharedLifes )
        ent.ghost();

	// Nothing to do with dead players
	if ( ent.isGhosting() )
		return;

	// Clear inventory and give EB
	ent.client.inventoryClear();
	ent.client.setPMoveFeatures( ent.client.pmoveFeatures | PMFEAT_GHOSTMOVE );
	
	cItem @item;
	cItem @ammoItem;
	
	@item = @G_GetItemByName( "eb" );
	if ( @item != null )
	  ent.client.inventoryGiveItem( item.tag );
	
	@ammoItem = @G_GetItem( item.weakAmmoTag );
	if ( @ammoItem != null )
	  ent.client.inventorySetCount( ammoItem.tag, 1 ); 
	
	// select rocket launcher
	ent.client.selectWeapon( WEAP_ELECTROBOLT );

	// auto-select best weapon in the inventory
	if( ent.client.pendingWeapon == WEAP_NONE )
		ent.client.selectWeapon( -1 );
	
	// add a teleportation effect
	ent.respawnEffect();
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
	
	if( levelTime > lastLevelTime + 1000 )
    {       
        /* 
        for ( int i = 0; i < maxClients; i++ )
        {   
            cClient @client = @G_GetClient( i );
            if( client.state() != 4 ) 
            {
                //G_CmdExecute( "cvarcheck " + i + " sv_kickreason\n" );
                if( checkSurvColors( client.getName() ) && !client.isOperator )
                {
                  client.execGameCommand( "cmd name \"" + client.getName().removeColorTokens() + "\";\n" );
                  client.execGameCommand( "cmd echo \"^1You are using colors which are reserved for surv-members\";\n" );
                  client.execGameCommand( "cmd echo \"^1If you are a survival-member, then get an operator and rename\";\n" );
                }
                // todo name
                //getClanName
            }
        } */
        lastLevelTime = levelTime;     
    } 

	checkTournament();

	if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
	{
		if ( !match.checkExtendPlayTime() )
			match.launchState( match.getState() + 1 );
	}
	
	for ( int i = 0; i < maxClients; i++ )
	{
		if ( G_GetClient( i ).state() > 0 )
		{
			if ( G_GetClient( i ).team == TEAM_SPECTATOR )
			{
				// Spectators are not allowed to scout the map!
				G_GetClient( i ).setPMoveMaxSpeed( 0 );
				G_GetClient( i ).setPMoveJumpSpeed( 0 );
				G_GetClient( i ).setPMoveDashSpeed( 0 );
			}
		}
	}
	
	survival.thinkRules();
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
	if ( match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP
			&& incomingMatchState < MATCH_STATE_POSTMATCH )
		match.startAutorecord();

	if ( match.getState() == MATCH_STATE_POSTMATCH )
		match.stopAutorecord();

	return true;
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{          
	switch ( match.getState() )
	{
	case MATCH_STATE_WARMUP:
		Survival_SetUpWarmup();
		break;

	case MATCH_STATE_COUNTDOWN:
		Survival_SetUpCountdown();
		break;

	case MATCH_STATE_PLAYTIME:
		Survival_SetUpMatch();
		survival.start();
		break;

	case MATCH_STATE_POSTMATCH:
		Survival_SetUpEndMatch();
		break;

	default:
		break;
	}
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
}

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{   
}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{                                
	if( voteTournament.getInteger() == 1 )
		gametype.setTitle( "^3Survival (Tournament)^7" );
	else
		gametype.setTitle( "^3Survival^7" );
	gametype.setVersion( "^30.60b (04.06.2012)^7" );
	gametype.setAuthor( "^2A^3Mr^1K^7" );
	
	// if the gametype doesn't have a config file, create it
	if ( !G_FileExists( "configs/server/gametypes/" + gametype.getName() + ".cfg" ) )
	{
		cString config;

		// the config file doesn't exist or it's empty, create it
		config = "// '" + gametype.getTitle() + "' gametype configuration file\n"
				 + "// This config will be executed each time the gametype is started\n"
				 + "\n\n// map rotation\n"
				 + "set g_maplist \"pyramide_survival_v11 techfactory_survival_v6 gammastreet_v10\" // list of maps in automatic rotation\n"
				 + "set g_maprotation \"0\"   // 0 = same map, 1 = in order, 2 = random\n"
				 + "\n// game settings\n"
				 + "set g_scorelimit \"0\"\n"
				 + "set g_timelimit \"0\"\n"
				 + "set g_continues \"10\"\n"
				 + "set g_warmup_enabled \"1\"\n"
				 + "set g_warmup_timelimit \"0\"\n"
				 + "set g_match_extendedtime \"0\"\n"
				 + "set g_allow_falldamage \"0\"\n"
				 + "set g_allow_selfdamage \"0\"\n"
				 + "set g_allow_teamdamage \"0\"\n"
				 + "set g_allow_stun \"0\"\n"
				 + "set g_teams_maxplayers \"8\"\n"
				 + "set g_teams_allow_uneven \"0\"\n"
				 + "set g_countdown_time \"3\"\n"
				 + "set g_maxtimeouts \"-1\" // -1 = unlimited\n"
				 + "set g_challengers_queue \"0\"\n"
				 + "\n// gametype settings\n"
				 + "set g_ca_classbased \"0\"\n"
				 + "\n// classes settings\n"
				 + "\necho \"" + gametype.getName() + ".cfg executed\"\n";

		G_WriteFile( "configs/server/gametypes/" + gametype.getName() + ".cfg", config );
		G_Print( "Created default config file for '" + gametype.getName() + "'\n" );
		G_CmdExecute( "exec configs/server/gametypes/" + gametype.getName() + ".cfg silent" );
	}

	// Spawn everything
	gametype.spawnableItemsMask = ( IT_WEAPON | IT_AMMO | IT_ARMOR | IT_HEALTH );
	gametype.respawnableItemsMask = gametype.spawnableItemsMask ;
	gametype.dropableItemsMask = gametype.spawnableItemsMask;
	gametype.pickableItemsMask = gametype.spawnableItemsMask;

	gametype.isTeamBased = false; // Only 1 team
	gametype.isRace = true; // Racing
	gametype.hasChallengersQueue = false;
	gametype.maxPlayersPerTeam = 0; // No limit

	// Set respawn delay to 1 second
	gametype.ammoRespawn = 1;
	gametype.armorRespawn = 1;
	gametype.weaponRespawn = 1;
	gametype.healthRespawn = 1;
	gametype.powerupRespawn = 1;
	gametype.megahealthRespawn = 1;
	gametype.ultrahealthRespawn = 1;

	gametype.readyAnnouncementEnabled = false;
	gametype.scoreAnnouncementEnabled = false;
	gametype.countdownEnabled = false;
	gametype.mathAbortDisabled = false;
	gametype.shootingDisabled = false;
	gametype.infiniteAmmo = false;
	gametype.canForceModels = false;
	gametype.canShowMinimap = false; // Minimap not allowed... no scouts ;)
	gametype.teamOnlyMinimap = false;

	gametype.spawnpointRadius = 0; // Spawn directly on spawn entity

	// set spawnsystem type to instant while players join
	gametype.setTeamSpawnsystem( TEAM_PLAYERS, SPAWNSYSTEM_HOLD, 0, 0, true );
	
	// define the scoreboard layout
	G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %p 52 %l 48 %p 18" );
	G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Caps Cons Alive Ping R" );

	// precache images that can be used by the scoreboard
	prcYesIcon = G_ImageIndex( "gfx/hud/icons/vsay/yes" );
	prcNoIcon = G_ImageIndex( "gfx/hud/icons/vsay/no" );
	prcFlagIcon = G_ImageIndex( "gfx/hud/icons/flags/iconflag" );
	
	// set globals
	@latestCheckPoint = null;
	@listHeadCheckPoint = null;
	@listHeadFinish = null;

	//for ( i = 0; i < maxClients; i++ )
//		playerAtCheckpoint[ i ] = false;
	
	gravityTurned = false;

	killVoteMsgTimer = 0;

	// add commands
	G_RegisterCommand( "tournament" );
	G_RegisterCommand( "gametype" );
	G_RegisterCommand( "roll" );
	G_RegisterCommand( "swap" );
	G_RegisterCommand( "gameinfo" );
	G_RegisterCommand( "regist" );
	G_RegisterCommand( "register" );
	G_RegisterCommand( "login" );
	
	// add votes
	G_RegisterCallvote( "continues", "<0 or any higher number>", "Set the number of continues" );
	G_RegisterCallvote( "allow_Swap", "<0 or 1>", "Enables or disables swapping" );
	G_RegisterCallvote( "noCap", "<0 or 1>", "Enables or disables checkpoints" );
	G_RegisterCallvote( "kill", "<nick or id>", "Kills one player" );
	G_RegisterCallvote( "sharedLifes", "<0 or 1>", "Enables or disables life sharing" );
	G_RegisterCallvote( "captureMinimum", "<1 or any higher number>", "Sets the number of survivors which is needed to capture a flag" );
	G_RegisterCallvote( "tournament", "<0 or 1>", "Enable or disable tournament (OP only)" );
	//G_RegisterCallvote( "moveToProServer", "<nick or id>", "Moves a player to the SurvivalPro-Server" );
	//G_RegisterCallvote( "moveToNormalServer", "<nick or id>", "Moves a player to the normal Survival-Server" );
	G_RegisterCallvote( "poll", "<Your poll>", "Votes a poll (this vote cause no effect)" );

	G_Print( "Gametype '" + gametype.getTitle() + "' initialized\n" );
}
