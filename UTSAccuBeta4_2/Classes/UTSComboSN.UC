class UTSComboSN extends SpawnNotify;

var UTSDamageMut UTSDM;

simulated event Actor SpawnNotification(Actor A)
{
    if (A == None || A.Instigator == None)
        return A;

    UTSDM.zzBeamMin(A);

    return A;
}

defaultproperties
{
      UTSDM=None
      ActorClass=Class'Botpack.UT_ComboRing'
}
