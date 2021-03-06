// =============================================================================
//  SmartASS
// 
//  Changelog:-
//    May 2005 by cratos@gmx.at : Initial release to support match mode in
//             LeagueAS, bringing additional context into UT Stats.
//             Includes hammer jumps, launches and rocket launches, plus
//             detection of suicide via keybind, and other special events.
//   
//    Jul 2005 by cratos@gmx.at : Added support for 'Saves' and 'assists'.
//
//    Jul 2008 by timo@utassault.net : Allow "manual" match code generation
//             through remote setup for UTA PUG matches.
//
//    Feb 2022 by timo@utassault.net : Added multi-value hammer launch
//             detection for lower/higher value launches.
//
// =============================================================================
class SmartAS_Mutator expands Mutator config;

var() config bool bEnabled;
var() config bool bDebug;
var() config int MapSequence;
var() config string gRedTeam;
var() config string gBlueTeam;
var() config string MatchCode;
var string SmartASVersion;
var() config int AssistArea;
var() config int AssistTimeOut;
var() config bool bShowAssistMessage;
var() config bool bPlayAssistSound;
var() config string DebugName;
var() config int MaxID;
var() config bool bGenerateNewCode;
var() config string HiValueHLSpots[32]; // AS-Map,Radius,Height;X,Y,Z;X,Y,Z;
var() config string LoValueHLSpots[32]; // e.g. AS-Siege][,300,60;250,-250,25;
var int MapSpots;
var() config bool bSaved;

var class<actor> MessageClass;

struct PlayerInfoType
{
	var int RInstigatorID;
	var int LastTick;
	var int RocketCount;
	var FortStandard AssistFort;
	var vector SpawnLocation;
};
var PlayerInfoType PlayerInfo[100];

struct KillLogType
{
	var Pawn Killer;
	var Pawn Victim;
	var vector VictimLocation;
	var float TimeStamp;
};
var KillLogType KillLog[25];
var int KillLogPointerNextFree;

var int ticks;
var bool bGameParamsLogged;
var bool bEndScoreLogged;

var bool bMatchMode;
var string RedTeam, BlueTeam;
var int RedScore, BlueScore;
var int MatchLength;
var int MapsLeft;
var MsgSpec MsgSpec;


event PreBeginPlay()
{
	Assault(Level.Game).bCoopWeaponMode = Assault(Level.Game).bMultiWeaponStay;
	Level.Game.RegisterDamageMutator(self);
	setTimer(1.0,true);

	MsgSpec = Level.Spawn(class'MsgSpec');
	MsgSpec.SmartAS = self;

	if (!bSaved)
		StaticSaveConfig();

	ConfigureTZs();

	MessageClass = class<actor>(DynamicLoadObject("SmartAS-Message.SmartASMessage", class'class',true));
	if (MessageClass==None) log ("SmartAS-Message is disabled");
}

event Timer()
{
	if (!bGameParamsLogged && Level.Game.LocalLog!=None)
	{
		Tag='EndGame';
		LogGameStart();
		bGameParamsLogged = true;
		settimer(0,false);
	}
}

// Endgame Trigger: LeagueAS Teamscore is updated
event Trigger(Actor Other, Pawn EventInstigator)
{
	if (Other.IsA('Assault'))
	{
		LogGameEnd();
	}
}


// Warning: LeagueAS Teamscore is not updated yet
function bool HandleEndGame()
{
	// Fix final fort bug
	if (MsgSpec!=None) MsgSpec.Clientmessage("",'CriticalEvent',false);
	return super.HandleEndGame();
}

// =============================================================================
// Trigger Zone support for defining areas of interest
//  Currently used to define high or low value Hammer Launch zones
// =============================================================================
function ConfigureTZs()
{
	local string MapName;
	local string TZRaw;
	local int i;

	MapName = Left(Self, InStr(Self, "."));
	for (i = 0; i < MapSpots; i++)
	{
		if (Len(HiValueHLSpots[i]) > 0 && InMap(MapName,HiValueHLSpots[i],","))
		{
			TZRaw = StripMap(MapName,HiValueHLSpots[i]);
			UnpackTZData(TZRaw, 1);
		}
		if (Len(LoValueHLSpots[i]) > 0 && InMap(MapName,LoValueHLSpots[i],","))
		{
			TZRaw = StripMap(MapName,LoValueHLSpots[i]);
			UnpackTZData(TZRaw,-1);
		}
	}
}

function bool InMap(string MapName, string Test, optional string AdditionalData)
{
	return bool(Left(Test,Len(MapName)+Len(AdditionalData)) ~= MapName$AdditionalData);
}

function string StripMap(string MapName, string Data, optional string AdditionalData)
{
	return Right(Data,Len(Data)-(Len(MapName)+Len(AdditionalData)));
}

function UnpackTZData(string LocationData, int Rating)
{
	local int i;
	local string TZCollision;
	local string TZData[16]; // Index 0 is Collision (Radius, Height), Indexes 1-15 are Vectors
	local vector TZVector;

	ParseToArray(LocationData,";",TZData);
	TZCollision = "0,0";
	if (Len(TZData[0]) > 2)
		TZCollision = TZData[0];
	for (i = 1; i < 16; i++)
	{
		TZVector = vect(0,0,0);
		if (Len(TZData[i]) > 4)
		{
			TZVector = vector(TZData[i]);
			if (TZVector != vect(0,0,0))
				SpawnHLTZ(TZVector,TZCollision,Rating);
		}
	}
}

function SpawnHLTZ(vector Location, string TZC, int TZR)
{
	local SmartAS_TriggerZone TZ;
	local int R, H, i;

	TZ = Spawn(class'SmartAS_TriggerZone',Self, , Location);
	TZ.bHidden = true;
    TZ.SetCollision(true,false,false);
    R = 50;  // default radius
	H = 50;  // default height
	i = InStr(TZC, ",");
	if (i >= 0)
	{
		R = int(Left(TZC, i));
		H = int(Mid(TZC, i+1));
	}
    TZ.SetCollisionSize(R,H);
    TZ.Rating = TZR;
}

// =============================================================================
// LogGameStart() and LogGameEnd() injection into Stats Logs
// =============================================================================

function LogGameEnd()
{
	local string ScoreString;

	RedTeam = Level.Game.GetPropertyText("TeamNameRed");
	BlueTeam = Level.Game.GetPropertyText("TeamNameBlue");
	ScoreString = Level.Game.GameReplicationInfo.GetPropertyText("MatchScore");
	ScoreString = mid(ScoreString,len(RedTeam)+1,len(ScoreString)-len(RedTeam)-len(BlueTeam)-2);
	RedScore = int(left(ScoreString,instr(ScoreString,"-")-1));
	BlueScore = int(mid(ScoreString,instr(ScoreString,"-")+2));
	LogSpecialEvent("ass_teamnames_end", RedTeam, BlueTeam);
	LogSpecialEvent("ass_teamscore_end", RedScore, BlueScore);
	// Matchmode
	bMatchMode = bool(Level.Game.GetPropertyText("bMatchMode"));
	LogSpecialEvent("ass_matchmode_end", bMatchMode);

	// test @ REMOVE ME
	log("CurrentID:"@Level.Game.CurrentID);
	if (Level.Game.CurrentID > MaxID)
	{
	 	MaxID = Level.Game.CurrentID;
	 	SaveConfig();
	}
}


function LogGameStart()
{
	local string ScoreString;

	// Log ExtObjInfo
	MsgSpec.zzSetup();

	// SmartAS Version
	LogSpecialEvent("ass_smartas_vers", SmartASVersion, string(Self.class));
	LogSpecialEvent("ass_leagueas_vers", string(Level.Game.class));

	// Get Real Servername (without prefixes)
	LogSpecialEvent("ass_servername",Level.Game.GameReplicationInfo.default.ServerName);

	// Matchmode
	bMatchMode = bool(Level.Game.GetPropertyText("bMatchMode"));
	LogSpecialEvent("ass_matchmode", bMatchMode);

	// MatchSequence
	MapSequence++;
	SaveConfig();
	LogSpecialEvent("ass_mapsequence", MapSequence);

	//Maps - Matchlength
	MatchLength = int(Level.Game.GetPropertyText("MatchLength"));
	MapsLeft = int(Level.Game.GetPropertyText("MapsLeft"));
	LogSpecialEvent("ass_matchlenth", MatchLength);
	LogSpecialEvent("ass_mapsleft", MapsLeft);

	// Score at start
	RedTeam = Level.Game.GetPropertyText("TeamNameRed");
	BlueTeam = Level.Game.GetPropertyText("TeamNameBlue");
	ScoreString = Level.Game.GameReplicationInfo.GetPropertyText("MatchScore");
	ScoreString = mid(ScoreString,len(RedTeam)+1,len(ScoreString)-len(RedTeam)-len(BlueTeam)-2);
	RedScore = int(left(ScoreString,instr(ScoreString,"-")-1));
	BlueScore = int(mid(ScoreString,instr(ScoreString,"-")+2));
	LogSpecialEvent("ass_teamnames", RedTeam, BlueTeam);
	LogSpecialEvent("ass_teamscore", RedScore, BlueScore);

	// Matchcode
	if (bGenerateNewCode || (bMatchMode && (RedTeam!=gRedTeam || BlueTeam!=gBlueTeam)))
	{
		gRedTeam = RedTeam;
		gBlueTeam = BlueTeam;
		MatchCode = GenerateAssaultMatchCode();
		bGenerateNewCode = False; // Added to allow manual triggering of GenerateAssaultMatchCode()
		SaveConfig();
	}
	LogSpecialEvent("ass_matchcode", MatchCode);

	// some general stuff
	LogSpecialEvent("game","FriendlyFireScale",Assault(Level.Game).FriendlyFireScale);
	LogSpecialEvent("game","AirControl",Assault(Level.Game).AirControl);
}

// =============================================================================
// GenerateAssaultMatchCode() - creates a random string of characters which
//  are used to tie multiple rounds of Assault maps together as a "match".
// =============================================================================
function string GenerateAssaultMatchCode()
{
	local int i;
	local int num;
	local string MatchCode;

	while (i<8)
	{
		Num = Rand(123);
		if ( ((Num >= 48) && (Num <= 57)) ||
			 ((Num >= 65) && (Num <= 91)) ||
			((Num >= 97) && (Num <= 123)) )
		{
			MatchCode = MatchCode $ Chr(Num);
			i++;
		}
	}
	return MatchCode;
}


event Tick (float Deltatime)
{
	ticks++;
}

function Mutate(string MutateString, PlayerPawn Sender)
{
	if (MutateString ~= "smartas") Sender.ClientMessage("SmartAS Version:"@SmartASVersion);
	else super.Mutate(MutateString, Sender);
}

function MutatorTakeDamage(out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
	local int PID,HLRating;
	local SmartAS_TriggerZone TZ;

	// Super
	if (NextDamageMutator != None)
		NextDamageMutator.MutatorTakeDamage(ActualDamage, Victim, InstigatedBy, HitLocation, Momentum, DamageType);

	//log("===>>MutatorTakeDamage"@ActualDamage@DamageType@Momentum@VSize(Momentum)@"VH:"$Victim.Health);

	if (VSize(Momentum) == 0) return; // Victim has spawnprotection

	if (DamageType=='impact')
	{
	 	// Detect Hammerjump
		if (Victim==InstigatedBy)	// Damaging myself
		{
			if (  Victim.Weapon.IsA('ImpactHammer') &&   					// yes its a hammer
					ImpactHammer(Victim.Weapon).IsInState('Firing') &&		// primary fire
					ImpactHammer(Victim.Weapon).ChargeSize > 1.49 &&    	// fully charged
					Victim.Health > Actualdamage                          // I do survive it
			   )
			{
				if (bDebug) log("-->ass_h_jump!");
				LogSpecialEvent("ass_h_jump", Victim.PlayerReplicationInfo.PlayerID);
			}
		}

		// Detect Hammerlaunch
		if (Victim!=InstigatedBy && Victim!=None && InstigatedBy!=None) 		// Damaging someone else
		if (Victim.PlayerReplicationInfo.Team==InstigatedBy.PlayerReplicationInfo.Team) // Teammate
		if (Victim.PlayerReplicationInfo.Team!=Assault(Level.Game).CurrentDefender) // Attackers only
		{
			if (	InstigatedBy.Weapon.IsA('ImpactHammer') &&         		// yes its a hammer
					ImpactHammer(InstigatedBy.Weapon).IsInState('Firing') &&	// primary fire
					ImpactHammer(InstigatedBy.Weapon).ChargeSize > 1.49 && 	// fully charged
					Victim.Health > Actualdamage										// he survives it
				)
			{
				HLRating = 0;
				foreach InstigatedBy.TouchingActors(class'SmartAS_TriggerZone', TZ)
				{
					// Higher priority overrides lower priority, except for no pri.
					if (TZ.Rating > 0)
						HLRating = TZ.Rating;
					else if (HLRating == 0)
						HLRating = TZ.Rating;
				}
				if (HLRating > 0)
				{
					if (bDebug) log("-->ass_h_launch_hi!");
					LogSpecialEvent("ass_h_launch_hi",InstigatedBy.PlayerReplicationInfo.PlayerID, Victim.PlayerReplicationInfo.PlayerID);	
				}
				else if (HLRating < 0)
				{
					if (bDebug) log("-->ass_h_launch_lo!");
					LogSpecialEvent("ass_h_launch_lo",InstigatedBy.PlayerReplicationInfo.PlayerID, Victim.PlayerReplicationInfo.PlayerID);	
				}
				else
				{
					if (bDebug) log("-->ass_h_launch!");
					LogSpecialEvent("ass_h_launch",InstigatedBy.PlayerReplicationInfo.PlayerID, Victim.PlayerReplicationInfo.PlayerID);	
				}
				
			}
		}
	}

	// Detect Rocketlaunch
	else if (DamageType=='Rocketdeath')
	{
		if (Victim!=None && InstigatedBy!=None && Victim!=InstigatedBy)			// Damaging someone else
	 	if (Victim.PlayerReplicationInfo.Team==InstigatedBy.PlayerReplicationInfo.Team)	// Teammate
		if (Victim.PlayerReplicationInfo.Team!=Assault(Level.Game).CurrentDefender) // Attackers only
		if (Actualdamage == 0)  																	 // no pro
		{
			//log("Rockets in tick:"@ticks);
			PID = Victim.PlayerReplicationInfo.PlayerID % 100;
			if (((ticks - PlayerInfo[PID].LastTick) <= 2) &&
				(PlayerInfo[PID].RInstigatorID == InstigatedBy.PlayerReplicationInfo.PlayerID))
			{
				PlayerInfo[PID].LastTick = ticks;
				PlayerInfo[PID].RocketCount++;
				//log("Setting Rockets to"@PlayerInfo[PID].RocketCount@ticks@InstigatedBy.PlayerReplicationInfo.PlayerID);
				if (PlayerInfo[PID].RocketCount >= 5)  // 5 or 6 rockets
				{
					if (VSize(Victim.Location-InstigatedBy.Location) < 500) 	// they are quite near
					{
					 	if (bDebug) log ("-->ass_r_launch"@VSize(Victim.Location-InstigatedBy.Location));
					 	LogSpecialEvent("ass_r_launch",InstigatedBy.PlayerReplicationInfo.PlayerID, Victim.PlayerReplicationInfo.PlayerID, VSize(Victim.Location-InstigatedBy.Location));
					}
					PlayerInfo[PID].RocketCount = 0;
				}
			}
			else
			{
				 //log("Reset Rockets"@ticks@InstigatedBy.PlayerReplicationInfo.PlayerID);
				 PlayerInfo[PID].RocketCount = 1;
				 PlayerInfo[PID].LastTick = ticks;
				 PlayerInfo[PID].RInstigatorID = InstigatedBy.PlayerReplicationInfo.PlayerID;
			}
		}
	}
}

function bool PreventDeath(Pawn Killed, Pawn Killer, name damageType, vector HitLocation)
{
	// Suicide
	if (Killer==None && damageType=='Suicided')
	{
		if (bDebug) log ("-->ass_suicide_coop"@Killed.PlayerReplicationInfo.PlayerID);
		LogSpecialEvent("ass_suicide_coop",Killed.PlayerReplicationInfo.PlayerID);
	}

	// Teamchange
	if (Killer==None && damageType=='None')
	{
	 	CheckTeamChange(Killed);
	}

	// Headshot
	if (Killed!=Killer && damageType=='Decapitated')
	{
	 	if (bDebug) log ("-->Headshot"@Killer.PlayerReplicationInfo.PlayerID@Killed.PlayerReplicationInfo.PlayerID);
		LogSpecialEvent("headshot",Killer.PlayerReplicationInfo.PlayerID,Killed.PlayerReplicationInfo.PlayerID);
	}

	if (NextMutator != None) return NextMutator.PreventDeath(Killed,Killer, damageType,HitLocation);
	return false;
}

function FixTeams()
{
	local Pawn P;
	local int RedTeam;
	local int BlueTeam;

	// Fix Teamsizes
	for (P=Level.PawnList; P!=None; P=P.nextPawn)
	{
		if (P.bIsPlayer && (P.IsA('PlayerPawn') || P.IsA('Bot'))  && P.PlayerReplicationInfo!=None)
		{
		  	if (P.PlayerReplicationInfo.Team == 0) RedTeam++;
		  	if (P.PlayerReplicationInfo.Team == 1) BlueTeam++;
		}
	}
	Assault(Level.Game).Teams[0].Size = RedTeam;
	Assault(Level.Game).Teams[1].Size = BlueTeam;
}

function CheckTeamChange(Pawn Killed)
{
	local int RedTeam;
	local int BlueTeam;

	FixTeams();
	RedTeam = Assault(Level.Game).Teams[0].Size;
	BlueTeam = Assault(Level.Game).Teams[1].Size;

	LogSpecialEvent("ass_teamchange",Killed.PlayerReplicationInfo.PlayerID,Killed.PlayerReplicationInfo.Team,RedTeam,BlueTeam);
}

function ScoreKill(Pawn Killer, Pawn Other)
{
	if (Killer!=None && Killer.bIsPlayer && Other!=None && Other.bIsPlayer && Killer!=Other)
	{
		KillLog[KillLogPointerNextFree].Killer = Killer;
		KillLog[KillLogPointerNextFree].Victim = Other;
		KillLog[KillLogPointerNextFree].TimeStamp = Level.TimeSeconds;
		KillLog[KillLogPointerNextFree].VictimLocation = Other.Location;
		if (++KillLogPointerNextFree >= 25) KillLogPointerNextFree = 0;
	}
}

function ModifyPlayer(Pawn Other)
{
 	super.ModifyPlayer(Other);
 	PlayerInfo[Other.PlayerReplicationInfo.PlayerID%100].SpawnLocation = Other.Location;
}

function RemoveFort(FortStandard F, Pawn Instigator, bool bFinal, int ObjNum)
{
	local Pawn P;
	local int Att_Size;
	local int Def_Size;
	local int i;
	local int AssistPID;

	if (!Instigator.bIsPlayer) return;

	//Log ("REMOVE FORT"@GetFortName(F)@Instigator);

	// Log Teamsize on Removefort
	FixTeams();
	if (Assault(Level.Game).Attacker != None) Att_Size = Assault(Level.Game).Attacker.Size;
	if (Assault(Level.Game).Defender != None) Def_Size = Assault(Level.Game).Defender.Size;
	LogSpecialEvent("assault_obj_teams",objnum,Att_Size,Def_Size);

	// Get Assists by kill/death
	for (i=0; i<25; i++)
	{
		// if Kill was within Timeout
		if (KillLog[i].TimeStamp>0 && ((Level.TimeSeconds - KillLog[i].TimeStamp < AssistTimeOut)))
		{
			// if Attacker killed Defender that was near Fort
			if ((KillLog[i].Killer.PlayerReplicationInfo.Team == Assault(Level.Game).Attacker.TeamIndex) &&
				 (KillLog[i].Victim.PlayerReplicationInfo.Team == Assault(Level.Game).Defender.TeamIndex))
			{
				// Was it near enough?
				if (DistanceFrom(KillLog[i].Victim,F) < AssistArea)
				{
					CheckAssist("kill",KillLog[i].Killer, KillLog[i].Victim,F,ObjNum,Instigator);
				}
			}

			// if Attacker got Killed by Defender near Fort
			if ((KillLog[i].Killer.PlayerReplicationInfo.Team == Assault(Level.Game).Defender.TeamIndex) &&
				 (KillLog[i].Victim.PlayerReplicationInfo.Team == Assault(Level.Game).Attacker.TeamIndex))
			{
				// Was it near enough?
				if (DistanceFrom(KillLog[i].Victim,F) < AssistArea)
				{
					CheckAssist("death",KillLog[i].Victim,KillLog[i].Killer,F,ObjNum,Instigator);
				}
			}
		}
	}

	// Get Assists by being in Area
	for (P=Level.PawnList; P!=None; P=P.nextPawn)
	{
	 	if (P.IsA('TournamentPlayer'))
	 	{
 	 	 	if (P.PlayerReplicationInfo.Team == Assault(Level.Game).Attacker.TeamIndex)
 	 	 	{
 	 	 		if (DistanceFrom(P,F) < AssistArea && P!=Instigator)
 	 	 		{
 	 	 			AssistPID = P.PlayerReplicationInfo.PlayerID % 100;
					if (DistanceFromLocation(F,PlayerInfo[AssistPID].SpawnLocation) > 2*AssistArea)
					{
						// Check Spawnprotection to prevent stuff like Ballistic laserfield
						if (!HasSpawnProtectionActive(P))
						{
							CheckAssist("area",P,none,F,ObjNum,Instigator);
						}
					}
 	 	 		}
 	 	 	}
	 	}
	}
}

function CheckAssist(string type, Pawn AssistPawn, Pawn OtherPawn, FortStandard F, int ObjNum, Pawn Instigator)
{
	local int AssistPID;

	AssistPID = AssistPawn.PlayerReplicationInfo.PlayerID % 100;
	if (PlayerInfo[AssistPID].AssistFort!=F && AssistPawn!=Instigator)
	{
		PlayerInfo[AssistPID].AssistFort = F;

		if (type=="kill")
		{
			LogSpecialEvent("ass_assist","kill",ObjNum,AssistPID);
			log("Assist: (kill)"@GetFortName(F)@AssistPawn.PlayerReplicationInfo.PlayerName@"killed"@OtherPawn.PlayerReplicationInfo.PlayerName);
		 	if (bShowAssistMessage)
		 	{
		 		AssistPawn.Clientmessage("Assist! (kill) (" $ GetFortName(F) $ ") (" $ OtherPawn.PlayerReplicationInfo.PlayerName $")",'CriticalEvent');
		 	}
		}
		if (type=="death")
		{
			LogSpecialEvent("ass_assist","death",ObjNum,AssistPID);
			log("Assist: (death)"@GetFortName(F)@AssistPawn.PlayerReplicationInfo.PlayerName@"death by"@OtherPawn.PlayerReplicationInfo.PlayerName);
		 	if (bShowAssistMessage)
		 	{
		 		AssistPawn.Clientmessage("Assist! (death) (" $ GetFortName(F) $ ") (" $OtherPawn.PlayerReplicationInfo.PlayerName $")",'CriticalEvent');
		 	}
		}
		if (type=="area")
		{
			LogSpecialEvent("ass_assist","area",ObjNum,AssistPID);
			log("Assist: (area)"@GetFortName(F)@AssistPawn.PlayerReplicationInfo.PlayerName);
		 	if (bShowAssistMessage)
		 	{
		 		AssistPawn.Clientmessage("Assist! (area) (" $ GetFortName(F) $ ")",'CriticalEvent');
		 	}
		}
		if (bPlayAssistSound || instr(AssistPawn.PlayerReplicationInfo.PlayerName, DebugName) >= 0)
			SmartASSound(AssistPawn,"Announcer.Assist");
	}
}

function SmartASSound(Pawn P, string SoundString)
{
	local actor MessageActor;

	if (MessageClass != None)
	{
	 	MessageActor = P.Spawn(MessageClass,P);
	 	if (MessageActor != None)
	 	{
	 		MessageActor.SetPropertyText("TheSoundString",SoundString);
	 		MessageActor.Trigger(none,none);
	 	}
	}
}

function bool HasSpawnProtectionActive(Pawn P)
{
 	local Inventory Inv;

	for(Inv=P.Inventory; Inv!=None; Inv=Inv.Inventory)
	{
		if (instr(string(Inv.class),"LeagueAS_Inventory") > 0)
		{
			return (Inv.GetPropertyText("SpawnProtectActive") ~= "True");
		}
	}
	return false;
}


// =============================================================================
// NearestObjDist - Returns the distance to the nearest Obj
// =============================================================================
function float NearestObjDist(Pawn Sender, out FortStandard NearestFort, out FortStandard NearestFort2)
{
	local FortStandard F;
	local float DistToNearestFort, DistToNearestFort2, ThisFortDist;

	DistToNearestFort = 1000000;
	DistToNearestFort2 = 1000000;
	NearestFort = none;
	NearestFort2 = none;

	ForEach AllActors(class'FortStandard', F)
	{
		ThisFortDist = DistanceFrom(Sender, F);
		if (ThisFortDist < DistToNearestFort)
		{
			DistToNearestFort2 = DistToNearestFort;
			NearestFort2 = NearestFort;
			DistToNearestFort = ThisFortDist;
			NearestFort = F;
		}
		else if (ThisFortDist < DistToNearestFort2)
		{
			DistToNearestFort2 = ThisFortDist;
			NearestFort2 = F;
		}
	}
	return DistToNearestFort;
}

// =============================================================================
// DistanceFrom - Returns the distance between 2 actors
// =============================================================================
function float DistanceFrom(Actor P1, Actor P2)
{

	local float DistanceX, DistanceY, DistanceZ, ADistance;

	DistanceX = P1.Location.X - P2.Location.X;
	DistanceY = P1.Location.Y - P2.Location.Y;
	DistanceZ = P1.Location.Z - P2.Location.Z;

	ADistance = sqrt(Square(DistanceX) + Square(DistanceY) + Square(DistanceZ));

	return ADistance;
}
// =============================================================================
// DistanceFromLocation - Returns the distance an actor and a vector location
// =============================================================================
function float DistanceFromLocation(Actor P1, vector Location)
{
 	local float DistanceX, DistanceY, DistanceZ, ADistance;

	DistanceX = P1.Location.X - Location.X;
	DistanceY = P1.Location.Y - Location.Y;
	DistanceZ = P1.Location.Z - Location.Z;

	ADistance = sqrt(Square(DistanceX) + Square(DistanceY) + Square(DistanceZ));

	return ADistance;
}

// =============================================================================
// GetFortName
// =============================================================================
function string GetFortName(FortStandard F)
{
	if ((F.FortName == "Assault Target") || (F.FortName == "") || (F.FortName == " "))
		return (string(F));
	else
		return F.FortName;
}

function LogSpecialEvent(string EventType, optional coerce string Arg1, optional coerce string Arg2, optional coerce string Arg3, optional coerce string Arg4)
{
	if(Level.Game.LocalLog != None)
	{
		LogSpecialEventString(EventType, Arg1, Arg2, Arg3, Arg4);
		//Level.Game.LocalLog.LogSpecialEvent(EventType, Arg1, Arg2, Arg3, Arg4);
	}
}

function LogSpecialEventString(string EventType, optional coerce string Arg1, optional coerce string Arg2, optional coerce string Arg3, optional coerce string Arg4)
{
	local string Event;
	event = EventType;
	if (Arg1 != "")
		event = Event$Chr(9)$Arg1;
	if (Arg2 != "")
		Event = Event$Chr(9)$Arg2;
	if (Arg3 != "")
		Event = Event$Chr(9)$Arg3;
	if (Arg4 != "")
		Event = Event$Chr(9)$Arg4;
	Level.Game.LocalLog.LogEventString(Level.Game.LocalLog.GetTimeStamp()$Chr(9)$Event);
}
// =============================================================================
// ParseToArray - Splits a string by its delimiter into an array (max number of
//  items are defined in the function as an output. This must match the target
//  variable length.
// =============================================================================
function ParseToArray(string InputString, string Delimiter, out string SplitOutput[16])
{
	local int i;
	local int row;

	i = InStr(InputString, Delimiter);
	while (i >= 0)
	{
		SplitOutput[row] = Left(InputString, i);
		InputString = Mid(InputString, i+1);
		i = InStr(InputString, Delimiter);
		row++;
	}
	if (row < 16)
		SplitOutput[row] = InputString;

	if (row<(16-1))
		SplitOutput[row+1] = "";
}



defaultproperties
{
     bEnabled=True
     gRedTeam="RED"
     gBlueTeam="BLUE"
     SmartASVersion="1.01m"
     AssistArea=1000
     AssistTimeOut=5
     DebugName="debug"
     bGenerateNewCode=False
     MapSpots=32 // align with defined array counts
     HiValueHLSpots(0)="AS-Siege][,140,260;0,0,500;" // e.g. 4/5-hammer launching from middle tower
     LoValueHLSpots(0)="AS-Siege][,300,60;250,-250,25;-250,-250,25;" // e.g. hammer launching into middle tower
}
