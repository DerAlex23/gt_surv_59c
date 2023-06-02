
// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{
    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        break;

    case MATCH_STATE_COUNTDOWN:
        break;

    case MATCH_STATE_PLAYTIME:
        break;

    case MATCH_STATE_POSTMATCH:
        break;

    default:
        break;
    }
}           

    
    
bool GT_Command( cClient @client, cString &cmdString, cString &argsString, int argc )
{
    if ( cmdString == "gametype" )
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
    else if ( cmdString == "cvarinfo" )
    {
    }
    
    else if ( cmdString == "callvotecheckpermission" )
    {
    }
    else if ( cmdString == "callvotevalidate" )
    {
    }
    else if ( cmdString == "callvotepassed" )
    {
    }
    else if ( cmdString == "weapondef" )
    {
    }
    else if ( cmdString == "weapondef" )
    {
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
    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
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

        // "Name Clan Caps Cons Alive Ping R"
        entry = "&p " + playerID + " " + ent.client.getClanName() + " "
                + ent.client.stats.score + " " + survival.continues + " " + aliveIcon + " "
                + ent.client.ping + " " + readyIcon + " ";

        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;
    }
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
    else if ( score_event == "enterGame" )
    {
    }                
    else if ( score_event == "disconnect" )
    {
    }                
    else if ( score_event == "userinfochanged" )
    {
    }                            
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_playerRespawn( cEntity @ent, int old_team, int new_team )
{
  
}

// Thinking function. Called each frame
void GT_ThinkRules()
{

}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{       
    return true;
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
    gametype.setTitle( "Empty" );
    gametype.setVersion( "0" );
    gametype.setAuthor( "Empty" );

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.getName() + ".cfg" ) )
    {
        cString config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.getTitle() + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"0\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"21\"\n"
                 + "set g_timelimit \"0\"\n"
                 + "set g_warmup_enabled \"1\"\n"
                 + "set g_warmup_timelimit \"1\"\n"
                 + "set g_match_extendedtime \"0\"\n"
                 + "set g_allow_falldamage \"0\"\n"
                 + "set g_allow_selfdamage \"0\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"0\"\n"
                 + "set g_teams_maxplayers \"20\"\n"
                 + "set g_teams_allow_uneven \"0\"\n"
                 + "set g_countdown_time \"3\"\n"
                 + "set g_maxtimeouts \"0\" // -1 = unlimited\n"
                 + "set g_challengers_queue \"0\"\n"
                 + "\n// gametype settings\n"
                 + "set g_ca_classbased \"0\"\n"
                 + "\n// classes settings\n"
                 + "\necho \"" + gametype.getName() + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.getName() + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.getName() + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.getName() + ".cfg silent" );
    }
                      
    gametype.spawnableItemsMask = 0;
    gametype.respawnableItemsMask = 0;
    gametype.dropableItemsMask = 0;
    gametype.pickableItemsMask = 0;

    gametype.isTeamBased = false;
    gametype.isRace = true;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 10;

    gametype.ammoRespawn = 20;
    gametype.armorRespawn = 25;
    gametype.weaponRespawn = 15;
    gametype.healthRespawn = 25;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 20;
    gametype.ultrahealthRespawn = 60;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = false;
    gametype.canForceModels = false;
    gametype.canShowMinimap = false;
    gametype.teamOnlyMinimap = true;

    gametype.spawnpointRadius = 256;

    // set spawnsystem type to instant while players join
    gametype.setTeamSpawnsystem( TEAM_PLAYERS, SPAWNSYSTEM_HOLD, 0, 0, true );


    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %p 52 %l 48 %p 18" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "Name Clan Caps Cons Alive Ping R" );

    // add commands
    G_RegisterCommand( "gametype" );

    G_Print( "Gametype '" + gametype.getTitle() + "' initialized\n" );
}