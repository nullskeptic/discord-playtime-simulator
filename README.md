# **Discord Playtime Simulator**

A PowerShell script that simulates Discord game activity by generating a placeholder executable file. 

## **Usage**
**Step 1**: Clone the repo `git clone https://github.com/nullskeptic/discord-playtime-simulator`

**Step 2**: `cd .\discord-playtime-simulator\`

**Step 3**: Run the script `.\Simulate.ps1` **OR** you can paste any lightweight executable file (named: placeholder.exe) in the script’s working directory.

**Step 4**: Input the path (e.g): `win64\wwm.exe`

**Step 5**: Input (Y) to select any lightweight executable for example: Choose Notepad++

**Step 6**: Input (Y) to Run the application

## **Parameters**

* **-Path** — Sets the destination where the placeholder executable will be created.
* **-Run** — Launches the newly created executable automatically.
* **-Clear** — Removes all previously created destination paths.
* **-Stop** — Terminates all running processes generated from your history.

### **Parameter Examples**

One liner command
```powershell
.\Simulate.ps1 -Path "win64\dota2.exe" -Run
```
  - This generates and runs:
    ```
    C:\Users\<User>\Desktop\win64\dota2.exe
    ```
Stop all running processes you created
```powershell
.\Simulate.ps1 -Stop
```
Clear all the paths you created
```powershell
.\Simulate.ps1 -Clear
```


**Note:** Match the real game’s filename and folder structure for Discord to detect it properly.

### Paths:

- Storm Lancers: `Storm Lancers Demo\StormLancersDemo.exe`
- Where Winds Meet: `win64\wwm.exe`
- Fortnite: `win64\FortniteClient-Win64-Shipping.exe`
- Marvel Rivals: `win64\Marvel-Win64-Shipping.exe`


