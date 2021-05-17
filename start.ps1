param ($repo)
# --- User Config ---
# Which mod repos do you want to run? Can be overriden by launching the script with the "-repo" parameter
# Mix and match between: main, dev, campaign, gm (Cold War Germany), vn (S.O.G. Prairie Fire)
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
$numHC = 0
# Use latest CBA settings: yes/no
$useLatestCBA = "no"
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
# Add support to override $modRepo with parameter at launch
if (-Not ([string]::IsNullOrWhiteSpace($repo))) {
    Write-Host "Overriding modRepo in config with -repos launch parameter: $repo"
    $modRepo = $repo
}

# Check if $modRepo is properly setup, if it is then prefix and postfix the string for more accurate matching.
if ([string]::IsNullOrWhiteSpace($modRepo)) {
    Write-Error "The `$modRepo variable is invalid or empty."
    Start-Sleep 10
    exit
}
else {
    $prettyModRepo = $modRepo
    $modRepo = "+" + $modRepo + "+"
}
# Check if the $armaPath variable exists and if game exe exists.
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

# Fix requirement to use different ARMA3 branch if creator DLC is being used
if ($modRepo -like "*+gm+*" -or $modRepo -like "*+vn+*") {
    $commonServerParameters += " -beta creatordlc"
}

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
    return "$($modDiffList)"+ ";" +"$(Get-Mods($devMods))"
}

# Rewrite Get-ModList to use array, both for $modRepoList and $type/$modRepo
function Get-ModList($type) {
    if ($type -like "*+main+*" -and $type -like "*+dev+*") {
        $modRepoList = "$(Get-DevModDiff)"
    } 
    elseif ($type -like "*+main+*") {
        $modRepoList = "$(Get-Mods($mainMods))"
    }
    else {
        Write-Error "You didn't specify a valid modRepo string. Missing `"main`""
        exit
    }

    if ($type -like "*+campaign+*") {
        $modRepoList += ';' +"$(Get-Mods($campaignMods))"
    }
    
    # Creator DLCs
    if ($type -like "*+vn+*") {
        $modRepoList += ';' +"vn"
    }
    if ($type -like "*+gm+*") {
        $modRepoList += ';' +"gm"
    }
    
    return $modRepoList
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
    Write-Host "Starting the server with modset $prettyModRepo"
    Start-Process -FilePath "$gameExeFullPath" -ArgumentList "$commonServerParameters -filePatching -name=server -config=$configDir\server.cfg -cfg=$configDir\basic.cfg `"-mod=$mods`""
}

Initialize-Server
Start-Server -type $modRepo -getLatestCBA $useLatestCBA -useHC $numHC
# Close Powershell window after 60 seconds, to let the user see info.
Start-Sleep 60