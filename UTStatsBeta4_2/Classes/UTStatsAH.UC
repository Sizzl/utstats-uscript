class UTStatsAH extends MessagingSpectator;

var UTStats zzLogger;
var Assault zzAssault;
var bool bEndGame,bFinalObj;
var int zzNumForts, zzRemForts;

struct FortInfo
{
	var FortStandard zzFS;
	var bool bTaken;
	var string zzFortName;
};

var FortInfo zzFI[16];

// =============================================================================
// zzSetup ~ Setup the class
// =============================================================================

function zzSetup()
{
	local FortStandard zzFS;
	local string zzFortName;

	zzNumForts = 0;

	zzLogger.LogEventString(zzLogger.GetTimeStamp()$Chr(9)$"assault_timelimit"$chr(9)$zzAssault.TimeLimit);
	zzLogger.LogEventString(zzLogger.GetTimeStamp()$Chr(9)$"assault_gamecode"$chr(9)$zzAssault.GameCode$chr(9)$zzAssault.Part);

	foreach Level.AllActors(class'FortStandard',zzFS)
	{
		 zzFI[zzNumForts].zzFortName = GetFortName(zzFS);
		 if (zzFI[zzNumForts].zzFortName != "")
		 {
			  zzLogger.LogEventString(zzLogger.GetTimeStamp()$Chr(9)$"assault_objname"$chr(9)$zzNumForts$chr(9)$zzFI[zzNumForts].zzFortName);
		 }
		 zzFI[zzNumForts].zzFS = zzFS;
		 zzFI[zzNumForts++].bTaken = false;
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
      zzLogger=None
      zzAssault=None
      bEndGame=False
      bFinalObj=False
      zzNumForts=0
      zzRemForts=0
      zzFI(0)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(1)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(2)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(3)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(4)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(5)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(6)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(7)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(8)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(9)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(10)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(11)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(12)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(13)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(14)=(zzFS=None,bTaken=False,zzFortName="")
      zzFI(15)=(zzFS=None,bTaken=False,zzFortName="")
}
