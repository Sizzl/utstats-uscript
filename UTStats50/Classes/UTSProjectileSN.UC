//================================================================================
// UTSProjectileSN (from UTSAccu)
//================================================================================

class UTSProjectileSN extends SpawnNotify;

var UTSDamageMut UTSDM;

simulated event Actor SpawnNotification (Actor A)
{
  if ( (A == None) || (A.Instigator == None) )
  {
    return A;
  }
  // Explicitly include only what we want to track, otherwise it'll add load
  if ( A.IsA('RocketMk2') || A.IsA('UT_Grenade') || A.IsA('UT_BioGel') )
  {
    UTSDM.zzProjPlus(A);
  }
  return A;
}

defaultproperties
{
    ActorClass=Class'Engine.Projectile'
    RemoteRole=ROLE_SimulatedProxy
}
