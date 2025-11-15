# **Discord Playtime Simulator**

A PowerShell script that simulates Discord game activity by generating a placeholder executable file. 

## **Usage**
- Copy paste any lightweight executable file in the script’s working directory.
- Run the script

## **Parameters**

* **-Path** — Sets the destination where the placeholder executable will be created.
* **-Run** — Launches the newly created executable automatically.
* **-Clear** — Removes all previously created destination paths.
* **-Stop** — Terminates all running processes generated from your history.

## **Example**

```powershell
.\Simulate.ps1 -Path "win64\dota2.exe" -Run
```

This generates and runs:

```
C:\Users\<User>\Desktop\win64\dota2.exe
```

**Note:** Match the real game’s filename and folder structure for Discord to detect it properly.
