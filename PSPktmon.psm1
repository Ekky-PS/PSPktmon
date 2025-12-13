#requires -RunAsAdministrator

if($PSPktmon)
{
    $PSPktmon.PacketMonitorUninitialize()
}

$PSPktmon = [PSPktmon]::new();

function Initialize-PktMon 
{
    $PSPktmon.PacketMonitorInitialize();
}

function Stop-PktMon 
{
    if($PSPktmon)
    {
        $PSPktmon.PacketMonitorUninitialize();
    }
}

function Start-PktmonAuto
{
    Initialize-PktMon
    $session = Get-PktMonSession
    $pktmonDataSources = Get-PktMonDataSources

    for($i = 0; $i -lt $pktmonDataSources.Count; $i++)
    {
        Add-PktMonDataSourceToSession -Session $session -DataSource $pktmonDataSources[$i]
    }

    $realTimeStream = Get-PktmonRealtimeStreamHandle
    Add-PktmonRealTimeStreamToSession -Session $session -PktmonRealTimeStream $realTimeStream
    Start-PktmonSession -Session $session
}

function Get-PktMonDataSources
{
    param
    (
        [Bool]$ShowHidden = $false,
        [int]$SourceKind = 1
    )

    return ($PSPktmon.PacketMonitorEnumDataSources($ShowHidden, $SourceKind));
}

function Get-PktMonSession 
{
    param([string] $Name = "PktmonSession")

    return $PSPktmon.PacketMonitorCreateLiveSession($Name);
}

function Add-PktMonDataSourceToSession 
{
    param
    (
        [Parameter(Mandatory)][PktmonSession]$Session, 
        [Parameter(Mandatory)][PktmonDataSource]$DataSource
    )

    $Session.PacketMonitorAddSingleDataSourceToSession($DataSource)
}

function Get-PktmonRealtimeStreamHandle
{
    param
    (
        [uint16] $BufferSizeMultiplier = 10,
        [uint16] $TruncationSize = 9000
    )
    
    return $PSPktmon.CreateRealtimeStream($BufferSizeMultiplier, $TruncationSize)
}

function Close-PktmonRealTimeStreamHandle
{
    param
    (
        [Parameter(Mandatory)][PktmonRealTimeStream]$PktmonRealTimeStream
    )

    $PSPktmon.PacketMonitorCloseRealtimeStream($realTimeStream);
}

function Add-PktmonRealTimeStreamToSession
{
    param
    (
        [Parameter(Mandatory)][PktmonSession]$Session,
        [Parameter(Mandatory)][PktmonRealTimeStream]$PktmonRealTimeStream
    )
    
    $Session.PacketMonitorAttachOutputToSession($PktmonRealTimeStream);
}

function Start-PktmonSession
{
    param
    (
        [Parameter(Mandatory)][PktmonSession]$Session
    )

    $Session.PacketMonitorSetSessionActive($true)
    
}

function Stop-PktmonSession
{
    param
    (
        [Parameter(Mandatory)][PktmonSession]$Session
    )

    $Session.PacketMonitorSetSessionActive($false)
}

function Close-PktmonSession
{
    param
    (
        [Parameter(Mandatory)][PktmonSession]$Session
    )

    $PSPktmon.PacketMonitorCloseSessionHandle($session)
}

function Get-PktmonPackets
{
    return $PSPktmon.GetAllPackets();
}
function Get-PktmonPacketMissedCount
{
    return [pscustomobject]@{
                MissedPacketWriteCount = [PacketData]::MissedPacketWriteCount
                MissedPacketReadCount = [PacketData]::MissedPacketReadCount
            }
}


function Set-PktmonPacketParsing
{
    param
    (
        [bool] $State
    )
    [PacketData]::ParsePackets = $State
}

function Clear-PktmonPacketBuffer
{
    [PktMonApi]::ClearPacketBuffer()    
}

function Get-PktmonPacketsInBuffer
{
    return [PktMonApi]::PacketDataCQ.Count
}

function Write-ToHex
{
    param
    (
         [Byte[]] $ByteArray
    )
    [BitUtils]::toHex($ByteArray)
}
Register-EngineEvent PowerShell.Exiting -Action {Stop-PktMon}