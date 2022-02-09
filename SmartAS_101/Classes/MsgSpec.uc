//-----------------------------------------------------------
//
//-----------------------------------------------------------
class MsgSpec expands MessagingSpectator;

var SmartAS_Mutator SmartAS;
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

	zzNumForts = 0;

	foreach Level.AllActors(class'FortStandard',zzFS)
	{
		 zzFI[zzNumForts].zzFortName = GetFortName(zzFS);
		 if (zzFI[zzNumForts].zzFortName != "")
		 {
			if(Level.Game.LocalLog != None)
				SmartAS.LogSpecialEvent("assault_objinfo",zzNumForts,zzFS.DefensePriority,zzFS.DestroyedMessage);
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
						SmartAS.RemoveFort(zzFI[i].zzFS, zzFI[i].zzFS.Instigator, bFinalObj,i);
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
