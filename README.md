# PSPktmon

PSPktmon is a PowerShell module that wraps the Windows Pktmonapi.dll, allowing real-time capture and analysis of network packets.

---

## Installation

```powershell
Install-Module PSPktmon
```

---

## Quick Start

```powershell
Start-PktmonAuto
```

This command:
- Initializes Packet Monitor
- Creates and starts a PktmonSession
- Attaches all network interfaces
- Attaches a PktmonRealTimeStream

---

## Commands

### Initialize Packet Monitor

```powershell
Initialize-PktMon
```

Initializes Packet Monitor and manages the handle internally.

---

### Create a Session

```powershell
Get-PktMonSession
```

Returns a [PktmonSession] object.

---

### Get Data Sources

```powershell
Get-PktMonDataSources
```

Returns available [PktmonDataSource] objects.

---

### Add Data Source to Session

```powershell
Add-PktMonDataSourceToSession
```

Parameters:
- [PktmonSession] $Session
- [PktmonDataSource] $DataSource

---

### Create a Real-Time Stream

```powershell
Get-PktmonRealtimeStreamHandle
```

Returns a [PktmonRealTimeStream] object.

---

### Add Stream to Session

```powershell
Add-PktmonRealTimeStreamToSession
```

Parameters:
- [PktmonSession] $Session
- [PktmonRealTimeStream] $RealTimeStream

---

### Start Session

```powershell
Start-PktmonSession
```

Starts packet capture.

---

### Enable or Disable Parsing

```powershell
Set-PktmonPacketParsing
```

Default is true.

---

### Get Captured Packets

```powershell
Get-PktmonPackets
```

Returns [PacketData] objects captured since the last call.

---

### Stop Packet Monitor

```powershell
Stop-PktMon
```

Releases all handles and resources.

---

### Stop Packet Monitor
```powershell
Convert-PacketDataToPcap
```

Parameters:
- [System.Collections.ArrayList] $Packets
- [String] $OutputFile

### If you are The One

```powershell
Start-TheMatrix -Mode Binary # Binary / Hex / Ascii
```


## Example: ICMP Packet Capture

```powershell
Import-Module PSPktmon
Start-PktmonAuto

$ICMPPackets = [System.Collections.ArrayList]::new()

try {
    while ($true) {
        foreach ($packet in Get-PktmonPackets) {
            if ($packet.ParsedPacket.IPv4Data.Protocol -eq 'ICMP') {
                $ICMPPackets.Add($packet) | Out-Null

                Write-Host "Source: $($packet.ParsedPacket.IPv4Data.SourceAddress)"
                Write-Host "Destination: $($packet.ParsedPacket.IPv4Data.DestinationAddress)"
                Write-Host "Type: $($packet.ParsedPacket.ProtocolData.Type)"
                Write-Host "Timestamp: $($packet.ParsedPacket.TimeStamp)"
                if($packet.ParsedPacket.ProtocolData.Data.Count -gt 0){
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
finally {
    Stop-PktMon
}
```
