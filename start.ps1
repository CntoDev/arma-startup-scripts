# --- User Config ---
# Which mod repos do you want to run? Pick between: main, main+dev, main+campaign or main+dev+campaign
$modRepo = "main+dev"
# WE DEAL WITH ABSOLUTES!
# $configLocation = "C:\Users\Gandolf\Documents\GIT-CNTO\testscript"
# Main cnto repo directory path
$mainRepoPath = "X:\Games\steamapps\common\Arma 3\Main-Repo"
# Campaign cnto repo path (optional)
$campaignRepoPath = "X:\Games\steamapps\common\Arma 3\Campaign-Repo"
# Dev cnto repo path (optional)
$devRepoPath = "X:\Games\steamapps\common\Arma 3\Dev-Repo"
# Path to Arma3
$armaPath = "X:\Games\steamapps\common\Arma 3"
# Number of HCs: number of headless clients you want. 0 for none.
$numHC = 1
# Use latest CBA settings: yes/no
$useLatestCBA = "no"
# Config directory name: dedicated-config (this is the "related directory" from above)

# Static Config
# Set location to the folder where the start script resides
Set-Location $PSScriptRoot
$currentLocation = Get-Location
$configDir = "$currentLocation\configDir"
$cbaSettingsURL = "https://raw.githubusercontent.com/CntoDev/cba-settings-lock/master/cba_settings_userconfig/cba_settings.sqf"
$commonServerParameters = "-port 2302 -noSplash -noLand -enableHT -hugePages -profiles=$configDir\profiles"

# Test Mods
if (Test-Path $mainRepoPath) {
    $mainMods = Get-ChildItem $mainRepoPath
}
else {
    Write-Host "The main repo path is invalid!"
    exit
}
if ($modRepo -like "*dev*") {
    if ([string]::IsNullOrWhiteSpace($devRepoPath)) {
        Write-Host "You've set `$modrepo to $modRepo, but the dev repo variable is invalid or empty."
        exit
    }
    elseif (-Not (Test-Path $devRepoPath)) {
        Write-Host "You've set `$modrepo to $modRepo, but the dev repo directory is invalid or empty."
        exit
    }
    $devMods = Get-ChildItem $devRepoPath
}
if ($modRepo -like "*campaign*") {
    if ([string]::IsNullOrWhiteSpace($campaignRepoPath)) {
        Write-Host "You've set `$modrepo to $modRepo, but the campaign repo variable is invalid or empty."
        exit
    }
    elseif (-Not (Test-Path $campaignRepoPath)) {
        Write-Host "You've set `$modrepo to $modRepo, but the campaign repo directory is invalid or empty."
        exit
    }
    $campaignMods = Get-ChildItem $campaignRepoPath
} 

# Functions
function Get-Mods($modsObject) {
    $modList = $modsObject | Group-Object -Property Directory | ForEach-Object {
        @(
            $_.Group | Resolve-Path | Convert-Path
        )-join','
    }
    return $modList
}

function Get-DevModDiff() {
    # If dev folder is empty, just return the main mods. Otherwise the Compare-Object below will crash.
    if (($devMods | Measure-Object).Count -eq 0) {
        Write-Host "Dev repo is empty."
        return Get-Mods($mainMods)
    }
    $devDiff = Compare-Object -ReferenceObject $mainMods -DifferenceObject $devMods -IncludeEqual -ExcludeDifferent -PassThru
    $modDiffList = Compare-Object -ReferenceObject $devDiff -DifferenceObject $mainMods -PassThru | Group-Object -Property Directory | ForEach-Object {
        @(
            $_.Group | Resolve-Path | Convert-Path
        )-join','
    }
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


# First Setup - 
# https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.1
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
    # Force overwrite cba_settings.sqf if requested
    if ($getLatestCBA -eq "yes") {
        Write-Host "Downloading latest CBA Settings from Github"
        Invoke-RestMethod -Uri $cbaSettingsURL -OutFile "$armaPath\userconfig\cba_settings.sqf"
    }
    if ($useHC -gt 0) {
        foreach($i in 1..$useHC) {
            Write-Host "Starting headless client $i..."
            Start-Process -FilePath "$armapath\arma3server.exe" -ArgumentList "$commonServerParameters -client -connect=127.0.0.1 -password=cnto -mod=`"$mods`""
        }
    }
    Write-Host "Starting the server with modset $type - $mods"
    Start-Process -FilePath "$armapath\arma3server.exe" -ArgumentList "$commonServerParameters -filePatching -name=server -config=$configDir\server.cfg -cfg=$configDir\basic.cfg -mod=`"$mods`""

}


Initialize-Server
Start-Server -type $modRepo -getLatestCBA $useLatestCBA -useHC $numHC