class UTSProjectileSN extends SpawnNotify;

var UTSDamageMut UTSDM;

simulated event Actor SpawnNotification(Actor A)
{
    if (A == None || UTSDM == None || A.Instigator == None)
        return A;

    // Ignore these types of projectiles to reduce load on the server
    if (A.IsA('MiniShellCase') || A.IsA('MTracer') || A.IsA('PBolt') || A.IsA('PlasmaSphere') || A.IsA('TranslocatorTarget'))
        return A;

    UTSDM.zzProjPlus(A);

    return A;
}

defaultproperties
{
     ActorClass=Class'Engine.Projectile'
}
