//================================================================================
// UTSComboSN (from UTSAccu)
//================================================================================

class UTSComboSN extends SpawnNotify;

var UTSDamageMut UTSDM;

simulated event Actor SpawnNotification (Actor A)
{
  if ( (A == None) || (A.Instigator == None) )
  {
    return A;
  }
  UTSDM.zzCombo(A);
  return A;
}

defaultproperties
{
    ActorClass=Class'Botpack.UT_ComboRing'
    RemoteRole=ROLE_SimulatedProxy
}
