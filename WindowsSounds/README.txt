Made by 1337leets

1. Place the WindowsSounds folder in C:\

2. Go to Group Policy Management Editor (you can press Win+R then type gpedit.msc and run) 

3.1. If you want to add Startup/Shutdown sounds go to Computer Configuration>Windows Settings>Scripts (Startup/Shutdown) and add the scripts inside the SciptFiles folder.

3.2. If you want to add Login/Logoff sounds go to User Configuration>Windows Settings>Scripts (Login/Logoff) and add the scripts inside the SciptFiles folder.



If you want to change the sounds go to C:\WindowsSounds\SoundFiles and make sure it's in .wav format and has the same name as the original file. 

Otherwise you can edit the script files on C:\WindowsSounds\ScriptFiles and edit the Powershell scripts as:

powershell.exe -c (New-Object Media.SoundPlayer 'location of your file').PlaySync();

