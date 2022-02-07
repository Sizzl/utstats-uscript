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

// =============================================================================
// Setup the damagemut
// =============================================================================

function PostBeginPlay()
{
   local int i;

   for (i=0;i<32;++i)
      zzPI[i].zzPID = -1;

   Log("### UTSAccu package loaded!");

   Level.Game.RegisterDamageMutator(self);

   if (InStr(CAPS(Level.ConsoleCommand("get Engine.GameEngine ServerActors")),".GLACTOR") != -1)
       bUTGLEnabled = true;
}

// =============================================================================
// Handle damage
// =============================================================================

function MutatorTakeDamage( out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
   local int i, VictimPID, InstigatorPID;
   local bool bVictimFound, bInstigatorFound;

   super.MutatorTakeDamage(ActualDamage,Victim,InstigatedBy,HitLocation,Momentum,DamageType);

   if (Victim != None && Victim.IsA('Pawn') && Victim.PlayerReplicationInfo != None)
       VictimPID = Victim.PlayerReplicationInfo.PlayerID;
   else
       bVictimFound = true;

   if (InstigatedBy != None && InstigatedBy.IsA('Pawn') && InstigatedBy.PlayerReplicationInfo != None)
       InstigatorPID = InstigatedBy.PlayerReplicationInfo.PlayerID;
   else
       bInstigatorFound = true;

   for (i=0;i<32;++i)
   {
       if (!bVictimFound && (zzPI[i].zzPID == VictimPID) && (zzPI[i].zzRI != None))
       {
           zzPI[i].zzRI.ReceivedDamage(ActualDamage);
           bVictimFound = true;
       }
       if (!bInstigatorFound && (zzPI[i].zzPID == InstigatorPID) && (zzPI[i].zzRI != None))
       {
           if ((Victim != InstigatedBy) && (bNoTeamGame || Victim.PlayerReplicationInfo.Team != InstigatedBy.PlayerReplicationInfo.Team))
               zzPI[i].zzRI.GaveDamage(DamageType,ActualDamage);
           bInstigatorFound = true;
       }
       if (bVictimFound && bInstigatorFound)
           break;

   }
}

// =============================================================================
// HandlePickupQuery ~ Used to fix minigun
// =============================================================================

function bool HandlePickupQuery(Pawn Other, Inventory item, out byte bAllowPickup)
{
    local int i;

    if (item.IsA('Minigun2'))
    {
        for (i=0;i<32;++i)
        {
            if (zzPI[i].zzPID == Other.PlayerReplicationInfo.PlayerID)
            {
                if (!Weapon(item).bWeaponStay)
                {
                    zzPI[i].zzRI.bHasMini = true;
                    zzPI[i].zzRI.GiveMiniBullets(Weapon(item).PickupAmmoCount,false);
                }
                else
                    zzPI[i].zzRI.GiveMiniBullets(Weapon(item).PickupAmmoCount,true,true);
                break;
            }
        }
    }
    else if (item.IsA('enforcer'))
    {
        for (i=0;i<32;++i)
        {
            if (zzPI[i].zzPID == Other.PlayerReplicationInfo.PlayerID)
            {
                if (!Weapon(item).bWeaponStay)
                    zzPI[i].zzRI.GiveMiniBullets(Weapon(item).PickupAmmoCount,false);
                else
                    zzPI[i].zzRI.GiveMiniBullets(Weapon(item).PickupAmmoCount,true,,true);
                break;
            }
        }
    }
    else if (item.IsA('PulseGun'))
    {
        for (i=0;i<32;++i)
        {
            if (zzPI[i].zzPID == Other.PlayerReplicationInfo.PlayerID)
            {
                if (!Weapon(item).bWeaponStay)
                {
                    zzPI[i].zzRI.bHasPulse = true;
                    zzPI[i].zzRI.GivePulseAmmo(Weapon(item).PickupAmmoCount,false);
                }
                else
                    zzPI[i].zzRI.GivePulseAmmo(Weapon(item).PickupAmmoCount,true);
                break;
            }
        }
    }
    else if (item.IsA('miniammo'))
    {
        for (i=0;i<32;++i)
        {
            if (zzPI[i].zzPID == Other.PlayerReplicationInfo.PlayerID)
            {
                zzPI[i].zzRI.GiveMiniBullets(Ammo(item).AmmoAmount,false);
                break;
            }
        }
    }
    else if (item.IsA('PAmmo'))
    {
        for (i=0;i<32;++i)
        {
            if (zzPI[i].zzPID == Other.PlayerReplicationInfo.PlayerID)
            {
                zzPI[i].zzRI.GivePulseAmmo(Ammo(item).AmmoAmount,false);
                break;
            }
        }
    }

    if (NextMutator != None)
        return NextMutator.HandlePickupQuery(Other, item, bAllowPickup);
    return false;

}

// =============================================================================
// EffectPlus, EffectMin, ProjPlus ~ Called by SpawnNotify classes
// =============================================================================

function EffectPlus (Actor A)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID)
        {
            zzPI[i].zzRI.EffectPlus(A);
            break;
        }
    }
}

function EffectMin (Actor A)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID)
        {
            zzPI[i].zzRI.EffectMin(A);
            break;
        }
    }
}

function ProjPlus (Actor A)
{
    local int i;

    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID)
        {
            zzPI[i].zzRI.ProjPlus(A);
            break;
        }
    }
}

// =============================================================================
// Process new players
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
               InitPlayer(P);
               break;
           }
       }
   }
}

function InitPlayer (Pawn P)
{
   local int i;

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
   zzPI[i].zzRI.InitRI();
   zzPI[i].zzRI.bUTGLActive = bUTGLEnabled;
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

defaultproperties
{
      zzPI(0)=(zzRI=None,zzPID=0)
      zzPI(1)=(zzRI=None,zzPID=0)
      zzPI(2)=(zzRI=None,zzPID=0)
      zzPI(3)=(zzRI=None,zzPID=0)
      zzPI(4)=(zzRI=None,zzPID=0)
      zzPI(5)=(zzRI=None,zzPID=0)
      zzPI(6)=(zzRI=None,zzPID=0)
      zzPI(7)=(zzRI=None,zzPID=0)
      zzPI(8)=(zzRI=None,zzPID=0)
      zzPI(9)=(zzRI=None,zzPID=0)
      zzPI(10)=(zzRI=None,zzPID=0)
      zzPI(11)=(zzRI=None,zzPID=0)
      zzPI(12)=(zzRI=None,zzPID=0)
      zzPI(13)=(zzRI=None,zzPID=0)
      zzPI(14)=(zzRI=None,zzPID=0)
      zzPI(15)=(zzRI=None,zzPID=0)
      zzPI(16)=(zzRI=None,zzPID=0)
      zzPI(17)=(zzRI=None,zzPID=0)
      zzPI(18)=(zzRI=None,zzPID=0)
      zzPI(19)=(zzRI=None,zzPID=0)
      zzPI(20)=(zzRI=None,zzPID=0)
      zzPI(21)=(zzRI=None,zzPID=0)
      zzPI(22)=(zzRI=None,zzPID=0)
      zzPI(23)=(zzRI=None,zzPID=0)
      zzPI(24)=(zzRI=None,zzPID=0)
      zzPI(25)=(zzRI=None,zzPID=0)
      zzPI(26)=(zzRI=None,zzPID=0)
      zzPI(27)=(zzRI=None,zzPID=0)
      zzPI(28)=(zzRI=None,zzPID=0)
      zzPI(29)=(zzRI=None,zzPID=0)
      zzPI(30)=(zzRI=None,zzPID=0)
      zzPI(31)=(zzRI=None,zzPID=0)
      bUTGLEnabled=False
      bNoTeamGame=False
      CurrentID=0
      zzGLTag=""
      bClickboard=False
}
