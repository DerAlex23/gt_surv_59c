///*****************************************************************
///	Author:	Alexander "AMrK" Mattis
///	Date:	29.05.2012
///
///	File:	survival/classes.as
///	Descr.:	Contains all classes which are needed for the survival match.
///*****************************************************************
    
void survival_NoDash_think( cEntity @ent )
{
}

void survival_NoDash( cEntity @ent )
{
    ent.setupModel( ent.getModelString() );
    ent.solid = SOLID_TRIGGER;
    ent.linkEntity();                   
    
    ent.nextThink = levelTime + 1000;
} 

void survival_NoDash_touch( cEntity @ent, cEntity @other, const cVec3 @planeNormal, int surfFlags )
{
    if( @other != null && @other.client != null )
        other.client.setPMoveFeatures( other.client.pmoveFeatures & ~int(PMFEAT_DASH) & ~int(PMFEAT_WALLJUMP) );
}


///*****************************************************************
///	Class:	cCheckPoint
///
///	Descr.:	Entity class, which will set the new respawn if a player comes in range.
///			If the cVar "g_captureMinimum" is set to more than 1, the entity will only
///			be activated if there are at least X players (X = value of"g_captureMinimum").
///			Every player who "captures" the entity will gain 1 point.
///*****************************************************************
class cCheckPoint
{
	cEntity @owner;
	cEntity @minimap;
	cCheckPoint @next;
	cString targetname;
	cString name;
	
	bool isCaptured;    
	
	void Initialize( cEntity @spawner )
	{
		@this.next = @listHeadCheckPoint;
		@listHeadCheckPoint = @this;

		@this.owner = @spawner;

		if ( @this.owner == null )
			return;

		cVec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );

		this.owner.type = ET_FLAG_BASE;
		this.owner.effects = EF_CARRIER|EF_FLAG_TRAIL;
		this.owner.setupModel( "models/objects/flag/flag_base.md3" );
		this.owner.setSize( mins, maxs );
		this.owner.solid = SOLID_TRIGGER;
		this.owner.team = TEAM_BETA;
		this.owner.svflags &= ~uint(SVF_NOCLIENT);
		this.owner.nextThink = levelTime + 1500;

		if ( ( this.owner.spawnFlags & 1 ) != 0 ) // float spawnFlag
			this.owner.moveType = MOVETYPE_NONE;
		else
			this.owner.moveType = MOVETYPE_TOSS;

		this.owner.linkEntity();
		this.owner.addAIGoal( true ); // bases are special because of the timers, use custom reachability checks

		// drop to floor
		cTrace tr;
		tr.doTrace( this.owner.getOrigin(), vec3Origin, vec3Origin, this.owner.getOrigin() - cVec3( 0.0f, 0.0f, 128.0f ), 0, MASK_DEADSOLID );

		@this.minimap = @G_SpawnEntity( "flag_minimap_icon" );
		this.minimap.type = ET_MINIMAP_ICON;
		this.minimap.solid = SOLID_NOT;
		this.minimap.setOrigin( this.owner.getOrigin() );
		this.minimap.setOrigin2( this.owner.getOrigin() );
		this.minimap.modelindex = prcFlagIcon;
		this.minimap.team = TEAM_BETA;
		this.minimap.frame = 24; // size in case of a ET_MINIMAP_ICON
		this.minimap.svflags = (this.owner.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST);
		this.minimap.linkEntity();
		this.minimap.nextThink = levelTime + 1000;
		
		this.isCaptured = false;
		this.name = owner.getTargetString();
		this.targetname = owner.getTargetnameString();
	}

	cCheckPoint()
	{
		Initialize( null );
	}

	cCheckPoint( cEntity @owner )
	{
		Initialize( owner );    
	}

	~cCheckPoint()
	{
	}
	
	void countCheckPoints()
	{
		numberOfCheckpoints += 1;
		if ( this.isCaptured )
			numberOfCapturedCheckpoints += 1;
		if ( @this.next != null )
			this.next.countCheckPoints();
	}
	
	void captured( cEntity @ent )
	{
		this.isCaptured = true;
		@latestCheckPoint = this;
		this.owner.team = TEAM_ALPHA;
		this.minimap.team = TEAM_ALPHA;
		
		if( !survival.sharedLifes )
			survival.setRespawn( 1 );

		survival.isCaptureing = true;
		respawnPlayers( !survival.sharedLifes );
		survival.isCaptureing = false;

		tournament_addPoint( ent.client, 1 );

		ent.client.stats.setScore(ent.client.stats.score + 1); 
		G_CenterPrintMsg( null, ent.client.getName() + " ^7captured a checkpoint!\n" );
		G_PrintMsg( null, ent.client.getName() + " ^7captured a checkpoint!\n" ); 
	}

	void multiCaptured( cClient@[] capturingSurvivors, int count )
	{
		this.isCaptured = true;
		@latestCheckPoint = this;
		this.owner.team = TEAM_ALPHA;
		this.minimap.team = TEAM_ALPHA;
		
		if( !survival.sharedLifes )
			survival.setRespawn( 1 );

		survival.isCaptureing = true;
		respawnPlayers( !survival.sharedLifes );
		survival.isCaptureing = false;

		cString message;
		for(int i = 0; i < count; i++)
		{
			if( i == 0)
				message = capturingSurvivors[i].getName();
			else if( i == count-1)
				message += " ^7and " + capturingSurvivors[i].getName();
			else
				message += "^7, " + capturingSurvivors[i].getName();

			tournament_addPoint( capturingSurvivors[i], 1 );

			capturingSurvivors[i].stats.setScore(capturingSurvivors[i].stats.score + 1); 
		}
		
		G_CenterPrintMsg( null, message + " ^7captured a checkpoint!\n" );
		G_PrintMsg( null, message + " ^7captured a checkpoint!\n" ); 
	}
	
	void thinkRules()
	{
		if ( match.getState() != MATCH_STATE_PLAYTIME )
			return;

		if ( survival.noCap )
			return;

		if ( !this.isCaptured )
		{
			// find players around
			cEntity @target = null;
			cEntity @stop = null;
			cVec3 origin = this.owner.getOrigin();
			bool notFound = false;
	
			@target = G_GetEntity( 0 );
			@stop = G_GetClient( maxClients - 1 ).getEnt(); // the last entity to be checked
			  
			int survivors = 0;    
			int neededSurvivors = survival.captureMinimum;
			if( neededSurvivors > G_GetTeam( TEAM_PLAYERS ).numPlayers )
				neededSurvivors = G_GetTeam( TEAM_PLAYERS ).numPlayers;
			cClient@[] capturingSurvivors ( neededSurvivors );
			int capturingSurvivorsCount = 0;

			while ( !this.isCaptured && !notFound )
			{
				@target = @G_FindEntityInRadius( target, stop, origin, 50.0f );
				if ( @target != null && @target.client != null )
				{
					if( !target.isGhosting() )
					{
						if( survival.captureMinimum == 1 )
						{
							this.captured( @target );
							break;
						}
						else
						{
							survivors++;
							@capturingSurvivors[capturingSurvivorsCount++] = @target.client;
							if(survivors >= neededSurvivors)
							{
								this.multiCaptured( capturingSurvivors, capturingSurvivorsCount );
								break;
							}
						}
					}
				}else{
					notFound = true;
				}
			}
		}
		
		if( @this.next != null )
			this.next.thinkRules();
	}  
}

///*****************************************************************
///	Descr.:	Creates a class "cCheckPoint" for every spawning entity "survival_CheckPoint"
///*****************************************************************
void survival_CheckPoint( cEntity @ent )
{
	cCheckPoint NewCheckpoint( ent );
}


///*****************************************************************
///	Class:	cFinish
///
///	Descr.:	Entity class, which will end the game if a player comes in range.
///			If the cVar "g_captureMinimum" is set to more than 1, the entity will only
///			be activated if there are at least X players (X = value of"g_captureMinimum").
///			Every player who "captures" the entity will gain 3 points.
///*****************************************************************
class cFinish
{
	cEntity @owner;
	cEntity @minimap;
	cFinish @next;
	
	bool isCaptured;    
	
	void Initialize( cEntity @spawner )
	{
		@this.next = @listHeadFinish;
		@listHeadFinish = @this;

		@this.owner = @spawner;

		if ( @this.owner == null )
			return;

		cVec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );

		this.owner.type = ET_FLAG_BASE;
		this.owner.effects = EF_CARRIER|EF_FLAG_TRAIL;
		this.owner.setupModel( "models/objects/flag/flag_base.md3" );
		this.owner.setSize( mins, maxs );
		this.owner.solid = SOLID_TRIGGER;
		this.owner.team = TEAM_BETA;
		this.owner.svflags &= ~uint(SVF_NOCLIENT);
		this.owner.nextThink = levelTime + 1500;

		if ( ( this.owner.spawnFlags & 1 ) != 0 ) // float spawnFlag
			this.owner.moveType = MOVETYPE_NONE;
		else
			this.owner.moveType = MOVETYPE_TOSS;

		this.owner.linkEntity();
		this.owner.addAIGoal( true ); // bases are special because of the timers, use custom reachability checks

			// drop to floor
			cTrace tr;
			tr.doTrace( this.owner.getOrigin(), vec3Origin, vec3Origin, this.owner.getOrigin() - cVec3( 0.0f, 0.0f, 128.0f ), 0, MASK_DEADSOLID );

		@this.minimap = @G_SpawnEntity( "flag_minimap_icon" );
		this.minimap.type = ET_MINIMAP_ICON;
		this.minimap.solid = SOLID_NOT;
		this.minimap.setOrigin( this.owner.getOrigin() );
		this.minimap.setOrigin2( this.owner.getOrigin() );
		this.minimap.modelindex = prcFlagIcon;
		this.minimap.team = TEAM_BETA;
		this.minimap.frame = 24; // size in case of a ET_MINIMAP_ICON
		this.minimap.svflags = (this.owner.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST);
		this.minimap.linkEntity();
		this.minimap.nextThink = levelTime + 1000;
		
		this.isCaptured = false;
	}

	cFinish()
	{
		Initialize( null );
	}

	cFinish( cEntity @owner )
	{
		Initialize( owner );
	}

	~cFinish()
	{
	}
	
	void captured( cEntity @ent )
	{
		this.isCaptured = true;
		this.owner.team = TEAM_ALPHA;
		this.minimap.team = TEAM_ALPHA;
		
		survival.reachedFinish();
		
		tournament_addPoint( ent.client, 1 );

		ent.client.stats.setScore(ent.client.stats.score + 3); 

		G_CenterPrintMsg( null, ent.client.getName() + " ^7reached the finish!\n" );
		G_PrintMsg( null, ent.client.getName() + " ^7reached the finish!\n" ); 
	}
	
	void multiCaptured( cClient@[] capturingSurvivors, int count )
	{
		this.isCaptured = true;
		this.owner.team = TEAM_ALPHA;
		this.minimap.team = TEAM_ALPHA;
		
		survival.reachedFinish();

		cString message;
		for(int i = 0; i < count; i++)
		{
			if( i == 0)
				message = capturingSurvivors[i].getName();
			else if( i == count-1)
				message += " ^7and " + capturingSurvivors[i].getName();
			else
				message += "^7, " + capturingSurvivors[i].getName();

			tournament_addPoint( capturingSurvivors[i], 1 );

			capturingSurvivors[i].stats.setScore(capturingSurvivors[i].stats.score + 3); 
		}
		
		G_CenterPrintMsg( null, message + " ^7reached the finish!\n" );
		G_PrintMsg( null, message + " ^7reached the finish!\n" ); 
	}
	
	void thinkRules()
	{
		if ( match.getState() != MATCH_STATE_PLAYTIME )
			return;

		if ( !this.isCaptured )
		{
			// find players around
			cEntity @target = null;
			cEntity @stop = null;
			cVec3 origin = this.owner.getOrigin();
			bool notFound = false;
	
			@target = G_GetEntity( 0 );
			@stop = G_GetClient( maxClients - 1 ).getEnt(); // the last entity to be checked
			  
			int survivors = 0;    
			int neededSurvivors = survival.captureMinimum;
			if( neededSurvivors > G_GetTeam( TEAM_PLAYERS ).numPlayers )
				neededSurvivors = G_GetTeam( TEAM_PLAYERS ).numPlayers;
			cClient@[] capturingSurvivors ( neededSurvivors );
			int capturingSurvivorsCount = 0;

			while ( !this.isCaptured && !notFound )
			{
				@target = @G_FindEntityInRadius( target, stop, origin, 50.0f );
				if ( @target != null && @target.client != null )
				{
					if( !target.isGhosting() )
					{
						if( survival.captureMinimum == 1 )
						{
							this.captured( @target );
							break;
						}
						else
						{
							survivors++;
							@capturingSurvivors[capturingSurvivorsCount++] = @target.client;
							if(survivors >= neededSurvivors)
							{
								this.multiCaptured( capturingSurvivors, capturingSurvivorsCount );
								break;
							}
						}
					}
				}else{
					notFound = true;
				}
			}
		}
		
		if( @this.next != null )
			this.next.thinkRules();
	}
}

///*****************************************************************
///	Descr.:	Creates a class "cFinish" for every spawning entity "survival_Finish"
///*****************************************************************
void survival_Finish( cEntity @ent )
{
	cFinish NewFinish( ent );
}

///*****************************************************************
///	Class:	cSurvivalRound
///
///	Descr.:	Class which contains the current settings of the match and handles events.
///*****************************************************************
class cSurvivalRound
{
	uint timer;
	int continues;
	bool needToRespawn;
	bool noCap;
	bool sharedLifes;
	int captureMinimum;
	bool isCaptureing;
	
	cSurvivalRound()
	{
		this.needToRespawn = false;
		this.continues = 0;
		this.isCaptureing = false;
	}
	
	void start()
	{        
		G_ConfigString( CS_GENERAL, "- 0 players alive -" );
		
		this.captureMinimum = voteCaptureMinimum.getInteger();
		
		if ( voteSharedLifes.getInteger() == 0 )
		{
			this.sharedLifes = false;
		}
		else
		{
			this.sharedLifes = true;
		}
		
		if ( voteContinues.getInteger() == -1 )
		{
			G_ConfigString( CS_GENERAL +1, "- unlimited continues -" );
			this.setContinues( -1 );
		}
		else
		{
			this.setContinues( voteContinues.getInteger() );
		}
		
		if ( voteNoCap.getInteger() == 0 )
		{
			this.noCap = false;
		}
		else
		{
			this.noCap = true;
		}
		
		for ( cCheckPoint @checkPoint = @listHeadCheckPoint; @checkPoint != null; @checkPoint = @checkPoint.next )
		{
			checkPoint.owner.team = TEAM_BETA;
			checkPoint.minimap.team = TEAM_BETA;
			checkPoint.isCaptured = false;
		}
		
		for ( cFinish @finish = @listHeadFinish; @finish != null; @finish = @finish.next )
		{
			finish.owner.team = TEAM_BETA;
			finish.minimap.team = TEAM_BETA;
			finish.isCaptured = false;
		}
		
		for(int i = 0; i < maxClients; i++)
		{
			sl_isDead[i] = false;
		}
		
		this.needToRespawn = true;
	}
	
	void thinkRules()
	{ 
		if ( match.getState() != MATCH_STATE_PLAYTIME )
			return;

		this.checkCaptures();

		this.updateHud();

		if ( this.continues == -1 && match.timeLimitHit() )
			this.timeLimitHit();
			
		if ( this.needToRespawn && !this.sharedLifes)
		{
			if ( levelTime >= this.timer )
			{                           
				this.needToRespawn = false;
				respawnPlayers( false );
			}
		}
		else
		{
			this.checkTeam();
			for ( int i = 0; i < maxClients; i++ )
			{    
				cClient @client = @G_GetClient( i );          

				cItem @itemrl = @G_GetItemByName( "eb" );
				cItem @ammoItemrl = @G_GetItem( itemrl.weakAmmoTag );
				client.inventorySetCount( ammoItemrl.tag, 1);
				
			} 
		}
	}
	
	void checkCaptures()
	{
		if( @listHeadCheckPoint != null )
			listHeadCheckPoint.thinkRules();
		if( @listHeadFinish != null )
			listHeadFinish.thinkRules();
	}
	
	void updateHud()
	{
		for ( int i = 0; i < maxClients; i++ )
		{
			cClient @client = @G_GetClient( i );
			
			client.setHUDStat( STAT_MESSAGE_ALPHA, CS_GENERAL );
			client.setHUDStat( STAT_MESSAGE_SELF, CS_GENERAL + 1 );
		}
	}
	
	void setRespawn( float seconds )
	{
		if(this.sharedLifes)
			return;
		this.timer = levelTime + (seconds * 1000);
		this.needToRespawn = true;
	}        
	
	void reachedFinish()
	{
		match.launchState( match.getState() + 1 );
	}
	
	void timeLimitHit()
	{
		G_CenterPrintMsg( null, "^7The time ran out!\n" );
		G_PrintMsg( null, "^7The time ran out!\n" );
		match.launchState( match.getState() + 1 );
	}
	
	void checkTeam()
	{
		if( match.getState() != MATCH_STATE_PLAYTIME )
			return;
			
		if( this.isCaptureing )
			return; 

		cTeam @team;
		int alive = 0;
	
		@team = @G_GetTeam( TEAM_PLAYERS );
		for ( int i = 0; @team.ent( i ) != null; i++ )
		{
			if ( !team.ent( i ).isGhosting() )
				alive++;
			else
			{
				if( this.sharedLifes )
				{
					if ( this.continues != 0 && match.getState() == MATCH_STATE_PLAYTIME )
					{
						if( sl_isDead[ team.ent( i ).client.playerNum() ] )
						{
							if( levelTime - sl_respawnTimer[ team.ent( i ).client.playerNum() ] >= 2000 && sl_allowRespawn[ team.ent( i ).client.playerNum() ])
							{
								sl_isDead[ team.ent( i ).client.playerNum() ] = false;
								team.ent( i ).client.respawn( false );
							}
						}
						else
						{
							sl_isDead[ team.ent( i ).client.playerNum() ] = true;
							sl_allowRespawn[ team.ent( i ).client.playerNum() ] = true;
							sl_respawnTimer[ team.ent( i ).client.playerNum() ] = levelTime;
							team.ent( i ).client.chaseCam( "FirstPerson", true );

							if( this.continues != -1 )
							{
								if( this.continues == 0 )
									sl_allowRespawn[ team.ent( i ).client.playerNum() ] = false;
									
								this.setContinues( this.continues -1 );
								if ( this.continues == 1 )
								{
									G_CenterPrintMsg( null, "1 ^7continue left!\n" );
									G_PrintMsg( null, "1 ^7continue left!\n" );
								}
								else
								{
									G_CenterPrintMsg( null, this.continues + " ^7continues left!\n" );
									G_PrintMsg( null, this.continues + " ^7continues left!\n" );
								}
							}
						}
					}                      
				}
			}
		} 
		
		if ( alive == 1 )
		{
			G_ConfigString( CS_GENERAL, "- 1 player alive -" );
		}
		else
		{
			G_ConfigString( CS_GENERAL, "- " + alive + " players alive -" );
		}
		
		if ( this.sharedLifes )
		{
			if ( this.continues == 0 && match.getState() == MATCH_STATE_PLAYTIME && alive == 0 )
			{
				G_CenterPrintMsg( null, "^7No continues left!\n" );
				G_PrintMsg( null, "^7No continues left!\n" );
				this.setContinues( 0 );
				respawnPlayers( true );
				match.launchState( match.getState() + 1 );
			}
		}
		else
		{
		  if ( alive == 0 && this.needToRespawn == false)
		  {
			  this.groupDied();
		  }
		}
	}
	
	void groupDied()
	{
		if ( this.continues == -1 && match.getState() == MATCH_STATE_PLAYTIME )
		{
			this.setRespawn( 2 );
		}
		else if ( this.continues == 1 && match.getState() == MATCH_STATE_PLAYTIME )
		{
			G_CenterPrintMsg( null, "^7No continues left!\n" );
			G_PrintMsg( null, "^7No continues left!\n" );
			this.setContinues( 0 );
			respawnPlayers( true );
			match.launchState( match.getState() + 1 );
		}
		else if ( match.getState() == MATCH_STATE_PLAYTIME  )
		{
			this.setContinues( this.continues -1 );
			this.setRespawn( 2 );
			if ( this.continues > -1 )
			{
				if ( this.continues == 1 )
				{
					G_CenterPrintMsg( null, "1 ^7continue left!\n" );
					G_PrintMsg( null, "1 ^7continue left!\n" );
				}
				else
				{
					G_CenterPrintMsg( null, this.continues + " ^7continues left!\n" );
					G_PrintMsg( null, this.continues + " ^7continues left!\n" );
				}
			}
		} 
	}
	
	void setContinues( int left )
	{
		if ( left == -1 )
		{
			G_ConfigString( CS_GENERAL +1, "- unlimited continues -" );
		}
		else if ( left == 1 )
		{
			G_ConfigString( CS_GENERAL +1, "- 1 continue left -" );
		}
		else
		{
			G_ConfigString( CS_GENERAL +1, "- " + left + " continues left -" );
		}
		this.continues = left;
	}
	
	cEntity @getRespawnPoint( cEntity @self )
	{
		if ( @latestCheckPoint == null )
		{
			return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
		}
		else
		{
			return @latestCheckPoint.owner;
		}    
	}
}

class cSurvivor
{
	bool isLoggedIn;
	cString username;
	cString password;
	int[] score;

	cSurvivor()
	{
		this.score = int[](4);
		this.logout();
	}

	int regist(cString username, cString password)
	{
		username = username.tolower().removeColorTokens();
		
		if ( username != removeBadChars( username ) )
			return -1;

		if( G_FileExists( "survival/tournament/players/" + username ) )
			return -2;
		
		this.logout(); // clear score
		this.username = username;
		this.password = password;

		this.saveData(); // now save it

		return 1;
	}

	int login(cString username, cString password)
	{
		username = username.tolower().removeColorTokens();
		
		if ( username != removeBadChars( username ) )
			return -1;

		if( !G_FileExists( "survival/tournament/players/" + username ) )
			return -2;

		cString fileContent = G_LoadFile( "survival/tournament/players/" + username );
		cString realPassword = fileContent.getToken( 0 );
		if( realPassword != password )
			return -3;

		loadData( username );

		return 1;
	}

	void addScore( int index, int count )
	{
		this.score[ index ] += count;
		this.saveData();
	}

	void saveData()
	{
		cString fileContent = "" + this.password + "\n" + this.score[0] + "\n" + this.score[1] + "\n" + this.score[2] + "\n" + this.score[3];
		G_WriteFile( "survival/tournament/players/" + this.username, fileContent );
	}

	void loadData(cString username)
	{
		this.username = username;
		this.isLoggedIn = true;
		cString fileContent = G_LoadFile( "survival/tournament/players/" + username );
		this.password = fileContent.getToken( 0 );
		for(int i = 0; i < 4; i++)
			this.score[i] = fileContent.getToken( 1 + i ).toInt();
	}

	void logout()
	{
		this.isLoggedIn = false;
		this.username = "";
		for(int i = 0; i < 4; i++)
			this.score[i] = 0;
	}
}