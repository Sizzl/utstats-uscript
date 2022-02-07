//-----------------------------------------------------------
//
//-----------------------------------------------------------
class SmartAS_SA expands Info;


function PreBeginPlay()
{
 	if (Level.Game.IsA('Assault') && class'SmartAS_Mutator'.default.bEnabled)
 	{
		log("SmartAS starting up...");
 		Level.Game.BaseMutator.AddMutator(Level.Spawn(class'SmartAS_Mutator'));
 	}
 	else
 	{
 	 	log("SmartAS: Not an assault game!",'SmartAS');
 	}
 	Destroy();
}

defaultproperties
{
}
