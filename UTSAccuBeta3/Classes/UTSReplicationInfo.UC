class UTSReplicationInfo extends ReplicationInfo;

var Pawn P; // Pawn that owns this class
var Weapon LastWeapon; // Weapon in the last tick
var bool bUTGLActive,bLog,bShotPending,bReady;
var int zzShotCount,zzHitCount,zzLastShotCount,zzPID;
var int zzLastMiniBullets,zzLastPulseAmmo,zzMiniIndex,zzPulseIndex,zzEnforcerIndex;
var int zzSuicides;
var string zzLogin;
var bool bHasMini,bHasPulse;

var bool bClickboard;

struct WeaponInfo
{
    var weapon zzWeapon;
    var string zzWeaponName;
    var string zzWeaponClass;
    var int zzShotCount;
    var int zzHitCount;
    var float zzDamageGiven;
    var name FirstDamageType;
    var name AltDamageType;
    var class<Projectile> FirstProjClass;
    var class<Projectile> AltProjClass;
    var bool bIsAShockRifle,bIsASuperShockRifle,bIsAMinigun,bIsAFlakCannon,bIsAnEnforcer,bIsASniper;
    var bool bIsAPulseGun,bIsATransLoc,bShotPending,bReset,bIgnoreAccu;
};

var WeaponInfo zzWI[32];

var int zzIndex; // Nr of weapons indexed
var int zzSelectedWeapon; // Index of the current weapon
var int zzWeaponHistory[32]; // Hold the list of weaponindexes (zzWeaponHistory[0] = Index of current Weapon, zzWeaponHistory[1] = Index of previous Weapon)

var int zzDamageGiven, zzDamageReceived;

var int zzKillCount, zzDeathCount;

replication
{
   // Variables: server -> client
   reliable if (ROLE == ROLE_AUTHORITY)
       zzIndex,zzSelectedWeapon,zzPID,zzKillCount,zzDeathCount,zzShotCount,zzHitCount,zzLogin,bUTGLActive,bLog,zzDamageGiven,zzDamageReceived,zzSuicides,bReady;
   // Functioncalls: server -> client
   reliable if (ROLE == ROLE_AUTHORITY)
       ReplicateWeapon,ReplicateGaveDamage,ReplicateReceivedDamage,ReplicateShotCount;
}

// =============================================================================
// Initialize the class
// =============================================================================

function InitRI()
{
   local int i;

   P = Pawn(Owner);
   zzPID = P.PlayerReplicationInfo.PlayerID;

   if (bClickboard && Level.Game.IsA('DeathMatchPlus') && DeathMatchPlus(Level.Game).bTournament && DeathMatchPlus(Level.Game).CountDown > 0)
       SetTimer(1.0,true);

   /*if (Owner.IsA('PlayerPawn'))
       bLog=true;*/

   for (i=0;i<32;++i)
   {
       zzWeaponHistory[i] = -1;
   }

   zzEnforcerIndex = -1;
   zzMiniIndex = -1;
   zzPulseIndex = -1;
}

// =============================================================================
// Tick function, scan for weaponchanges here
// =============================================================================

function Tick (float DeltaTime)
{
   if (P == None)
   {
       Destroy();
       goto'EndTick';
   }
   else
   {
       zzKillCount = P.KillCount;
       if (P.DieCount > zzDeathCount)
       {
           bHasMini = false;
           bHasPulse = false;
       }
       zzDeathCount = P.DieCount;
   }
   if (((P.Weapon == None) || (!P.Weapon.bWeaponUp)))
   {
       LastWeapon = none;
       goto'EndTick';
   }

   // Weapon switch, process info
   if (LastWeapon != P.Weapon)
   {
       if (bLog)
       PlayerPawn(P).ClientMessage("### SWITCHED WEAPON");
       GetIndex(P.Weapon);
       if (bLog)
       PlayerPawn(P).ClientMessage("### new WEAPON INDEX"@zzSelectedWeapon);
       LastWeapon = P.Weapon;
   }

   if ((zzEnforcerIndex != -1 && zzWI[zzEnforcerIndex].zzWeapon != None && zzWI[zzEnforcerIndex].zzWeapon.bTossedOut)
   || (zzMiniIndex != -1 && zzWI[zzMiniIndex].zzWeapon != none && zzWI[zzMiniIndex].zzWeapon.bTossedOut))
       zzLastMiniBullets = 0;

   if (zzPulseIndex != -1 && zzWI[zzPulseIndex].zzWeapon != None && zzWI[zzPulseIndex].zzWeapon.bTossedOut)
       zzLastPulseAmmo = 0;

   if (zzWI[zzSelectedWeapon].bIsAnEnforcer)
       zzLastMiniBullets = P.Weapon.AmmoType.AmmoAmount;

   if (zzWI[zzSelectedWeapon].bIsAMinigun)
   {
       if (zzLastMiniBullets - P.Weapon.AmmoType.AmmoAmount > 0)
       {
           zzShotCount += zzLastMiniBullets - P.Weapon.AmmoType.AmmoAmount;
           zzWI[zzSelectedWeapon].zzShotCount += zzLastMiniBullets - P.Weapon.AmmoType.AmmoAmount;

           ReplicateShotCount(zzSelectedWeapon,zzWI[zzSelectedWeapon].zzShotCount);

           if (bLog)
           PlayerPawn(P).ClientMessage("### MINIGUN+"@zzLastMiniBullets - P.Weapon.AmmoType.AmmoAmount);

           zzLastMiniBullets = P.Weapon.AmmoType.AmmoAmount;
       }
   }

   if (zzWI[zzSelectedWeapon].bIsAPulseGun)
   {
       if (zzLastPulseAmmo - P.Weapon.AmmoType.AmmoAmount > 0)
       {
           zzShotCount += zzLastPulseAmmo - P.Weapon.AmmoType.AmmoAmount;
           zzWI[zzSelectedWeapon].zzShotCount += zzLastPulseAmmo - P.Weapon.AmmoType.AmmoAmount;

           ReplicateShotCount(zzSelectedWeapon,zzWI[zzSelectedWeapon].zzShotCount);

           if (bLog)
           PlayerPawn(P).ClientMessage("### PULSE+"@zzLastPulseAmmo - P.Weapon.AmmoType.AmmoAmount);

           zzLastPulseAmmo = P.Weapon.AmmoType.AmmoAmount;
       }
   }

   EndTick:
}

// =============================================================================
// Get the index of the weapon in the zzWI array
// =============================================================================

function GetIndex(Weapon zzWeapon)
{
   local int i;
   local bool bFound;

   if (zzIndex == 0)
   {
       zzSelectedWeapon = 0;
       UpdateHistory(0);
       InitWeapon(zzWeapon);
   }
   else
   {
       // Look for the weapon in the current list first
       for (i=0;i<zzIndex;++i)
       {
           if (zzWI[i].zzWeaponClass == string(zzWeapon.class))
           {
               zzSelectedWeapon = i;
               UpdateHistory(i);
               bFound = true;
           }
       }

       if (!bFound)
       {
           zzSelectedWeapon = zzIndex;
           UpdateHistory(zzIndex);
           InitWeapon(zzWeapon);
       }
   }

   zzWI[zzSelectedWeapon].zzWeapon = zzWeapon;
}

simulated function ReplicateShotCount(int i,int zzShotCount)
{
   //Log("### REPLICATESHOTCOUNT"@i@zzShotCount);
   zzWI[i].zzShotCount = zzShotCount;
}

// =============================================================================
// Called when the pawn has a weapon he hasn't used before
// =============================================================================

function InitWeapon(Weapon zzWeapon)
{
   zzWI[zzIndex].zzWeaponName = zzWeapon.ItemName;
   zzWI[zzIndex].zzWeaponClass = string(zzWeapon.class);
   zzWI[zzIndex].FirstDamageType = zzWeapon.MyDamageType;
   zzWI[zzIndex].AltDamageType = zzWeapon.AltDamageType;
   zzWI[zzIndex].zzShotCount = 0;
   zzWI[zzIndex].FirstProjClass = zzWeapon.default.ProjectileClass;
   zzWI[zzIndex].AltProjClass = zzWeapon.default.AltProjectileClass;

   zzWI[zzIndex].bIsAMinigun = zzWeapon.IsA('Minigun2');
   zzWI[zzIndex].bIsAShockRifle = zzWeapon.IsA('ShockRifle') && !zzWeapon.IsA('SuperShockRifle');
   zzWI[zzIndex].bIsASuperShockRifle = zzWeapon.IsA('SuperShockRifle');
   zzWI[zzIndex].bIsAnEnforcer = zzWeapon.IsA('Enforcer');
   zzWI[zzIndex].bIsASniper = zzWeapon.IsA('SniperRifle');
   zzWI[zzIndex].bIsAPulseGun = zzWeapon.IsA('PulseGun');
   zzWI[zzIndex].bIsATransLoc = zzWeapon.IsA('Translocator');
   zzWI[zzIndex].bIsAFlakCannon = zzWeapon.IsA('UT_FlakCannon');

   if (zzWI[zzIndex].bIsATransLoc || zzWeapon.IsA('ImpactHammer'))
       zzWI[zzIndex].bIgnoreAccu = true;

   zzWI[zzIndex++].zzDamageGiven = 0.0;

   if (bLog)
       PlayerPawn(P).ClientMessage("###"@zzWI[zzIndex-1].FirstProjClass@zzWI[zzIndex-1].AltProjClass);

   if (zzWeapon.IsA('enforcer'))
   {
       zzLastMiniBullets = zzWeapon.AmmoType.AmmoAmount;
       zzEnforcerIndex = zzIndex-1;
   }
   if (zzWeapon.IsA('Minigun2'))
   {
       zzLastMiniBullets = zzWeapon.AmmoType.AmmoAmount;
       zzMiniIndex = zzIndex-1;
   }
   if (zzWeapon.IsA('PulseGun'))
   {
       zzLastPulseAmmo = zzWeapon.AmmoType.AmmoAmount;
       zzPulseIndex = zzIndex-1;
   }


   ReplicateWeapon(zzIndex-1,string(zzWeapon.class),zzWeapon.ItemName);
}

simulated function ReplicateWeapon(int zzIndex,string zzWeaponClass,string zzWeaponName)
{
   zzWI[zzIndex].zzWeaponClass = zzWeaponClass;
   zzWI[zzIndex].zzWeaponName = zzWeaponName;
}

// =============================================================================
// Used to hold the order of the weapons you had
// =============================================================================

function UpdateHistory(int CurrentWeapon)
{
   local int i, zzPosition;

   for (i=0;i<zzIndex;++i)
   {
       // Look for the position of CurrentWeapon in the history.
       if (zzWeaponHistory[i] == CurrentWeapon)
       {
           zzPosition = i;
           break;
       }
   }

   // If the weapon is found -> zzPosition = position in list
   // if the weapon is not found -> zzPosition = zzIndex

   for (i=zzPosition;i>0;i--)
   {
       // Push all weapons before CurrentWeapon back one position
       zzWeaponHistory[i] = zzWeaponHistory[i-1];
   }

   zzWeaponHistory[0] = CurrentWeapon;
}

// =============================================================================
// Called by DamageMut whenever the pawn gives damage
// =============================================================================

function GaveDamage(Name DamageType, int DamageGiven)
{
   local int i;
   local bool bPlusHit;

   if (bLog)
   PlayerPawn(P).ClientMessage("### GAVE DAMAGE");

   zzDamageGiven += DamageGiven;

   // Look for the weapon that gives this damagetype in the history
   for (i=0;i<32;++i)
   {
       if (zzWeaponHistory[i] == -1)
           break;

       if (zzWI[zzWeaponHistory[i]].FirstDamageType == DamageType || zzWI[zzWeaponHistory[i]].AltDamageType == DamageType)
       {
           zzWI[zzWeaponHistory[i]].zzDamageGiven += DamageGiven;
           if (zzShotCount > zzLastShotCount)
           {
               zzWI[zzWeaponHistory[i]].zzHitCount++;
               zzHitCount++;
               bPlusHit = true;
           }
           zzLastShotCount = zzShotCount;
           ReplicateGaveDamage(zzWeaponHistory[i],DamageGiven,bPlusHit);
           break;
       }
   }
}

simulated function ReplicateGaveDamage(int zzIndex,int DamageGiven, bool bPlusHit)
{
   zzDamageGiven += DamageGiven;
   zzHitCount++;

   if (bPlusHit)
   {
       zzWI[zzIndex].zzDamageGiven += DamageGiven;
       zzWI[zzIndex].zzHitCount++;
   }
}

// =============================================================================
// Called by DamageMut whenever the pawn receives damage
// =============================================================================

function ReceivedDamage(int DamageReceived)
{
   zzDamageReceived += DamageReceived;

   ReplicateReceivedDamage(DamageReceived);

   if (bLog)
   PlayerPawn(P).ClientMessage("### GOT DAMAGE");
}

simulated function ReplicateReceivedDamage(int DamageReceived)
{
   zzDamageReceived += DamageReceived;
}

// =============================================================================
// Functions called by the damagemutator to change shotcount
// =============================================================================

function EffectPlus (Actor A)
{
   local int i;

   zzShotCount++;

   if (bLog)
       PlayerPawn(P).ClientMessage("### EFFECTSHOT++");

   for (i=0;i<32;++i)
   {
       if (zzWeaponHistory[i] == -1)
           break;

       if (zzWI[zzWeaponHistory[i]].bIsAShockRifle && A.IsA('ShockBeam'))
       {
           zzWI[zzWeaponHistory[i]].zzShotCount++;
           ReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
           break;
       }
       else if (zzWI[zzWeaponHistory[i]].bIsASuperShockRifle && A.IsA('SuperShockBeam'))
       {
           zzWI[zzWeaponHistory[i]].zzShotCount++;
           ReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
           break;
       }
   }
}

function EffectMin (Actor A)
{
   local int i;

   zzShotCount--;

   if (bLog)
       PlayerPawn(P).ClientMessage("### EFFECTSHOT--");

   for (i=0;i<32;++i)
   {
       if (zzWeaponHistory[i] == -1)
           break;

       if (zzWI[zzWeaponHistory[i]].bIsAShockRifle && A.IsA('UT_ComboRing'))
       {
           zzWI[zzWeaponHistory[i]].zzShotCount--;
           ReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
           break;
       }
   }
}

function ProjPlus (Actor A)
{
   local int i;

   if (bLog)
       PlayerPawn(P).ClientMessage("### PROJSHOT++"@A.class);

   for (i=0;i<32;++i)
   {
       if (zzWeaponHistory[i] == -1)
           break;

       // Translocator fix
       if (A.IsA('TranslocatorTarget') && zzWI[zzWeaponHistory[i]].bIsATransLoc)
       {
           zzShotCount++;
           zzWI[zzWeaponHistory[i]].zzShotCount++;
           ReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
           break;
       }
       // Enforcer/sniper fix
       else if (A.IsA('UT_ShellCase') && (zzWI[zzWeaponHistory[i]].bIsASniper || zzWI[zzWeaponHistory[i]].bIsAnEnforcer))
       {
           zzWI[zzWeaponHistory[i]].zzShotCount++;
           ReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
           zzShotCount++;
           break;
       }
       else if (zzWI[zzWeaponHistory[i]].bIsAFlakCannon && (A.IsA('UTChunk1') || A.IsA('flakslug')))
       {
           if (zzWI[zzWeaponHistory[i]].bShotPending)
           {
               zzWI[zzWeaponHistory[i]].zzShotCount++;
               ReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
               zzWI[zzWeaponHistory[i]].bShotPending = false;
           }
           else
               zzWI[zzWeaponHistory[i]].bShotPending = true;

           if (bShotPending)
           {
               zzShotCount++;
               bShotPending = false;
           }
           else
               bShotPending = true;

           break;
       }
       else if (zzWI[zzWeaponHistory[i]].FirstProjClass == A.class || zzWI[zzWeaponHistory[i]].AltProjClass == A.class)
       {
           zzWI[zzWeaponHistory[i]].zzShotCount++;
           ReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
           zzShotCount++;
           break;
       }
   }
}

// =============================================================================
// GiveMiniBullets, called by UTSDamageMut when a player picks up minibullets
// =============================================================================

function GiveMiniBullets(int zzAmount,bool bCheckWeapon,optional bool bMinigun,optional bool bEnforcer)
{
    if (bCheckWeapon)
    {
        if (bEnforcer && !(zzEnforcerIndex == -1
        || zzWI[zzEnforcerIndex].zzWeapon == none
        || zzWI[zzEnforcerIndex].zzWeapon.Owner != P
        || zzWI[zzEnforcerIndex].zzWeapon.bTossedOut))
            return;
        else if (bMinigun && (bHasMini || !(zzMiniIndex == -1
        || zzWI[zzMiniIndex].zzWeapon == none
        || zzWI[zzMiniIndex].zzWeapon.Owner != P
        || zzWI[zzMiniIndex].zzWeapon.bTossedOut)))
            return;
    }

    if (bMinigun)
        bHasMini = true;

    if (P.Weapon.IsA('Minigun2'))
    {
       if ((zzLastMiniBullets-P.Weapon.AmmoType.AmmoAmount) > 0)
       {
           zzShotCount += (zzLastMiniBullets-P.Weapon.AmmoType.AmmoAmount);
           if (zzMiniIndex != -1)
           zzWI[zzMiniIndex].zzShotCount += (zzLastMiniBullets-P.Weapon.AmmoType.AmmoAmount);
       }

       if (bLog)
       PlayerPawn(P).ClientMessage("### ADDING"@(zzLastMiniBullets-P.Weapon.AmmoType.AmmoAmount)@"MINISHOTS");
    }

    zzLastMiniBullets += zzAmount;
    if (zzLastMiniBullets >= 200)
    zzLastMiniBullets = 199;
    if (bLog)
    PlayerPawn(P).ClientMessage("###"@P.PlayerReplicationInfo.PlayerName@"PICKED UP MINIGUN AMMO"@zzAmount@"NOW HAS"@zzLastMiniBullets@"MINIBULLETS");
}

// =============================================================================
// GivePulseBullets, called by UTSDamageMut when a player picks up pulseammo
// =============================================================================

function GivePulseAmmo (int zzAmount,bool bCheckWeapon)
{
    if (bCheckWeapon)
    {
        if (bHasPulse || !(zzPulseIndex == -1
        || zzWI[zzPulseIndex].zzWeapon == none
        || zzWI[zzPulseIndex].zzWeapon.Owner != P
        || zzWI[zzPulseIndex].zzWeapon.bTossedOut))
            return;

        bHasPulse = true;
    }

    if (P.Weapon.IsA('PulseGun'))
    {
       if (zzLastPulseAmmo-P.Weapon.AmmoType.AmmoAmount > 0)
       {
           zzShotCount += (zzLastPulseAmmo-P.Weapon.AmmoType.AmmoAmount);
           if (zzPulseIndex != -1)
           zzWI[zzPulseIndex].zzShotCount += (zzLastPulseAmmo-P.Weapon.AmmoType.AmmoAmount);
       }

       if (bLog)
       PlayerPawn(P).ClientMessage("### ADDING"@(zzLastPulseAmmo-P.Weapon.AmmoType.AmmoAmount)@"PULSESHOTS");
    }

    zzLastPulseAmmo += zzAmount;
    if (zzLastPulseAmmo >= 200)
    zzLastPulseAmmo = 199;
    if (bLog)
    PlayerPawn(P).ClientMessage("###"@P.PlayerReplicationInfo.PlayerName@"PICKED UP PULSEGUN AMMO"@zzAmount@"NOW HAS"@zzLastPulseAmmo@"PULSEBULLETS");
}

// =============================================================================
// Accessors
// =============================================================================

simulated function string GetWeaponName (int i) { return zzWI[i].zzWeaponName; }
simulated function int GetShotCount (int i) { return zzWI[i].zzShotCount; }
simulated function int GetHitCount (int i) { return zzWI[i].zzHitCount; }
simulated function int GetDamage (int i) { return zzWI[i].zzDamageGiven; }
simulated function float GetAccu (int i)
{
   if (zzWI[i].zzShotCount == 0)
       return 0.00;
   else
       return float(zzWI[i].zzHitCount)/float(zzWI[i].zzShotCount)*100.00;
}

// =============================================================================
// Clickboard stuff
// =============================================================================

function Timer()
{
   if (Owner == None)
   {
       Destroy();
       return;
   }

   if (Level == None || Level.Game == None || DeathMatchPlus(Level.Game) == None)
       return;

   if (DeathMatchPlus(Level.Game).CountDown > 0)
   {
       if (Owner.IsA('Bot') || (Owner.IsA('PlayerPawn') && !Owner.IsA('Spectator') && PlayerPawn(Owner).bReadyToPlay))
           bReady = true;
   }
   else
   {
       bReady = false;
       SetTimer(0.0,false);
   }
}

// =============================================================================
// Defaultproperties
// =============================================================================

defaultproperties
{
      P=None
      LastWeapon=None
      bUTGLActive=False
      bLog=False
      bShotPending=False
      bReady=False
      zzShotCount=0
      zzHitCount=0
      zzLastShotCount=0
      zzPID=0
      zzLastMiniBullets=0
      zzLastPulseAmmo=0
      zzMiniIndex=0
      zzPulseIndex=0
      zzEnforcerIndex=0
      zzSuicides=0
      zzLogin=""
      bHasMini=False
      bHasPulse=False
      bClickboard=False
      zzWI(0)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(1)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(2)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(3)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(4)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(5)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(6)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(7)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(8)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(9)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(10)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(11)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(12)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(13)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(14)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(15)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(16)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(17)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(18)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(19)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(20)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(21)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(22)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(23)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(24)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(25)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(26)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(27)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(28)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(29)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(30)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzWI(31)=(zzWeapon=None,zzWeaponName="",zzWeaponClass="",zzShotCount=0,zzHitCount=0,zzDamageGiven=0.000000,FirstDamageType="None",AltDamageType="None",FirstProjClass=None,AltProjClass=None,bIsAShockRifle=False,bIsASuperShockRifle=False,bIsAMinigun=False,bIsAFlakCannon=False,bIsAnEnforcer=False,bIsASniper=False,bIsAPulseGun=False,bIsATransLoc=False,bShotPending=False,bReset=False,bIgnoreAccu=False)
      zzIndex=0
      zzSelectedWeapon=0
      zzWeaponHistory(0)=0
      zzWeaponHistory(1)=0
      zzWeaponHistory(2)=0
      zzWeaponHistory(3)=0
      zzWeaponHistory(4)=0
      zzWeaponHistory(5)=0
      zzWeaponHistory(6)=0
      zzWeaponHistory(7)=0
      zzWeaponHistory(8)=0
      zzWeaponHistory(9)=0
      zzWeaponHistory(10)=0
      zzWeaponHistory(11)=0
      zzWeaponHistory(12)=0
      zzWeaponHistory(13)=0
      zzWeaponHistory(14)=0
      zzWeaponHistory(15)=0
      zzWeaponHistory(16)=0
      zzWeaponHistory(17)=0
      zzWeaponHistory(18)=0
      zzWeaponHistory(19)=0
      zzWeaponHistory(20)=0
      zzWeaponHistory(21)=0
      zzWeaponHistory(22)=0
      zzWeaponHistory(23)=0
      zzWeaponHistory(24)=0
      zzWeaponHistory(25)=0
      zzWeaponHistory(26)=0
      zzWeaponHistory(27)=0
      zzWeaponHistory(28)=0
      zzWeaponHistory(29)=0
      zzWeaponHistory(30)=0
      zzWeaponHistory(31)=0
      zzDamageGiven=0
      zzDamageReceived=0
      zzKillCount=0
      zzDeathCount=0
      NetPriority=10.000000
}
