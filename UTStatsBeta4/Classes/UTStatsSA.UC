// =============================================================================
//                        # # ### ### ###  #  ### ###
//                        # #  #  #    #  # #  #  #
//                        # #  #  ###  #  # #  #  ###
//                        # #  #    #  #  ###  #    #
//                        ###  #  ###  #  # #  #  ###
//                                 Beta 4.2
// =============================================================================
// UTStats Team:
//     * Azazel (Main PHP Coder)
//     * Toa (PHP Coder)
//     * AnthraX (Unrealscript Coder)
// UTStats Forum:
//     * http://www.unrealadmin.org/forums/forumdisplay.php?f=173
// Released under the Unreal Open MOD License (included in zip package)
// =============================================================================

class UTStatsSA extends Actor;

var UTStats LocalLog;
var UTStatsAH UTSAH;

var UTSDamageMut UTSDM;

// =============================================================================
// PreBeginPlay ~ Call the gamecode fix before the assault class sets it
// =============================================================================

function PreBeginPlay()
{
    Super.PreBeginPlay();

    if (!Level.Game.IsA('Assault'))
        return;

    FixAssaultGameCode();
}

// =============================================================================
// PostBeginPlay ~ Setup UTStats
// =============================================================================

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
	        return;
	    }
    }
    //Log("### UTSAccu package linked!");

    UTSDM.bUTStatsRunning = true;

    // Spawn the statlog class and log standard info
	LocalLog = spawn(Class'UTStats');
	LocalLog.bWorld = False;
	LocalLog.UTSDM = UTSDM;
	LocalLog.StartLog();
	LocalLog.LogStandardInfo();
	LocalLog.LogServerInfo();
    LocalLog.LogMapParameters();
    for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
        LocalLog.AddMutator(M);
    LocalLog.LogMutatorList();
    Level.Game.LogGameParameters(LocalLog);
	Level.Game.LocalLog = LocalLog;
	Level.Game.LocalLogFileName = LocalLog.GetLogFileName();

	// Spawn the messaging spectator that will parse assault messages
	if (!Level.Game.IsA('Assault'))
	  return;

	UTSAH = Level.Spawn(class'UTStatsAH');
	UTSAH.zzLogger = LocalLog;
	UTSAH.zzAssault = Assault(Level.Game);
	UTSAH.zzSetup();

	LocalLog.UTSAH = UTSAH;
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

// =============================================================================
// FixAssaultGameCode ~ Cratos' fix for some epic fuckup
// =============================================================================

function FixAssaultGameCode()
{
	local int i;
	local int num;

	if (Assault(Level.Game).GameCode  == "")
	{
		while (i<8)
		{
			Num = Rand(123);
			if ( ((Num >= 48) && (Num <= 57)) ||
				 ((Num >= 65) && (Num <= 91)) ||
				((Num >= 97) && (Num <= 123)) )
			{
				Assault(Level.Game).GameCode  = Assault(Level.Game).GameCode $ Chr(Num);
				i++;
			}
		}
	}
}


// =============================================================================
// Defaultproperties
// =============================================================================

defaultproperties
{
      LocalLog=None
      UTSAH=None
      UTSDM=None
      bHidden=True
}
