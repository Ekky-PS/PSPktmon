Add-Type @"
using System;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;

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

public struct PSPacketData
{
    public byte[] Data;
    public UInt32 DataSize;
    public UInt32 MetadataOffset;
    public UInt32 PacketOffset;
    public UInt32 PacketLength;
    public UInt32 MissedPacketWriteCount;
    public UInt32 MissedPacketReadCount;


    public PSPacketData(byte[] data, uint dataSize, uint metadataOffset, uint packetOffset, uint packetLength, uint missedPacketWriteCount, uint missedPacketReadCount)
    {
        Data = data;
        DataSize = dataSize;
        MetadataOffset = metadataOffset;
        PacketOffset = packetOffset;
        PacketLength = packetLength;
        MissedPacketWriteCount = missedPacketWriteCount;
        MissedPacketReadCount = missedPacketReadCount;
    }
}

[UnmanagedFunctionPointer(CallingConvention.Winapi)]
public delegate void PACKETMONITOR_STREAM_DATA_CALLBACK(IntPtr zeroPtr, PACKETMONITOR_STREAM_DATA_DESCRIPTOR descriptor);

public static class PktMonApi
{
    public static PACKETMONITOR_STREAM_DATA_CALLBACK DataCallback;
    public static ConcurrentQueue<PSPacketData> PacketDataCQ = new ConcurrentQueue<PSPacketData>();

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
    
    private static void PacketDataCallBack(IntPtr userContext, PACKETMONITOR_STREAM_DATA_DESCRIPTOR descriptor)
    {
        Byte[] byteArray = new Byte[descriptor.DataSize];
        Marshal.Copy(descriptor.Data, byteArray, 0, (int) descriptor.DataSize);
        PSPacketData tmp = new PSPacketData
        (
            byteArray, 
            descriptor.DataSize, descriptor.MetadataOffset, 
            descriptor.PacketOffset, descriptor.PacketLength, 
            descriptor.MissedPacketWriteCount, descriptor.MissedPacketReadCount
        );
        
        PacketDataCQ.Enqueue(tmp);
    }
    
    public static void ClearPacketBuffer()
    {
        PSPacketData packet;
        while (PacketDataCQ.TryDequeue(out packet)){}
    }
    
    public static int GetPacketData(PSPacketData[] buffer)
    {
        int i = 0;
        PSPacketData packet;
        while(i < buffer.Length && PacketDataCQ.TryDequeue(out packet))
        {
            buffer[i++] = packet;
        }

        return i;
    }
    
    public static IntPtr CreateRealtimeStream(IntPtr pktmonHandle, PACKETMONITOR_REALTIME_STREAM_CONFIGURATION cfg)
    {
        DataCallback = new PACKETMONITOR_STREAM_DATA_CALLBACK(PacketDataCallBack);
        cfg.DataCallback = Marshal.GetFunctionPointerForDelegate(DataCallback);
        IntPtr streamHandle = IntPtr.Zero;
        
        var hr = PacketMonitorCreateRealtimeStream(pktmonHandle, ref cfg, out streamHandle);
        if (hr != 0)
        {
            return IntPtr.Zero;
        }
        
        return streamHandle;
    }
}
"@