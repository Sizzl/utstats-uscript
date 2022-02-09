//================================================================================
// UTStatsHTTPClient.
// - Cratos ~2005 - Originally added to fix the "real IP" problem
// - Sizzl 2022 - Added call-out to AWS API for public IP checking, since running
//                Cloud VMs in the likes of AWS/Azure are often not aware of PIPs
//================================================================================

class UTStatsHTTPClient extends UBrowserHTTPClient;

var UTStats UTS;
var bool bDebug, bForceCheck; // inherit from UTStats config
var string IPData;
var int Timeout;

var() config string CheckAddress, CheckURI;
var() config int CheckPort;

function GetServerIP ()
{
    local bool bDeferred;
    local string ReturnedIP;
    if (UTS == None)
    {
        UTS = UTStats(Owner);
    }
    if (UTS != None)
    {
        ReturnedIP = UTS.IPOnly(GetIP());
        // Determine if private or public IP then return to log or defer and get via AWS API
        // Someone let me know if there's a better way of doing this ;(
        if (bForceCheck)
            bDeferred = true;
        else if (Left(ReturnedIP,3) ~= "10." || Left(ReturnedIP,8) ~= "192.168.")
        {
            bDeferred = true;
        }
        else if (Left(ReturnedIP,5) ~= "172.1" || Left(ReturnedIP,5) ~= "172.2" || Left(ReturnedIP,5) ~= "172.3")
        {
            if (Left(ReturnedIP,7) ~= "172.16." || Left(ReturnedIP,7) ~= "172.17." || Left(ReturnedIP,7) ~= "172.18." || Left(ReturnedIP,7) ~= "172.19." 
                || Left(ReturnedIP,7) ~= "172.20." || Left(ReturnedIP,7) ~= "172.21." || Left(ReturnedIP,7) ~= "172.22." || Left(ReturnedIP,7) ~= "172.23."
                || Left(ReturnedIP,7) ~= "172.24." || Left(ReturnedIP,7) ~= "172.25." || Left(ReturnedIP,7) ~= "172.26." || Left(ReturnedIP,7) ~= "172.27."
                || Left(ReturnedIP,7) ~= "172.28." || Left(ReturnedIP,7) ~= "172.29." || Left(ReturnedIP,7) ~= "172.30." || Left(ReturnedIP,7) ~= "172.31.")
            {
                bDeferred = true;
            }
        }
        else if (Left(ReturnedIP,4) ~= "100.")
        {
            if (Left(ReturnedIP,7) ~= "100.64." || Left(ReturnedIP,7) ~= "100.65." || Left(ReturnedIP,7) ~= "100.66." || Left(ReturnedIP,7) ~= "100.67." 
                || Left(ReturnedIP,7) ~= "100.68." || Left(ReturnedIP,7) ~= "100.69." || Left(ReturnedIP,5) ~= "100.7" || Left(ReturnedIP,5) ~= "100.8"
                || Left(ReturnedIP,5) ~= "100.9" || Left(ReturnedIP,7) ~= "100.100" || Left(ReturnedIP,7) ~= "100.101" || Left(ReturnedIP,7) ~= "100.102"
                || Left(ReturnedIP,7) ~= "100.103" || Left(ReturnedIP,7) ~= "100.104" || Left(ReturnedIP,7) ~= "100.105" || Left(ReturnedIP,7) ~= "100.106"
                || Left(ReturnedIP,7) ~= "100.107" || Left(ReturnedIP,7) ~= "100.108" || Left(ReturnedIP,7) ~= "100.109" || Left(ReturnedIP,7) ~= "100.110"
                || Left(ReturnedIP,7) ~= "100.111" || Left(ReturnedIP,7) ~= "100.112" || Left(ReturnedIP,7) ~= "100.113" || Left(ReturnedIP,7) ~= "100.114"
                || Left(ReturnedIP,7) ~= "100.115" || Left(ReturnedIP,7) ~= "100.116" || Left(ReturnedIP,7) ~= "100.117" || Left(ReturnedIP,7) ~= "100.118"
                || Left(ReturnedIP,7) ~= "100.119" || Left(ReturnedIP,7) ~= "100.120" || Left(ReturnedIP,7) ~= "100.121" || Left(ReturnedIP,7) ~= "100.122"
                || Left(ReturnedIP,7) ~= "100.123" || Left(ReturnedIP,7) ~= "100.124" || Left(ReturnedIP,7) ~= "100.125" || Left(ReturnedIP,7) ~= "100.126"
                || Left(ReturnedIP,7) ~= "100.127")
            {
                bDeferred = true;
            }
        }
        if (bDeferred)
        {
            if (bDebug)
                if (bForceCheck)
                    Log("### Enforcing Public IP lookup...",'UTStats');    
                else
                    Log("### Private IP detected ("$ReturnedIP$"), attempting to fetch Public IP...",'UTStats');
            ReturnedIP = "";
            // curl -s checkip.amazonaws.com
            Browse(CheckAddress, CheckURI, CheckPort, Timeout);
        }
        else
        {
            if (bDebug)
                Log("### Public IP detected ("$ReturnedIP$").",'UTStats');
            UTS.LogIP(ReturnedIP);    
            Destroy();
        }
    }
}

function string GetIP ()
{
    local IPAddr IPAddr;
    // Added by Cratos
    GetLocalIP(IpAddr);
    return IpAddrToString(IPAddr);
}

function CheckIP ()
{
    if (Len(IPData) > 0 && InStr(IPData,".")>=0)
    {
        if (bDebug)
            Log("### Retrieved a public IP from API:"@IPData,'UTStats');
    }
    else
    {
        Log("### Failed to retrieve a public IP for this server, reverting to private IP.",'UTStats');
        Log("### HTTP State:"@CurrentState$", Code:"@ErrorCode,'UTStats');
        IPData = GetIP();
    }
}

function string ParseString (String Input)
{
    local int CRLF;
    local string result;


    CRLF = InStr(Input,CR$LF);
    result = Input;

    if (InStr(result,CR$LF) == -1 && InStr(result,CR) == -1 && InStr(result,LF) == -1)
        return Input;

    if (InStr(result,CR$LF) >= 0)
        ReplaceText(result,CR$LF,"");
    if (InStr(Input,CR) >= 0)
        ReplaceText(result,CR,"");
    if (InStr(Input,LF) >= 0)
        ReplaceText(result,LF,"");
    return result;
}

function ReplaceText( out string Text, string Replace, string With )
{
    local int i;
    local string Input;

    Input = Text;
    Text = "";
    for ( i=InStr(Input,Replace); i!=-1; i=InStr(Input,Replace) )
    {
        Text = Text $ Left( Input, i ) $ With;
        Input = Mid( Input, i+Len(Replace) );
    }
    Text = Text $ Input;
}

function HTTPReceivedData(string data)
{
    IPData = ParseString(data);
    Super.SetTimer(0.0, false);
    if (UTS != None)
    {
        CheckIP();
        if (bDebug)
            Log("### Returning IP to UTStats -"@UTS.IPOnly(IPData),'UTStats');
        UTS.LogIP(UTS.IPOnly(IPData));
    }
}

function DoBind()
{
    if( BindPort() == 0 )
    {
        SetError(-2);
        return;
    }

    Open( ServerIpAddr );
    bClosed = False;
}

function SetError(int code)
{
    Super.SetError(code);

    switch(code)
    {
        case -1:
            Log("### Error in binding the port while connecting to "$ServerAddress,'UTStats');
            break;
        case -2:
            Log("### Error while resolving the host "$ServerAddress,'UTStats');
            break;
        case -3:
            Log("### Query timed out for "$ServerAddress$" out after "$Timeout$" seconds",'UTStats');
            break;
        case -4:
            Log("### Error resolving to the host of the IP for the domain "$ServerAddress,'UTStats');
            break;
        default:
            if (code != 200)
                CheckIP();
            Log("### Received HTTP error with code "$string(code)$" from "$ServerAddress,'UTStats');
    }
}

event Closed()
{
    Super.Closed();
}

defaultproperties
{
    bHidden=True
    CheckAddress="checkip.amazonaws.com"
    CheckPort=80
    CheckURI="/"
    Timeout=10
}
