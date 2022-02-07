class UTSProjectileSN extends SpawnNotify;

var UTSDamageMut UTSDM;

simulated event Actor SpawnNotification(Actor A)
{
    if (A == None || UTSDM == None || A.Instigator == None)
        return A;

    // Ignore Minigun/pulse/altbio shots and make flakshot count as 1 shot instead of 4
    if (A.IsA('MiniShellCase') || (A.IsA('UTChunk') && (A.IsA('UTChunk2') || A.IsA('UTChunk3') || A.IsA('UTChunk4'))) || A.IsA('MTracer') || A.IsA('BioSplash') || A.IsA('PBolt') || A.IsA('PlasmaSphere'))
        return A;

    UTSDM.ProjPlus(A);

    return A;
}

defaultproperties
{
      UTSDM=None
      ActorClass=Class'Engine.Projectile'
}
