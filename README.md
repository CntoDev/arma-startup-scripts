# arma-startup-scripts

*arma-startup-scripts* is a GIT repository with the purpose of helping our developers and mission makers to quickly setup a local ARMA3 server for development and testing. 

The only requirement is that your computer has Powershell. The script has only been tested on Windows 10, so if you're on Windows 7 give it a try and report back with your findings!


Instructions
------------
To get started, download the GIT repo from: https://github.com/CntoDev/arma-startup-scripts/archive/refs/heads/main.zip  Unzip and place the resulting directory where ever you'd like to store it.

The `start.ps1` script will require some modifications from the user to get started. 
1. Open `start.ps1` in your favorite text editor
2. Modify `$modRepo` and select which modsets you're planning to use. (Alternatively use the `-repo` launch parameter)
3. Set `$armaPath` to the path of your ARMA3 installation. Don't put a slash in the end.
4. Set `$mainRepoPath` (and optionally `$campaignRepoPath` and `$devRepoPath`) to the path correct path. Again, don't put a slash in the end. For most of you this means copying the paths that are in your ARMA3Sync:

![image](https://user-images.githubusercontent.com/9605751/113356500-9d3bd200-9342-11eb-96cd-537d8a1c5905.png)

5. Edit `$numHC` to the amount of headless clients you want to use. If you're unsure, select 0.
6. If you're planning on editing CBA settings, set `$useLatestCBA` to "no" to avoid it being overwritten with the latest CNTO version.
7. Finally, if you've changed the server password in server.cfg, edit `$serverPassword` to the correct password.

You're now good to go! Right-click start.ps1 and select "Run with Powershell" and the server will start if they're no errors.  


Issues
------------
If you haven't had the chance to run any Powershell scripts before you might encounter the following error: `The file start.ps1 is not digitally signed. You cannot run this script on the current system.`

To fix this, we need to change a few settings:
1. Open Powershell as an administrator
2. Navigate to the script folder. Type `cd` followed by the path to the `arma-startup-scripts` folder. Example: `cd Z:\Git\arma-startup-scripts\`
3. Change settings so that only remote scripts have to be signed: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned`
4. Change start.ps1 into a local script `Unblock-File start.ps1`
