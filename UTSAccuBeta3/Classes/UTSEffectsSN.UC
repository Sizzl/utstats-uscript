class UTSEffectsSN extends SpawnNotify;

var UTSDamageMut UTSDM;

simulated event Actor SpawnNotification(Actor A)
{
    if (A == None || UTSDM == None || A.Instigator == None)
        return A;

    // Ignore minigun ~ mingun stuff is handled by the damagemut
    if (A.IsA('UT_LightWallHitEffect') || A.IsA('UT_SpriteSmokePuff'))
    {
        return A;
    }
    // Player fired shock/supershockrifle
    else if (A.IsA('ShockBeam') || A.IsA('SuperShockBeam'))
    {
        UTSDM.EffectPlus(A);
    }
    // Player had a shockcombo
    else if (A.IsA('UT_ComboRing'))
    {
        UTSDM.EffectMin(A);
    }

    return A;
}

defaultproperties
{
      UTSDM=None
      ActorClass=Class'Engine.Effects'
}
