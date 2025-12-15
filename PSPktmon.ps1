class PSPktmon
{
    [System.Collections.ArrayList] $OpenPktmonPointers;
    [System.Collections.ArrayList] $OpenPktmonSessions;
    [System.Collections.ArrayList] $OpenPktmonRealTimeStreams;
    [IntPtr] $PktmonHandle;

    PSPktmon()
    {
        $this.OpenPktmonPointers = [System.Collections.ArrayList]::new()
        $this.OpenPktmonSessions = [System.Collections.ArrayList]::new()
        $this.OpenPktmonRealTimeStreams = [System.Collections.ArrayList]::new()
        $this.PktmonHandle = [IntPtr]::Zero 
    }

    [void] PacketMonitorInitialize()
    {
        [UInt32]$ApiVersion = 0x00010000
        if ($this.PktmonHandle -ne [IntPtr]::Zero) { return }
        [IntPtr] $handle = [IntPtr]::Zero
        $result = [PktMonApi]::PacketMonitorInitialize($ApiVersion, [IntPtr]::Zero, [ref]$handle)
        if ($result -ne 0) { throw "Failed to initialize PktMon: 0x{0:X}" -f $result }
        $this.PktmonHandle = $handle
        [PacketData]::MissedPacketWriteCount = 0
        [PacketData]::MissedPacketReadCount = 0
    }

    [void] PacketMonitorUninitialize()
    {
        if ($this.PktmonHandle -eq [IntPtr]::Zero) { return }
        $this.FreeAllMemoryPointers()
        foreach($session in $this.OpenPktmonSessions)
        {
            if($session.Active)
            {
                $session.PacketMonitorSetSessionActive($false)
            }
            if($session.Handle -ne [IntPtr]::Zero)
            {
                $session.PacketMonitorCloseSessionHandle()
            }
        }
        $this.OpenPktmonSessions.Clear()
        foreach($realTimeStream in $this.OpenPktmonRealTimeStreams)
        {
            if($realTimeStream.Handle -ne [IntPtr]::Zero)
            {
                $realTimeStream.PacketMonitorCloseRealtimeStream()
            }
        }
        $this.OpenPktmonRealTimeStreams.Clear()
        [PktMonApi]::PacketMonitorUninitialize($this.PktmonHandle)
        $this.PktmonHandle = [IntPtr]::Zero
    }

    [PktmonSession] PacketMonitorCreateLiveSession([string] $name)
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        $session = [IntPtr]::Zero
        $res = [PktMonApi]::PacketMonitorCreateLiveSession($this.PktMonHandle, $Name, [ref]$session)
        if ($res -ne 0) { throw "Failed to create session: 0x{0:X}" -f $res }
        [PktmonUtils]::WriteInformation("Live session created: $Name, handle = $session")

        $pktmonSession = [PktmonSession]::new($name, $session)
        $null = $this.OpenPktmonSessions.Add($pktmonSession)
        return $pktmonSession;
    }
    
    [void] PacketMonitorCloseSessionHandle([string] $name)
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        $this.CloseSession($this.GetSession($name))
    }


    [void] PacketMonitorCloseSessionHandle([PktmonSession] $pktmonSession)
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        $pktmonSession.PacketMonitorCloseSessionHandle()
        $this.OpenPktmonSessions.Remove($pktmonSession)
    }

    [PktmonSession] GetSession([string] $name)
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        foreach($session in $this.OpenPktmonSessions)
        {
            if($session.name -eq $name)
            {
                return $session
            }
        }
        return $null   
    }
    [PktmonSession] GetSession([IntPtr] $handle)
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        foreach($session in $this.OpenPktmonSessions)
        {
            if($session.handle -eq $handle)
            {
                return $session
            }
        }
        return $null   
    }


    [void] FreeAllMemoryPointers()
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        foreach($pointer in $this.OpenPktmonPointers)
        {
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($pointer)
        }
        $this.OpenPktmonPointers.Clear()
    }

    [PktmonRealTimeStream] CreateRealtimeStream([uint16] $BufferSizeMultiplier, [uint16] $TruncationSize)
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        
        #$id =  $this.OpenPktmonRealTimeStreams.Count
        $config = [PACKETMONITOR_REALTIME_STREAM_CONFIGURATION]::new()
        $config.UserContext = [IntPtr] [PktmonRealTimeStream]::Index
        $config.EventCallback = [IntPtr]::Zero
        $config.DataCallback = [IntPtr]::Zero
        $config.BufferSizeMultiplier = [uint16] $BufferSizeMultiplier
        $config.TruncationSize = [uint16] $TruncationSize
        
        $RSPtr = [PktMonApi]::CreateRealtimeStream($this.PktmonHandle, [PACKETMONITOR_REALTIME_STREAM_CONFIGURATION]$config)
        if ($RSPtr  -eq [IntPtr]::Zero) { throw "Failed to create realtime stream."}

        $realTimeStream = [PktmonRealTimeStream]::new($BufferSizeMultiplier, $TruncationSize, $RSPtr)
        [PktmonUtils]::WriteInformation("Real time stream created: handle = $($realTimeStream.Handle)") 

        $null = $this.OpenPktmonRealTimeStreams.Add($realTimeStream);
        return $realTimeStream
    }

    [void] PacketMonitorCloseRealtimeStream([PktmonRealTimeStream] $realTimeStream)
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        $tmpHandle = $realTimeStream.Handle
        $realTimeStream.PacketMonitorCloseRealtimeStream()
        [PktmonUtils]::WriteInformation("Real time stream closed: handle = $($tmpHandle)")
        foreach($session in $this.OpenPktmonSessions)
        {
            $session.RemoveOutputFromSession($realTimeStream);
        }
        $this.OpenPktmonRealTimeStreams.Remove($realTimeStream)
    }

    [PktmonDataSource[]] PacketMonitorEnumDataSources([bool] $ShowHidden, [int] $SourceKind)
    {
        if ($this.PktMonHandle -eq [IntPtr]::Zero) { throw "Pktmon not initialized" }
        

        $bytesNeeded = [uint64]::Zero
        $res = [PktMonApi]::PacketMonitorEnumDataSources(
            $this.PktmonHandle,
            $SourceKind,
            $ShowHidden,
            [UIntPtr]::Zero,
            [ref]$bytesNeeded,
            [IntPtr]::Zero
        )
        if ($res -ne 0) { throw "EnumDataSources failed: 0x{0:X}" -f $res }
        if ($bytesNeeded -eq [uint64]::Zero) { return $null }


        $DataSourceMemoryPointer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($bytesNeeded)
        $this.OpenPktmonPointers.Add($DataSourceMemoryPointer)
        $bytesReturned = [UIntPtr]::Zero
        $res = [PktMonApi]::PacketMonitorEnumDataSources(
            $this.PktmonHandle,
            $SourceKind,
            $ShowHidden.IsPresent,
            $bytesNeeded,
            [ref]$bytesReturned,
            $DataSourceMemoryPointer
        )
        if ($res -ne 0) { throw "EnumDataSources failed: 0x{0:X}" -f $res }

        [int]$ItemSize   = 424 
        $basePtr = $DataSourceMemoryPointer;
        $length = $bytesNeeded

        if ($BasePtr -eq [IntPtr]::Zero) {
            throw "BasePtr cannot be zero."
        }

        [int] $itemCount = [System.Runtime.InteropServices.Marshal]::ReadInt32($basePtr, 0)
        [int] $HeaderSize = (16 + $itemCount * 8)
        $dataSize = $length - $HeaderSize
        if ($dataSize -le 0) 
        {
            throw "BytesReturned is smaller or equal to headersize"
        }

        $pktmonSources = [PktmonDataSource[]]::new($itemCount);

        for ($i = 0; $i -lt $itemCount; $i++) {

            $offset = $HeaderSize + ($i * $ItemSize)
            $ptrVal = $BasePtr.ToInt64() + $offset

            $itemPtr = [IntPtr]$ptrVal

            $pktmonSources[$i] = [PktmonDataSource]::new($itemPtr)
        }

        return $pktmonSources
    }

    [System.Collections.ArrayList] GetAllPackets()
    {
        $returnArray = [System.Collections.ArrayList]::new()
        foreach($session in $this.OpenPktmonSessions)
        {
            $returnArray.AddRange($session.ReadPacketsFromBuffer())
        }
        return $returnArray;
    }
}


class PktmonDataSource
{
    hidden [int] $Length;
    [string] $Name
    [string] $Description
    [int] $ID 
    [int] $SecondaryID
    [int] $ParentID
    hidden [IntPtr] $Pointer
    [int] $Type
    [string] $MacAddress

    PktmonDataSource([IntPtr] $pointer)
    {
        $this.Pointer = $pointer
        $this.Length = 424
        $this.type = [System.Runtime.InteropServices.Marshal]::ReadInt32($this.pointer, 0)
        $this.name = $this.ReadWCharStringAtOffset(4)
        $this.description = $this.ReadWCharStringAtOffset(132)
        $this.id = [System.Runtime.InteropServices.Marshal]::ReadInt32($this.pointer, 388)
        $this.secondaryId = [System.Runtime.InteropServices.Marshal]::ReadInt32($this.pointer, 392)
        $this.parentId = [System.Runtime.InteropServices.Marshal]::ReadInt32($this.pointer, 396)
        $this.macAddress = ""
        for($j = 0; $j -lt 6; $j++)
        {
            $b = [System.Runtime.InteropServices.Marshal]::ReadByte($this.pointer, 408+$j)
            $this.macAddress +=  "{0:X2}" -f $b
            if($j -lt 5)
            {
                $this.macAddress += ":"
            }
        }
        
    }

    [string] ReadWCharStringAtOffset([int] $Offset)
    {
        $chars = @()
        for ($i = $Offset; $i -lt $this.Length; $i += 2) {
            if ($i + 1 -ge $this.Length) { break }

            $char = $this.ReadWCharAtOffset($i)

            if ($char -eq 0) { break }

            $chars += $char
        }

        return -join $chars
    }

    [char] ReadWCharAtOffset([int]$Offset)
    {

        if ($Offset -lt 0 -or $Offset + 1 -ge $this.length) {
            throw "Offset out of bounds"
        }

        $lo = [System.Runtime.InteropServices.Marshal]::ReadByte($this.pointer, $offset)
        $hi = [System.Runtime.InteropServices.Marshal]::ReadByte($this.pointer, $offset + 1)


        $charCode = ($hi -shl 8) -bor $lo

        return [char]$charCode
    }

}

class PktmonSession
{
    [string] $Name;
    [IntPtr] $Handle;
    [System.Collections.ArrayList] $AttachedDataSources;
    [System.Collections.ArrayList] $AttachedOutputStream;
    [Bool] $Active;

    PktmonSession([string] $name, [intptr]$handle)
    {
        $this.name = $name
        $this.handle = $handle
        $this.AttachedDataSources = [System.Collections.ArrayList]::new()
        $this.AttachedOutputStream = [System.Collections.ArrayList]::new()
    }

    [void] PacketMonitorSetSessionActive([bool] $active)
    {
        if($this.handle -eq [IntPtr]::Zero) {Throw "Null pointer"}
        $res = [PktMonApi]::PacketMonitorSetSessionActive($this.handle, $active)
        if ($res -ne 0) { throw "Failed to start session: 0x{0:X}" -f $res }
        [PktmonUtils]::WriteInformation("Pktmon session state: $($this.Name) set to $active")
        $this.active = $active;
    }

    [void] PacketMonitorAddSingleDataSourceToSession([PktmonDataSource] $DataSource)
    {
        $res = [PktMonApi]::PacketMonitorAddSingleDataSourceToSession($this.handle, $DataSource.Pointer)
        if ($res -ne 0) { throw "Failed to add data source: 0x{0:X}" -f $res }
        [PktmonUtils]::WriteInformation("Data source added to session: handle = $($this.handle)")
        $null = $this.AttachedDataSources.Add($DataSource)
    }
    
    [void] PacketMonitorAttachOutputToSession([PktmonRealTimeStream] $realTimeStream)
    {
        $res = [PktMonApi]::PacketMonitorAttachOutputToSession($this.handle, $realTimeStream.Handle)
        if ($res -ne 0) { throw "Failed to attach realtime stream to session: 0x{0:X}" -f $res }
        [PktmonUtils]::WriteInformation("Real time stream : handle = $realTimeStream attached to session: handle = $($this.handle)")
        $null = $this.AttachedOutputStream.Add($realTimeStream)
    }
    [void] RemoveOutputFromSession([PktmonRealTimeStream] $realTimeStream)
    {
        if($this.AttachedOutputStream.Contains($realTimeStream))
        {
            $this.AttachedOutputStream.Remove($realTimeStream)
        }
    }
    [void] PacketMonitorCloseSessionHandle()
    {
        if($this.handle -eq [IntPtr]::Zero){Throw "Null pointer"}
        [PktMonApi]::PacketMonitorCloseSessionHandle($this.handle)
        $this.handle = [IntPtr]::Zero
        $this.AttachedDataSources.Clear()
        $this.AttachedOutputStream.Clear()
        $this.Active = $false
    }

    [System.Collections.ArrayList] ReadPacketsFromBuffer()
    {
        $returnArray = [System.Collections.ArrayList]::new()
        foreach($outputStream in $this.AttachedOutputStream)
        {
            $returnArray.AddRange($outputStream.ReadPacketsFromBuffer())
        }
        return $returnArray;
    }
}

class PktmonRealTimeStream
{
    static [int] $Index
    static [int] $PacketBufferSize = 10240
    [Int] $Id
    [uint16] $BufferSizeMultiplier;
    [uint16] $TruncationSize;
    [IntPtr] $Handle;
    [PSPacketData[]] $PacketBuffer



    PktmonRealTimeStream([uint16] $BufferSizeMultiplier, [uint16] $TruncationSize, [IntPtr] $pointer)
    {
        $this.BufferSizeMultiplier = $BufferSizeMultiplier
        $this.TruncationSize = $TruncationSize
        $this.Handle = $pointer
        $this.Id = [PktmonRealTimeStream]::Index
        [PktmonRealTimeStream]::Index += 1;
        $this.PacketBuffer = [PSPacketData[]]::new([PktmonRealTimeStream]::PacketBufferSize)
    }

    [void] PacketMonitorCloseRealtimeStream()
    {
        if($this.Handle -eq [IntPtr]::Zero){Throw "Null pointer"}
        [PktMonApi]::PacketMonitorCloseRealtimeStream($this.Handle)
        $this.Handle = [IntPtr]::Zero
    }

    [PacketData[]] ReadPacketsFromBuffer()
    {
        $packetCount = [PktMonApi]::GetPacketData($this.PacketBuffer);
        [PacketData[]] $packetData = [PacketData[]]::new($packetCount)
        
        for($i = 0; $i -lt $packetData.Count; $i++)
        {
            $packetData[$i] = [PacketData]::new($this.PacketBuffer[$i])
        }

        return $packetData
    }

}