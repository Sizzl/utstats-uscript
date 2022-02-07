//================================================================================
// UTSReplicationInfo (from UTSAccu)
// =============================================================================
// UTSReplicationInfo ~ This class holds all weapon information. The server
// always has the most accuracy values for each weapon. These values only get
// replicated to the client when the statsboard is up, thus saving a lot of bandwith
//================================================================================

class UTSReplicationInfo extends Info;

// WI struct definition
struct WeaponInfo
{
    var weapon zzWeapon;
    var string zzWeaponName;
    var class<Weapon> zzWeaponClass;
    var int zzShotCount,zzLastShotCount,zzHitCount;
    var float zzDamageGiven;

    // Used by zzGaveDamage
    var name FirstDamageType,AltDamageType;

    // Used by zzProjPlus
    var class<Projectile> FirstProjClass,AltProjClass;

    // Ammocounting vars
    var bool bAmmoCountingMethod; // Determine no of fired shots by counting ammo?
    var bool bAllowDoubleHit;
    var int zzAmmoCount;

    var bool bIgnoreAccu; // Ignore shotcount for this weapon?
    var bool bIsAShockRifle,bIsASuperShockRifle;
};

var WeaponInfo zzWI[32];

// Servervars!
var Pawn P; // Pawn that owns this class
var Weapon LastWeapon; // Weapon in the last tick
var int zzShotCount,zzHitCount,zzLastShotCount,zzPID;

var bool bDeleteObj,bUTStatsRunning; // UTStats support ~ DeleteObj gets set when UTStats finished logging all values in the class
var bool bInstaGame;

var int zzIndex; // Nr of weapons indexed
var int zzSelectedWeapon; // Index of the current weapon
var int zzWeaponHistory[32]; // Hold the list of weaponindexes (zzWeaponHistory[0] = Index of current Weapon, zzWeaponHistory[1] = Index of previous Weapon)
var int zzDamageGiven, zzDamageReceived;
var int zzKillCount, zzDeathCount;

// Clientvars
var bool bShowingScores;

replication
{
   // Variables: server -> all clients
   reliable if (ROLE == ROLE_AUTHORITY)
       zzKillCount,zzDeathCount,zzShotCount,zzHitCount,zzPID;
   // Variables: server -> client that owns the class
   reliable if (bNetOwner && ROLE == ROLE_AUTHORITY)
       zzIndex,zzSelectedWeapon,zzDamageGiven,zzDamageReceived;
   // Functioncalls: server -> client
   reliable if (ROLE == ROLE_AUTHORITY)
       zzClientTick,zzResetAmmoCount,zzReplicateWeapon,zzReplicateGaveDamage,zzReplicateShotCount,zzReplicateHitCount;
   // Functioncalls: client -> server
   reliable if (ROLE < ROLE_AUTHORITY)
       zzServerReplicateShotCount,zzReplicateAllValues;
   // Variables: client -> server
   reliable if (ROLE < ROLE_AUTHORITY)
       bShowingScores;
}


// =============================================================================
// Initialize the class
// =============================================================================

function InitRI()
{
   local int i;

   P = Pawn(Owner);
   //zzPID = P.PlayerReplicationInfo.PlayerID;
   bDeleteObj = false;

   for (i=0;i<32;++i)
   {
       zzWeaponHistory[i] = -1;
   }
}

// =============================================================================
// Tick function, scan for weaponchanges here
// =============================================================================

function Tick (float DeltaTime)
{
   local int i;

   if (P == None)
   {
       // If UTStats is running we want to wait to destroy
       // the class until the variables have been logged
       if (!bUTStatsRunning || bDeleteObj)
           Destroy();
       return;
   }
   else
   {
       zzKillCount = P.KillCount;
       if (P.DieCount > zzDeathCount)
       {
           // Reset ammo counts - clientside
           zzResetAmmoCount();
       }
       zzDeathCount = P.DieCount;
   }

   if (((P.Weapon == None) || (!P.Weapon.bWeaponUp)))
   {
       LastWeapon = none;
       return;
   }

   // Weapon switch, process info
   if (LastWeapon != P.Weapon)
   {
       zzGetIndex(P.Weapon);
       LastWeapon = P.Weapon;
   }

   // Ammo Counting method is done clientside
   if (zzWI[zzSelectedWeapon].bAmmoCountingMethod)
   {
       zzClientTick();
   }

}
// =============================================================================
// zzClientTick ~ Scan for fired shots using the ammo counting method
// =============================================================================
//simulated function zzClientTick ()
function zzClientTick ()
{
  local int zzFiredShots;

  //if (Pawn(Owner).Weapon == None || !Pawn(Owner).Weapon.bWeaponUp || Pawn(Owner).Weapon.class != zzWI[zzSelectedWeapon].zzWeaponClass)
  //      return;
  if ( (Pawn(Owner).Weapon == None) || (Pawn(Owner).Weapon.AmmoType == None) ||  !Pawn(Owner).Weapon.bWeaponUp || (Pawn(Owner).Weapon.Class != zzWI[zzSelectedWeapon].zzWeaponClass) )
  {
    return;
  }

  zzFiredShots = zzWI[zzSelectedWeapon].zzAmmoCount - Pawn(Owner).Weapon.AmmoType.AmmoAmount;

  if ( zzFiredShots > 0 )
  {
    // Always replicate to server as server holds most accurate values!
    zzWI[zzSelectedWeapon].zzShotCount += zzFiredShots;
    zzShotCount += zzFiredShots;
    //zzServerReplicateShotCount(zzSelectedWeapon,zzWI[zzSelectedWeapon].zzShotCount);
  }

  zzWI[zzSelectedWeapon].zzAmmoCount = Pawn(Owner).Weapon.AmmoType.AmmoAmount;
}

// =============================================================================
// zzResetAmmoCount ~ Reset the ammo count for all weapons to zero
// =============================================================================
//simulated function zzResetAmmoCount ()
function zzResetAmmoCount ()
{
  local int i;

  for (i=0;i<zzIndex;++i)
  {
      zzWI[i].zzAmmoCount = 0;
  }
}

// =============================================================================
// zzGetIndex ~ Get the index of the weapon in the zzWI array
// =============================================================================

function zzGetIndex(Weapon zzWeapon)
{
   local int i;
   local bool bFound;

   if (zzIndex == 0)
   {
       zzSelectedWeapon = 0;
       zzUpdateHistory(0);
       zzInitWeapon(zzWeapon);
   }
   else
   {
       // Look for the weapon in the current list first
       for (i=0;i<zzIndex;++i)
       {
           if (zzWI[i].zzWeaponClass == zzWeapon.class)
           {
               zzSelectedWeapon = i;
               zzUpdateHistory(i);
               bFound = true;
           }
       }

       if (!bFound)
       {
           zzSelectedWeapon = zzIndex;
           zzUpdateHistory(zzIndex);
           zzInitWeapon(zzWeapon);
       }
   }

   zzWI[zzSelectedWeapon].zzWeapon = zzWeapon;
}

// =============================================================================
// zzInitWeapon ~ Called when the pawn has a weapon he hasn't used before
// =============================================================================

function zzInitWeapon(Weapon zzWeapon)
{
  zzWI[zzIndex].zzWeaponName = zzWeapon.ItemName;
  zzWI[zzIndex].zzWeaponClass = zzWeapon.class;
  zzWI[zzIndex].FirstDamageType = zzWeapon.MyDamageType;
  zzWI[zzIndex].AltDamageType = zzWeapon.AltDamageType;
  zzWI[zzIndex].zzShotCount = 0;
  zzWI[zzIndex].FirstProjClass = zzWeapon.default.ProjectileClass;
  zzWI[zzIndex].AltProjClass = zzWeapon.default.AltProjectileClass;
  
  zzWI[zzIndex].bIsAShockRifle = zzWeapon.IsA('ShockRifle');
  zzWI[zzIndex].bIsASuperShockRifle = zzWeapon.IsA('SuperShockRifle');

  // These weapontypes are easy to track using ammo counting
  //if (zzWeapon.IsA('Minigun2') || zzWeapon.IsA('Ripper') || zzWeapon.IsA('PulseGun') || zzWeapon.IsA('Enforcer') || zzWeapon.IsA('UT_FlakCannon') || zzWeapon.IsA('SniperRifle') || zzWeapon.IsA('AssaultRifle'))
  //  zzWI[zzIndex].bAmmoCountingMethod = true;
  
  zzWI[zzIndex].bAmmoCountingMethod =  !zzWeapon.IsA('ut_biorifle') || zzWeapon.IsA('UT_Eightball') || zzWeapon.IsA('ImpactHammer') || zzWeapon.IsA('Translocator');

  if ( zzWeapon.IsA('Translocator') || zzWeapon.IsA('ImpactHammer') )
  {
    zzWI[zzIndex].bIgnoreAccu = True;
  }

  if ( zzWI[zzIndex].bAmmoCountingMethod || zzWI[zzIndex].bIsASuperShockRifle )
  {
    zzWI[zzIndex].bAllowDoubleHit = True;
  }
  zzWI[zzIndex++ ].zzDamageGiven = 0.0;

  // Always replicate!
  //zzReplicateWeapon(zzIndex-1,zzWeapon.class,zzWeapon.ItemName);
}

// =============================================================================
// zzUpdateHistory ~ Used to hold the order of the weapons you had
// =============================================================================

function zzUpdateHistory(int CurrentWeapon)
{
   local int i, zzPosition;

   for (i=0;i<32;++i)
   {
       zzPosition = i;
       // Look for the position of CurrentWeapon in the history.
       if (zzWeaponHistory[i] == CurrentWeapon)
       {
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

function zzGaveDamage (name DamageType, int DamageGiven, Weapon W)
{
  local int i;
  local bool bWeaponFound;

  zzDamageGiven += DamageGiven; // Automatic replication

  // Look for the weapon that gives this damagetype in the history
  for (i=0;i<32;++i)
  {
    if (zzWeaponHistory[i] == -1)
      break;

    if (zzWI[zzWeaponHistory[i]].FirstDamageType == DamageType || zzWI[zzWeaponHistory[i]].AltDamageType == DamageType)
    {
      // found the weapon
      zzWI[zzWeaponHistory[i]].zzDamageGiven += DamageGiven;

      // Check if hitcount needs an update
      if (zzWI[zzWeaponHistory[i]].bAllowDoubleHit || (zzWI[zzWeaponHistory[i]].zzShotCount > zzWI[zzWeaponHistory[i]].zzLastShotCount))
      {
        zzWI[zzWeaponHistory[i]].zzHitCount++;
        zzHitCount++; // Automatic replication
      }

      zzWI[zzWeaponHistory[i]].zzLastShotCount = zzWI[zzWeaponHistory[i]].zzShotCount;
      bWeaponFound = True

      // Replicate if showing scores
      if (bShowingScores)
      {
        //zzReplicateGaveDamage(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzDamageGiven);
        //zzReplicateHitCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzHitCount);
      }
      break;
    }
  }
  // Perform alternative lookup
  if (!bWeaponFound)
  {
    for (i=0;i<32;++i)
    {
      if ( zzWeaponHistory[i] == -1 )
        break;

      if ( zzWI[zzWeaponHistory[i]].zzWeapon == W )
      {
        // found the weapon
        zzWI[zzWeaponHistory[i]].zzDamageGiven += DamageGiven;

        // Check if hitcount needs an update
        if (zzWI[zzWeaponHistory[i]].bAllowDoubleHit || (zzWI[zzWeaponHistory[i]].zzShotCount > zzWI[zzWeaponHistory[i]].zzLastShotCount))
        {
          zzWI[zzWeaponHistory[i]].zzHitCount++;
          zzHitCount++; // Automatic replication
        }

        zzWI[zzWeaponHistory[i]].zzLastShotCount = zzWI[zzWeaponHistory[i]].zzShotCount;
        bWeaponFound = True
      } 
    }
  }
}

// =============================================================================
// zzReceiveDamage ~ Called by DamageMut whenever the pawn receives damage
// =============================================================================

function zzReceivedDamage(int DamageReceived)
{
   zzDamageReceived += DamageReceived; // Automatic replication
}

// =============================================================================
// zzBeamMin/zzCombo ~ Called by DamageMut whenever the pawn fires a shockcombo
// =============================================================================
function zzCombo (Actor A)
{
  local int i;

  zzShotCount -= 3;
  for (i=0;i<32;++i)
  {
    if (zzWeaponHistory[i] == -1)
      break;

    if (zzWI[zzWeaponHistory[i]].bIsAShockRifle)
    {
      zzWI[zzWeaponHistory[i]].zzShotCount -= 3;
      if (bShowingScores)
      {
      //zzReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
      }
      break;
    }
  }
}

// =============================================================================
// zzProjPlus ~ Called by DamageMut whenever the pawn fires a projectile
// =============================================================================

function zzProjPlus (Actor A)
{
  local int i;

  for (i=0;i<32;++i)
  {
    if (zzWeaponHistory[i] == -1)
      break;

    if (zzWI[zzWeaponHistory[i]].FirstProjClass == A.class || zzWI[zzWeaponHistory[i]].AltProjClass == A.class)
    {
      // Ignore weapons we track by using the ammocountingmethod
      if (zzWI[zzWeaponHistory[i]].bAmmoCountingMethod)
        break;

      zzShotCount++; // Automatic replication
      zzWI[zzWeaponHistory[i]].zzShotCount++;

      if (bShowingScores)
      {
      //zzReplicateShotCount(zzWeaponHistory[i],zzWI[zzWeaponHistory[i]].zzShotCount);
      }
      break;
    }
  }
}

// =============================================================================
// Server -> Client Communication
// =============================================================================

simulated function zzReplicateWeapon(int zzIndex,class<Weapon> zzWeaponClass,string zzWeaponName)
{
    zzWI[zzIndex].zzWeaponClass = zzWeaponClass;
    zzWI[zzIndex].zzWeaponName = zzWeaponName;
}

simulated function zzReplicateGaveDamage(int i,int WeapDamageGiven)
{
    zzWI[i].zzDamageGiven = WeapDamageGiven;
}

simulated function zzReplicateShotCount(int i,int zzShotCount)
{
    zzWI[i].zzShotCount = zzShotCount;
}

simulated function zzReplicateHitCount(int i,int zzHitCount)
{
    zzWI[i].zzHitCount = zzHitCount;
}

// =============================================================================
// Client -> Server Communication
// =============================================================================

simulated function zzServerReplicateShotCount(int i,int zzNewShotCount)
{
    if (zzWI[i].bAmmoCountingMethod)
    {
        zzShotCount += (zzNewShotCount-zzWI[i].zzShotCount);
        zzWI[i].zzShotCount = zzNewShotCount;
    }
}

simulated function zzReplicateAllValues() // Called when client toggles scoreboard?
{
    local int i;

    for (i=0;i<zzIndex;++i)
    {
        zzReplicateGaveDamage(i,int(zzWI[i].zzDamageGiven));
        zzReplicateShotCount(i,zzWI[i].zzShotCount);
        zzReplicateHitCount(i,zzWI[i].zzHitCount);
    }
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
// Defaultproperties
// =============================================================================

defaultproperties
{
     NetPriority=10.000000
}
