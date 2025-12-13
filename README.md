# PSPktmon
A PowerShell wrapper module for interacting with the Pktmon API to capture and analyze network packets in real-time.

## Download
Download from PowerShell Gallery:
```
Install-Module PSPktmon
```

## Usage
For fast setup 
Will Initializes Packet Monitor
And create a started [PktmonSession] with all Network interfaces and a [PktmonRealTimeStream] attached.
```
Start-PktmonAuto
```

Initializes Packet Monitor and gets a Handle to the Packet Monitor. (Module will keep track of the Handle)
```
Initialize-PktMon
```

Creates an independent Packet Monitor session.
```
Get-PktMonSession
```
Returns a [PktmonSession] object.

Retrieves list of [PktmonDataSource] to be used for attaching to a [PktmonSession]
```
Get-PktMonDataSources
```
Returns an array of [PktmonDataSource]

Add a [PktmonDataSource] as a source to a [PktmonSession]
param
(
    [PktmonSession]$Session, 
    [PktmonDataSource]$DataSource
)
```
Add-PktMonDataSourceToSession
```

Creates an independent Packet Monitor RealtimeStream.
```
Get-PktmonRealtimeStreamHandle
```
Returns a [PktmonRealTimeStream] object.

Add a [PktmonRealTimeStream] as a source to a [PktmonSession]
param
(
    [PktmonSession]$Session,
    [PktmonRealTimeStream]$PktmonRealTimeStream
)
```
Add-PktmonRealTimeStreamToSession
```

Sets a [PktmonSession] as Active. This will start the Packet capturing
param
(
    [PktmonSession]$Session
)
```
Start-PktmonSession
```


Sets if the module should attempt to parse the packets. (Default: $True)
param
(
    [Bool]$State
)
```
Set-PktmonPacketParsing
```

Returns all captured packets from active sessions since last called.
```
Get-PktmonPackets
```
Returns an array of [PacketData]

Stop PSPktmon and clears all handles and pointers.
```
Stop-PktMon
```

Example PS Script that prints IPv4 Data from ICMP packets and the payload.
```
Import-Module PSPktmon
Start-PktmonAuto

[System.Collections.ArrayList] $ICMPPackets = [System.Collections.ArrayList]::new()

try
{
    while($true)
    {
        $RetrievedPackets = Get-PktmonPackets 

        foreach($packet in $RetrievedPackets)
        {
            if($packet.ParsedPacket.IPv4Data.Protocol -eq "ICMP")
            {
                $ICMPPackets.Add($packet) | Out-Null
                Write-host "Source Address: $($packet.ParsedPacket.IPv4Data.SourceAddress)"
                Write-host "Destination Address: $($packet.ParsedPacket.IPv4Data.DestinationAddress)"
                Write-host "Direction: $($packet.ParsedPacket.PacketDirection)"
                Write-host "ICMP Type: $($packet.ParsedPacket.ProtocolData.Type)"
                Write-host "Timestamp: $($packet.ParsedPacket.TimeStamp)"
                if($packet.ParsedPacket.ProtocolData.Data.Count -gt 0)
                {
                    Write-host "Payload Data"
                    Write-host "-----------------------------------------------------------------------------"
                    Write-ToHex $packet.ParsedPacket.ProtocolData.Data
                    Write-host "-----------------------------------------------------------------------------"
                }
                Write-host ""
            }
        }
    }
}
finally
{
    Stop-PktMon
}
```