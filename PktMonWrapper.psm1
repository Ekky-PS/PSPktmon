Add-Type @"
using System;
using System.Collections;
using System.Runtime.InteropServices;
using System.Collections.Generic;

[StructLayout(LayoutKind.Sequential)]
public struct PACKETMONITOR_REALTIME_STREAM_CONFIGURATION
{
    public IntPtr UserContext;                                      
    public IntPtr EventCallback;      
    public IntPtr DataCallback;        

    public UInt16 BufferSizeMultiplier;                  

    public UInt16 TruncationSize;                                  
}

[StructLayout(LayoutKind.Sequential)]
public struct PACKETMONITOR_STREAM_DATA_DESCRIPTOR
{
    public IntPtr Data;
    public UInt32 DataSize;
    public UInt32 MetadataOffset;
    public UInt32 PacketOffset;
    public UInt32 PacketLength;
    public UInt32 MissedPacketWriteCount;
    public UInt32 MissedPacketReadCount;
}

[UnmanagedFunctionPointer(CallingConvention.Winapi)]
public delegate void PACKETMONITOR_STREAM_DATA_CALLBACK(IntPtr zeroPtr, PACKETMONITOR_STREAM_DATA_DESCRIPTOR descriptor);


public static class PktMonApi
{
    public static PACKETMONITOR_STREAM_DATA_CALLBACK DataCallback;
    public static List<Byte[]> PacketDataArrayList;

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern int PacketMonitorInitialize
    (
        UInt32 apiVersion,
        IntPtr reserved,
        out IntPtr handle
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void PacketMonitorUninitialize(IntPtr handle);

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern int PacketMonitorEnumDataSources
    (
        IntPtr handle,
        UInt32 sourceKind,
        [MarshalAs(UnmanagedType.U1)]bool showHidden,
        UInt64 bufferCapacity,
        out UInt64 bytesNeeded,
        IntPtr buffer
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern int PacketMonitorCreateLiveSession
    (
        IntPtr handle,
        [MarshalAs(UnmanagedType.LPWStr)] string sessionName,
        out IntPtr session
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void PacketMonitorCloseSessionHandle
    (
        IntPtr handle
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern int PacketMonitorAddSingleDataSourceToSession
    (
        IntPtr session,
        IntPtr dataSourceSpec
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern int PacketMonitorCreateRealtimeStream
    (
        IntPtr handle,
        ref PACKETMONITOR_REALTIME_STREAM_CONFIGURATION configuration,
        out IntPtr realtimeStream
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern int PacketMonitorAttachOutputToSession
    (
        IntPtr session,
        IntPtr realtimeStream
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void PacketMonitorCloseRealtimeStream
    (
        IntPtr realtimeStream
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern int PacketMonitorAddCaptureConstraint
    (
        IntPtr session,
        IntPtr captureConstraint
    );

    [DllImport("pktmonapi.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern int PacketMonitorSetSessionActive
    (
        IntPtr session,
        [MarshalAs(UnmanagedType.U1)] bool active
    );


    private static void PacketDataCallBack(IntPtr zeroPtr, PACKETMONITOR_STREAM_DATA_DESCRIPTOR descriptor)
    {
        Byte[] byteArray = new Byte[descriptor.DataSize];
        Marshal.Copy(descriptor.Data, byteArray, 0, (int) descriptor.DataSize);
        PacketDataArrayList.Add(byteArray);
    }

    public static Byte[][] GetPacketData()
    {
        Byte[][] returnArr = PacketDataArrayList.ToArray();
        PacketDataArrayList.Clear();
        return returnArr;
    }
    
    public static IntPtr CreateRealtimeStream(IntPtr PktmonHandle, PACKETMONITOR_REALTIME_STREAM_CONFIGURATION cfg)
    {
        PacketDataArrayList = new List<byte[]>();
        DataCallback = new PACKETMONITOR_STREAM_DATA_CALLBACK(PacketDataCallBack);
        cfg.DataCallback = Marshal.GetFunctionPointerForDelegate(DataCallback);
        IntPtr streamHandle = IntPtr.Zero;
        
        var hr = PacketMonitorCreateRealtimeStream(PktmonHandle, ref cfg, out streamHandle);
        if (hr != 0)
        {
            return IntPtr.Zero;
        }

        return streamHandle;
    }
}
"@

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
    param([Parameter(Mandatory)][string]$Name)

    return $script:PSPktmon.PacketMonitorCreateLiveSession($Name);
}

function Add-PktMonDataSource 
{
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Session, [Parameter(Mandatory)]$Adapter)

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

function Get-RealtimeStreamHandle
{
    param
    (
        [uint16] $BufferSizeMultiplier = 10,
        [uint16] $TruncationSize = 9000
    )
    
    return $PSPktmon.CreateRealtimeStream($BufferSizeMultiplier, $TruncationSize)
}

function Close-RealTimeStreamHandle
{
    param
    (
        $PktmonRealTimeStream
    )
    if ($RealTimeStreamHandle -isnot [PktmonRealTimeStream]) 
    {
        throw "PktmonRealTimeStream must be a [PktmonRealTimeStream]"
    }
    $PSPktmon.PacketMonitorCloseRealtimeStream($realTimeStream);
}

function Add-RealTimeStreamToSession
{
    param
    (
        $Session,
        $PktmonRealTimeStream
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
    param
    (
        $Session
    )
    if ($Session -isnot [PktmonSession]) 
    {
        throw "Session must be a PktmonSession"
    }
    $Session.PacketMonitorSetSessionActive($true)
}

function Stop-PktmonSession
{
    param
    (
        $Session
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
        $Session
    )
    if ($Session -isnot [PktmonSession]) 
    {
        throw "Session must be a PktmonSession"
    }
    $PSPktmon.PacketMonitorCloseSessionHandle($session)
}

function Get-PacketData
{
    $rawData = [PktMonApi]::GetPacketData();

    [PacketData[]] $packetData = [PacketData[]]::new($rawData.Count)
    
    for($i = 0; $i -lt $packetData.Count; $i++)
    {
        $packetData[$i] = [PacketData]::new($rawData[$i])
    }

    return $packetData
}

function Restart
{
    Stop-PktMon
    [PktMonApi]::PacketMonitorCloseRealtimeStream([IntPtr]::Zero)

}


Export-ModuleMember -Function * -Variable PSPktmon

Register-EngineEvent PowerShell.Exiting -Action { Stop-PktMon;}
