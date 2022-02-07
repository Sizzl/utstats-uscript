class UTStatsSA extends Actor;

var UTStats LocalLog;
var UTStatsAH UTSAH;

var UTSDamageMut UTSDM;

var UTSProjectileSN UTSPSN;
var UTSEffectsSN UTSESN;

function PostBeginPlay()
{
    local Mutator M;

    // Spawn the mutator that will handle the accuracy
    UTSDM = UTSDamageMut(FindMutator("UTSDamageMut"));
    if (UTSDM == None)
    {
	    Level.Game.BaseMutator.AddMutator(Level.Spawn(class'UTSDamageMut'));
	    UTSDM = UTSDamageMut(FindMutator("UTSDamageMut"));

	    if (UTSDM == None)
	    {
	        Log("### ERROR: UTStats cannot run without the UTSAccu package!");
	        goto 'xEnd';
	    }
	    UTSDM.bNoTeamGame = !Level.Game.bTeamGame;

	    // Spawn projectile/effects catchers
        UTSPSN = Level.Spawn(class'UTSProjectileSN');
        UTSPSN.UTSDM = UTSDM;
        UTSESN = Level.Spawn(class'UTSEffectsSN');
        UTSESN.UTSDM = UTSDM;
    }
    Log("### UTSAccu package found");

    // Spawn the statlog class
	LocalLog = spawn(Class'UTStats');
	LocalLog.bWorld = False;
	LocalLog.UTSDM = UTSDM;
	LocalLog.StartLog();
	LocalLog.LogStandardInfo();
	LocalLog.LogServerInfo();
    LocalLog.LogMapParameters();
    for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
        LocalLog.LogMutator(M);
    Level.Game.LogGameParameters(LocalLog);
	Level.Game.LocalLog = LocalLog;
	Level.Game.LocalLogFileName = LocalLog.GetLogFileName();

	// Spawn the messaging spectator that will parse assault messages
	if (!Level.Game.IsA('Assault'))
	  return;

	UTSAH = Level.Spawn(class'UTStatsAH');
	UTSAH.zzLogger = LocalLog;
	UTSAH.zzAssault = Assault(Level.Game);

	LocalLog.UTSAH = UTSAH;

	xEnd:
}

// =============================================================================
// FindMutator function
// =============================================================================

function Mutator FindMutator (string MutName)
{
   local Mutator M;

   M = Level.Game.BaseMutator;

   while (M != None)
   {
       if (InStr(M.class,MutName) != -1)
           return M;
       else
           M = M.NextMutator;
   }

   return M;
}

defaultproperties
{
      LocalLog=None
      UTSAH=None
      UTSDM=None
      UTSPSN=None
      UTSESN=None
      bHidden=True
}
