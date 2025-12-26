class PktmonMetaData
{
    [uint64]  $PktGroupId;         
    [uint16]  $PktCount;           
    [uint16]  $AppearanceCount;    
    [PKTMON_DIRECTION_TAG]  $DirectionName;      
    [PKTMON_PACKET_TYPE]  $PacketType;         
    [uint16]  $ComponentId;        
    [uint16]  $EdgeId;             
    [uint16]  $Reserved;           
    [PKTMON_DROP_REASON]  $DropReason;         
    [PKTMON_DROP_LOCATION]  $DropLocation;       
    [uint16]  $Processor;          
    [Int64] $TimeStamp; 

    PktmonMetaData([Byte[]] $byteArr)
    {   
        $this.PktGroupId = [BitConverter]::ToUInt64($byteArr, 0);
        $this.PktCount = [BitConverter]::ToUInt16($byteArr, 8)
        $this.AppearanceCount = [BitConverter]::ToUInt16($byteArr, 10)
        $this.DirectionName = [PKTMON_DIRECTION_TAG][BitConverter]::ToUInt16($byteArr, 12)
        $this.PacketType = [PKTMON_PACKET_TYPE][BitConverter]::ToUInt16($byteArr, 14)
        $this.ComponentId = [BitConverter]::ToUInt16($byteArr, 16)
        $this.EdgeId = [BitConverter]::ToUInt16($byteArr, 18)
        $this.Reserved = [BitConverter]::ToUInt16($byteArr, 20)
        $this.DropReason = [PKTMON_DROP_REASON][BitConverter]::ToUInt32($byteArr, 22)
        $this.DropLocation = [PKTMON_DROP_LOCATION][BitConverter]::ToUInt32($byteArr, 26)
        $this.Processor = [BitConverter]::ToUInt16($byteArr, 30)
        $this.TimeStamp = [BitConverter]::ToInt64($byteArr, 32)

    }
}


class IEEE80211
{
    [UInt16] $FrameControl
    [UInt16] $Duration
    [String] $ReceiverAddress
    [String] $TransmitterAddress
    [String] $SourceAddress
    [UInt16] $SequenceControl
    [UInt16] $QoSControl
    [UInt16] $HTControl
    [UInt16] $PayloadOffset

    [Byte]  $DSAP
    [Byte]  $SSAP
    [Byte]  $LLCControl
    [Byte[]] $OUI = [Byte[]]::new(3)
    [UInt16] $EtherType

    IEEE80211([Byte[]] $ByteArray)
    {
        $this.FrameControl = [BitConverter]::ToUInt16($ByteArray, 0)
        $this.Duration = [BitUtils]::ToUInt16BigEndian($ByteArray, 2)
        $this.ReceiverAddress = ($ByteArray[4..9] | ForEach-Object { $_.ToString("X2") }) -join ":"
        $this.TransmitterAddress = ($ByteArray[10..15] | ForEach-Object { $_.ToString("X2") }) -join ":"
        $this.SourceAddress = ($ByteArray[16..21] | ForEach-Object { $_.ToString("X2") }) -join ":"
        $this.SequenceControl = [BitUtils]::ToUInt16BigEndian($ByteArray, 22)
        $type = ($this.FrameControl -shr 2) -band 0x3
        $subtype = ($this.FrameControl -shr 4) -band 0xF
        $hasQoS = ($type -eq 2 -and ($subtype -band 0x08))
        $offset = 24

        if ($hasQoS) 
        {
            $this.QoSControl = [BitUtils]::ToUInt16BigEndian($ByteArray, $offset)
            $offset += 2
        }

        $hasHT = (($this.FrameControl -shr 10) -band 1) -eq 1
        if ($hasHT) 
        {
            $this.HTControl = [BitUtils]::ToUInt16BigEndian($ByteArray, $offset)
            $offset += 2
        }
        
        $this.PayloadOffset = $offset 
        if ($ByteArray.Length -ge ($offset + 8)) 
        {
            $this.DSAP = $ByteArray[$offset]
            $this.SSAP = $ByteArray[$offset + 1]
            $this.LLCControl = $ByteArray[$offset + 2]
            $snapStart = $offset + 3
            $this.OUI = $ByteArray[$snapStart..($snapStart + 2)]
            $this.EtherType = [BitUtils]::ToUInt16BigEndian($ByteArray, $snapStart + 3)
            $this.PayloadOffset = $offset + 8
        }
    }

    static [bool] IsIEEE80211([Byte[]]$ByteArray)
    {
        if ($ByteArray.Length -lt 10) { return $false }

        $fc = [BitConverter]::ToUInt16($ByteArray, 0)
        $version = $fc -band 0x3
        if ($version -ne 0) { return $false }

        $type = ($fc -shr 2) -band 0x3
        if ($type -gt 2) { return $false }

        return $true
    }
}

Class UnhandledData
{
    [Byte[]] $RawBytes

    UnhandledData([Byte[]] $ByteArray)
    {
        $this.RawBytes = $ByteArray
    }
}

Class ICMPData
{
    [Byte] $Type
    [ICMP4_TYPE] $Code
    [uint16] $CheckSum
    [Byte[]] $UnparsedHeaders
    [Byte[]] $Data

    ICMPData([Byte[]] $ByteArray)
    {
        if($ByteArray.Count -lt 8){return}
        $this.Type = [ICMP4_TYPE]$ByteArray[0]
        $this.Code = $ByteArray[1]
        $this.CheckSum = [BitUtils]::ToUInt16BigEndian($ByteArray, 2)
        $this.UnparsedHeaders = $ByteArray[4..7]

        $length = $ByteArray.Count - 8
        $this.Data = [byte[]]::new($length)
        [Array]::Copy($ByteArray, 8, $this.Data, 0, $length)
    }
}

Class TCPData
{
    [int] $Size
    [uint16] $SourcePort
    [uint16] $DestinationPort
    [uint32] $SequenceNumber
    [uint32] $AcknowledgementNumber
    [byte] $DataOffset
    [byte] $Reserved
    [byte] $Flags
    [uint16] $Window
    [uint16] $Checksum
    [uint16] $UrgentPointer
    [Byte[]] $Options
    [Byte[]] $Data


    TCPData([Byte[]] $ByteArray)
    {
        if($ByteArray.Count -lt 20) {return}
        $this.SourcePort = [BitUtils]::ToUInt16BigEndian($ByteArray, 0)
        $this.DestinationPort = [BitUtils]::ToUInt16BigEndian($ByteArray, 2)
        $this.SequenceNumber = [BitUtils]::ToUInt32BigEndian($ByteArray, 4)
        $this.AcknowledgementNumber = [BitUtils]::ToUInt32BigEndian($ByteArray, 8)
        $this.DataOffset = $ByteArray[12] -shr 4
        $this.size = $this.DataOffset * 4
        $this.Reserved = $ByteArray[12] -band 0x0F
        $this.Flags = $ByteArray[13]
        $this.Window = [BitUtils]::ToUInt16BigEndian($ByteArray, 14)
        $this.Checksum = [BitUtils]::ToUInt16BigEndian($ByteArray, 16)
        $this.UrgentPointer = [BitUtils]::ToUInt16BigEndian($ByteArray, 18)
        if($this.size -lt 20){return}

        $length = [Math]::Min($this.size - 20, $ByteArray.Count - 20)
        $this.Options = [byte[]]::new($length)
        [Array]::Copy($ByteArray, 20, $this.Options, 0, $length)
        
        if($ByteArray.Count - $this.Size -lt 0){ return }

        $length = $ByteArray.Count - $this.Size
        $this.Data = [byte[]]::new($length)
        [Array]::Copy($ByteArray, $this.Size, $this.Data, 0, $length)

    }
}

class UDPData
{
    [uint16] $SourcePort
    [uint16] $DestinationPort
    [uint16] $Length
    [uint16] $CheckSum
    [Byte[]] $Data

    UDPData([Byte[]] $ByteArray)
    {
        if($ByteArray.Length -lt 8) {return}
        $this.SourcePort = [BitUtils]::ToUInt16BigEndian($ByteArray, 0)
        $this.DestinationPort = [BitUtils]::ToUInt16BigEndian($ByteArray, 2)
        $this.Length = [BitUtils]::ToUInt16BigEndian($ByteArray, 4)
        $this.CheckSum = [BitUtils]::ToUInt16BigEndian($ByteArray, 6)
        $this.Data = [Byte[]]::new($this.Length - 8)
        for($i = 8; $i -lt $this.Length -and $i -lt $ByteArray.Count; $i++)
        {
            $this.Data[$i -8] = $ByteArray[$i]
        }

    }
}


class IPv4Data
{
    [int] $StartByteIndex;
    [int] $size;
    [byte] $Version
    [byte] $IHL
    [byte] $TOS
    [uint16] $TotalLength
    [uint16] $Identification
    [byte] $Flags
    [Byte[]] $FragmentOffset
    [byte] $TTL
    [IPv4Protocol] $Protocol
    [uint16] $HeaderChecksum
    [string] $SourceAddress
    [string] $DestinationAddress
    [byte[]] $Options

    IPv4Data([Byte[]] $byteArray)
    {
        $index = $this.FindIPv4HeaderIndex($byteArray)
        $this.ParseIPV4Data($byteArray, $index)
    }

    IPv4Data([Byte[]] $byteArray, [int] $index)
    {
        $this.ParseIPV4Data($byteArray, $index)
    }

    [void] ParseIPV4Data([Byte[]] $byteArray, [int] $index)
    {
        if($index -eq 0 -or $byteArray.Count - $index -lt 20) {return}
        $this.startByteIndex = $index
        $this.Version = ($byteArray[$index] -shr 4)
        $this.IHL = $byteArray[$index] -band 0x0F
        $this.size = $this.IHL * 4
        $this.TOS = $byteArray[$index + 1]
        $this.TotalLength = [BitUtils]::ToUInt16BigEndian($byteArray, ($index + 2))
        $this.Identification =  [BitUtils]::ToUInt16BigEndian($byteArray, ($index + 4))
        $this.Flags = $byteArray[6] -band 0x1F
        $this.FragmentOffset = [Byte[]]::new(2);
        $this.FragmentOffset[0] = $byteArray[$index + 6] -band 0xE0
        $this.FragmentOffset[1] = $byteArray[$index + 7]
        $this.TTL = $byteArray[8]
        if(([Enum]::IsDefined([IPv4Protocol], [int]$byteArray[$index + 9])))
        {
            $this.Protocol = [IPv4Protocol][int]$byteArray[$index + 9]
        }
        else
        {
            $this.Protocol = [IPv4Protocol]-1
        }
        $this.HeaderChecksum = [BitUtils]::ToUInt16BigEndian($byteArray, ($index + 10))
        $this.SourceAddress = $byteArray[($index+12)..($index+15)] -join "."
        $this.DestinationAddress = $byteArray[($index+16)..($index+19)] -join "."
        
        $this.options = [Byte[]]::new($this.size - 20);
        for($i = 20; $i -lt $this.size; $i++)
        {
            $this.Options[0] = $byteArray[$i];
        }
    }
    
    [int] FindIPv4HeaderIndex ([byte[]]$PacketBytes)
    {
        $etherTypeIPv4 = [Byte[]](0x08,0x00)
        $snapIPv4 = [Byte[]](0xAA,0xAA,0x03,0x00,0x00,0x00,0x08,0x00)

        for ($i = 0; $i -lt $PacketBytes.Count - 20; $i++)
        {
            $candidateIndex = $null

            $matchEther = $true
            for ($j=0; $j -lt $etherTypeIPv4.Length; $j++)
            {
                if ($PacketBytes[$i + $j] -ne $etherTypeIPv4[$j])
                {
                    $matchEther = $false
                    break
                }
            }
            if ($matchEther) { $candidateIndex = $i + 2 }

            $matchSnap = $true
            for ($j=0; $j -lt $snapIPv4.Length; $j++) 
            {
                if ($PacketBytes[$i + $j] -ne $snapIPv4[$j])
                {
                    $matchSnap = $false
                    break
                }
            }
            if ($matchSnap) { $candidateIndex = $i + 8 }

            if ($null -ne $candidateIndex -and $candidateIndex + 20 -le $PacketBytes.Count)
            {
                $tmpVersion = $PacketBytes[$candidateIndex] -shr 4
                $tmpIhlWords = $PacketBytes[$candidateIndex] -band 0x0F
                $tmpIhlBytes = $tmpIhlWords * 4
                $tmpTotalLength = ($PacketBytes[$candidateIndex + 2] -shl 8) -bor $PacketBytes[$candidateIndex + 3]
                $tmpTTL = $PacketBytes[$candidateIndex + 8]
                if ($tmpVersion -eq 4 -and $tmpIhlBytes -ge 20 -and $tmpTotalLength -ge $tmpIhlBytes`
                 -and $tmpTotalLength -le ($PacketBytes.Count - $candidateIndex) -and $tmpTTL -gt 0)
                {
                    return $candidateIndex
                }
            }
        }

        return $null
    }

}

Class EthernetII
{
    [String] $DestinationMacAddress
    [String] $SourceMacAddress
    [uint16] $EtherType
    [bool] $VlanTag
    [uint16] $TPID
    [uint16] $TCI


    EthernetII([Byte[]]$ByteArray)
    {
        $this.DestinationMacAddress = ($ByteArray[0..5] | ForEach-Object { $_.ToString("X2") }) -join ':'
        $this.SourceMacAddress = ($ByteArray[6..11] | ForEach-Object { $_.ToString("X2") }) -join ':'
        $tmp = [BitUtils]::ToUInt16BigEndian($ByteArray, 12)
        if($tmp -eq 0x8100)
        {
            $this.VlanTag = $true
            $this.TPID = $tmp 
            $this.TCI = [BitUtils]::ToUInt16BigEndian($ByteArray, 14)
            $this.EtherType = [BitUtils]::ToUInt16BigEndian($ByteArray, 16)
        }
        else
        {
            $this.EtherType = $tmp
        }
    }
}
