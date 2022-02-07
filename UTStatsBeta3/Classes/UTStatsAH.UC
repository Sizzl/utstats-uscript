class UTStatsAH extends MessagingSpectator;

var UTStats zzLogger;
var Assault zzAssault;
var bool bEndGame,bFinalObj;
var int zzNumForts, zzRemForts;

struct FortInfo
{
   var FortStandard zzFS;
   var bool bTaken;
};

var FortInfo zzFI[16];

function PostBeginPlay()
{
   local FortStandard zzFS;

   foreach Level.AllActors(class'FortStandard',zzFS)
   {
       zzFI[zzNumForts].zzFS = zzFS;
       zzFI[zzNumForts++].bTaken = false;
   }

   zzRemForts = zzNumForts;
}

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

               zzLogger.LogAssaultObj(bFinalObj,zzFI[i].zzFS.Instigator.PlayerReplicationInfo.PlayerID);
               bObjFound = true;

               break;
           }
       }
   }
}

event TeamMessage (PlayerReplicationInfo PRI, coerce string S, name Type, optional bool bBeep)
{
}

function ClientVoiceMessage (PlayerReplicationInfo Sender, PlayerReplicationInfo Recipient, name messagetype, byte messageID)
{
}

defaultproperties
{
      zzLogger=None
      zzAssault=None
      bEndGame=False
      bFinalObj=False
      zzNumForts=0
      zzRemForts=0
      zzFI(0)=(zzFS=None,bTaken=False)
      zzFI(1)=(zzFS=None,bTaken=False)
      zzFI(2)=(zzFS=None,bTaken=False)
      zzFI(3)=(zzFS=None,bTaken=False)
      zzFI(4)=(zzFS=None,bTaken=False)
      zzFI(5)=(zzFS=None,bTaken=False)
      zzFI(6)=(zzFS=None,bTaken=False)
      zzFI(7)=(zzFS=None,bTaken=False)
      zzFI(8)=(zzFS=None,bTaken=False)
      zzFI(9)=(zzFS=None,bTaken=False)
      zzFI(10)=(zzFS=None,bTaken=False)
      zzFI(11)=(zzFS=None,bTaken=False)
      zzFI(12)=(zzFS=None,bTaken=False)
      zzFI(13)=(zzFS=None,bTaken=False)
      zzFI(14)=(zzFS=None,bTaken=False)
      zzFI(15)=(zzFS=None,bTaken=False)
}
