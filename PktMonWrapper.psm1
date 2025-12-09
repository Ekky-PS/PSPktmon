. "$PSScriptRoot\PktmonPInvokeWrapper.ps1"
. "$PSScriptRoot\PktmonClasses.ps1"

if($script:PSPktmon)
{
    $script:PSPktmon.PacketMonitorUninitialize()
}

$script:PSPktmon = [PSPktmon]::new();

function Initialize-PktMon 
{
    $script:PSPktmon.PacketMonitorInitialize();
}

function Stop-PktMon 
{
    if($script:PSPktmon)
    {
        $script:PSPktmon.PacketMonitorUninitialize();
    }
}

function Start-PktmonQuick
{
    Initialize-PktMon
    $session = Get-PktMonSession
    $pktmonAdapterSources = Get-PktMonAdapter

    for($i = 0; $i -lt $pktmonAdapterSources.Count; $i++)
    {
        Add-PktMonDataSource -Session $session -Adapter $pktmonAdapterSources[$i]
    }

    $realTimeStream = Get-PktmonRealtimeStreamHandle
    Add-PktmonRealTimeStreamToSession -Session $session -PktmonRealTimeStream $realTimeStream
    Start-PktmonSession -Session $session
}

function Get-PktMonAdapter 
{
    [CmdletBinding()]
    param
    (
        [Bool]$ShowHidden = $false,
        [int]$SourceKind = 1
    )

    return ($script:PSPktmon.PacketMonitorEnumDataSources($ShowHidden, $SourceKind));
}



function Get-PktMonSession 
{
    [CmdletBinding()]
    param([string] $Name = "PktmonSession")

    return $script:PSPktmon.PacketMonitorCreateLiveSession($Name);
}

function Add-PktMonDataSource 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]$Session, 
        [Parameter(Mandatory)]$Adapter
    )

    if ($Session -isnot [PktmonSession]) 
    {
        throw "Session must be a [PktmonSession]"
    }
    if($adapter -isnot [PktmonAdapter])
    {
         throw "Adapter must be a [PktmonAdapter]"
    }
    $Session.PacketMonitorAddSingleDataSourceToSession($adapter)
}

function Get-PktmonRealtimeStreamHandle
{
    [CmdletBinding()]
    param
    (
        [uint16] $BufferSizeMultiplier = 10,
        [uint16] $TruncationSize = 9000
    )
    
    return $script:PSPktmon.CreateRealtimeStream($BufferSizeMultiplier, $TruncationSize)
}

function Close-PktmonRealTimeStreamHandle
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]$PktmonRealTimeStream
    )
    if ($PktmonRealTimeStream -isnot [PktmonRealTimeStream]) 
    {
        throw "PktmonRealTimeStream must be a [PktmonRealTimeStream]"
    }
    $script:PSPktmon.PacketMonitorCloseRealtimeStream($realTimeStream);
}

function Add-PktmonRealTimeStreamToSession
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]$Session,
        [Parameter(Mandatory)]$PktmonRealTimeStream
    )
    if ($Session -isnot [PktmonSession]) 
    {
        throw "Session must be a [PktmonSession]"
    }
    if ($Session -isnot [PktmonSession]) 
    {
        throw "PktmonRealTimeStream must be a [PktmonRealTimeStream]"
    }
    
    $Session.PacketMonitorAttachOutputToSession($PktmonRealTimeStream);
}

function Start-PktmonSession
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]$Session
    )
    if ($Session -isnot [PktmonSession]) 
    {
        throw "Session must be a PktmonSession"
    }
    $Session.PacketMonitorSetSessionActive($true)
    Write-host "Pktmon session: $($session.Name) started"
}

function Stop-PktmonSession
{
    param
    (
        [Parameter(Mandatory)]$Session
    )
    if ($Session -isnot [PktmonSession]) 
    {
        throw "Session must be a PktmonSession"
    }
    $Session.PacketMonitorSetSessionActive($false)
}

function Close-PktmonSession
{
    param
    (
        [Parameter(Mandatory)]$Session
    )
    if ($Session -isnot [PktmonSession]) 
    {
        throw "Session must be a PktmonSession"
    }
    $script:PSPktmon.PacketMonitorCloseSessionHandle($session)
}

function Get-PktmonPackets
{
    return $script:PSPktmon.GetAllPackets();
}
function Get-PktmonPacketMissedCount
{
    return [pscustomobject]@{
                MissedPacketWriteCount = [PacketData]::MissedPacketWriteCount
                MissedPacketReadCount = [PacketData]::MissedPacketReadCount
            }
}


function Set-PacketParsing
{
    param
    (
        [bool] $State
    )
    [PacketData]::ParsePackets = $State
}

function ToHex
{
    param
    (
         [Byte[]] $ByteArray
    )
    [BitUtils]::toHex($ByteArray)
}

Export-ModuleMember -Function * -Variable PSPktmon

Register-EngineEvent PowerShell.Exiting -Action { Stop-PktMon;}
