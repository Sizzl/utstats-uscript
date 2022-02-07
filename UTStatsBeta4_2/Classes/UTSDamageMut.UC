//================================================================================
// UTSDamageMut (from UTSAccu)
// =============================================================================
//                      UTS Accuracy Package Beta 4.2
//                                   ~
//                    UTStats - UTPro statistics addon
//                        © 2005 )°DoE°(-AnthraX
// =============================================================================
// Released under the Unreal Open MOD License (included in zip package)
// =============================================================================

class UTSDamageMut extends Mutator;

struct PlayerInfo
{
  var UTSReplicationInfo zzRI;
  var int zzPID;
};

var PlayerInfo zzPI[32];
var bool bNoTeamGame;
var int CurrentID;

var bool bUTStatsRunning;
var bool bInsta;

// =============================================================================
// Setup the damagemut
// =============================================================================

function PostBeginPlay()
{
   local int i;
   local UTSProjectileSN UTSPSN;
   local UTSShockBeamSN UTSSBSN;
   local UTSSuperShockBeamSN UTSSSBSN;
   local UTSComboSN UTSCSN;

   for (i=0;i<32;++i)
      zzPI[i].zzPID = -1;

   //Log("### UTSAccu package loaded!");

   Level.Game.RegisterDamageMutator(self);

   bNoTeamGame = !Level.Game.bTeamGame;

   // Spawn projectile/effects catchers
   UTSPSN = Level.Spawn(class'UTSProjectileSN');
   UTSPSN.UTSDM = self;
   //UTSSBSN = Level.Spawn(class'UTSShockBeamSN');
   //UTSSBSN.UTSDM = Self;
   //UTSSSBSN = Level.Spawn(class'UTSSuperShockBeamSN');
   //UTSSSBSN.UTSDM = Self;
   UTSCSN = Level.Spawn(class'UTSComboSN');
   UTSCSN.UTSDM = Self;
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

function zzCombo (Actor A)
{
  local int i;

  i = 0;
  if ( i < 32 )
  {
    if ( zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID )
    {
      zzPI[i].zzRI.zzCombo(A);
    } else {
      ++i;
      goto JL0007;
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
           if (P.bIsPlayer && P.PlayerReplicationInfo.PlayerID == currentID)
           {
               zzInitPlayer(P);
               break;
           }
       }
       currentID++;
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
   zzPI[i].zzRI.bUTStatsRunning = bUTStatsRunning;
   zzPI[i].zzRI.bDeleteObj = false;
   zzPI[i].zzRI.bInstaGame = bInsta;
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
// zzBeamPlus ~ Called by UTSEffectsSN when Actor A fires a (super)shockbeam
// =============================================================================

function zzBeamPlus (Actor A)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID)
        {
            zzPI[i].zzRI.zzBeamPlus(A);
            break;
        }
    }
}

// =============================================================================
// zzBeamMin ~ Called by UTSEffectsSN when Actor A fires a shockcombo
// =============================================================================

function zzBeamMin (Actor A)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID)
        {
            zzPI[i].zzRI.zzBeamMin(A);
            break;
        }
    }
}