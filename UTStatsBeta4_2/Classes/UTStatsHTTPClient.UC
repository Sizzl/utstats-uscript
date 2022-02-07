class UTStatsHTTPClient extends UBrowserHTTPClient;

function string GetIP ()
{
    local IPAddr IPAddr;
    // Added by Cratos
    GetLocalIP(IpAddr);
    return IpAddrToString(IPAddr);
}

defaultproperties
{
}
