class ByteRain
{
    static [System.Collections.ArrayList] $queuedDrops;
    static [Drop[]] $drops
    static [int] $width
    static [int] $height
    static [int] $mode = 0
    
    static Intitalize([int] $mode)
    {
        [Console]::CursorVisible = $false
        [ByteRain]::width  = [Console]::WindowWidth
        [ByteRain]::height = [Console]::WindowHeight
        [ByteRain]::drops = [Drop[]]::new([ByteRain]::width)
        [ByteRain]::mode = $mode
    }

    static AddDrop([Byte[]] $byteArray)
    {
        if([ByteRain]::queuedDrops.Count -gt 0)
        {
            [ByteRain]::queuedDrops.Add($byteArray)
            return
        }

        [System.Collections.ArrayList] $OpenSpots = [System.Collections.ArrayList]::new();
        for($i = 0; $i -lt [ByteRain]::drops.Count; $i++)
        {
            if($null -eq [ByteRain]::drops[$i])
            {
                $OpenSpots.Add($i)
            }
        }
        if($OpenSpots.Count -gt 0)
        {
            $index = $OpenSpots[(Get-Random -Minimum 0 -Maximum ($OpenSpots.Count))]
            [ByteRain]::drops[$index] = [Drop]::new($byteArray, $index)
        }
    }
    static TickDrops()
    {
        if([ByteRain]::width -ne [Console]::WindowWidth -or [ByteRain]::height -ne [Console]::WindowHeight)
        {
            [ByteRain]::width  = [Console]::WindowWidth
            [ByteRain]::height = [Console]::WindowHeight
            [ByteRain]::drops = [Drop[]]::new([ByteRain]::width)
        }
        for($i = 0; $i -lt [ByteRain]::drops.Count; $i++)
        {
            if($null -ne [ByteRain]::drops[$i])
            {
                if([ByteRain]::drops[$i].Tick())
                {
                    if([ByteRain]::queuedDrops.Count -gt 0)
                    {
                        [ByteRain]::drops[$i] = [Drop]::new([ByteRain]::queuedDrops[0], $i)
                        [ByteRain]::queuedDrops.RemoveAt(0)
                    }
                    else
                    {
                        [ByteRain]::drops[$i] = $null
                    }
                }
            }
        }
    }
}

class Drop
{
    [string[]] $Symbols;
    [int] $yPosition = 0;
    [int] $xPosition;
    [int] $index;

    Drop([Byte[]] $byteArray, [int] $xPosition)
    {
        $this.yPosition = Get-Random -Minimum 0 -Maximum ([ByteRain]::height)
        if([ByteRain]::mode -eq 0)
        {
            $this.Symbols = $ByteArray | ForEach-Object { $_.ToString("X2") } 
        }
        if([ByteRain]::mode -eq 1)
        {
            $this.Symbols = $byteArray | ForEach-Object {if ($_ -ge 32 -and $_ -le 126) {[char]$_} else {'.'} }
        }
        if([ByteRain]::mode -eq 2)
        {
            $this.Symbols = [char[]]@(foreach ($b in $byteArray) {foreach ($bit in ([Convert]::ToString($b, 2).PadLeft(8, '0')).ToCharArray()) {$bit}})
        }
        $this.xPosition = $xPosition
        $this.index = 0;
    }

    [bool] Tick()
    {
        if($this.xPosition -ge [Console]::WindowWidth -or $this.yPosition -ge [Console]::WindowHeight)
        {
            return $true
        }

        [Console]::SetCursorPosition($this.xPosition, $this.yPosition)
        [Console]::ForegroundColor = "Green"
        Write-Host $this.Symbols[$this.index] -NoNewline

        if($this.index -gt 0)
        {
            $prevY = $this.yPosition - 1   
            if($prevY -lt 0)
            {
                $prevY = ([Console]::WindowHeight - 1)
            }
            [Console]::SetCursorPosition($this.xPosition, $prevY)
            Write-Host $this.Symbols[$this.index - 1] -NoNewline -ForegroundColor DarkGreen
        }

        $this.index++;
        $this.yPosition++

        if($this.yPosition -ge [ByteRain]::height)
        {
            $this.yPosition = 0;
        }


        if($this.index -eq $this.Symbols.Count)
        {
            return $true
        }
        return $false
    }
}