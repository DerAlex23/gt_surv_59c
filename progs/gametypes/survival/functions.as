//////////////////////////////////////////////////////////////////////////////////////////
///
///	Author:	Alexander "AMrK" Mattis
///	Date:	29.05.2012
///
///	File:	survival/function.as
///	Descr.:	Contains supporting functions.
///
//////////////////////////////////////////////////////////////////////////////////////////

bool checkSurvColors( cString text )
{
  // Filter Spaces
  int i = 0;  
  cString name = "";
  cString chr = "";
  while( i < text.len() )
  {
    chr = text.substr( i, 1 );
    if( chr != " ")
      name += chr;
    i++;
  }
  
  
  i = 0;
  bool colorInc = false;
  cString color = "7";
  cString colorCode = "";
  while( i < text.len() )
  {
    chr = name.substr( i, 1 );
    
    if( colorInc )
    {
      if( chr == "1" || chr == "2" || chr == "3" || chr == "4" || chr == "5" || chr == "6" || chr == "7" || chr == "8" || chr == "9" || chr == "0" ){
        color = chr;
      }else{
        if( colorCode.len() > 0 )
        {
          if( colorCode.substr( colorCode.len()-1, 1 ) != color )
            colorCode += color;
        }else
          colorCode += color;
      }
      colorInc = false;
    }else{
      if( chr == "^")
      {
        colorInc = true;
      }else{
      
        if( colorCode.len() > 0 )
        {
          if( colorCode.substr( colorCode.len()-1, 1 ) != color )
            colorCode += color;
        }else
          colorCode += color;
        
      }
    }
    
    i++;
  }
  
  return colorCode == "231";
}

void Survival_SetUpWarmup()
{
	@latestCheckPoint = null;
	
	cTeam @team;

	gametype.shootingDisabled = false;
	gametype.readyAnnouncementEnabled = true;
	gametype.scoreAnnouncementEnabled = false;
	gametype.countdownEnabled = false;

	@team = @G_GetTeam( TEAM_PLAYERS );
	team.clearInvites();

	if ( team.unlock() )
		G_PrintMsg( null, "Teams unlocked.\n" );

	if( voteTournament.getInteger() == 1 )
		match.setName( "Waiting for player (Tournament)" );
	else
		match.setName( "Waiting for player" );
}

void Survival_SetUpCountdown()
{
	G_RemoveAllProjectiles();
	G_Items_RespawnByType( 0, 0, 0 ); // respawn all items

	gametype.shootingDisabled = true;
	gametype.readyAnnouncementEnabled = false;
	gametype.scoreAnnouncementEnabled = false;
	gametype.countdownEnabled = true;

	// lock teams
	bool any = false;
	if ( G_GetTeam( TEAM_PLAYERS ).lock() )
		any = true;

	if ( any )
		G_PrintMsg( null, "Teams locked.\n" );
		
	//survival.timer = levelTime + 3000;
}

void updateCheckpointCount()
{
	numberOfCheckpoints = 0;
	numberOfCapturedCheckpoints = 0;
	if ( @listHeadCheckPoint != null )
		listHeadCheckPoint.countCheckPoints();
}

void Survival_SetUpMatch()
{
	int i, j;
	cEntity @ent;
	cTeam @team;
	cString gameNameExtentsion = "";

	G_RemoveAllProjectiles();
	gametype.shootingDisabled = false;
	gametype.readyAnnouncementEnabled = false;
	gametype.scoreAnnouncementEnabled = true;
	gametype.countdownEnabled = true;

	// clear player stats and scores, team scores and respawn clients in team lists
	@team = @G_GetTeam( TEAM_PLAYERS );
	team.stats.clear();

	// respawn all clients inside the playing teams
	for ( j = 0; @team.ent( j ) != null; j++ )
	{
		@ent = @team.ent( j );
		ent.client.stats.clear(); // clear player scores & stats
		ent.client.respawn( false );
	}

	// set items to be spawned with a delay
	G_Items_RespawnByType( 0, 0, 0 ); // respawn all items
	G_RemoveDeadBodies();

	// Countdowns should be made entirely client side, because we now can
	int soundindex = G_SoundIndex( "sounds/announcer/countdown/fight0" + int( brandom( 1, 2 ) ) );
	G_AnnouncerSound( null, soundindex, GS_MAX_TEAMS, false, null );
	G_CenterPrintMsg( null, "Survive!\n" );      
		
	if ( voteNoCap.getInteger() == 1 )
	{
		if ( gameNameExtentsion.len() > 0 )
			gameNameExtentsion += " / ";
			
		gameNameExtentsion += "no Cap";
	}
	
	if ( voteContinues.getInteger() == -1 )
	{
		if ( gameNameExtentsion.len() > 0 )
			gameNameExtentsion += " / ";
			
		gameNameExtentsion += "no Limit";
	}
	
	if ( gameNameExtentsion.len() > 0 )
	{
		if( voteTournament.getInteger() == 1 )
			match.setName( "In Survival (Tournament) (" + gameNameExtentsion +")" );
		else
			match.setName( "In Survival (" + gameNameExtentsion +")" );
	}
	else
	{
		if( voteTournament.getInteger() == 1 )
			match.setName( "In Survival (Tournament)" );
		else
			match.setName( "In Survival" );
	}
	
	int soundIndex = G_SoundIndex( "sounds/announcer/countdown/go0" + int( brandom( 1, 2 ) ) );
	G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
	
	for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
		gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_HOLD, 0, 0, true );
}

void Survival_SetUpEndMatch()
{
	cClient @client;

	gametype.shootingDisabled = true;
	gametype.readyAnnouncementEnabled = false;
	gametype.scoreAnnouncementEnabled = false;
	gametype.countdownEnabled = false;

	for ( int i = 0; i < maxClients; i++ )
	{
		@client = @G_GetClient( i );

		if ( client.state() >= CS_SPAWNED )
			client.respawn( true ); // ghost them all
	}

	int soundIndex = G_SoundIndex( "sounds/announcer/postmatch/game_over0" + int( brandom( 1, 2 ) ) );
	G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, true, null );
	
	if( voteTournament.getInteger() == 1 )
		match.setName( "Survival (Tournament) finished" );
	else
		match.setName( "Survival finished" );
	
	//survival.timer = levelTime + 5000;
}

void respawnPlayers( bool ghost )
{
	cEntity @ent;
	cTeam @team;

	@team = @G_GetTeam( TEAM_PLAYERS );

	// respawn all clients inside the playing teams
	for ( int j = 0; @team.ent( j ) != null; j++ )
	{
		@ent = @team.ent( j );      
		ent.client.respawn( ghost );
	}
}

cCheckPoint @Survival_getCheckPointForEntity( cEntity @ent )
{
	for ( cCheckPoint @checkPoint = @listHeadCheckPoint; @checkPoint != null; @checkPoint = @checkPoint.next )
	{
		if ( @checkPoint.owner == @ent )
			return checkPoint;
	}

	return null;
}

cFinish @Survival_getFinishForEntity( cEntity @ent )
{
	for ( cFinish @finish = @listHeadFinish; @finish != null; @finish = @finish.next )
	{
		if ( @finish.owner == @ent )
			return finish;
	}

	return null;
}

void swapEnts( cEntity @swapEnt, cEntity @deadEnt )
{                
	cVec3 playerSpawnPosition = swapEnt.getOrigin();
	cVec3 playerSpawnRotation = swapEnt.getAngles();
	float health = swapEnt.health;
	
	deadEnt.client.respawn(false);
	
	deadEnt.setOrigin(playerSpawnPosition);
	deadEnt.setAngles(playerSpawnRotation);
	deadEnt.health = health;
	
	swapEnt.ghost();
	swapEnt.client.chaseCam( "FirstPerson", true );
	
	G_PrintMsg( null, swapEnt.client.getName() + " ^3swapped ^7with " + deadEnt.client.getName() + "^7!\n" );
}

cString getArgumentLine( cString arguments, int offset )
{
	cString argumentLine = "";
	while( arguments.getToken(offset) != "" )
	{
		if( argumentLine == "" )
		argumentLine += arguments.getToken(offset);
			else
		argumentLine += " " +  arguments.getToken(offset);
		offset++;
	}
	return argumentLine;
}

bool isID( cString nameOrID )
{
	int ID = nameOrID.toInt();
	return ( (ID == 0 && nameOrID == "0") || ID > 0 );
}

cClient @ getClientViaNameOrId( cString nameOrID )
{
	int ID = nameOrID.toInt();
	
	if ( isID(nameOrID) )
	{
		return getClientViaID( ID );
	}
	else
	{
		return getClientViaName( nameOrID );
	}
}

cClient @ getClientViaName( cString clientName )
{
	clientName = clientName.tolower().removeColorTokens();
	for ( int i = 0; i < maxClients; i++ )
	{
		cClient @client = @G_GetClient( i );
		
		if( client.getName().tolower().removeColorTokens() == clientName )
			return @client;      
	}
	
	return null;
}

cClient @ getClientViaID( int ID )
{   
	cClient @client = @G_GetClient( ID );
	if( @client == null)
		return null;
		
	if( client.state() > 0 )
		return  @client;
	
	return null;
}

void removePlayers()
{
	cTeam @team = @G_GetTeam( TEAM_PLAYERS );
	for ( int i = 0; @team.ent( i ) != null; i++ )
	{
		team.ent( i ).team = TEAM_SPECTATOR;
	}     
}

cString getIP( cClient @client)
{
	cString IpPort;
	IpPort = client.getUserInfoKey( "ip" );
	if( IpPort.substr( 0, 1) == '[' )
		return getIPv6(IpPort);
	else
		return getIPv4(IpPort); 
}

cString getIPv4( cString IpPort )
{            
	cString Ip;
	int pos; 
			 
	Ip = ""; 
	pos = 0; 
	while ( IpPort.substr( pos, 1 ) != ":" && pos < IpPort.len() )
	{        
		Ip += IpPort.substr( pos, 1 );
		pos += 1;
	}        
			 
	return Ip;
}            

cString getIPv6( cString IpPort )                                                  
{                                                                                                                                               
	cString Ip;                                                                   
	int pos;                                                                                                            
																				  
	Ip = "";                                                                      
	pos = 1;                                                                      
	while ( IpPort.substr( pos, 1 ) != "]" && pos < IpPort.len() )                
	{                                                                             
		Ip += IpPort.substr( pos, 1 );                                            
		pos += 1;                                                                 
	}                                                                             
																				  
	return Ip;                                                                    
}   

void checkTournament()
{
	cString fileContent = G_LoadFile( "survival/tournament/status" );
	if( fileContent.getToken( 0 ).len() == 0 )
		return;

	if( fileContent.getToken( 0 ).tolower() == "active" )
	{
		if( voteTournament.getInteger() == 0)
		{
			voteTournament.set( 1 );
			G_PrintMsg( null, "^1================================================\n" );
			G_PrintMsg( null, "^9 The tournament mode is now active\n" );
			G_PrintMsg( null, "^9 /regist and/or /login to gain points!\n" );
			G_PrintMsg( null, "^1================================================\n" );
			G_CmdExecute( "exec tournament.cfg silent" );
		}
	}
	else if( fileContent.getToken( 0 ).tolower() == "inactive" )
	{
		if( voteTournament.getInteger() == 1)
		{
			voteTournament.set( 0 );
			G_PrintMsg( null, "^1================================================\n" );
			G_PrintMsg( null, "^9 The tournament mode is now inactiv\n" );
			G_PrintMsg( null, "^9 No more captures will be counted!\n" );
			G_PrintMsg( null, "^1================================================\n" );
			G_CmdExecute( "exec dedicated_autoexec.cfg silent" );
		}
	}
}

cString removeBadChars( cString username )
{
	int pos = 0;
	cString newUsername = "";
	while ( pos <= username.len() )
	{
		if( username.substr( pos, 1 ) != "." && 
			username.substr( pos, 1 ) != "/" && 
			username.substr( pos, 1 ) != "?" && 
			username.substr( pos, 1 ) != "*" && 
			username.substr( pos, 1 ) != "|" && 
			username.substr( pos, 1 ) != "\\" && 
			username.substr( pos, 1 ) != "\"" &&
			username.substr( pos, 1 ) != "<" && 
			username.substr( pos, 1 ) != ">" )
				newUsername += username.substr( pos, 1 );
			pos += 1;
	}
	return newUsername;
}

void tournament_addPoint(cClient @ client, int additionalPoints)
{
	if( voteTournament.getInteger() == 1)
	{
		if( survivor[ client.playerNum() ].isLoggedIn )
		{
			cVar currentMap( "mapname", "", 0 );

			if( currentMap.getString() == "surv_pyramid_v19" )
			{
				survivor[ client.playerNum() ].addScore( 0, additionalPoints );
				G_PrintMsg( client.getEnt(), "^1Tournament: ^7You gain 1 point!\n" );
			}
			else if( currentMap.getString() == "surv_techfactory_v7" )
			{
				survivor[ client.playerNum() ].addScore( 1, additionalPoints );
				G_PrintMsg( client.getEnt(), "^1Tournament: ^7You gain 1 point!\n" );
			}
			else if( currentMap.getString() == "surv_majorjumpz_v9" )
			{
				survivor[ client.playerNum() ].addScore( 2, additionalPoints );
				G_PrintMsg( client.getEnt(), "^1Tournament: ^7You gain 1 point!\n" );
			}
			else if( currentMap.getString() == "surv_gammastreet_v11" )
			{
				survivor[ client.playerNum() ].addScore( 3, additionalPoints );
				G_PrintMsg( client.getEnt(), "^1Tournament: ^7You gain 1 point!\n" );
			}
		}
	}
}

void printMOTD(cClient @client)
{
		cString MOTDFile;
	
		MOTDFile = G_LoadFile( "survival/motd" );
	
		if ( MOTDFile.len() > 0 )
		{
			cString MOTDMessage = "\"";
			int pos = 0;        
			while( pos <= MOTDFile.len() )
			{

				if( MOTDFile.substr(pos, 1) == "\n" )
				  MOTDMessage += "\" \"";
				else if( MOTDFile.substr(pos, 1) != "\r" )
				  MOTDMessage += MOTDFile.substr(pos, 1);

				pos++;
			}
			MOTDMessage += "\"";    

			client.execGameCommand("cmd menu_msgbox " + MOTDMessage + ";\n");
		} 
}
/*
void checkBan( cClient @ client, float id )
{
	if( G_FileExists( "survival/banned/" + id + "/reason" ) )
	{
		cString reason = G_LoadFile( "survival/banned/" + id + "/reason" );
		cString IP = getIP( @client );
	
		G_AppendToFile( "survival/banned/" + id + "/names", client.getName() + "\n" );

		G_CmdExecute( "addip " + IP + "\n" );

		
		client.execGameCommand("cmd disconnect;\n");
		client.execGameCommand("cmd menu_failed 1 \"-> ^1You were banned^7\" 2 \"" + reason + "\";\n");
	}
}

void banPlayer( cClient @ client, cString reason )
{
	if ( reason.len() == 0 )
	{
		reason = "Admin Decision";
	}
	
	float id = createBanReason( reason );

	client.execGameCommand("cmd seta \"sv_banreason\" \"" + id + "\";\n");
	client.execGameCommand("cmd seta \"sv_banreason\" \"" + id + "\";\n");

	G_PrintMsg(null, client.getName() + msgFirstToken + " was banned from this server with reason: " + msgSecondToken + reason + S_COLOR_WHITE + "\n");

	checkBan( client, id );
}

float createBanReason( cString reason )
{
	float id = random(1000000,9999999);
		
	while( G_FileExists( "survival/banned/" + id + "/reason" ) )
		id = random(1000000,9999999);
	G_WriteFile( "survival/banned/" + id + "/reason", reason );
	return id;
}
*/