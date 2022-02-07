//================================================================================
// UTStatsAH.
//================================================================================

class UTStatsAH extends MessagingSpectator
  Config(User);

struct FortInfo
{
  var FortStandard zzFS;
  var bool bTaken;
  var string zzFortName;
};

var UTStats zzLogger;
var Assault zzAssault;
var bool bEndGame,bFinalObj;
var int zzNumForts, zzRemForts;
var FortInfo zzFI[16];
// =============================================================================
// zzSetup ~ Setup the class
// =============================================================================
function zzSetup ()
{
  local FortStandard zzFS;
  local string zzFortName;

  zzNumForts = 0;
  zzLogger.LogEventString(zzLogger.GetTimeStamp() $ Chr(9) $ "assault_timelimit" $ Chr(9) $ string(zzAssault.TimeLimit));
  zzLogger.LogEventString(zzLogger.GetTimeStamp() $ Chr(9) $ "assault_gamecode" $ Chr(9) $ zzAssault.GameCode $ Chr(9) $ string(zzAssault.Part));
  foreach Level.AllActors(Class'FortStandard',zzFS)
  {
    zzFI[zzNumForts].zzFortName = GetFortName(zzFS);
    if ( zzFS.bFinalFort && (zzFI[zzNumForts].zzFortName == "") )
    {
      zzFI[zzNumForts].zzFortName = "F" $ "inal Objective";
    }
    if ( zzFI[zzNumForts].zzFortName != "" )
    {
      zzLogger.LogEventString(zzLogger.GetTimeStamp() $ Chr(9) $ "assault_objname" $ Chr(9) $ string(zzNumForts) $ Chr(9) $ zzFI[zzNumForts].zzFortName $ Chr(9) $ zzFS.DestroyedMessage);
      zzLogger.LogSpecialEvent("assault_objinfo",string(zzNumForts),string(zzFS.DefensePriority),string(zzFS.DefenseTime));
    }
    zzFI[zzNumForts].zzFS = zzFS;
    zzFI[zzNumForts++ ].bTaken = False;
  }
  zzRemForts = zzNumForts;
}
// =============================================================================
// GetFortName ~ Added by cratos
// =============================================================================
function string GetFortName(FortStandard F)
{
  if ((F.FortName == "Assault Target") || (F.FortName == "") || (F.FortName == " "))
    return "";
  else
    return F.FortName;
}

// =============================================================================
// ClientMessage ~ Parse assault events
// =============================================================================

event ClientMessage( coerce string S, optional name Type, optional bool bBeep )
{
  local int i;
  local bool bObjFound;

  if (Type != 'CriticalEvent' || (bEndGame && bFinalObj))
     return;

  bObjFound = true;

  while (bObjFound)
  {
     bObjFound = false;

     for (i=0;i<zzNumForts;++i)
     {
        if (!zzFI[i].bTaken && zzFI[i].zzFS.Instigator.IsA('Pawn') && !zzFI[i].zzFS.Instigator.IsA('FortStandard'))
        {
          zzFI[i].bTaken = true;
          zzRemForts--;

          if ((zzRemForts == 0) || zzFI[i].zzFS.bFinalFort)
             bFinalObj = true;

          if (zzFI[i].zzFortName != "")
             zzLogger.LogAssaultObj(bFinalObj,zzFI[i].zzFS.Instigator.PlayerReplicationInfo.PlayerID,i);
          bObjFound = true;

          break;
        }
     }
  }
}

// =============================================================================
// We don't need these
// =============================================================================

event TeamMessage (PlayerReplicationInfo PRI, coerce string S, name Type, optional bool bBeep) {}
function ClientVoiceMessage (PlayerReplicationInfo Sender, PlayerReplicationInfo Recipient, name messagetype, byte messageID) {}

// =============================================================================
// Defaultproperties
// =============================================================================

defaultproperties
{
}
