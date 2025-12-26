class PacketData
{
    static [uint32] $MissedPacketWriteCount = 0;
    static [uint32] $MissedPacketReadCount = 0;
    static [bool] $ParsePackets = $true
    [PktmonMetaData] $PktmonMetaData;
    [ParsedPacket] $ParsedPacket;
    [Byte[]] $RawPacketData;
    
    
    PacketData([PSPacketData] $packetData)
    {
        [PacketData]::MissedPacketWriteCount = $packetData.MissedPacketWriteCount
        [PacketData]::MissedPacketReadCount = $packetData.MissedPacketReadCount
        
        $length = 39 - $packetData.MetadataOffset + 1
        $metaBytes = [byte[]]::new($length)
        [Array]::Copy($packetData.Data, $packetData.MetadataOffset, $metaBytes, 0, $length)
        $this.PktmonMetaData = [PktmonMetaData]::new($metaBytes)

        $length = $packetData.Data.Count - $packetData.PacketOffset
        $this.rawPacketData = [byte[]]::new($length)
        [Array]::Copy($packetData.Data, $packetData.PacketOffset, $this.rawPacketData, 0, $length)

        if([PacketData]::ParsePackets -and $this.RawPacketData.Count -ge 14)
        {
            $this.ParsedPacket = [ParsedPacket]::new($this.RawPacketData, $this.PktmonMetaData)
        }
    }
}


Class ParsedPacket
{
    $LinkLayerData;
    [IPv4Data] $IPv4Data;
    $ProtocolData
    [PacketDirection] $PacketDirection
    [DateTime] $TimeStamp

    ParsedPacket([Byte[]] $PacketByteArray, [PktmonMetaData] $ptkmonMetaData)
    {
        $this.IPv4Data = $null
        $this.LinkLayerData = $null
        $etherType = $null
        $ipv4Tmp = $null
        $this.TimeStamp = [DateTime]::FromFileTimeUtc($ptkmonMetaData.TimeStamp).ToLocalTime()

        if($ptkmonMetaData.DirectionName -eq [PKTMON_DIRECTION_TAG]::PktMonDirTag_In`
        -or $ptkmonMetaData.DirectionName -eq [PKTMON_DIRECTION_TAG]::PktMonDirTag_Rx`
        -or $ptkmonMetaData.DirectionName -eq [PKTMON_DIRECTION_TAG]::PktMonDirTag_Ingress)
        {
            $this.PacketDirection = [PacketDirection]::Incoming 
        }
        elseif($ptkmonMetaData.DirectionName -eq [PKTMON_DIRECTION_TAG]::PktMonDirTag_Out`
        -or $ptkmonMetaData.DirectionName -eq [PKTMON_DIRECTION_TAG]::PktMonDirTag_Tx`
        -or $ptkmonMetaData.DirectionName -eq [PKTMON_DIRECTION_TAG]::PktMonDirTag_Egress)
        {
            $this.PacketDirection = [PacketDirection]::Outgoing 
        }
        else
        {
            $this.PacketDirection = [PacketDirection]::Unknown 
        }

        if($ptkmonMetaData.PacketType -eq [PKTMON_PACKET_TYPE]::PktMonPayload_WiFi)
        {
            $this.LinkLayerData = [IEEE80211]::new($PacketByteArray);
            $etherType = $this.LinkLayerData.EtherType
            if($this.LinkLayerData -and $etherType -eq 0x0800 `
            -and $PacketByteArray.Count -gt $this.LinkLayerData.PayloadOffset `
            -and $PacketByteArray[$this.LinkLayerData.PayloadOffset] -eq 0x45)
            {
                $ipv4Tmp = [IPv4Data]::new($PacketByteArray, $this.LinkLayerData.PayloadOffset)
            }
        }
        elseif ($ptkmonMetaData.PacketType -eq [PKTMON_PACKET_TYPE]::PktMonPayload_Ethernet)
        {

            $this.LinkLayerData = [EthernetII]::new($PacketByteArray);
            $etherType = $this.LinkLayerData.EtherType


            if($this.LinkLayerData -and $etherType -eq 0x0800 -and `
                $PacketByteArray.Count -ge 15 -and $PacketByteArray[14] -eq 0x45)
            {
                if($this.LinkLayerData.VlanTag)
                {
                    $ipv4Tmp = [IPv4Data]::new($PacketByteArray, 18)
                }
                else
                {
                    $ipv4Tmp = [IPv4Data]::new($PacketByteArray, 14)
                }
            }
        }
        
        if(-not $ipv4Tmp)
        {
            $ipv4Tmp = [IPv4Data]::new($PacketByteArray)
        }

        if($ipv4Tmp.StartByteIndex -ne 0)
        {
            $this.IPv4Data = $ipv4Tmp
            $this.ProtocolData = $null
            $StartByteIndex = $this.IPv4Data.StartByteIndex + $this.IPv4Data.size
            if($this.IPv4Data.TotalLength - $this.IPv4Data.Size -gt 0)
            {
                $EndByteIndex = $StartByteIndex + ($this.IPv4Data.TotalLength - $this.IPv4Data.Size)
            }
            else
            {
                $EndByteIndex = $PacketByteArray.Count - 1
            }
            if($EndByteIndex -gt $PacketByteArray.Count - 1)
            {
                $EndByteIndex  = $PacketByteArray.Count - 1;
            }

            $length = $EndByteIndex - $StartByteIndex + 1
            $ProtocolByteArray = [byte[]]::new($length)
            [Array]::Copy($PacketByteArray, $StartByteIndex, $ProtocolByteArray, 0, $length)


            if($this.IPv4Data.Protocol -eq [IPv4Protocol]::ICMP)
            {
                $this.ProtocolData = [ICMPData]::new($ProtocolByteArray)
            }
            if($this.IPv4Data.Protocol -eq [IPv4Protocol]::TCP)
            {
                $this.ProtocolData = [TCPData]::new($ProtocolByteArray)
            }
            if($this.IPv4Data.Protocol -eq [IPv4Protocol]::UDP)
            {
                $this.ProtocolData = [UDPData]::new($ProtocolByteArray)
            }
            if(-not $this.ProtocolData)
            {
                $this.ProtocolData = [UnhandledData]::new($ProtocolByteArray)
            }

        }
    }
}
