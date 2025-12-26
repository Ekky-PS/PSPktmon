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

function Start-TheMatrix
{
    param
    (
        [ValidateSet('Hex','Ascii','Binary')]
        [string] $Mode
    )
    if($Mode -eq "Hex")
    {
        [ByteRain]::Intitalize(0)
    }
    if($Mode -eq "Ascii")
    {
        [ByteRain]::Intitalize(1)
    }
    if($Mode -eq "Binary")
    {
        [ByteRain]::Intitalize(2)
    }
    
    try
    {
        while($true)
        {
            $RetrievedPackets = Get-PktmonPackets 

            foreach($packet in $RetrievedPackets)
            {
                [ByteRain]::AddDrop($packet.RawPacketData)
            }
            Start-Sleep -Milliseconds 15
            [ByteRain]::TickDrops()
        }
    }
    finally
    {
        [Console]::ForegroundColor = 'White'
        Clear-Host
        Stop-PktMon
    }
}

function Convert-PacketDataToPcap {
    param (
        [Parameter(Mandatory)]
        [System.Collections.ArrayList] $Packets,

        [Parameter(Mandatory)]
        [string]$OutputFile
    )

    $fs = [System.IO.File]::Open($OutputFile, 'Create', 'Write')
    $bw = New-Object System.IO.BinaryWriter($fs)

    try 
    {

        $bw.Write([UInt32]2712847316)
        $bw.Write([UInt16]2)
        $bw.Write([UInt16]4)
        $bw.Write([Int32]0)
        $bw.Write([UInt32]0)
        $bw.Write([UInt32]65535)
        $bw.Write([UInt32]1)

        foreach ($packet in $Packets) 
        {
            if($packet.GetType() -notlike [PacketData]){continue}
            $TimeStamp = [DateTime]::FromFileTimeUtc([Int64]$packet.PktmonMetaData.TimeStamp).ToLocalTime()
            $unixSeconds = [int]([DateTimeOffset]$TimeStamp).ToUnixTimeSeconds()

            $microseconds = [int](($TimeStamp.Millisecond) * 1000)
            

            $length = $packet.RawPacketData.Count


            $bw.Write([UInt32]$unixSeconds)  
            $bw.Write([UInt32]$microseconds)
            $bw.Write([UInt32]$length)
            $bw.Write([UInt32]$length)

            $bw.Write($packet.RawPacketData)
        }
    }
    finally 
    {
        $bw.Close()
        $fs.Close()
    }
}


Register-EngineEvent PowerShell.Exiting -Action {Stop-PktMon}