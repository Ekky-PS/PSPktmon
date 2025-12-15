class BitUtils
{
    static [uint16] ToUInt16BigEndian([Byte[]] $ByteArray, [int] $offset)
    {
        $byte1 = [uint16]$ByteArray[0 + $offset]   
        $byte2 = [uint16]$ByteArray[1 + $offset] 
        return [uint16](($byte1 -shl 8) -bor $byte2)
    } 
    
    static [uint32] ToUInt32BigEndian([byte[]] $ByteArray, [int] $offset)
    {
        $b1 = [uint32]$ByteArray[$offset]
        $b2 = [uint32]$ByteArray[$offset + 1]
        $b3 = [uint32]$ByteArray[$offset + 2]
        $b4 = [uint32]$ByteArray[$offset + 3]

        return [uint32](($b1 -shl 24) -bor ($b2 -shl 16) -bor ($b3 -shl 8)  -bor $b4)
    }
    static [void] ToHex([Byte[]] $ByteArray)
    {
        $bytesPerLine = 16
        for($i = 0; $i -lt $ByteArray.Count; $i+= 16)
        {
            $hex = ""
            $ascii = ""
            for ($j = $i; $j -lt $ByteArray.Count -and $j -lt ($bytesPerLine + $i); $j++) 
            {
                [Byte] $byte = $ByteArray[$j]
                $tmpHex = "{0:X2} " -f $byte
                $hex += $tmpHex
                if ($byte -ge 32 -and $byte -le 126) 
                {
                    $ascii += [char]$byte
                } 
                else 
                {
                    $ascii += "."
                }
            }
            $output = "{0:X8}:  {1,-48}  {2}" -f $i, $hex, $ascii
            write-host $output   
        }
    }
}

class PktmonUtils
{
    static [bool] $WriteInfo = $true

    static [Void] WriteInformation([string] $info)
    {
        if([PktmonUtils]::WriteInfo)
        {
            Write-host $info
        }
    }
}
