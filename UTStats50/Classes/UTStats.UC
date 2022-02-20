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
var() config bool bEnabled;
var() config bool bDebug;
var() config bool bForceIPCheck;
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
var PlayerInfo PInfo[33];
var UTStatsAH UTSAH;
var UTStatsHTTPClient UTSHTTP;

function LogStandardInfo ()
{
  local int i;
  local Mutator zzMutator;
  local bool bInsta;

  // Setup the buffer
  zzBuffer = "";

  // Setup the Pi structs
  for (i=0;i<32;++i)
  {
    PInfo[i].zzID = -1;
  }

  // Setup the zzCombo array
  zzComboCode[0] = "spree_dbl";
  zzComboCode[1] = "spree_mult";
  zzComboCode[2] = "spree_ult";
  zzComboCode[3] = "spree_mon";

  Log("### ___________________________________",'UTStats');
  Log("###                                    ",'UTStats');
  Log("###     # # ### ### ###  #  ### ###    ",'UTStats');
  Log("###     # #  #  #    #  # #  #  #      ",'UTStats');
  Log("###     # #  #  ###  #  # #  #  ###    ",'UTStats');
  Log("###     # #  #    #  #  ###  #    #    ",'UTStats');
  Log("###     ###  #  ###  #  # #  #  ###    ",'UTStats');
  Log("### ___________________________________",'UTStats');
  Log("###",'UTStats');
  Log("### - Version : " $ zzVersion,'UTStats');
  Log("### ___________________________________",'UTStats');
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
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "utglenabled" $ Chr(9) $ string(False));
  // Check for insta
  foreach AllActors(class'Mutator',zzMutator)
  {
     if (zzMutator.IsA('InstaGibDM'))
        bInsta = true;
  }

  UTSDM.bInsta = bInsta;

  LogEventString(GetTimeStamp() $ Chr(9) $ "game" $ Chr(9) $ "insta" $ Chr(9) $ string(bInsta));
  if (UTSHTTP == None)
    UTSHTTP = Spawn(Class'UTStatsHTTPClient',self);
  UTSHTTP.UTS = self;
  UTSHTTP.bDebug = bDebug;
  UTSHTTP.bForceCheck = bForceIPCheck;
  UTSHTTP.GetServerIP();
}

function LogIP (string zzMyIP)
{
  LogEventString(GetTimeStamp() $ Chr(9) $ "info" $ Chr(9) $ "True_Server_IP" $ Chr(9) $ zzMyIP);
  if (UTSHTTP != None)
    UTSHTTP.Destroy();
}
// =============================================================================
// LogPlayerInfo ~ Called right after a player connects
// =============================================================================
function LogPlayerInfo (Pawn Player)
{
  local int i;

  Super.LogPlayerInfo(Player);

  // Setup a playerinfo struct for this player
  for (i=0;i<32;++i)
  {
    if (PInfo[i].zzID == -1) // This slot is free
      break;
  }

  PInfo[i].zzID = Player.PlayerReplicationInfo.PlayerID;
  PInfo[i].zzPawn = Player;
  PInfo[i].zzSpree = 0;
  PInfo[i].zzCombo = 1;
  PInfo[i].zzKills = 0;
  PInfo[i].zzDeaths = 0;
  PInfo[i].zzSuicides = 0;
  PInfo[i].zzTeamKills = 0;
  PInfo[i].zzLastKill = 0.0;
  PInfo[i].zzEndTime = 0.0;
  PInfo[i].zzJoinTime = Level.TimeSeconds;
  PInfo[i].bHasFlag = False;
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
  
  PInfo[zzKillerID].zzKills++;
  PInfo[zzVictimID].zzDeaths++;
  
  if ( !bFirstBlood )
  {
    LogEventString(GetTimeStamp() $ Chr(9) $ "first_blood" $ Chr(9) $ string(KillerID));
    bFirstBlood = True;
  }
  
  LogSpree(zzKillerID,zzVictimID);
  LogCombo(zzKillerID);
  
  if ( PInfo[zzVictimID].bHasFlag )
  {
    LogEventString(GetTimeStamp() $ Chr(9) $ "flag_kill" $ Chr(9) $ string(KillerID));
    PInfo[zzVictimID].bHasFlag = False;
  }
  
  if (UTSDM != None)
  {
    // Perform a backwards call to reach LogKillDetail
    UTSDM.GetAttributableDamage(VictimID);
  }
}
// =============================================================================
// LogKillDetail ~ Calls backwards from UTSReplicationInfo > UTSDamageMut > this
// =============================================================================
function LogKillDetail (int VictimPID, int InstigatorPID, string zzInstigatorWeapon, int zzInstigatorDamage, int zzActualDamage, float zzLastWeaponHit, float zzLastHit, int zzVictimArmour, int zzVictimHealth, int zzVPreArmour, int zzVPreHealth)
{
  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }
  LogEventString(GetTimeStamp() $ Chr(9) $ "damage_tracker" $ Chr(9) $ string(VictimPID) $ Chr(9) $ string(InstigatorPID) $ Chr(9) $ zzInstigatorWeapon $ Chr(9) $ string(zzInstigatorDamage) $ Chr(9) $ string(zzActualDamage) $ Chr(9) $ string(zzLastWeaponHit) $ Chr(9) $ string(zzLastHit) $ Chr(9) $ string(zzVictimArmour) $ Chr(9) $ string(zzVictimHealth) $ Chr(9) $ string(zzVPreArmour) $ Chr(9) $ string(zzVPreHealth));
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
    PInfo[KillerID].zzSpree++;
  }
  i = PInfo[VictimID].zzSpree;
  PInfo[VictimID].zzSpree = 0;

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

  LogEventString(GetTimeStamp() $ Chr(9) $ "spree" $ Chr(9) $ Spree $ Chr(9) $ string(PInfo[VictimID].zzID));
}

// =============================================================================
// LogCombo ~ Handle combos
// Note: combos get logged when they end.
// =============================================================================
function LogCombo (int KillerID, optional bool bEndGame,optional bool bDisconnect)
{
   local float zzNow;

   if (bEndGame)
    zzNow = zzEndTime;
   else if (bDisconnect)
    zzNow = PInfo[KillerID].zzEndTime;
   else
    zzNow = Level.TimeSeconds;

   if (zzNow - PInfo[KillerID].zzLastKill < 3.0)
   {
    if ((bEndGame || bDisconnect) && (PInfo[KillerID].zzCombo > 1))  // Combo was still going on when player disconnected
      LogEventString(GetTimeStamp()$chr(9)$"spree"$chr(9)$zzComboCode[Clamp(PInfo[KillerID].zzCombo-2,0,3)]$chr(9)$PInfo[KillerID].zzID);
    else
      PInfo[KillerID].zzCombo++;
   }
   else
   {
    if (PInfo[KillerID].zzCombo > 1)
      LogEventString(GetTimeStamp()$chr(9)$"spree"$chr(9)$zzComboCode[Clamp(PInfo[KillerID].zzCombo-2,0,3)]$chr(9)$PInfo[KillerID].zzID);
    PInfo[KillerID].zzCombo = 1;
   }

   PInfo[KillerID].zzLastKill = zzNow;
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

  PInfo[zzKillerID].zzTeamKills++;
  PInfo[zzVictimID].zzDeaths++;

  super.LogTeamKill(KillerID,VictimID,KillerWeaponName,VictimWeaponName,DamageType);

  if (PInfo[zzVictimID].bHasFlag)
    PInfo[zzVictimID].bHasFlag = false;

  if (UTSDM != None)
  {
    UTSDM.GetAttributableDamage(VictimID);
  }
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

  PInfo[zzKilled].zzSuicides++;

  super.LogSuicide(Killed,DamageType,Instigator);

  if (PInfo[zzKilled].bHasFlag)
    PInfo[zzKilled].bHasFlag = false;

  if (UTSDM != None)
  {
    UTSDM.GetAttributableDamage(zzKilled);
  }
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
  
  PInfo[i].zzEndTime = Level.TimeSeconds;
  
  if (  !bGameStarted &&  !GameStarted() )
  {
    return;
  }
  
  LogSpree(33,i);
  LogCombo(i,,True);

  if (UTSDM != None)
  {
    UTSDM.GetAttributableDamage(i);
  }
  
  AddToBuffer(i);
  
  PInfo[i].zzID = -1;
}
// =============================================================================
// LogSpecialEvent ~ Any gametype-specific event goes trough this function
// Note: we don't log translocation events as it's a lot of spam and it's not
// usefull at all
// =============================================================================
function LogSpecialEvent (string EventType, optional coerce string Arg1, optional coerce string Arg2, optional coerce string Arg3, optional coerce string Arg4)
{
  local int i;

  if ( (InStr(EventType,"transloc") != -1) || (InStr(EventType,"dom_") != -1) && (Level.Game.NumPlayers == 0) )
  {
    if ( EventType == "translocate" )
    {
      i = GetID(int(Arg1));
      PInfo[i].bHasFlag = False;
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

    PInfo[i].bHasFlag = true;
  }
  else if (EventType=="flag_captured")
  {
    i = GetID(int(Arg1));

    PInfo[i].bHasFlag = false;
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
     if (PInfo[i].zzID != -1) // Player is still on the server
     {
      LogSpree(33,i);
      LogCombo(i,true);
      AddToBuffer(i);
      PInfo[i].zzID = -1;
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

  if ( PInfo[zzPlayerID].zzPawn == None )
  {
    return;
  }
  
  zzRI = UTSDM.GetRI(PInfo[zzPlayerID].zzPawn.PlayerReplicationInfo);
  
  if ( zzRI == None )
  {
    return;
  }

  zzAccuracy = UTSDM.GetAccuracy(PInfo[zzPlayerID].zzPawn.PlayerReplicationInfo);

  zzTimeOnServer = Min(Level.TimeSeconds-PInfo[zzPlayerID].zzJoinTime,Level.TimeSeconds-zzWarmupTime);

  if ( PInfo[zzPlayerID].zzDeaths != 0 )
  {
    zzTTL = zzTimeOnServer / PInfo[zzPlayerID].zzDeaths;
  }
  else
  {
    zzTTL = zzTimeOnServer;  
  }
  
  if ((PInfo[zzPlayerID].zzKills+PInfo[zzPlayerID].zzDeaths+PInfo[zzPlayerID].zzSuicides+PInfo[zzPlayerID].zzTeamKills) == 0)
  {
    zzEfficiency = 0.0;
  }
  else
  {
    zzEfficiency = float(PInfo[zzPlayerID].zzKills)/float(PInfo[zzPlayerID].zzKills+PInfo[zzPlayerID].zzDeaths+PInfo[zzPlayerID].zzSuicides+PInfo[zzPlayerID].zzTeamKills)*100.0;
  }
  

  BufferLog("stat_player","accuracy",PInfo[zzPlayerID].zzID,string(zzAccuracy));
  BufferLog("stat_player","score",PInfo[zzPlayerID].zzID,string(int(PInfo[zzPlayerID].zzPawn.PlayerReplicationInfo.Score)));
  BufferLog("stat_player","frags",PInfo[zzPlayerID].zzID,string(PInfo[zzPlayerID].zzKills - PInfo[zzPlayerID].zzSuicides));
  BufferLog("stat_player","kills",PInfo[zzPlayerID].zzID,string(PInfo[zzPlayerID].zzKills));
  BufferLog("stat_player","deaths",PInfo[zzPlayerID].zzID,string(PInfo[zzPlayerID].zzDeaths));
  BufferLog("stat_player","suicides",PInfo[zzPlayerID].zzID,string(PInfo[zzPlayerID].zzSuicides));
  BufferLog("stat_player","teamkills",PInfo[zzPlayerID].zzID,string(PInfo[zzPlayerID].zzTeamKills));
  BufferLog("stat_player","efficiency",PInfo[zzPlayerID].zzID,string(zzEfficiency));
  BufferLog("stat_player","time_on_server",PInfo[zzPlayerID].zzID,string(Level.TimeSeconds-PInfo[zzPlayerID].zzJoinTime));
  BufferLog("stat_player","ttl",PInfo[zzPlayerID].zzID,string(zzTTL));

  for (i=0;i<zzRI.zzIndex;++i)
  {
    if (!(zzRI.GetWeaponName(i) ~= "translocator"))
    {
      BufferLog("weap_shotcount",zzRI.GetWeaponName(i),PInfo[zzPlayerID].zzID,string(zzRI.GetShotCount(i)));
      BufferLog("weap_hitcount",zzRI.GetWeaponName(i),PInfo[zzPlayerID].zzID,string(zzRI.GetHitCount(i)));
      BufferLog("weap_damagegiven",zzRI.GetWeaponName(i),PInfo[zzPlayerID].zzID,string(zzRI.GetDamage(i)));
      BufferLog("weap_accuracy",zzRI.GetWeaponName(i),PInfo[zzPlayerID].zzID,string(zzRI.GetAccu(i)));
    }
  }

  zzRI.bDeleteObj = true;
}

function BufferLog ( string zzTag, string zzType, int zzPlayerID, string zzValue )
{
   zzBuffer = zzBuffer$":::"$zzTag$chr(9)$zzType$chr(9)$string(zzPlayerID)$chr(9)$zzValue;
}

function ProcessBuffer () // This will cause extreme cpu usage on the server for a sec :)
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
     if (PInfo[i].zzID == PID)
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
    bDebug=False
    zzVersion="5.0"
}
