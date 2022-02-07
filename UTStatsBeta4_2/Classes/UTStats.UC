//================================================================================
// UTStats.
//================================================================================

class UTStats extends StatLogFile;

struct PlayerInfo
{
  var Pawn zzPawn;
  var int zzID,zzSpree,zzCombo,zzKills,zzDeaths,zzSuicides,zzTeamKills;
  var float zzLastKill, zzEndTime, zzJoinTime;
  var bool bHasFlag;
  var string zzLogin,zzIP;
};
//var config bool bUTGLEnabled;
var config bool bEnabled;
var bool bFirstBlood;
var bool bGameStarted;
var string zzComboCode[4];
var string zzBuffer;
var string zzVersion;
var string zzMutatorList;
var float zzEndTime;
var float zzWarmupTime;
var int CurrentID;
var int zzPHPos;
var UTSDamageMut UTSDM;
var PlayerInfo Pi[33];
var UTStatsAH UTSAH;

function LogStandardInfo ()
{
  local UTStatsHTTPClient UTSHTTP;
  local int i;
  local Mutator zzMutator;
  local bool bInsta;
  // Tag our actor to receive UTGL calls
  //Tag='UTGLCatcher'; // Removed for 'a' and 'b' versions
  // Setup the buffer
  zzBuffer = "";

  // Setup the Pi structs
  for (i=0;i<32;++i)
  {
    Pi[i].zzID = -1;
  }

  // Setup the zzCombo array
  zzComboCode[0] = "spree_dbl";
  zzComboCode[1] = "spree_mult";
  zzComboCode[2] = "spree_ult";
  zzComboCode[3] = "spree_mon";

  // Check the serveractors list
  //zzServerActors = Level.ConsoleCommand("get Engine.GameEngine ServerActors");
  //if (InStr(CAPS(zzServerActors),"GLACTOR") != -1)
  //  bUTGLEnabled = true;

  Log("### ___________________________________");
  Log("###                                    ");
  Log("###     # # ### ### ###  #  ### ###    ");
  Log("###     # #  #  #    #  # #  #  #      ");
  Log("###     # #  #  ###  #  # #  #  ###    ");
  Log("###     # #  #    #  #  ###  #    #    ");
  Log("###     ###  #  ###  #  # #  #  ###    ");
  Log("### ___________________________________");
  Log("###");
  Log("### - Version      : " $ zzVersion);
  //Log("### - UTGL Running :"@bUTGLEnabled);
  Log("### ___________________________________");
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "Log_Standard" $ Chr(9) $ "UTStats");
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "Log_Version" $ Chr(9) $ zzVersion);
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "Game_Name" $ Chr(9) $ GameName);
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "Game_Version" $ Chr(9) $ Level.EngineVersion);
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "Absolute_Time" $ Chr(9) $ GetAbsoluteTime());
  if ( bWorld )
  {
    if ( Level.ConsoleCommand("get UdpServerUplink douplink") ~= string(True) )
    {
      LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "Server_Public" $ Chr(9) $ "1");
    } else {
      LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "Server_Public" $ Chr(9) $ "0");
    }
  }
  //LogEventString(GetTimeStamp()$Chr(9)$"info"$Chr(9)$"utglenabled"$Chr(9)$string(bUTGLEnabled));
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "utglenabled" $ Chr(9) $ string(False));
  // Check for insta
  foreach AllActors(class'Mutator',zzMutator)
  {
     if (zzMutator.IsA('InstaGibDM'))
        bInsta = true;
  }

  UTSDM.bInsta = bInsta;

  LogEventString(GetTimeStamp() $ Chr(9) $ "game" $ Chr(9) $ "insta" $ Chr(9) $ string(bInsta));

  UTSHTTP = Spawn(Class'UTStatsHTTPClient');
  //UTSHTTP.Browse("212.42.16.16","/myip.php",80,10);
  LogIP(IPOnly(UTSHTTP.GetIP()));
  UTSHTTP.Destroy();
}

function LogIP (string zzMyIP)
{
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "True_Server_IP" $ Chr(9) $ zzMyIP);
}

// =============================================================================
// LogPlayerInfo ~ Called right after a player connects
// =============================================================================
function LogPlayerInfo (Pawn Player)
{
  local int i,j;

  Super.LogPlayerInfo(Player);

  // Setup a playerinfo struct for this player
  for (i=0;i<32;++i)
  {
    if (Pi[i].zzID == -1) // This slot is free
      break;
  }

  Pi[i].zzID = Player.PlayerReplicationInfo.PlayerID;
  Pi[i].zzPawn = Player;
  Pi[i].zzSpree = 0;
  Pi[i].zzCombo = 1;
  Pi[i].zzKills = 0;
  Pi[i].zzDeaths = 0;
  Pi[i].zzSuicides = 0;
  Pi[i].zzTeamKills = 0;
  Pi[i].zzLastKill = 0.0;
  Pi[i].zzEndTime = 0.0;
  Pi[i].zzJoinTime = Level.TimeSeconds;
  Pi[i].bHasFlag = False;
}

// =============================================================================
// LogKill ~ Called for each killevent
// =============================================================================
function LogKill (int KillerID, int VictimID, string KillerWeaponName, string VictimWeaponName, name DamageType)
{
  local int zzKillerID,zzVictimID;

  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }

  zzKillerID = GetID(KillerID);
  zzVictimID = GetID(VictimID);

  LogEventString(GetTimeStamp() $ Chr(9) $ "kill" $ Chr(9) $ string(KillerID) $ Chr(9) $ KillerWeaponName $ Chr(9) $ string(VictimID) $ Chr(9) $ VictimWeaponName $ Chr(9) $ string(DamageType));
  
  Pi[zzKillerID].zzKills++;
  Pi[zzVictimID].zzDeaths++;
  
  if ( !bFirstBlood )
  {
    LogEventString(GetTimeStamp() $ Chr(9) $ "first_blood" $ Chr(9) $ string(KillerID));
    bFirstBlood = True;
  }
  
  LogSpree(zzKillerID,zzVictimID);
  LogCombo(zzKillerID);
  
  if ( Pi[zzVictimID].bHasFlag )
  {
    LogEventString(GetTimeStamp() $ Chr(9) $ "flag_kill" $ Chr(9) $ string(KillerID));
    Pi[zzVictimID].bHasFlag = False;
  }
}

// =============================================================================
// LogSpree ~ Handle killing sprees
// Note: killing sprees get logged when they end. If someone has a killing spree
// at the end of the game or while he disconnects, this function gets called
// with KillerID 33
// =============================================================================
function LogSpree (int KillerID, int VictimID)
{
  local int i;
  local string Spree;

  if ( KillerID != 33 )
  {
    Pi[KillerID].zzSpree++;
  }
  i = Pi[VictimID].zzSpree;
  Pi[VictimID].zzSpree = 0;

  if (i < 5) // No Spree
    return;
   else if (i<10)
    spree = "spree_kill";
   else if (i<15)
    spree = "spree_rampage";
   else if (i<20)
    spree = "spree_dom";
   else if (i<25)
    spree = "spree_uns";
   else
    spree = "spree_god";

  LogEventString(GetTimeStamp() $ Chr(9) $ "spree" $ Chr(9) $ Spree $ Chr(9) $ string(Pi[VictimID].zzID));
}

// =============================================================================
// LogCombo ~ Handle combos
// Note: combos get logged when they end.
// =============================================================================
function LogCombo (int KillerID, optional bool bEndGame,optional bool bDisconnect)
{
   local float zzNow;
   local int i;
   local string spree;

   if (bEndGame)
    zzNow = zzEndTime;
   else if (bDisconnect)
    zzNow = Pi[KillerID].zzEndTime;
   else
    zzNow = Level.TimeSeconds;

   if (zzNow - Pi[KillerID].zzLastKill < 3.0)
   {
    if ((bEndGame || bDisconnect) && (Pi[KillerID].zzCombo > 1))  // Combo was still going on when player disconnected
      LogEventString(GetTimeStamp()$chr(9)$"spree"$chr(9)$zzComboCode[Clamp(Pi[KillerID].zzCombo-2,0,3)]$chr(9)$Pi[KillerID].zzID);
    else
      Pi[KillerID].zzCombo++;
   }
   else
   {
    if (Pi[KillerID].zzCombo > 1)
      LogEventString(GetTimeStamp()$chr(9)$"spree"$chr(9)$zzComboCode[Clamp(Pi[KillerID].zzCombo-2,0,3)]$chr(9)$Pi[KillerID].zzID);
    Pi[KillerID].zzCombo = 1;
   }

   Pi[KillerID].zzLastKill = zzNow;
}

// =============================================================================
// LogTeamKill ~ :/
// =============================================================================

function LogTeamKill( int KillerID, int VictimID, string KillerWeaponName, string VictimWeaponName, name DamageType )
{
  local int zzKillerID, zzVictimID;

  if (!Level.Game.IsA('TeamGamePlus'))
  {
     LogKill(KillerID,VictimID,KillerWeaponName,VictimWeaponName,DamageType);
     return;
  }

  if (!bGameStarted && !GameStarted())
    return;

  zzKillerID = GetID(KillerID);
  zzVictimID = GetID(VictimID);

  Pi[zzKillerID].zzTeamKills++;
  Pi[zzVictimID].zzDeaths++;

  super.LogTeamKill(KillerID,VictimID,KillerWeaponName,VictimWeaponName,DamageType);

  if (Pi[zzVictimID].bHasFlag)
    Pi[zzVictimID].bHasFlag = false;
}

// =============================================================================
// LogSuicide
// =============================================================================
function LogSuicide (Pawn Killed, name DamageType, Pawn Instigator)
{
  local int zzKilled;

  if (!bGameStarted && !GameStarted())
    return;

  zzKilled = GetID(Killed.PlayerReplicationInfo.PlayerID);

  Pi[zzKilled].zzSuicides++;

  super.LogSuicide(Killed,DamageType,Instigator);

  if (Pi[zzKilled].bHasFlag)
    Pi[zzKilled].bHasFlag = false;
}

// =============================================================================
// LogPlayerConnect ~ We don't like spectators
// =============================================================================

function LogPlayerConnect(Pawn Player, optional string Checksum)
{
   if (Player.IsA('Spectator'))
      return;

   //Cratos:
   if (Player.IsA('TournamentPlayer')) Player.PlayerReplicationInfo.bIsABot = false;

   super.LogPlayerConnect(Player,Checksum);
}

// =============================================================================
// LogPlayerDisconnect ~ Handle sprees/combos, then add to the buffer
// =============================================================================
function LogPlayerDisconnect (Pawn Player)
{
  local int i;

  if ( Player.IsA('Spectator') )
  {
    return;
  }

  i = GetID(Player.PlayerReplicationInfo.PlayerID);
  
  LogEventString(GetTimeStamp() $ Chr(9) $ "player" $ Chr(9) $ "Disconnect" $ Chr(9) $ string(Player.PlayerReplicationInfo.PlayerID));
  
  Pi[i].zzEndTime = Level.TimeSeconds;
  
  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }
  
  LogSpree(33,i);
  LogCombo(i,,True);
  
  AddToBuffer(i);
  
  Pi[i].zzID = -1;
}
// =============================================================================
// LogSpecialEvent ~ Any gametype-specific event goes trough this function
// Note: we don't log translocation events as it's a lot of spam and it's not
// usefull at all
// =============================================================================
function LogSpecialEvent (string EventType, optional coerce string Arg1, optional coerce string Arg2, optional coerce string Arg3, optional coerce string Arg4)
{
  local int i;
  local string Event;

  if ( (InStr(EventType,"transloc") != -1) || (InStr(EventType,"dom_") != -1) && (Level.Game.NumPlayers == 0) )
  {
    if ( EventType == "translocate" )
    {
      i = GetID(int(Arg1));
      Pi[i].bHasFlag = False;
    }
  } else {
    Super.LogSpecialEvent(EventType,Arg1,Arg2,Arg3,Arg4);
  }
  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }
  if (EventType=="flag_taken" || EventType=="flag_pickedup")
  {
    i = GetID(int(Arg1));

    Pi[i].bHasFlag = true;
  }
  else if (EventType=="flag_captured")
  {
    i = GetID(int(Arg1));

    Pi[i].bHasFlag = false;
  }
}
// =============================================================================
// We're using the tick function to set IP's
// =============================================================================
function Tick (float DeltaTime)
{
  local pawn NewPawn;

  super.Tick(DeltaTime);

  if (Level.Game.CurrentID > currentID)
  {
     for( NewPawn = Level.PawnList ; NewPawn!=None ; NewPawn = NewPawn.NextPawn )
     {
        if(NewPawn.bIsPlayer && NewPawn.PlayerReplicationInfo.PlayerID == currentID)
        {
             SetIP(NewPawn);
         break;
        }
     }
     ++currentID;
  }
}

function SetIP (Pawn Player)
{
  local string zzIP;
  local int i,j;
  local bool bReconnected;

  if ( Player.IsA('PlayerPawn') )
  {
    zzIP = PlayerPawn(Player).GetPlayerNetworkAddress();
  }
  else
  {
    zzIP = "0.0.0.0";
  }

  zzIP = IPOnly(zzIP);

  LogEventString(GetTimeStamp() $ Chr(9) $ "player" $ Chr(9) $ "IP" $ Chr(9) $ string(Player.PlayerReplicationInfo.PlayerID) $ Chr(9) $ zzIP);
}

function string IPOnly (string zzIP)
{
   if (InStr(zzIP,":") != -1)
      zzIP = Left(zzIP,InStr(zzIP,":"));

   return zzIP;
}

// =============================================================================
// Game Start/End functions
// =============================================================================
function LogGameStart ()
{
  LogEventString(GetTimeStamp() $ Chr(9) $ "game_start");
  if ( Level.Game.IsA('Assault') )
  {
    DeathMatchPlus(Level.Game).CountDown = 0;
  }
  GameStarted();
}

function LogGameEnd (string Reason)
{
  local int i;

  zzEndTime = Level.TimeSeconds;
  if ( (UTSAH != None) && (Reason == "Assault succeeded!") )
  {
    UTSAH.bEndGame = True;
    UTSAH.ClientMessage("",'CriticalEvent');
  }
  Super.LogGameEnd(Reason);

   for (i=0;i<32;++i)
   {
     if (Pi[i].zzID != -1) // Player is still on the server
     {
      LogSpree(33,i);
      LogCombo(i,true);
      AddToBuffer(i);
      Pi[i].zzID = -1;
     }
   }

  ProcessBuffer();
}

// =============================================================================
// Some lame code here. We want UTStats to log all playerstats at the end of the
// game, not during the game. That's why we'll use a buffer.
// =============================================================================
function AddToBuffer (int zzPlayerID)
{
  local float zzAccuracy;
  local float zzEfficiency;
  local float zzTTL;
  local float zzTimeOnServer;
  local UTSReplicationInfo zzRI;
  local int i;

  if ( Pi[zzPlayerID].zzPawn == None )
  {
    return;
  }
  
  zzRI = UTSDM.GetRI(Pi[zzPlayerID].zzPawn.PlayerReplicationInfo);
  
  if ( zzRI == None )
  {
    return;
  }

  zzAccuracy = UTSDM.GetAccuracy(PI[zzPlayerID].zzPawn.PlayerReplicationInfo);

  zzTimeOnServer = Min(Level.TimeSeconds-PI[zzPlayerID].zzJoinTime,Level.TimeSeconds-zzWarmupTime);

  if ( Pi[zzPlayerID].zzDeaths != 0 )
  {
    zzTTL = zzTimeOnServer / Pi[zzPlayerID].zzDeaths;
  }
  else
  {
    zzTTL = zzTimeOnServer;  
  }
  
  if ((PI[zzPlayerID].zzKills+PI[zzPlayerID].zzDeaths+PI[zzPlayerID].zzSuicides+PI[zzPlayerID].zzTeamKills) == 0)
  {
    zzEfficiency = 0.0;
  }
  else
  {
    zzEfficiency = float(PI[zzPlayerID].zzKills)/float(PI[zzPlayerID].zzKills+PI[zzPlayerID].zzDeaths+PI[zzPlayerID].zzSuicides+PI[zzPlayerID].zzTeamKills)*100.0;
  }
  

  BufferLog("stat_player","accuracy",PI[zzPlayerID].zzID,string(zzAccuracy));
  BufferLog("stat_player","score",PI[zzPlayerID].zzID,string(int(PI[zzPlayerID].zzPawn.PlayerReplicationInfo.Score)));
  BufferLog("stat_player","frags",PI[zzPlayerID].zzID,string(PI[zzPlayerID].zzKills - PI[zzPlayerID].zzSuicides));
  BufferLog("stat_player","kills",PI[zzPlayerID].zzID,string(PI[zzPlayerID].zzKills));
  BufferLog("stat_player","deaths",PI[zzPlayerID].zzID,string(PI[zzPlayerID].zzDeaths));
  BufferLog("stat_player","suicides",PI[zzPlayerID].zzID,string(PI[zzPlayerID].zzSuicides));
  BufferLog("stat_player","teamkills",PI[zzPlayerID].zzID,string(PI[zzPlayerID].zzTeamKills));
  BufferLog("stat_player","efficiency",PI[zzPlayerID].zzID,string(zzEfficiency));
  BufferLog("stat_player","time_on_server",PI[zzPlayerID].zzID,string(Level.TimeSeconds-PI[zzPlayerID].zzJoinTime));
  BufferLog("stat_player","ttl",PI[zzPlayerID].zzID,string(zzTTL));

  for (i=0;i<zzRI.zzIndex;++i)
  {
    if (!(zzRI.GetWeaponName(i) ~= "translocator"))
    {
      BufferLog("weap_shotcount",zzRI.GetWeaponName(i),PI[zzPlayerID].zzID,string(zzRI.GetShotCount(i)));
      BufferLog("weap_hitcount",zzRI.GetWeaponName(i),PI[zzPlayerID].zzID,string(zzRI.GetHitCount(i)));
      BufferLog("weap_damagegiven",zzRI.GetWeaponName(i),PI[zzPlayerID].zzID,string(zzRI.GetDamage(i)));
      BufferLog("weap_accuracy",zzRI.GetWeaponName(i),PI[zzPlayerID].zzID,string(zzRI.GetAccu(i)));
    }
  }

  zzRI.bDeleteObj = true;
}

function BufferLog ( string zzTag, string zzType, int zzPlayerID, string zzValue )
{
   zzBuffer = zzBuffer$":::"$zzTag$chr(9)$zzType$chr(9)$string(zzPlayerID)$chr(9)$zzValue;
}

function ProcessBuffer ();

function zzProcessBuffer () // This will cause extreme cpu usage on the server for a sec :)
{
   local int index,i;

   while (InStr(zzBuffer,":::") != -1)
   {
      index = InStr(zzBuffer,":::");

      LogEventString(GetTimeStamp()$chr(9)$Left(zzBuffer,index));
      zzBuffer = Mid(zzBuffer,index+3);
   }

   LogEventString(GetTimeStamp()$chr(9)$zzBuffer);

   if (Level.Game.IsA('TeamGamePlus')) // Requested by the php-coders :o
   {
      for (i=0;i<TeamGamePlus(Level.Game).MaxTeams;++i)
      {
        LogEventString(GetTimeStamp()$chr(9)$"teamscore"$chr(9)$string(i)$chr(9)$string(int(TeamGamePlus(Level.Game).Teams[i].Score)));
      }
   }
}

// =============================================================================
// Functions used to get the offset in the PI array
// =============================================================================
function int GetID (int PID)
{
   local int i;

   for (i=0;i<32;++i)
   {
     if (PI[i].zzID == PID)
      return i;
   }

   return -1;
}

// =============================================================================
// Assault support. function called by the UTStatsSA.
// =============================================================================

function LogAssaultObj (bool bFinalObj, int zzPID, int zzFortID)
{
  LogEventString(GetTimeStamp() $ Chr(9) $ "assault_obj" $ Chr(9) $ string(zzPID) $ Chr(9) $ string(bFinalObj) $ Chr(9) $ string(zzFortID));
}

// =============================================================================
// Random lame functions that shouldn't be active in warmup mode
// =============================================================================
function LogPings ()
{
  local PlayerReplicationInfo PRI;

  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }
  if ( Level.Game.NumPlayers <= 0 )
  {
    return;  // <-- Cratos
  }
  foreach AllActors(Class'PlayerReplicationInfo',PRI)
  {
    if ( (PRI.Owner != None) && Pawn(PRI.Owner).bIsPlayer )  // <-- Cratos
    {
      LogEventString(GetTimeStamp() $ Chr(9) $ "player" $ Chr(9) $ "Ping" $ Chr(9) $ string(PRI.PlayerID) $ Chr(9) $ string(PRI.Ping));
      LogEventString(GetTimeStamp() $ Chr(9) $ "player" $ Chr(9) $ "Loss" $ Chr(9) $ string(PRI.PlayerID) $ Chr(9) $ string(PRI.PacketLoss));
    }
  }
}

function LogItemActivate (Inventory Item, Pawn Other)
{
  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }
  Super.LogItemActivate(Item,Other);
}

function LogItemDeactivate (Inventory Item, Pawn Other)
{
  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }
  Super.LogItemDeactivate(Item,Other);
}

function LogPickup (Inventory Item, Pawn Other)
{
  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }
  Super.LogPickup(Item,Other);
}

// =============================================================================
// Warmupmode
// =============================================================================
function bool GameStarted()
{
   if(DeathMatchPlus(Level.Game).bTournament && DeathMatchPlus(Level.Game).CountDown > 0)
      return false;
   else
   {
      if (!bGameStarted)
      {
        zzWarmupTime = Level.TimeSeconds;
        LogEventString(GetTimeStamp()$Chr(9)$"game"$chr(9)$"realstart");
      }

      bGameStarted = true;
      return true;
   }
}

// =============================================================================
// AddMutator ~ Add mutatorclass to our list
// =============================================================================
function AddMutator (Mutator M)
{
  zzMutatorList = zzMutatorList $ ":::" $ string(M.Class);
}
// =============================================================================
// LogMutatorList ~ Log the list
// =============================================================================
function LogMutatorList()
{
   local string zzEntry,zzDesc;
   local int zzNum;

   zzEntry = "(none)";

   while (zzEntry != "")
   {
      if ((InStr(CAPS(zzMutatorList),CAPS(zzEntry)) != -1) && zzDesc != "")
      {
        if (InStr(zzDesc,",") != -1)
           zzDesc = Left(zzDesc,InStr(zzDesc,","));
        LogEventString(GetTimeStamp()$chr(9)$"game"$chr(9)$"GoodMutator"$chr(9)$zzDesc);
      }
      GetNextIntDesc("Engine.Mutator",zzNum++,zzEntry,zzDesc);
   }
}

// =============================================================================
// Defaultproperties
// =============================================================================
defaultproperties
{
    bEnabled=True
    zzVersion="0.4.2b"
}
