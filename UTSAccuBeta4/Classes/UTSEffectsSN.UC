class UTSEffectsSN extends SpawnNotify;

var UTSDamageMut UTSDM;

simulated event Actor SpawnNotification(Actor A)
{
    if (A == None || UTSDM == None || A.Instigator == None)
        return A;

    // Player fired shock/supershockrifle
    if (A.IsA('ShockBeam') || A.IsA('SuperShockBeam'))
    {
        UTSDM.zzEffectPlus(A);
    }
    // Player had a shockcombo
    else if (A.IsA('UT_ComboRing'))
    {
        UTSDM.zzEffectMin(A);
    }

    return A;
}

defaultproperties
{
     ActorClass=Class'Engine.Effects'
}
