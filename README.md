# arma-startup-scripts

*arma-startup-scripts* a GIT repository with the purpose of helping our developers and mission makers to quickly setup a local development ARMA3 server. 

The only requirement is that your computer has Powershell. The script has only tested on Windows 10, so if you're on Windows 7 give it a try and report back with your findings!


Instructions
------------
The start.ps1 will require some modifications from the user to get started. 
1. Open the script in your favorite text editor
2. Modify `$modRepo` and select which modsets you're planning to use.
3. Set `$armaPath` to the path of your ARMA3 installation. Don't put a slash in the end.
4. Set `$mainRepoPath` (and optionally `$campaignRepoPath` and `$devRepoPath`) to the path correct path. Again, don't put a slash in the end. For most of you, just copy the path that's in your ARMA3Sync:

![image](https://user-images.githubusercontent.com/9605751/113356500-9d3bd200-9342-11eb-96cd-537d8a1c5905.png)

5. Edit `$numHC` to the amount of headless clients you want to use. If you're unsure, select 0.
6. If you're planning on editing CBA settings, set `$useLatestCBA` to "no" to avoid it being overwritten with the latest CNTO version.
7. Finally, if you've changed the server password in server.cfg, edit `$serverPassword` to the correct password.

You're now good to go! Right-click start.ps1 and select "Run with Powershell" and the server will start if they're no errors.
