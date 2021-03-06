
[console]::CursorVisible=$false
#Clear-Host
write-host
$originalBufferSize = $Host.UI.RawUI.BufferSize
$Host.UI.RawUI.BufferSize = $Host.UI.RawUI.WindowSize
$Script:Exit = $false
$Script:Score = 0
$fenceColor = 'Yellow'

# :TODO: Remove the fence when game ends
# :TODO: Diagonal movement! Or not, maybe.
# :TODO: Clear the first row
# :TODO: Clear other areas outside of the play area
# :TODO: Tasty morsels!
# :TODO: Might want to add a win state too at some point...
# ...though I guess when you start generating tasty morsels, 
# the game could just go on forever.
# :TODO: Allow play area to be set via parameter(s)
# :TODO: It does kinda seems like the game gets slower when 
# the worm gets longer, there shouldn't really be a reason 
# for that to happen. Well, it might be because there's more 
# segments to get through to see if the player has hit the 
# worm... that could probably be improved. Maybe a hashmap 
# or something could work, such as "does $solid.X12Y21 exist".
# Right now, in fact it's searching twice if the first one 
# does not hit. In a manner that might not be the fastest 
# possible. Could also check if there's anything but the 
# background in a position before doing other checks. Yeah.

$playArea = @{
    UpperLeft = [PSCustomObject]@{
        X = 1
        Y = 2 # Leave the first row for the score counter
    }
    BottomLeft = [PSCustomObject]@{
        X = 1
        Y = $Host.UI.RawUI.BufferSize.Height - 2
    }
    BottomRight = [PSCustomObject]@{
        X = $Host.UI.RawUI.BufferSize.Width - 2
        Y = $Host.UI.RawUI.BufferSize.Height - 2
    }
    UpperRight = [PSCustomObject]@{
        X = $Host.UI.RawUI.BufferSize.Width - 2
        Y = 2 # Leave the first row for the score counter
    }
}

# If the width of the $playArea isn't divisible by two...
if ((($UpperRight.X - $UpperLeft.X + 1) % 2) -ne 0) {
    # ...decrease its width by one so that it will be!
    $playArea.UpperLeft.X += 1
    $playArea.BottomLeft.X += 1
}

[System.Collections.ArrayList]$segments = @(
    [PSCustomObject]@{
        X1 = 0 #    To...
        X2 = 0 # ...be... # :TODO: Now that I implemented the two X character segments, 
                          # I realize X2 isn't really required. Get rid of it.
         Y = 0 # ...determined!
    }
)

$worm = [PSCustomObject]@{
    Char = '+'
    Color = @('Magenta', 'Green', 'Cyan', 'Red', 'Yellow')[0]
    Length = 3
    Direction = 'Right'
    Segments = $segments
}

function Move-CursorPosition {
    Param(
        [Parameter(Mandatory=$false)][Int]$X = 0,
        [Parameter(Mandatory=$false)][Int]$Y = 0
    )
    $pos = $host.UI.RawUI.CursorPosition
    $pos.X += $X
    $pos.Y += $Y
    Set-CursorPosition -X $pos.X -Y $pos.Y
}

function Set-CursorPosition {
    Param(
        [Parameter(Mandatory=$false)]$X,
        [Parameter(Mandatory=$false)]$Y
    )
    $pos = $host.UI.RawUI.CursorPosition
    if ($X) {
        $pos.X = $X
        if ($pos.X -ge $Host.UI.RawUI.BufferSize.Width) {
            $pos.X = $Host.UI.RawUI.BufferSize.Width - 1
        }
        if ($pos.X -lt 0) {
            $pos.X = 0
        }
    }
    # :TODO: 'If ($X)' thinks 0 is $null, so the line below. There must be a better way.
    if ($X -eq 0) { $pos.X = 0 }
    if ($Y) {
        $pos.Y = $Y
        if ($pos.Y -ge $Host.UI.RawUI.BufferSize.Height) {
            $pos.Y = $Host.UI.RawUI.BufferSize.Height - 1
        }
        if ($pos.Y -lt 0) {
            $pos.Y = 0
        }
    }
    # :TODO: 'If ($Y)' thinks 0 is $null, so the line below. There must be a better way.
    if ($Y -eq 0) { $pos.Y = 0 }
    $host.UI.RawUI.CursorPosition = $pos
}

function Write-Score {
    $pos = $host.UI.RawUI.CursorPosition
    Set-CursorPosition -X 0 -Y 0
    Write-Host $Script:Score -ForegroundColor Black -BackgroundColor Green -NoNewline
    Set-CursorPosition -X $pos.X -Y $pos.Y
}

function Place-Character {
    Param(
        [Parameter(Mandatory=$true)][Char]$Character,
        [Parameter(Mandatory=$false)][String]$ForegroundColor = (Get-Host).ui.rawui.ForegroundColor,
        [Parameter(Mandatory=$false)][String]$BackgroundColor = (Get-Host).ui.rawui.BackgroundColor,
        [Parameter(Mandatory=$false)][Int]$X = 0,
        [Parameter(Mandatory=$false)][Int]$Y = 0
    )
    $pos = $host.UI.RawUI.CursorPosition
    if ((-not $X) -and (-not $Y)) { # :TODO: 0 0 here will equal to $false, fix
        # Place the character where the cursor is currently located
        Write-Host $Character -NoNewline -ForegroundColor $ForegroundColor -BackgroundColor `
            $BackgroundColor
    } else {
        Set-CursorPosition -X $X -Y $Y
        Write-Host $Character -NoNewline -ForegroundColor $ForegroundColor -BackgroundColor `
            $BackgroundColor
    }
    Set-CursorPosition -X $pos.X -Y $pos.Y
}

function Add-WormSegment {
    # Capture the content of the destination cell, 
    # if it's not a whitespace, eat it and grow!
    # :TODO: Update for two part segment. It's a bit of work though, when going 
    # left and right, the X position of the rectangle need to be adjusted 
    # correctly or the worm will rack up score on itself.
    $pos = $host.UI.RawUI.CursorPosition
    $rec = New-Object System.Management.Automation.Host.Rectangle $pos.X, $pos.Y, $pos.X, $pos.Y
    $destinationCell = $Host.UI.RawUI.GetBufferContents($rec)
    if ($destinationCell.Character -ne ' ') {
        $worm.Length += 1
        $Script:Score = $Script:Score + 1
    }

    # :TODO: Clean up the reoccurring code or whatever
    switch ($worm.Direction) {
        Up      {
            $wormEyeChar = "'"
            $wormBodyChar = '-'
            # Place left half of the segment
            Place-Character -Character $wormEyeChar -ForegroundColor White `
                -BackgroundColor $worm.Color

            # Move cursor one position to the right and place the right half of the segment
            Move-CursorPosition -X 1
            Place-Character -Character $wormEyeChar -ForegroundColor White `
                -BackgroundColor $worm.Color
        }
        Right   {
            $wormEyeChar = ':'
            $wormBodyChar = '|'
            # Place left half of the segment
            Place-Character -Character ' ' -ForegroundColor White `
                -BackgroundColor $worm.Color

            # Move cursor one position to the right and place the right half of the segment
            Move-CursorPosition -X 1
            Place-Character -Character $wormEyeChar -ForegroundColor White `
                -BackgroundColor $worm.Color
        }
        Down    {
            $wormEyeChar = '.'
            $wormBodyChar = '-'
            # Place left half of the segment
            Place-Character -Character $wormEyeChar -ForegroundColor White `
                -BackgroundColor $worm.Color

            # Move cursor one position to the right and place the right half of the segment
            Move-CursorPosition -X 1
            Place-Character -Character $wormEyeChar -ForegroundColor White `
                -BackgroundColor $worm.Color
        }
        Left    {
            $wormEyeChar = ':'
            $wormBodyChar = '|'
            # Place left half of the segment
            Place-Character -Character $wormEyeChar -ForegroundColor White `
                -BackgroundColor $worm.Color

            # Move cursor one position to the right and place the right half of the segment
            Move-CursorPosition -X 1
            Place-Character -Character ' ' -ForegroundColor White `
                -BackgroundColor $worm.Color
        }
    }

    if ($worm.Segments.Count -gt 1) {
        Place-Character -Character $wormBodyChar -X $worm.Segments[-1].X1 -Y $worm.Segments[-1].Y `
            -BackgroundColor $worm.Color -ForegroundColor Black
        Place-Character -Character $wormBodyChar -X $worm.Segments[-1].X2 -Y $worm.Segments[-1].Y `
            -BackgroundColor $worm.Color -ForegroundColor Black
    }
    $worm.Segments.Add(
        [PSCustomObject]@{
            X1 = $pos.X
            X2 = $pos.X + 1
             Y = $pos.Y
        }
    ) | Out-Null
}

function Remove-WormSegment {
    Place-Character -Character ' ' -X $worm.Segments[0].X1 -Y $worm.Segments[0].Y
    Place-Character -Character ' ' -X $worm.Segments[0].X2 -Y $worm.Segments[0].Y    
    $worm.Segments.RemoveAt(0)
}

Function Get-CursorWithinPlayArea {
    if ($Host.UI.RawUI.CursorPosition.X -lt $playArea.UpperLeft.X) {
        # The cursor has exited the play area on the left side
        return $false
    } elseif ($Host.UI.RawUI.CursorPosition.Y -gt $playArea.BottomLeft.Y) {
        # The cursor has exited the play area at the bottom
        return $false        
    } elseif ($Host.UI.RawUI.CursorPosition.X -gt $playArea.BottomRight.X) {
        # The cursor has exited the play area at the right side
        return $false        
    } elseif ($Host.UI.RawUI.CursorPosition.Y -lt $playArea.UpperRight.Y) {
        # The cursors has exited the play area at the top
        return $false        
    }
    return $true
}

function Get-CursorIsOnWormSegment {
    $pos = $host.UI.RawUI.CursorPosition
    # Check if the player is running into himself
    if ($worm.Segments | Where-Object { ($_.X1 -eq $pos.X) -and ($_.Y -eq $pos.Y) }) {
        return $true
    } elseif ($worm.Segments | Where-Object { ($_.X2 -eq $pos.X) -and ($_.Y -eq $pos.Y) }) {
        return $true
    }
    return $false
}

function End-Game {
    Param(
        [Parameter(Mandatory=$true)]$Message
    )
    $Script:Exit = $true
    # Erase the worm!
    1..($worm.Segments.Count) | ForEach-Object {
        Start-Sleep -Milliseconds 10
        Remove-WormSegment
    }
    Set-CursorPosition -X ($Host.UI.RawUI.BufferSize.Width / 2 - ($Message.Length / 2)) `
        -Y ($Host.UI.RawUI.BufferSize.Height / 2)
    Write-Host $Message -ForegroundColor Black -BackgroundColor DarkRed -NoNewline
}

function Move-Worm {
    switch ($worm.Direction) {
        Up      {
            Move-CursorPosition -Y -1 -X -1
        }
        Right   {
            Move-CursorPosition -X 1
        }
        Down    {
            Move-CursorPosition -Y 1 -X -1
        }
        Left    {
            Move-CursorPosition -X -3
        }
    }
    if ((-not (Get-CursorWithinPlayArea)) -or (Get-CursorIsOnWormSegment)) {
    End-Game -Message " BAM! You're DEAD! Score : $Script:Score "
    } else {
        Add-WormSegment
        if ($worm.Segments.Count -gt $worm.Length) {
            Remove-WormSegment
        }
    }
}

Function Read-Key {
    $hideKeysStrokes = $true
    if ([console]::KeyAvailable) {
        $key = [Console]::ReadKey($hideKeysStrokes)
        switch ($key.key) {
            RightArrow  {
                switch ($worm.Direction) {
                    Right   { $worm.Direction = 'Down' }
                    Down    { $worm.Direction = 'Left' }
                    Left    { $worm.Direction = 'Up' }
                    Up      { $worm.Direction = 'Right' }
                }
            }
            LeftArrow   {
                switch ($worm.Direction) {
                    Right   { $worm.Direction = 'Up' }
                    Up      { $worm.Direction = 'Left' }
                    Left    { $worm.Direction = 'Down' }
                    Down    { $worm.Direction = 'Right' }
                }
            }
            Escape {
                End-Game -Message " Goodbye! Score : $Script:Score "
            }
        }
    }
}

function Write-Fence {
    $pos = $Host.UI.RawUI.CursorPosition
    $pos.X = $playArea.UpperLeft.X - 1
    $pos.Y = $playArea.UpperLeft.Y - 1
    $Host.UI.RawUI.CursorPosition = $pos
    do {
        Write-Host '#' -NoNewline -ForegroundColor $fenceColor
        $pos.Y += 1
        $Host.UI.RawUI.CursorPosition = $pos
    } until ($pos.Y -eq ($playArea.BottomRight.Y + 1))
    do {
        Write-Host '#' -NoNewline -ForegroundColor $fenceColor
        $pos.X += 1
        $Host.UI.RawUI.CursorPosition = $pos
    } until ($pos.X -eq ($playArea.BottomRight.X + 1))
    do {
        Write-Host '#' -NoNewline -ForegroundColor $fenceColor
        $pos.Y -= 1
        $Host.UI.RawUI.CursorPosition = $pos
    } until ($pos.Y -eq ($playArea.UpperRight.Y - 1))
    do {
        Write-Host '#' -NoNewline -ForegroundColor $fenceColor
        $pos.X -= 1
        $Host.UI.RawUI.CursorPosition = $pos
    } until ($pos.X -eq ($playArea.UpperLeft.X - 1))
}

Write-Fence

# Set starting position to the middle of the buffer by moving the cursor there
Set-CursorPosition -X ($Host.UI.RawUI.BufferSize.Width / 2) -Y ($Host.UI.RawUI.BufferSize.Height / 2)

# Set random starting direction
switch (Get-Random -Minimum 0 -Maximum 4) {
    0 {
        $worm.Direction = 'Up'
    }
    1 {
        $worm.Direction = 'Right'
    }
    2 {
        $worm.Direction = 'Down'
    }
    3 {
        $worm.Direction = 'Left'
    }
}

# Set the coordinates of the first worm segment determined by the starting direction
$worm.Segments[0].X1 = $Host.UI.RawUI.CursorPosition.X
Move-CursorPosition -X 1 # Unless the cursor is repositioned here, the worm 
                         # immediately eats itself if the starting direction is Right
$worm.Segments[0].X2 = $Host.UI.RawUI.CursorPosition.X
$worm.Segments[0].Y = $Host.UI.RawUI.CursorPosition.Y

while ($Script:Exit -eq $false) {
    Write-Score
    Read-Key
    Move-Worm
    Start-Sleep -Milliseconds 40
}

#Start-Sleep 10
Set-CursorPosition -X 0 -Y $Host.UI.RawUI.BufferSize.Height
Write-Host "#" # Moves prompt below the bottom fence
$Host.UI.RawUI.BufferSize = $originalBufferSize
[console]::CursorVisible=$true
