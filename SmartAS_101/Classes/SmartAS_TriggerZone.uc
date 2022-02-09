// =============================================================================
//  SmartASS extension - sizzl@utassault.net
// =============================================================================
class SmartAS_TriggerZone expands TeamTrigger;
var int Rating;
var bool bDebug;

function Touch( Actor A )
{
	if ( IsRelevant(A) && Pawn(A).bIsPlayer && PlayerPawn(A) != None)
	{
		if (bDebug)
			log("-->"@PlayerPawn(A).PlayerReplicationInfo.PlayerName$", entered a Rated TZ, value:"@Rating);
	}
}

function UnTouch( Actor A )
{
	if ( IsRelevant(A) && Pawn(A).bIsPlayer && PlayerPawn(A) != None )
	{
		if (bDebug)
			log("-->"@PlayerPawn(A).PlayerReplicationInfo.PlayerName$", left a Rated TZ, value:"@Rating);
	}
}

defaultproperties
{
	Rating=0 // -1 = "Low", 0 = "Normal", 1 = "High"
	Team=0 // attackers only
}
