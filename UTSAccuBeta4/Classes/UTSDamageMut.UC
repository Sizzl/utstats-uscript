// =============================================================================
//                      UTS Accuracy Package Beta 4.0
//                                   ~
//                    UTStats - UTPro statistics addon
//                        © 2005 )°DoE°(-AnthraX
// =============================================================================
// !!! THE UNREAL OPEN MOD LICENSE DOES NOT APPLY TO THIS PACKAGE
//     , YOU ARE NOT ALLOWED TO COPY OR CHANGE ANY OF THE CODE INCLUDED
//     IN THIS PACKAGE WITHOUT WRITTEN PERMISSION FROM AnthraX (Unrealadmin) !!!
// =============================================================================

class UTSDamageMut extends Mutator;

struct PlayerInfo
{
   var UTSReplicationInfo zzRI;
   var int zzPID;
};

var PlayerInfo zzPI[32];
var bool bUTGLEnabled,bNoTeamGame;
var int currentID;
var string zzGLTag;

var bool bClickboard;
var bool bUTStatsRunning;

// =============================================================================
// Setup the damagemut
// =============================================================================

function PostBeginPlay()
{
   local int i;

   for (i=0;i<32;++i)
      zzPI[i].zzPID = -1;

   //Log("### UTSAccu package loaded!");

   Level.Game.RegisterDamageMutator(self);

   if (InStr(CAPS(Level.ConsoleCommand("get Engine.GameEngine ServerActors")),".GLACTOR") != -1)
       bUTGLEnabled = true;
}

// =============================================================================
// MutatorTakeDamage ~ Handle damage and dispatch to the right Replicationclass
// =============================================================================

function MutatorTakeDamage( out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
   local int i, VictimPID, InstigatorPID;
   local bool bVictimFound, bInstigatorFound;

   if (Victim != None && Victim.PlayerReplicationInfo != None)
       VictimPID = Victim.PlayerReplicationInfo.PlayerID;
   else
       bVictimFound = true;

   if (InstigatedBy != None && InstigatedBy.PlayerReplicationInfo != None)
       InstigatorPID = InstigatedBy.PlayerReplicationInfo.PlayerID;
   else
       bInstigatorFound = true;

   for (i=0;i<32;++i)
   {
       if (!bVictimFound && (zzPI[i].zzPID == VictimPID) && (zzPI[i].zzRI != None))
       {
           zzPI[i].zzRI.zzReceivedDamage(ActualDamage);
           bVictimFound = true;
       }
       if (!bInstigatorFound && (zzPI[i].zzPID == InstigatorPID) && (zzPI[i].zzRI != None))
       {
           if ((Victim != InstigatedBy) && (bNoTeamGame || Victim.PlayerReplicationInfo.Team != InstigatedBy.PlayerReplicationInfo.Team))
               zzPI[i].zzRI.zzGaveDamage(DamageType,ActualDamage);
           bInstigatorFound = true;
       }
       if (bVictimFound && bInstigatorFound)
           break;
   }

   if (NextDamageMutator != None)
        NextDamageMutator.MutatorTakeDamage(ActualDamage,Victim,InstigatedBy,HitLocation,Momentum,DamageType);
}

// =============================================================================
// zzEffectPlus ~ Called by UTSEffectsSN when Actor A fires an effectshot
// =============================================================================

function zzEffectPlus (Actor A)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID)
        {
            zzPI[i].zzRI.zzEffectPlus(A);
            break;
        }
    }
}

// =============================================================================
// zzEffectMin ~ Called by UTSEffectsSN when Actor A fires a shockcombo
// =============================================================================

function zzEffectMin (Actor A)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID)
        {
            zzPI[i].zzRI.zzEffectMin(A);
            break;
        }
    }
}

// =============================================================================
// zzProjPlus ~ Called by UTSProjectileSN when Actor A fires a projectile
// =============================================================================

function zzProjPlus (Actor A)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID)
        {
            zzPI[i].zzRI.zzProjPlus(A);
            break;
        }
    }
}

// =============================================================================
// Tick ~ Scan for new players
// =============================================================================

function Tick (float DeltaTime)
{
   local Pawn P;

   if (Level.Game.CurrentID > currentID)
   {
       for (P = Level.PawnList; P != None; P = P.NextPawn)
       {
           if (P.PlayerReplicationInfo.PlayerID == currentID)
           {
               currentID++;
               zzInitPlayer(P);
               break;
           }
       }
   }
}

// =============================================================================
// zzInitPlayer ~ Initialize a new pawn
// =============================================================================

function zzInitPlayer (Pawn P)
{
   local int i;
   local string zzPath;

   if (currentID < 32)
       i = currentID;
   else
   {
       for (i=0;i<32;++i)
       {
           if (zzPI[i].zzRI == None)
               break;
       }
   }

   zzPI[i].zzPID = P.PlayerReplicationInfo.PlayerID;
   zzPI[i].zzRI = Spawn(class'UTSReplicationInfo',P,,P.Location);
   if (bClickboard)
   zzPI[i].zzRI.bClickboard = true;
   zzPI[i].zzRI.bUTGLActive = bUTGLEnabled;
   zzPI[i].zzRI.bUTStatsRunning = bUTStatsRunning;
   zzPI[i].zzRI.bDeleteObj = false;
   zzPI[i].zzRI.InitRI();
}

// =============================================================================
// IPOnly ~ return IP without the portnr
// =============================================================================

function string IPOnly (string zzIP)
{
    if (InStr(zzIP,":") != -1)
        return Left(zzIP,InStr(zzIP,":"));
    else
        return zzIP;
}

// =============================================================================
// Touch function, called by UTGL on login
// =============================================================================

function Touch (Actor A)
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

   for (zzIndex=0;zzIndex<32;++zzIndex)
   {
       if(zzPI[zzIndex].zzPID == zzPID)
       {
           zzPI[zzIndex].zzRI.zzLogin = zzLogin;
       }
   }
}

// =============================================================================
// Log suicides
// =============================================================================

function DoSuicide (PlayerReplicationInfo PRI)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (PRI.PlayerID == zzPI[i].zzPID && zzPI[i].zzRI != None)
        {
            zzPI[i].zzRI.zzSuicides++;
            break;
        }
    }
}

// =============================================================================
// Log caps
// =============================================================================

function DoCap (PlayerReplicationInfo PRI)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (PRI.PlayerID == zzPI[i].zzPID && zzPI[i].zzRI != None)
        {
            zzPI[i].zzRI.zzCaps++;
            break;
        }
    }
}

// =============================================================================
// Accu accessor
// =============================================================================

function float GetAccuracy ( PlayerReplicationInfo PRI )
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == PRI.PlayerID)
        {
            if (zzPI[i].zzRI.zzShotCount != 0)
                return float(zzPI[i].zzRI.zzHitCount)/float(zzPI[i].zzRI.zzShotCount)*100.0;
            else
                return 0.00;
        }
    }
}

// =============================================================================
// RI Accessor
// =============================================================================

function UTSReplicationInfo GetRI ( PlayerReplicationInfo PRI )
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == PRI.PlayerID)
        {
            return zzPI[i].zzRI;
        }
    }

    return none;
}

// =============================================================================
// Defaultproperties
// =============================================================================

defaultproperties
{
}
