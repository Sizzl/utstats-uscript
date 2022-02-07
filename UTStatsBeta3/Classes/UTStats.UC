class UTStats extends StatLogFile;

var bool bUTGLEnabled;
var bool bFirstBlood;
var bool bGameStarted;

var string zzComboCode[4];
var string zzBuffer;
var string zzVersion;
var string zzGLTag; // Set by UTGL!

var float zzEndTime;
var float zzWarmupTime;

var int currentid;
var int zzPHPos; // Position in the PlayerHistory Array

var UTSDamageMut UTSDM;

struct PlayerInfo
{
   var Pawn zzPawn;
   var int zzID,zzSpree,zzCombo,zzKills,zzDeaths,zzSuicides,zzTeamKills;
   var float zzLastKill, zzEndTime, zzJoinTime;
   var bool bHasFlag;
   var string zzLogin,zzIP;
};

var PlayerInfo PI[33];

var UTStatsAH UTSAH;

// =============================================================================
// Pregame functions
// =============================================================================

function LogStandardInfo()
{
   local UTStatsHTTPClient UTSHTTP;
   local int i;
   local string zzServerActors, zzUTGLVer;
   local mutator zzMutator;
   local bool bInsta;

   // Tag our actor to receive UTGL calls
   Tag='UTGLCatcher';

   // Setup the buffer
   zzBuffer = "";

   // Setup the PI structs
   for (i=0;i<32;++i)
       PI[i].zzID = -1;

   // Setup the zzCombo array
   zzComboCode[0] = "spree_dbl";
   zzComboCode[1] = "spree_mult";
   zzComboCode[2] = "spree_ult";
   zzComboCode[3] = "spree_mon";

   super.LogStandardInfo();

   // Check the serveractors list
   zzServerActors = Level.ConsoleCommand("get Engine.GameEngine ServerActors");

   if (InStr(CAPS(zzServerActors),"GLACTOR") != -1)
     bUTGLEnabled = true;

   Log("### ___________________________________");
   Log("###                                    ");
   Log("###     # # ### ### ###  #  ### ###    ");
   Log("###     # #  #  #    #  # #  #  #      ");
   Log("###     # #  #  ###  #  # #  #  ###    ");
   Log("###     # #  #    #  #  ###  #    #    ");
   Log("###     ###  #  ###  #  # #  #  ###    ");
   Log("###");
   Log("###         by Azazel & AnthraX        ");
   Log("### ___________________________________");
   Log("###");
   Log("### - Version   : "$zzVersion);
   Log("### - Settings  : ");
   Log("###    * UTGL Running     :"@bUTGLEnabled);
   Log("### ___________________________________");

   LogEventString(GetTimeStamp()$Chr(9)$"info"$Chr(9)$"utglenabled"$Chr(9)$string(bUTGLEnabled));

   // Check for insta
   foreach AllActors(class'Mutator',zzMutator)
   {
          if (zzMutator.IsA('InstaGibDM'))
          {
            bInsta = true;
          }
   }

   LogEventString(GetTimeStamp()$Chr(9)$"game"$Chr(9)$"insta"$chr(9)$string(bInsta));

   UTSHTTP = Spawn(class'UTStatsHTTPClient');
   UTSHTTP.UTS = Self;
   // Getting the ip of the host machine tends to fail quite often. That's why
   // we'll use this workaround.
   UTSHTTP.Browse("utstats.unrealadmin.org","/myip.php",80,10);
}

function LogIP (string zzMyIP)
{
   LogEventString(GetTimeStamp()$Chr(9)$"info"$Chr(9)$"True_Server_IP"$Chr(9)$zzMyIP);
}

// =============================================================================
// Stat functions
// =============================================================================

function LogPlayerInfo(Pawn Player)
{
   local int i,j;

   Super.LogPlayerInfo(Player);

   // Setup a playerinfo struct for this player
   for (i=0;i<32;++i)
   {
      if (PI[i].zzID == -1) // This slot is free
         break;
   }

   PI[i].zzID = Player.PlayerReplicationInfo.PlayerID;
   PI[i].zzPawn = Player;
   PI[i].zzSpree = 0;
   PI[i].zzCombo = 1;
   PI[i].zzKills = 0;
   PI[i].zzDeaths = 0;
   PI[i].zzSuicides = 0;
   PI[i].zzTeamKills = 0;
   PI[i].zzLastKill = 0.0;
   PI[i].zzEndTime = 0.0;
   PI[i].zzJoinTime = Level.TimeSeconds;
   PI[i].bHasFlag = false;
}

function LogKill( int KillerID, int VictimID, string KillerWeaponName, string VictimWeaponName, name DamageType )
{
    local int zzKillerID,zzVictimID;

    if (!bGameStarted && !GameStarted())
      return;

    zzKillerID = GetID(KillerID);
    zzVictimID = GetID(VictimID);

    LogEventString(GetTimeStamp()$Chr(9)$"kill"$Chr(9)$KillerID$Chr(9)$KillerWeaponName$Chr(9)$VictimID$Chr(9)$VictimWeaponName$Chr(9)$DamageType);

    PI[zzKillerID].zzKills++;
    PI[zzVictimID].zzDeaths++;

    // ========================= FIRSTBLOOD CODE =========================
    if (!bFirstBlood)
    {
      LogEventString(GetTimeStamp()$chr(9)$"first_blood"$chr(9)$KillerID);
      bFirstBlood = true;
    }
    // ===================================================================

    // ============================ SPREE CODE ===========================
    LogSpree(zzKillerID,zzVictimID);
    // ===================================================================

    // ============================ COMBO CODE ===========================
    LogCombo(zzKillerID);
    // ===================================================================

    // ============================ FLAG CODE ============================
    if (PI[zzVictimID].bHasFlag)
    {
      LogEventString(GetTimeStamp()$chr(9)$"flag_kill"$chr(9)$KillerID);
      PI[zzVictimID].bHasFlag = false;
    }
    // ===================================================================
}

function LogSpree(int KillerID,int VictimID)
{
    local int i;
    local string spree;

    if (KillerID != 33)
      PI[KillerID].zzSpree++;
    i = PI[VictimID].zzSpree;

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

    PI[VictimID].zzSpree = 0;

    LogEventString(GetTimeStamp()$Chr(9)$"spree"$chr(9)$spree$chr(9)$VictimID);
}

function LogCombo (int KillerID, optional bool bEndGame,optional bool bDisconnect)
{
    local float zzNow;
    local int i;
    local string spree;

    if (bEndGame)
      zzNow = zzEndTime;
    else if (bDisconnect)
      zzNow = PI[KillerID].zzEndTime;
    else
      zzNow = Level.TimeSeconds;

    if (zzNow - PI[KillerID].zzLastKill < 3.0)
    {
      if ((bEndGame || bDisconnect) && (PI[KillerID].zzCombo > 1))  // Combo was still going on when player disconnected
        LogEventString(GetTimeStamp()$chr(9)$"spree"$chr(9)$zzComboCode[Clamp(PI[KillerID].zzCombo-2,0,3)]$chr(9)$KillerID);
      else
        PI[KillerID].zzCombo++;
    }
    else
    {
      if (PI[KillerID].zzCombo > 1)
        LogEventString(GetTimeStamp()$chr(9)$"spree"$chr(9)$zzComboCode[Clamp(PI[KillerID].zzCombo-2,0,3)]$chr(9)$KillerID);
      PI[KillerID].zzCombo = 1;
    }

    PI[KillerID].zzLastKill = zzNow;
}

function LogTeamKill( int KillerID, int VictimID, string KillerWeaponName, string VictimWeaponName, name DamageType )
{
   local int zzKillerID, zzVictimID;

   if (!bGameStarted && !GameStarted())
     return;

   zzKillerID = GetID(KillerID);
   zzVictimID = GetID(VictimID);

   PI[zzKillerID].zzTeamKills++;
   PI[zzVictimID].zzDeaths++;

   super.LogTeamKill(KillerID,VictimID,KillerWeaponName,VictimWeaponName,DamageType);

   if (PI[zzVictimID].bHasFlag)
      PI[zzVictimID].bHasFlag = false;
}

function LogSuicide (Pawn Killed, name DamageType, Pawn Instigator)
{
   local int zzKilled;

   if (!bGameStarted && !GameStarted())
     return;

   zzKilled = GetID(Killed.PlayerReplicationInfo.PlayerID);

   PI[zzKilled].zzSuicides++;

   Super.LogSuicide(Killed,DamageType,Instigator);

   if (PI[zzKilled].bHasFlag)
      PI[zzKilled].bHasFlag = false;
}

function LogPlayerConnect(Pawn Player, optional string Checksum)
{
    if (Player.IsA('Spectator'))
        return;

    super.LogPlayerConnect(Player,Checksum);
}

function LogPlayerDisconnect(Pawn Player)
{
    local int i;

    if (Player.IsA('Spectator'))
        return;

    i = GetID(Player.PlayerReplicationInfo.PlayerID);

    LogEventString(GetTimeStamp()$Chr(9)$"player"$Chr(9)$"Disconnect"$Chr(9)$Player.PlayerReplicationInfo.PlayerID);

    PI[i].zzEndTime = Level.TimeSeconds;

    if (!bGameStarted && !GameStarted())
        return;

    LogSpree(33,i);
    LogCombo(i,,true);

    AddToBuffer(i);

    PI[i].zzID = -1;
}

function LogSpecialEvent(string EventType, optional coerce string Arg1, optional coerce string Arg2, optional coerce string Arg3, optional coerce string Arg4)
{
    local int i;
    local string event;

    /*if (!bGameStarted)
      return;

    super.LogSpecialEvent(EventType,Arg1,Arg2,Arg3,Arg4);*/

    Event = EventType;
    if (Arg1 != "")
        Event = Event$Chr(9)$Arg1;
    if (Arg2 != "")
        Event = Event$Chr(9)$Arg2;
    if (Arg3 != "")
        Event = Event$Chr(9)$Arg3;
    if (Arg4 != "")
        Event = Event$Chr(9)$Arg4;

    LogEventString(GetTimeStamp()$Chr(9)$Event);

    if (!bGameStarted && !GameStarted())
        return;

    if (EventType=="flag_taken" || EventType=="flag_pickedup")
    {
        i = GetID(int(Arg1));

        PI[i].bHasFlag = true;
    }
    else if (EventType=="flag_captured")
    {
        i = GetID(int(Arg1));

        PI[i].bHasFlag = false;
    }
    else if (EventType=="translocate")
    {
        i = GetID(int(Arg1));

        PI[i].bHasFlag = false;
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
           if(NewPawn.PlayerReplicationInfo.PlayerID == currentID)
           {
               ++currentID;
	           SetIP(NewPawn);
			   break;
           }
       }
   }
}

function SetIP( Pawn Player)
{
   local string zzIP;
   local int i,j;
   local bool bReconnected;

   if (Player.IsA('PlayerPawn'))
     zzIP = PlayerPawn(Player).GetPlayerNetworkAddress();
   else
     zzIP = "0.0.0.0";

   if (InStr(zzIP,":") != -1)
     zzIP = Left(zzIP,InStr(zzIP,":"));

   LogEventString(GetTimeStamp()$Chr(9)$"player"$Chr(9)$"IP"$Chr(9)$Player.PlayerReplicationInfo.PlayerID$Chr(9)$zzIP);
}

// =============================================================================
// Game Start/End functions
// =============================================================================

function LogGameStart()
{
    LogEventString(GetTimeStamp()$Chr(9)$"game_start");
}

function LogGameEnd( string Reason )
{
    local int i;

    zzEndTime = Level.TimeSeconds;

    if ((UTSAH != None) && (Reason == "Assault succeeded!"))
    {
      UTSAH.bEndGame = true;
      UTSAH.ClientMessage("",'CriticalEvent');
    }

    Super.LogGameEnd(Reason);

    for (i=0;i<32;++i)
    {
       if (PI[i].zzID != -1) // Player is still on the server
       {
         LogSpree(33,i);
         LogCombo(i,true);
         AddToBuffer(i);
         PI[i].zzID = -1;
       }
    }

    ProcessBuffer();
}

// =============================================================================
// Some lame code here. We want UTStats to log all playerstats at the end of the
// game, not during the game. That's why we'll use a buffer.
// =============================================================================

function AddToBuffer ( int zzPlayerID )
{
    local float zzAccuracy,zzEfficiency,zzTTL,zzTimeOnServer;

    zzAccuracy = UTSDM.GetAccuracy(PI[zzPlayerID].zzPawn.PlayerReplicationInfo);

    zzTimeOnServer = Min(Level.TimeSeconds-PI[zzPlayerID].zzJoinTime,Level.TimeSeconds-zzWarmupTime);

    if (PI[zzPlayerID].zzDeaths != 0)
      zzTTL = zzTimeOnServer/(PI[zzPlayerID].zzDeaths) ;
    else
      zzTTL = zzTimeOnServer;

    if ((PI[zzPlayerID].zzKills+PI[zzPlayerID].zzDeaths+PI[zzPlayerID].zzSuicides+PI[zzPlayerID].zzTeamKills) == 0)
      zzEfficiency = 0.0;
    else
      zzEfficiency = float(PI[zzPlayerID].zzKills)/float(PI[zzPlayerID].zzKills+PI[zzPlayerID].zzDeaths+PI[zzPlayerID].zzSuicides+PI[zzPlayerID].zzTeamKills)*100.0;

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
}

function BufferLog ( string zzTag, string zzType, int zzPlayerID, string zzValue )
{
    zzBuffer = zzBuffer$":::"$zzTag$chr(9)$zzType$chr(9)$string(zzPlayerID)$chr(9)$zzValue;
}

function ProcessBuffer () // This will cause extreme cpu usage on the server for a sec :)
{
    local int index;

    while (InStr(zzBuffer,":::") != -1)
    {
         index = InStr(zzBuffer,":::");

         LogEventString(GetTimeStamp()$chr(9)$Left(zzBuffer,index));
         zzBuffer = Mid(zzBuffer,index+3);
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
// UTGL support
// =============================================================================

function Touch (Actor A) // Called by UTGL when a player logs in
{
   local string zzGLInfo,zzLogin;
   local int zzIndex, zzPID, zzOffset;

   zzGLInfo = zzGLTag;

   if (CAPS(Left(zzGLInfo,8)) == "UTGLJOIN")
   {
       zzIndex = InStr(zzGLInfo,chr(9));
       if (zzIndex != -1)
           zzGLInfo = Mid(zzGLInfo,zzIndex+1);

       zzIndex = InStr(zzGLInfo,chr(9));
       if (zzIndex != -1)
       {
           zzPID = int(Left(zzGLInfo,zzIndex));
           zzGLInfo = Mid(zzGLInfo,zzIndex+1);
       }

       zzIndex = InStr(zzGLInfo,chr(9));
       if (zzIndex != -1)
           zzLogin = Left(zzGLInfo,zzIndex);
   }

   if (zzLogin != "")
   {
       zzOffset = GetID(zzPID);
       PI[zzOffset].zzLogin = zzLogin;
   }

   LogEventString(GetTimeStamp()$Chr(9)$"player"$Chr(9)$"GLLogin"$Chr(9)$zzPID$Chr(9)$zzLogin);
}

// =============================================================================
// Assault support. Function called by the UTStatsSA.
// =============================================================================

function LogAssaultObj (bool bFinalObj, int zzPID)
{
   LogEventString(GetTimeStamp()$Chr(9)$"assault_obj"$Chr(9)$string(zzPID)$Chr(9)$string(bFinalObj));
}

// =============================================================================
// Random lame functions that shouldn't be active in warmup mode
// =============================================================================

function LogPings ()
{
   if (!bGameStarted && !GameStarted())
     return;

   super.LogPings();
}

function LogItemActivate (Inventory Item, Pawn Other)
{
   if (!bGameStarted && !GameStarted())
     return;

   Super.LogItemActivate(Item,Other);
}

function LogItemDeactivate (Inventory Item, Pawn Other)
{
   if (!bGameStarted && !GameStarted())
     return;

   super.LogItemDeactivate(Item,Other);
}

function LogPickup (Inventory Item, Pawn Other)
{
   if (!bGameStarted && !GameStarted())
     return;

   super.LogPickup(Item,Other);
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
// Defaultproperties
// =============================================================================

defaultproperties
{
      bUTGLEnabled=False
      bFirstBlood=False
      bGameStarted=False
      zzComboCode(0)=""
      zzComboCode(1)=""
      zzComboCode(2)=""
      zzComboCode(3)=""
      zzBuffer=""
      zzVersion="beta 3"
      zzGLTag=""
      zzEndTime=0.000000
      zzWarmupTime=0.000000
      CurrentID=0
      zzPHPos=0
      UTSDM=None
      Pi(0)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(1)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(2)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(3)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(4)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(5)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(6)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(7)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(8)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(9)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(10)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(11)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(12)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(13)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(14)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(15)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(16)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(17)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(18)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(19)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(20)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(21)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(22)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(23)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(24)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(25)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(26)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(27)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(28)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(29)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(30)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(31)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      Pi(32)=(zzPawn=None,zzID=0,zzSpree=0,zzCombo=0,zzKills=0,zzDeaths=0,zzSuicides=0,zzTeamKills=0,zzLastKill=0.000000,zzEndTime=0.000000,zzJoinTime=0.000000,bHasFlag=False,zzLogin="",zzIP="")
      UTSAH=None
}
