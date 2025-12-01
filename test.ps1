Clear-Host
Stop-PktMon
Remove-Module PktMonWrapper
Import-Module PktMonWrapper
Initialize-PktMon


$session = Get-PktMonSession -Name "PktmonSession"


$pktmonAdapterSources = Get-PktMonAdapter -SourceKind 1

for($i = 0; $i -lt $pktmonAdapterSources.Count; $i++)
{
    #Add-PktMonDataSource -Session $session -Adapter $pktmonAdapterSources[$i]
}

Add-PktMonDataSource -Session $session -Adapter $pktmonAdapterSources[3]
$realTimeStream = Get-RealtimeStreamHandle

Add-RealTimeStreamToSession -Session $session -PktmonRealTimeStream $realTimeStream


Start-PktmonSession -Session $session


[System.Collections.ArrayList] $allPackets =  [System.Collections.ArrayList]::new()

try
{
    while($true)
    {
        $Data = Get-PacketData
        if($data.Count -gt 0)
        {
            foreach($packet in $data)
            {
                $allPackets.Add($packet) | Out-Null
                Parse-Packet $packet.RawPacketData
                #$packet.ToHex()
                Write-host "-----------------------"

            }

        }
    }
}
finally
{

    Stop-PktmonSession -Session $session
    Close-PktmonSession -Session $session
    Close-RealTimeStreamHandle -RealTimeStreamHandle $realTimeStream
}

