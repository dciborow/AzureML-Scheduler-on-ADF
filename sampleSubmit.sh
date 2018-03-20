set target= remoteVM 
set script= .\iris_sklearn.py


set runcommand= az ml experiment submit -c %target% %script% --wait 
echo runcommand: %runcommand%

for /f "tokens=2" %%a in ('%runcommand% ^| findstr RunId') do set runId=%%a

set statuscommand= az ml experiment status --run %runId% --target %target%

echo statuscommand: %statuscommand%

set searchstr = state : 

for /f "tokens=3" %%a in ('%statuscommand% ^| findstr /C:"state : "') do set runstate=%%a

echo runstate: %runstate%
