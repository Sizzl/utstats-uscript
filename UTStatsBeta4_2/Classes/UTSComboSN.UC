//================================================================================
// UTSComboSN (from UTSAccu)
//================================================================================

class UTSComboSN extends SpawnNotify;

var UTSDamageMut UTSDM;

event Actor SpawnNotification (Actor A)
{
  if ( (A == None) || (A.Instigator == None) )
  {
    return A;
  }
  //UTSDM.zzBeamMin(A);
  UTSDM.zzCombo(A);
  return A;
}

defaultproperties
{
    ActorClass=Class'Botpack.UT_ComboRing'
}
