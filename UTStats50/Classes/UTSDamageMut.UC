//================================================================================
// UTSDamageMut (from UTSAccu)
// =============================================================================
//              Forked from the UTS Accuracy Package Beta 4.2
//                                   ~
//                    UTStats - UTPro statistics addon
//                        © 2005 )°DoE°(-AnthraX
//               Updated in 2006 by Cratos (utassault.net)
//       Updated in 2021 by Sizzl (utassault.net - discord.gg/unbFxh2t66)
// =============================================================================
// Released under the Unreal Open MOD License (included in zip package)
// =============================================================================

class UTSDamageMut extends Mutator;

struct PlayerInfo
{
  var UTSReplicationInfo zzRI;
  var int zzPID;
};

var PlayerInfo zzPI[33];
var int CurrentID;
var bool bNoTeamGame, bUTStatsRunning, bInsta, bInventoryHook, bDebug;
var UTStats zzLogger;

// =============================================================================
// Setup the damagemut
// =============================================================================

function PostBeginPlay()
{
   local int i;
   local UTSProjectileSN UTSPSN;
   local UTSComboSN UTSCSN;

   for (i=0;i<32;++i)
      zzPI[i].zzPID = -1;

   Level.Game.RegisterDamageMutator(self);

   bNoTeamGame = !Level.Game.bTeamGame;

   // Spawn projectile/effects catchers
   UTSPSN = Level.Spawn(class'UTSProjectileSN');
   UTSPSN.UTSDM = self;
   UTSCSN = Level.Spawn(class'UTSComboSN');
   UTSCSN.UTSDM = Self;
}

// =============================================================================
// Mutate capture
// =============================================================================

function Mutate(string MutateString, PlayerPawn Sender)
{
    local UTSInvTracker UTSInv;
    local Inventory Inv;

    if (MutateString~="uts" || MutateString~="uts info")
    {

        Sender.ClientMessage("UTStats Damage Tracking Mutator");
        if (zzLogger != None)
        {
            Sender.ClientMessage(" - Version:"@zzLogger.zzVersion);
            Sender.ClientMessage(" - Enabled:"@string(zzLogger.bEnabled));
        }
        if (bDebug)
            Sender.ClientMessage(" - Debugging: Enabled!");
    }

    if (zzLogger != None && zzLogger.bEnabled)
    {
        if (MutateString~="uts debug")
        {
            if (zzLogger.bDebug == true) {
                zzLogger.bDebug = false;
                bDebug = false;
                Sender.ClientMessage("Debugging disabled");
            } else {
                zzLogger.bDebug = true;
                bDebug = true;
                Sender.ClientMessage("Debugging enabled");
            }
            zzLogger.SaveConfig();

        }
    }
    if (MutateString~="uts killinv" || MutateString~="uts kill inv")
    {
        for ( Inv=Sender.Inventory; Inv!=None; Inv=Inv.Inventory )
        {
            if (Inv.IsA('UTSInvTracker'))
            {
                UTSInvTracker(Inv).bNoRespawn = true;
                UTSInvTracker(Inv).Destroy();
            }
        }
        Sender.ClientMessage("* All your inventory hooks have been destroyed.");
        if (Sender.bAdmin)
            Sender.ClientMessage("* Use 'mutate uts enable inv' to re-enable inventory hooks.");
        else
            Sender.ClientMessage("* Reconnect to re-enable inventory hooks.");
    }
    else if (Sender.bAdmin && (MutateString~="uts killallinv" || MutateString~="uts killall inv"))
    {
        foreach AllActors(Class'UTSInvTracker',UTSInv)
        {
                UTSInv.bNoRespawn = true;
                UTSInv.Destroy();
        }
        Sender.ClientMessage("* -All- player inventory hooks have been destroyed.");
        Sender.ClientMessage("* Use 'mutate uts enable inv' to re-enable inventory hooks.");
    }
    else if (Sender.bAdmin && (MutateString~="uts disable inv" || MutateString~="uts noinv"))
    {
        // Temporary disables inventory hooking for the map
        bInventoryHook = false;
        Sender.ClientMessage("* Inventory hooking temporarily disabled.");
        Sender.ClientMessage("* Use 'mutate uts enable inv' to renable inventory hooks.");
    }
    else if (Sender.bAdmin && (MutateString~="uts enable inv" || MutateString~="uts enableinv"))
    {
        // Enables inventory hooking for the map
        if (bInventoryHook == false)
        {
            bInventoryHook = true;
            zzHookInventory(Sender);
            Sender.ClientMessage("* Inventory hooking enabled for you. Other players will need to reconnect.");
        }
        else
        {
            Sender.ClientMessage("* Inventory hooking is already enabled. Use 'mutate uts disable inv' or 'mutate uts kill inv' to disable.");
        }
    }
    if ( NextMutator != None )
        NextMutator.Mutate(MutateString, Sender);
}

// =============================================================================
// MutatorTakeDamage ~ Handle damage and dispatch to the right Replicationclass
// =============================================================================

function MutatorTakeDamage( out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
    local int i, VictimPID, InstigatorPID, TotalDamage;
    local bool bVictimFound, bInstigatorFound;
    local Inventory Inv;
    
    if (zzLogger != None)
        bDebug = zzLogger.bDebug;
    TotalDamage = ActualDamage; // MTD occurs after Inventory absorbs damage, so we're going to rewind this and get the TotalDamage
    if (Victim.IsA('PlayerPawn'))
        Inv = PlayerPawn(Victim).FindInventoryType(class'UTSInvTracker');
    if ( Inv != None )
    {
        // Check for spawn protection, then go fetch inventory damage stats
        if (ActualDamage == 0 && UTSInvTracker(Inv).CheckSpawnProtection())
        {
            if (bDebug)
                log("### MTD: UTSInvTracker"@Inv$", LAS spawn protection is active.",'UTStats');
        }
        else
        {
            if (bDebug)
            {
                log("### MTD: UTSInvTracker"@Inv,'UTStats');
                log("###    - DT: ID-"@UTSInvTracker(Inv).DT.InDamage$", D-"@UTSInvTracker(Inv).DT.Damage$", RA-"@UTSInvTracker(Inv).DT.ReducedAmount$", RT-"@UTSInvTracker(Inv).DT.ReturnDamage$", L-"@UTSInvTracker(Inv).DT.HitLocation,'UTStats');
            }
            TotalDamage = UTSInvTracker(Inv).DT.InDamage;
        }
        UTSInvTracker(Inv).ResetInvTracker();
    }
    if (bDebug)
    {
        if (InstigatedBy.IsA('PlayerPawn') && Victim.IsA('PlayerPawn'))
            log("### MTD:"@InstigatedBy.PlayerReplicationInfo.PlayerName@"->"@Victim.PlayerReplicationInfo.PlayerName@": TotDmg:"@TotalDamage$", MTD-Dmg ="@ActualDamage,'UTStats');
        else if (InstigatedBy.IsA('PlayerPawn') && !(Victim.IsA('PlayerPawn')))
            log("### MTD:"@InstigatedBy.PlayerReplicationInfo.PlayerName@"->"@Victim@": TotDmg:"@TotalDamage$", MTD-ActDmg ="@ActualDamage,'UTStats');
        else if (!(InstigatedBy.IsA('PlayerPawn')) && (Victim.IsA('PlayerPawn')))
            log("### MTD:"@InstigatedBy@"->"@Victim.PlayerReplicationInfo.PlayerName@": TotDmg:"@TotalDamage$", MTD-ActDmg ="@ActualDamage,'UTStats');
        else
            log("### MTD:"@InstigatedBy@"->"@Victim@": Dmg ="@ActualDamage,'UTStats');
    }
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
            zzPI[i].zzRI.zzReceivedDamage(TotalDamage);
            bVictimFound = true;
        }
        if (!bInstigatorFound && (zzPI[i].zzPID == InstigatorPID) && (zzPI[i].zzRI != None))
        {
            if ((Victim != InstigatedBy) && (bNoTeamGame || Victim.PlayerReplicationInfo.Team != InstigatedBy.PlayerReplicationInfo.Team))
                zzPI[i].zzRI.zzGaveDamage(DamageType,TotalDamage,instigatedBy.Weapon, Victim);
            bInstigatorFound = true;
        }
        if (bVictimFound && bInstigatorFound)
            break;
    }
    if (bDebug)
        log("----",'UTStats');
    if (NextDamageMutator != None)
        NextDamageMutator.MutatorTakeDamage(ActualDamage,Victim,InstigatedBy,HitLocation,Momentum,DamageType); // Send original ActualDamage
}

// =============================================================================
// GetAttributableDamage ~ Called by UTStats to loop through RIs and get damage
// =============================================================================
function GetAttributableDamage(int VictimPID)
{
    local int i;
    for (i=0;i<32;++i)
    {
        if (zzPI[i].zzPID > -1 && zzPI[i].zzRI != None)
        {
            zzPI[i].zzRI.GetPlayerDamage(zzLogger,VictimPID);
        }
    }
}

// =============================================================================
// zzCombo ~ Called by UTSProjectileSN when Actor A performs a combo
// =============================================================================
function zzCombo (Actor A)
{
  local int i;

    for (i=0;i<32;++i)
    {
        if ( zzPI[i].zzPID == A.Instigator.PlayerReplicationInfo.PlayerID )
        {
            zzPI[i].zzRI.zzCombo(A);
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
// zzHookInventory ~ Hooks player inventory
// =============================================================================
function zzHookInventory (Pawn P)
{
    local UTSInvTracker UTSIT;
    if (bInventoryHook)
        UTSIT = Spawn(class'UTSInvTracker',P);
    if ( UTSIT != None )
    {
        if (bDebug)
            log("### UTSDM: Giving"@UTSIT$", to player:"@P,'UTStats');
        UTSIT.UTSDM = self;
        UTSIT.bHeldItem = false;
        UTSIT.GiveTo(P);
        UTSIT.Activate();
    }
}

// =============================================================================
// zzInitPlayer ~ Initialize a new pawn
// =============================================================================

function zzInitPlayer (Pawn P)
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

    zzHookInventory(P);

    zzPI[i].zzRI = Spawn(class'UTSReplicationInfo',P,,P.Location);
    zzPI[i].zzRI.bUTStatsRunning = bUTStatsRunning;
    zzPI[i].zzRI.bDebug = bDebug;
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
/*
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
*/
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
            zzPI[i].zzRI.zzCombo(A);
            break;
        }
    }
}

defaultproperties
{
    bInventoryHook=True
}