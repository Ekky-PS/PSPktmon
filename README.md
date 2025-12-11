# PSPktmon
A PowerShell wrapper module for interacting with the Pktmon API to capture and analyze network packets in real-time.

## Download
Download from PowerShell Gallery:
```
Install-Module PSPktmon
```

## Usage
Start PSPktmon
```
Start-PktmonAuto
```

Sets if the module should attempt to parse the packets. (Default: $True)
```
Set-PktmonPacketParsing -State [bool]
```

Returns all captured packets since last called.
```
Get-PktmonPackets
```

Stop PSPktmon and clears all handles and pointers
```
Stop-PktMon
```

Example PS Script that prints out the payload as hex from ICMP Packets.
```
Import-Module PSPktmon
Start-PktmonAuto
try
{
    while($true)
    {
        Start-Sleep -Milliseconds 10
        $packets = Get-PktmonPackets
        foreach($packet in $packets)
        {
            if($packet.ParsedPacket.IPv4Data.Protocol -like "ICMP")
            {
                Write-ToHex $packet.ParsedPacket.ProtocolData.Data
                Write-Host "--------------"
            }
        }
    }
}
finally
{
    Stop-Pktmon
}
```