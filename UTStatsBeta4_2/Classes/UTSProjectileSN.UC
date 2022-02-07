//================================================================================
// UTSProjectileSN (from UTSAccu)
//================================================================================

class UTSProjectileSN extends SpawnNotify;

var UTSDamageMut UTSDM;

event Actor SpawnNotification (Actor A)
{
  if ( (A == None) || (A.Instigator == None) )
  {
    return A;
  }
  // Ignore these types of projectiles to reduce load on the server
  //if (A.IsA('MiniShellCase') || A.IsA('MTracer') || A.IsA('PBolt') || A.IsA('PlasmaSphere') || A.IsA('TranslocatorTarget'))
  //{
  //  return A;
  //}
  if ( A.IsA('RocketMk2') || A.IsA('UT_Grenade') || A.IsA('UT_BioGel') )
  {
    UTSDM.zzProjPlus(A);
  }
  return A;
}

defaultproperties
{
    ActorClass=Class'Engine.Projectile'

}
