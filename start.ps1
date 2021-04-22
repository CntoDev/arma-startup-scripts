# --- User Config ---
# Which mod repos do you want to run? Pick between: main, main+dev, main+campaign or main+dev+campaign
$modRepo = "main+dev"
# Path to Arma3
$armaPath = "X:\Games\steamapps\common\Arma 3"
# Main repo directory path
$mainRepoPath = "X:\Games\steamapps\common\Arma 3\Main-Repo"
# Campaign repo path (optional)
$campaignRepoPath = "X:\Games\steamapps\common\Arma 3\Campaign-Repo"
# Dev repo path (optional)
$devRepoPath = "X:\Games\steamapps\common\Arma 3\Dev-Repo"
# Number of HCs: number of headless clients you want to use. 0 for none.
$numHC = 1
# Use latest CBA settings: yes/no
$useLatestCBA = "yes"
# Server password defined in server.cfg
$serverPassword = "localpass"

# --- Static Config ---
# Set location to the folder where the start script resides
Set-Location $PSScriptRoot
$currentLocation = Get-Location
$configDir = "$currentLocation\configDir"
$cbaSettingsURL = "https://raw.githubusercontent.com/CntoDev/cba-settings-lock/master/cba_settings_userconfig/cba_settings.sqf"
$commonServerParameters = "-port 2302 -noSplash -noLand -enableHT -hugePages -profiles=$configDir\profiles"
# Use 64-bit exe if possible
$gameExe = if ([Environment]::Is64BitOperatingSystem) { "arma3server_x64.exe" } else { "arma3server.exe" }
$gameExeFullPath = Join-Path "$armaPath" "$gameExe"
# Fix TLS bug
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-Mods($repoName, $repoPath) {
    if ($modRepo -like "*$repoName*") {
        if ([string]::IsNullOrWhiteSpace($repoPath)) {
            Write-Error "ERROR! You've set `$modrepo to $modRepo, but the $reponame repo variable is invalid or empty."
            Start-Sleep 10
            exit
        }
        elseif (-Not (Test-Path $repoPath)) {
            Write-Error "ERROR! You've set `$modrepo to $modRepo, but the $reponame repo directory is invalid or does not exist."
            Start-Sleep 10
            exit
        }
        Write-Host "$repoName is activated." 
        return Get-ChildItem $repoPath
    }
    Write-Host "$repoName not activated." 
}

# Test Mods with above function
$mainMods=$(Test-Mods -repoName "main" -repoPath $mainRepoPath)
$devMods=$(Test-Mods -repoName "dev" -repoPath $devRepoPath)
$campaignMods=$(Test-Mods -repoName "campaign" -repoPath $campaignRepoPath)

# Also check the $armaPath variable and if game exe exists.
if ([string]::IsNullOrWhiteSpace($armaPath)) {
    Write-Error "The `$armaPath variable is invalid or empty."
    Start-Sleep 10
    exit
}
elseif (-Not (Test-Path "$gameExeFullPath")) {
    Write-Error "You've set `$armaPath to $armaPath, but the directory is invalid or does not include $gameExe."
    Start-Sleep 10
    exit
}


function Get-Mods($modsObject) {
    $modList = $modsObject | Group-Object -Property Directory | ForEach-Object {
        @(
            $_.Group | Resolve-Path | Convert-Path
        )-join';'
    }
    return $modList
}

function Get-DevModDiff() {
    # If dev folder is empty, just return the main mods. Otherwise the Compare-Object below will crash.
    if (($devMods | Measure-Object).Count -eq 0) {
        Write-Warning "Dev repo directory is empty but `$modrepo is set to $modRepo."
        return Get-Mods($mainMods)
    }
    $devDiff = Compare-Object -ReferenceObject $mainMods -DifferenceObject $devMods -IncludeEqual -ExcludeDifferent -PassThru
    if (($devDiff | Measure-Object).Count -eq 0) {
        Write-Host "No main and dev mods are in conflict."
        return Get-Mods($mainMods)
    }
    $modDiffList = Compare-Object -ReferenceObject $devDiff -DifferenceObject $mainMods -PassThru | Group-Object -Property Directory | ForEach-Object {
        @(
            $_.Group | Resolve-Path | Convert-Path
        )-join';'
    }
    Write-Warning "A few main and dev mods are in conflict. Resolving..."
    return "$($modDiffList)"+ "," +"$(Get-Mods($devMods))"
}

# Awful switch statement to get correct mods - preferably move $modrepos to an array
function Get-ModList($type) {
    switch ($type) {
        "main" {return "$(Get-Mods($mainMods))"}

        "main+dev" {return "$(Get-DevModDiff)"}

        "main+campaign" {return "$(Get-Mods($mainMods))"+ "," +"$(Get-Mods($campaignMods))"}

        "main+dev+campaign" {return "$(Get-DevModDiff)"+ ',' +"$(Get-Mods($campaignMods))"}
    }
}

function Initialize-Server {
    # Create userconfig folder in arma3 folder, if it doesn't exist:
    if (-not (Test-Path "$armaPath\userconfig")) {
        New-Item -Path "$armaPath" -Name "userconfig" -ItemType "directory" -Force | Out-Null
    }
    # Add cba_settings, if it doesn't exist:
    if (-not (Test-Path "$armaPath\userconfig\cba_settings.sqf")) {
        Invoke-RestMethod -Uri $cbaSettingsURL -OutFile "$armaPath\userconfig\cba_settings.sqf"
    }
}

function Start-Server($type,$getLatestCBA,$useHC) {
    $mods = Get-ModList($type)
    $modlist = $mods -Split(";")
    Write-Host "Modlist:"
    $modlist
    # Force overwrite cba_settings.sqf if requested
    if ($getLatestCBA -eq "yes") {
        Write-Host "Downloading latest CBA Settings from Github..."
        try {
            Invoke-RestMethod -Uri $cbaSettingsURL -OutFile "$armaPath\userconfig\cba_settings.sqf" -ErrorAction Stop
        } catch {
            Write-Warning "Unable to fetch latest CBA! Exiting... "
            Write-Warning $Error[0]
            exit
        }
    }
    if ($useHC -gt 0) {
        foreach($i in 1..$useHC) {
            Write-Host "Starting headless client $i..."
            Start-Process -FilePath "$gameExeFullPath" -ArgumentList "$commonServerParameters -client -connect=127.0.0.1 -password=$serverPassword `"-mod=$mods`""
            Start-Sleep 3
        }
    }
    Write-Host "Starting the server with modset $type"
    Start-Process -FilePath "$gameExeFullPath" -ArgumentList "$commonServerParameters -filePatching -name=server -config=$configDir\server.cfg -cfg=$configDir\basic.cfg `"-mod=$mods`""
}

Initialize-Server
Start-Server -type $modRepo -getLatestCBA $useLatestCBA -useHC $numHC
# Close Powershell window after 60 seconds, to let the user see info.
Start-Sleep 60