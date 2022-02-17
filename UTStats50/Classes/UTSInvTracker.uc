//==================================================================//
// Inventory damage tracking for UTStats - sizzl@utassault.net      //
//                                                                  //
// Simply keeps a log of the last bit of damage done so that the    //
// MutateTakeDamage function, which fires after inventory items are //
// processed, can keep tabs on the afflicted damage to the victim.  //
//==================================================================//
class UTSInvTracker extends TournamentPickup;

// DT struct definition
struct DamageTracking
{
    var int InDamage,Damage,ReducedAmount,ReturnDamage,InHealth,InArmour;
    var name DamageType;
    var vector HitLocation;
    var Inventory Armour;
};

var UTSDamageMut UTSDM;
var DamageTracking DT;
var bool bNoRespawn;

state Activated
{

Begin:
    if (Owner == None)
    {
        bNoRespawn = true;
        if (UTSDM.bDebug)
            log("### UTSIT: Removing abandoned Inventory tracker",'UTStats');
        Destroy();
    }
    else
    {
        if (UTSDM.bDebug)
            log("### UTSIT: Activating Inventory Tracker for"@Owner,'UTStats');
    }
}

state DeActivated
{

Begin:
    if (UTSDM.bDebug)
        log("### UTSIT: Deactivating Inventory Tracker for"@Owner,'UTStats');
}

function bool CheckSpawnProtection()
{
    local Inventory Inv;
    local int i;
    for ( Inv=Owner.Inventory; Inv!=None; Inv=Inv.Inventory )
    {
        if (InStr(string(Inv.class),"LeagueAS_Inventory") > 0)
        {
            if (Inv.GetPropertyText("SpawnProtectActive") ~= "True")
            {
                if (UTSDM.bDebug)
                    log("### UTSIT: LAS spawn protection active",'UTStats');
                return true;
            }
        }
        i++;
        if (i > 100)
            break;
    }
    return false;
}

function int ArmorAbsorbDamage(int Damage, name DamageType, vector HitLocation)
{
    local Inventory Inv, FirstArmor;
    local int i, InvCount, ReducedAmount, ReturnDamage, lastPri, InCharge;
    if (UTSDM.bDebug)
        log("### UTSIT: Damage-"@Damage$", type:"@DamageType$", location:"@HitLocation,'UTStats');

    if (CheckSpawnProtection())
    {
        return 0;
    }
    i = 0;
	DT.InDamage = Damage;
    ReturnDamage = Damage;
    for ( Inv=Owner.Inventory; Inv!=None; Inv=Inv.Inventory )
    {
        if ( Inv.bIsAnArmor && (Inv != self) )
        {
            if (UTSDM.bDebug)
                log("### UTSIT: Detected armour-"@Inv$", for owner:"@Owner,'UTStats');
            InCharge+=Inv.Charge;
            InvCount++;
        }
        else if (Inv.IsA('UTSInvTracker'))
        {
        	if (Inv != self)
        	{
	            if (UTSDM.bDebug)
	                log("### UTSIT: Removing duplicate IT:"@Inv,'UTStats');
	            UTSInvTracker(Inv).bNoRespawn=True;
	            Inv.Destroy();
        	}
        	else
        	{
                UTSInvTracker(Inv).default.AbsorptionPriority = 0;
                UTSInvTracker(Inv).default.bIsAnArmor = false;
                Inv.AbsorptionPriority = 0;
                Inv.bIsAnArmor = false;
        	}
        }
        i++;
        if (i > 100)
            break;
    }
    DT.InHealth = PlayerPawn(Owner).Health;
    DT.InArmour = InCharge;
    if (InvCount > 0)
    {
        FirstArmor=Inventory.PrioritizeArmor(Damage, DamageType, HitLocation);
        if (UTSDM.bDebug)
        {
            log("### UTSIT: Sending RD to other armours - D="$Damage,'UTStats');
            log("### UTSIT: First armour-"@FirstArmor$", next armour-"@nextArmor);
        }
        if (FirstArmor == None && nextArmor == None)
        {
            // Manually prioritise order of armours
            lastPri = 0;
            i = 0;
            for ( Inv=Owner.Inventory; Inv!=None; Inv=Inv.Inventory )
            {
                if ( Inv.bIsAnArmor && (Inv != self) )
                {
                    if (Inv.AbsorptionPriority > lastPri)
                    {
                        nextArmor = Inv;
                    }
                }
                i++;
                if (i > 100)
                    break;
            }
        }
        if (FirstArmor == None && nextArmor != None)
        {
        	FirstArmor = nextArmor;
		}
        if (UTSDM.bDebug)
            log("### UTSIT: Looping"@Damage@"damage through"@FirstArmor$", using ReduceDamage",'UTStats');
        ReducedAmount = Super.ReduceDamage(Damage, DamageType, HitLocation);
        ReturnDamage = ReducedAmount;
    }

    DT.Armour = FirstArmor;
    DT.Damage = Damage;
    DT.ReducedAmount = ReducedAmount;
    DT.ReturnDamage = ReturnDamage;
    DT.DamageType = DamageType;
    DT.HitLocation = HitLocation;
    return ReturnDamage;    
    
}

function ResetInvTracker()
{
    local Inventory Inv;
    local int i;
    for ( Inv=Owner.Inventory; Inv!=None; Inv=Inv.Inventory )
    {
        if (Inv.IsA('UTSInvTracker'))
        {
            UTSInvTracker(Inv).default.AbsorptionPriority = 500;
            UTSInvTracker(Inv).default.bIsAnArmor = true;
            Inv.AbsorptionPriority = 500;
            Inv.bIsAnArmor = true;
        }
        i++;
        if (i > 100)
            break;
    }
}

function Destroyed()
{
    local UTSInvTracker UTSIT;
    local bool bDebug;

    // Shield belt kills other armours, so we need to respawn to continue tracking
    // Temporarily disable any debugging to reduce log spam.
    if (Owner.IsA('PlayerPawn') && !bNoRespawn)
    {
        UTSIT = Spawn(class'UTSInvTracker',Owner);    
        if ( UTSIT != None )
        {
            UTSIT.UTSDM = self.UTSDM;
            UTSIT.bHeldItem = false;
            UTSIT.GiveTo(PlayerPawn(Owner));
            bDebug = UTSDM.bDebug;
            UTSDM.bDebug = false;
            UTSIT.Activate();
            UTSDM.bDebug = bDebug;
        }
    }
    Super.Destroyed();
}

defaultproperties
{
    bAutoActivate=True
    bActivatable=True
    bDisplayableInv=False
    bIsAnArmor=True
    ItemName="UTS Inventory Tracker"
    Charge=0
    ProtectionType1=ProtectNone
    ProtectionType2=ProtectNone
    MaxDesireability=0
    RemoteRole=ROLE_DumbProxy
    CollisionRadius=0
    CollisionHeight=0
    bHidden=True
    AbsorptionPriority=500
    ArmorAbsorption=0
    bOwnerNoSee=True
    bOnlyOwnerSee=True
    bCarriedItem=True
}

