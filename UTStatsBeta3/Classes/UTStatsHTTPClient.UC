class UTStatsHTTPClient extends UBrowserHTTPClient;

var string zzMyIP;
var UTStats UTS;

function HTTPReceivedData(string Data)
{
        zzMyIP = Data;

        UTS.LogIP(zzMyIP);

        Destroy();
}

defaultproperties
{
      zzMyIP=""
      UTS=None
}
