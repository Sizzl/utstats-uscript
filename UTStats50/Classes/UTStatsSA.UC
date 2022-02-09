// =============================================================================
//                        # # ### ### ###  #  ### ###
//                        # #  #  #    #  # #  #  #
//                        # #  #  ###  #  # #  #  ###
//                        # #  #    #  #  ###  #    #
//                        ###  #  ###  #  # #  #  ###
//                                   v5.0
// =============================================================================
// UTStats Team:
//     * Azazel (Main PHP Coder)
//     * Toa (PHP Coder)
//     * AnthraX (Unrealscript Coder)
// UTA Team:
//     * Cratos (Unrealscript Coder)
//     * Sizzl (aka Timo/Weirdo) (Unrealscript Coder, PHP Coder)
//     * brajan (PHP Coder)
// UTStats Forum:
//     * http://www.unrealadmin.org/forums/forumdisplay.php?f=173
// UTA Forum:
//     * https://forums.utassault.net
//
// Released under the Unreal Open MOD License (included in code repository)
// =============================================================================

class UTStatsSA extends Info;

var UTStats LocalLog;
var UTStatsAH UTSAH;

var UTSDamageMut UTSDM;

// =============================================================================
// PreBeginPlay ~ Call the gamecode fix before the assault class sets it
// =============================================================================
function PreBeginPlay ()
{
  Super.PreBeginPlay();
  if (  !Class'UTStats'.Default.bEnabled )
  {
    Log("### UTStats is Disabled!",'UTStats');
    Destroy();
    return;
  }
  if (  !Level.Game.IsA('Assault') )
  {
    return;
  }
  FixAssaultGameCode();
}

// =============================================================================
// PostBeginPlay ~ Setup UTStats
// =============================================================================
function PostBeginPlay ()
{
  local Mutator M;

  if (  !Class'UTStats'.Default.bEnabled )
  {
    Log("### UTStats is Disabled!",'UTStats');
    Destroy();
    return;
  }
  UTSDM = Level.Spawn(Class'UTSDamageMut');
  if ( UTSDM == None )
  {
    Log("### ERROR: Spawning UTSDamageMut failed!",'UTStats');
    return;
  }
  Level.Game.BaseMutator.AddMutator(UTSDM);
  UTSDM.bUTStatsRunning = True;
  LocalLog = Spawn(Class'UTStats');
  LocalLog.bWorld = False;
  LocalLog.UTSDM = UTSDM;
  UTSDM.zzLogger = LocalLog;
  
  LocalLog.StartLog();
  LocalLog.LogStandardInfo();
  LocalLog.LogServerInfo();
  LocalLog.LogMapParameters();
  for (M = Level.Game.BaseMutator; M != None; M = M.NextMutator)
  {
      LocalLog.AddMutator(M);
  }
  LocalLog.LogMutatorList();
  Level.Game.LogGameParameters(LocalLog);
  Level.Game.LocalLog = LocalLog;
  Level.Game.LocalLogFileName = LocalLog.GetLogFileName();
  
  // Spawn the messaging spectator that will parse assault messages
  if (!Level.Game.IsA('Assault'))
    return;

  UTSAH = Level.Spawn(Class'UTStatsAH');
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
     bHidden=True
}

