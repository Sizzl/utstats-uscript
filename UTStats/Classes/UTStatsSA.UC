//=============================================================================
// UTStats v1.0
// ------------
//
// Coding by azazel and PJMODOS
// For help/feedback go to www.unrealadmin.org
//
// About: Logs game events in sql format for stat collection
//
//=============================================================================

Class UTStatsSA expands Actor;

function PreBeginPlay()
{
	Level.Game.bLocalLog = false;
}

function PostBeginPlay()
{
	local StatLog LocalLog;

	Log("Initiating UTStats logging...");
	LocalLog = spawn(Class'UTStats.UTStats');
	LocalLog.bWorld = False;
	LocalLog.StartLog();
	LocalLog.LogStandardInfo();
	Level.Game.LocalLog = LocalLog;
//	Level.Game.LogGameParameters(Level.Game.LocalLog);
	Level.Game.LocalLogFileName = LocalLog.GetLogFileName();
}

defaultproperties
{
}
