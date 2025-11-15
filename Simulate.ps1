[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string] $Path,

    [switch] $Run,

    [string] $PlaceholderFilename = 'placeholder.exe',

    [string] $Content,
    
    [switch] $Clear,
    
    [switch] $Stop
)

$HistoryFile = Join-Path $PSScriptRoot "destination-history.txt"

# Display banner
function Show-Banner {
    Write-Host ""
    Write-Host ("=" * 55) -ForegroundColor Cyan
    Write-Host "  Discord Playtime Simulator " -ForegroundColor White
    Write-Host "  Simulate running the game on discord " -ForegroundColor Gray
    Write-Host ("=" * 55) -ForegroundColor Cyan
    Write-Host ""
}

function Add-DestinationHistory {
    param([string] $DestinationPath)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp | $DestinationPath"
    Add-Content -Path $HistoryFile -Value $entry -ErrorAction SilentlyContinue
}

function Clear-DestinationHistory {
    if (-not (Test-Path $HistoryFile)) {
        Write-Host ""
        Write-Host "No history file found." -ForegroundColor Yellow
        Write-Host ""
        return
    }
    
    Write-Host ""
    Write-Host "Current history entries:" -ForegroundColor Cyan
    Write-Host ""
    
    $entries = Get-Content $HistoryFile -ErrorAction SilentlyContinue
    if ($entries) {
        $entries | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host ""
        
        $confirm = Read-Host "Clear history and delete all files? [Y/n]"
        if ($confirm -notmatch '^[Nn]') {
            Write-Host ""
            
            # Parse entries to get paths and try to delete files
            $deletedCount = 0
            $failedCount = 0
            $notFoundCount = 0
            $failedFiles = @()
            
            foreach ($entry in $entries) {
                if ($entry -match '\| (.+)$') {
                    $filePath = $matches[1]
                    
                    if (Test-Path $filePath) {
                        try {
                            Remove-Item -LiteralPath $filePath -Force -ErrorAction Stop
                            Write-Host "  [OK] Deleted: $filePath" -ForegroundColor Green
                            $deletedCount++
                        }
                        catch {
                            Write-Host "  [FAIL] Cannot delete (file may be in use): $filePath" -ForegroundColor Red
                            $failedCount++
                            $failedFiles += $filePath
                        }
                    } else {
                        Write-Host "  [SKIP] Not found: $filePath" -ForegroundColor DarkGray
                        $notFoundCount++
                    }
                }
            }
            
            Write-Host ""
            
            # Only clear history if no files failed to delete
            if ($failedCount -eq 0) {
                Remove-Item -Path $HistoryFile -Force -ErrorAction SilentlyContinue
                Write-Host "Summary:" -ForegroundColor Cyan
                Write-Host "  Deleted: $deletedCount" -ForegroundColor Green
                if ($notFoundCount -gt 0) {
                    Write-Host "  Not found: $notFoundCount" -ForegroundColor DarkGray
                }
                Write-Host "  History cleared." -ForegroundColor Green
                Write-Host ""
            } else {
                Write-Host "Summary:" -ForegroundColor Cyan
                Write-Host "  Deleted: $deletedCount" -ForegroundColor Green
                Write-Host "  Failed: $failedCount" -ForegroundColor Red
                if ($notFoundCount -gt 0) {
                    Write-Host "  Not found: $notFoundCount" -ForegroundColor DarkGray
                }
                Write-Host ""
                Write-Host "Some files are still in use." -ForegroundColor Yellow
                Write-Host "Close the following applications and try again:" -ForegroundColor Yellow
                foreach ($file in $failedFiles) {
                    Write-Host "  - $file" -ForegroundColor Red
                }
                Write-Host ""
                Write-Host "TIP: Use -Stop to terminate running processes first" -ForegroundColor Cyan
                Write-Host "     .\Simulate.ps1 -Stop" -ForegroundColor DarkGray
                Write-Host ""
            }
        } else {
            Write-Host ""
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            Write-Host ""
        }
    } else {
        Write-Host "  No entries found." -ForegroundColor Yellow
        Write-Host ""
    }
}

function Stop-HistoryProcesses {
    if (-not (Test-Path $HistoryFile)) {
        Write-Host ""
        Write-Host "No history file found." -ForegroundColor Yellow
        Write-Host ""
        return
    }
    
    Write-Host ""
    Write-Host "Checking for running processes from history..." -ForegroundColor Cyan
    Write-Host ""
    
    $entries = Get-Content $HistoryFile -ErrorAction SilentlyContinue
    if (-not $entries) {
        Write-Host "No entries in history." -ForegroundColor Yellow
        Write-Host ""
        return
    }
    
    $stoppedCount = 0
    $notRunningCount = 0
    
    foreach ($entry in $entries) {
        if ($entry -match '\| (.+)$') {
            $filePath = $matches[1]
            $fileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
            
            # Find processes running this executable
            $processes = Get-Process -Name $fileName -ErrorAction SilentlyContinue | Where-Object {
                $_.Path -eq $filePath
            }
            
            if ($processes) {
                foreach ($proc in $processes) {
                    try {
                        $proc | Stop-Process -Force -ErrorAction Stop
                        Write-Host "  [STOPPED] $fileName (PID: $($proc.Id))" -ForegroundColor Green
                        $stoppedCount++
                    }
                    catch {
                        Write-Host "  [FAIL] Cannot stop $fileName (PID: $($proc.Id))" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "  [SKIP] Not running: $fileName" -ForegroundColor DarkGray
                $notRunningCount++
            }
        }
    }
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Stopped: $stoppedCount" -ForegroundColor Green
    Write-Host "  Not running: $notRunningCount" -ForegroundColor DarkGray
    Write-Host ""
}

# Check for stop processes switch first
if ($Stop) {
    Stop-HistoryProcesses
    return
}

# Check for clear history switch first
if ($Clear) {
    Clear-DestinationHistory
    return
}

function New-PlaceholderFile {
    param(
        [string] $Name,
        [string] $Body
    )
    
    Write-Verbose "New-PlaceholderFile called with Name='$Name'"
    
    $exists = Test-Path -LiteralPath $Name
    if (-not $exists) {
        Write-Host ("-" * 50) -ForegroundColor Yellow
        Write-Host "  No placeholder file found!" -ForegroundColor Yellow
        Write-Host ("-" * 50) -ForegroundColor Yellow
        Write-Host ""
        
        # Check for any .exe files in current directory
        $exeFiles = Get-ChildItem -Path (Get-Location) -Filter "*.exe" -File -ErrorAction SilentlyContinue
        
        if ($exeFiles.Count -gt 0) {
            Write-Host "Found existing .exe file(s) in this directory:" -ForegroundColor Cyan
            foreach ($exe in $exeFiles) {
                Write-Host "  - $($exe.Name)" -ForegroundColor White
            }
            Write-Host ""
            
            $useExisting = Read-Host "Use '$($exeFiles[0].Name)' as placeholder? [Y/n]"
            
            if ($useExisting -notmatch '^[Nn]') {
                Write-Host ""
                Write-Host "[OK] Renaming '$($exeFiles[0].Name)' to '$Name'..." -ForegroundColor Green
                
                try {
                    Rename-Item -LiteralPath $exeFiles[0].FullName -NewName $Name -Force -ErrorAction Stop
                    Write-Host "     Placeholder created successfully." -ForegroundColor Green
                    Write-Host ""
                    
                    $placeholderFullPath = Join-Path (Get-Location) $Name
                    return Get-Item -LiteralPath $placeholderFullPath
                }
                catch {
                    Write-Host ""
                    Write-Host "Error: Failed to rename file: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host ""
                }
            }
        }
        
        Write-Host "You can select an executable from your Start Menu apps." -ForegroundColor Gray
        $response = Read-Host "Continue to selection menu? [Y/n]"
        
        if ($response -match '^[Nn]') {
            Write-Host ""
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit
        }
        
        Start-Sleep -Milliseconds 300
        
        # Get source executable from Start Menu shortcuts
        $startMenuPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
        $allShortcuts = Get-ChildItem -Path $startMenuPath -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue
        
        # Filter out Windows system folders
        $windowsFolders = @(
            "Accessories", "Administrative Tools", "System Tools", "Windows PowerShell",
            "Maintenance", "Startup", "Windows Accessories"
        )
        
        $shortcuts = $allShortcuts | Where-Object {
            $path = $_.FullName
            $isWindowsFolder = $false
            foreach ($folder in $windowsFolders) {
                if ($path -like "*\$folder\*") {
                    $isWindowsFolder = $true
                    break
                }
            }
            -not $isWindowsFolder
        }
        
        if ($shortcuts.Count -eq 0) {
            throw "No third-party shortcuts found in Start Menu."
        }
        
        # Limit to 30 shortcuts
        if ($shortcuts.Count -gt 30) {
            $shortcuts = $shortcuts | Select-Object -First 30
        }
        
        # Check if Everything.lnk exists and prompt user
        $everythingShortcut = $shortcuts | Where-Object { $_.Name -eq "Everything.lnk" } | Select-Object -First 1
        
        $selectedPath = $null
        
        if ($everythingShortcut) {
            Write-Host ""
            Write-Host "Found Everything.lnk in Start Menu" -ForegroundColor Cyan
            $useEverything = Read-Host "Use Everything.lnk? [Y/n]"
            
            if ($useEverything -notmatch '^[Nn]') {
                Write-Host ""
                Write-Host "[OK] Using Everything.lnk" -ForegroundColor Green
                
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($everythingShortcut.FullName)
                $selectedPath = $shortcut.TargetPath
            }
        }
        
        if (-not $selectedPath) {
            # Interactive menu
            $selectedIndex = 0
        
            while ($true) {
                Clear-Host
                Write-Host ""
                Write-Host ("=" * 79) -ForegroundColor Cyan
                Write-Host "  SELECT SOURCE APPLICATION" -ForegroundColor Cyan
                Write-Host "  UP/DOWN Navigate  |  Enter = Select  |  Esc = Cancel" -ForegroundColor Cyan
                Write-Host ("=" * 79) -ForegroundColor Cyan
                Write-Host ""
                
                for ($i = 0; $i -lt $shortcuts.Count; $i++) {
                    $shortcutName = $shortcuts[$i].Name -replace '\.lnk$', ''
                    if ($i -eq $selectedIndex) {
                        Write-Host "  > $shortcutName" -ForegroundColor Black -BackgroundColor White
                    } else {
                        Write-Host "    $shortcutName" -ForegroundColor Gray
                    }
                }
                
                Write-Host ""
                
                $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                
                switch ($key.VirtualKeyCode) {
                    38 { # Up arrow
                        if ($selectedIndex -gt 0) { $selectedIndex-- }
                    }
                    40 { # Down arrow
                        if ($selectedIndex -lt ($shortcuts.Count - 1)) { $selectedIndex++ }
                    }
                    13 { # Enter
                        $shell = New-Object -ComObject WScript.Shell
                        $shortcut = $shell.CreateShortcut($shortcuts[$selectedIndex].FullName)
                        $selectedPath = $shortcut.TargetPath
                        break
                    }
                    27 { # Esc
                        Clear-Host
                        Write-Host ""
                        Write-Host "Operation cancelled." -ForegroundColor Yellow
                        exit
                    }
                }
                
                if ($selectedPath) { break }
            }
            
            Clear-Host
        }
        
        if (-not $selectedPath -or -not (Test-Path -LiteralPath $selectedPath)) {
            Write-Host ""
            Write-Host "Error: Selected shortcut target is invalid." -ForegroundColor Red
            Write-Host "Path: $selectedPath" -ForegroundColor Gray
            exit 1
        }
        
        Write-Host ""
        Write-Host "[OK] Selected executable:" -ForegroundColor Green
        Write-Host "     $selectedPath" -ForegroundColor White
        Write-Host ""
        Write-Host "     Copying to placeholder: $Name" -ForegroundColor Gray
        Write-Host ""
        
        try {
            $placeholderPath = Join-Path (Get-Location) $Name
            Copy-Item -LiteralPath $selectedPath -Destination $placeholderPath -Force -ErrorAction Stop
        }
        catch {
            throw "Failed to copy selected file to placeholder: $($_.Exception.Message)"
        }
    }

    $placeholderFullPath = Join-Path (Get-Location) $Name
    Get-Item -LiteralPath $placeholderFullPath
}

function Resolve-TargetPath {
    param([string] $Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { throw "Target path is empty." }
    
    # Expand special folder paths
    $Raw = $Raw.Trim()
    
    # Replace Desktop at the start with the actual Desktop path
    if ($Raw -match '^Desktop\\') {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $Raw = $Raw -replace '^Desktop\\', "$desktopPath\"
    }
    # If not an absolute path, assume Desktop
    elseif (-not [System.IO.Path]::IsPathRooted($Raw)) {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $Raw = Join-Path $desktopPath $Raw
    }
    
    $ext = [System.IO.Path]::GetExtension($Raw)
    
    # If no extension or not .exe, append .exe
    if ([string]::IsNullOrEmpty($ext) -or $ext -ne '.exe') {
        $Raw = $Raw + '.exe'
    }
    
    $dir = [System.IO.Path]::GetDirectoryName($Raw)
    $file = [System.IO.Path]::GetFileName($Raw)
    [PSCustomObject]@{ Directory = $dir; FileName = $file; FullPath = $Raw }
}

function Copy-PlaceholderToTarget {
    param(
        [System.IO.FileInfo] $Source,
        [pscustomobject] $TargetInfo
    )
    if (-not (Test-Path -LiteralPath $TargetInfo.Directory)) {
        if ($PSCmdlet.ShouldProcess($TargetInfo.Directory, 'Create directory')) {
            New-Item -Path $TargetInfo.Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
    }
    if ($PSCmdlet.ShouldProcess($TargetInfo.FullPath, "Copy '$($Source.Name)'")) {
        Copy-Item -LiteralPath $Source.FullName -Destination $TargetInfo.FullPath -Force -ErrorAction Stop
    }
}

if (-not $PSBoundParameters.ContainsKey('Path')) {
    Show-Banner
    
    Write-Host "Enter destination path:" -ForegroundColor White
    Write-Host "  Examples: myapp  or  Desktop\myapp  or  C:\Tools\myapp.exe" -ForegroundColor DarkGray
    Write-Host "  Use -Clear to clear history" -ForegroundColor DarkGray
    Write-Host ""
    $Path = Read-Host "Path"
    Write-Host ""
}

try {
    $placeholder = New-PlaceholderFile -Name $PlaceholderFilename -Body $Content
    $targetInfo  = Resolve-TargetPath -Raw $Path

    Write-Verbose "Resolved target directory: $($targetInfo.Directory)"
    Copy-PlaceholderToTarget -Source $placeholder -TargetInfo $targetInfo

    $success = Test-Path -LiteralPath $targetInfo.FullPath
    $ran = $false

    if ($success) {
        Write-Host ("-" * 50) -ForegroundColor Green
        Write-Host "  [SUCCESS]" -ForegroundColor Green
        Write-Host ("-" * 50) -ForegroundColor Green
        Write-Host ""
        Write-Host "  File: $($targetInfo.FileName)" -ForegroundColor White
        Write-Host "  Location: $($targetInfo.Directory)" -ForegroundColor Gray
        Write-Host ""
        
        # Add to history
        Add-DestinationHistory -DestinationPath $targetInfo.FullPath
        
        # Prompt user to run the application (unless -Run switch is used)
        if ($Run) {
            try {
                Start-Process -FilePath $targetInfo.FullPath -ErrorAction Stop
                $ran = $true
                Write-Host "  > Application started" -ForegroundColor Cyan
            }
            catch {
                Write-Warning "Failed to start process: $($_.Exception.Message)"
            }
        }
        else {
            $runResponse = Read-Host "Run the application now? [Y/n]"
            
            if ($runResponse -notmatch '^[Nn]') {
                try {
                    Start-Process -FilePath $targetInfo.FullPath -ErrorAction Stop
                    $ran = $true
                    Write-Host ""
                    Write-Host "  > Application started" -ForegroundColor Cyan
                }
                catch {
                    Write-Warning "Failed to start process: $($_.Exception.Message)"
                }
            }
        }
        Write-Host ""
    } else {
        Write-Host ""
        Write-Warning "File copy did not succeed."
    }

    $result = [PSCustomObject]@{
        Placeholder = $placeholder.FullName
        Destination = $targetInfo.FullPath
        Directory   = $targetInfo.Directory
        Success     = $success
        Ran         = $ran
    }

    $result
}
catch {
    Write-Host ""
    Write-Host ("-" * 50) -ForegroundColor Red
    Write-Host "  [ERROR]" -ForegroundColor Red
    Write-Host ("-" * 50) -ForegroundColor Red
    Write-Host ""
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Tip: Try running PowerShell as Administrator if permission denied." -ForegroundColor DarkGray
    Write-Host ""
}