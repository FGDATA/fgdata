rem @ECHO OFF

rem Skip ahead to CONT1 if FG_ROOT has a value
IF NOT %FG_ROOT%.==. GOTO CONT1

SET FG_ROOT=.

:CONT1

rem Check for the existance of the executable
IF NOT EXIST %FG_ROOT%\BIN\FGFS.EXE GOTO ERROR1

rem Now that FG_ROOT has been set, run the program
ECHO FG_ROOT = %FG_ROOT%


rem Cessna 172
%FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Cessna172        --time-offset=-0:00:00

rem Cessna 172 (with lift curve) from Flight Gear 0.7.1
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Cessna172-71     --time-offset=-8:00:00

rem Cessna 172 (with lift curve) from Flight Gear 0.7.3
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Cessna172-73     --time-offset=-5:00:00

rem Cessna 310
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Cessna310        --time-offset=-0:00:00

rem Cessna 620
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Cessna620        --time-offset=-2:00:00

rem Twin Otter
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/TwinOtter        --time-offset=-0:00:00

rem Twin Otter with ice accretion in flight
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/TwinOtterAllIce  --time-offset=10:00:00 --altitude=10000 --uBody=1000

rem Twin Otter with tail ice accretion in flight
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/TwinOtterTailIce --time-offset=10:00:00

rem Twin Otter with wing ice accretion in flight
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/TwinOtterWingIce --time-offset=10:00:00

rem Beech 99
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Beech99          --time-offset=-0:00:00

rem Marchetti trainer at Aspen, CO
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Marchetti        --time-offset=-0:00:00 --airport-id=25U  --heading=10  --disable-clouds

rem T-37 trainer
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/T37              --time-offset=-0:00:00

rem F-104 at Aspen, CO
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/F104             --time-offset=-0:00:00 --airport-id=25U  --heading=10  --disable-clouds

rem F-4    ! DIFFICULT TO FLY !
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/F4               --time-offset=-0:00:00 

rem Boeing 747
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Boeing747        --time-offset=-0:00:00

rem Convair 880    ! DIFFICULT TO FLY !
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Convair880       --time-offset=-0:00:00 --altitude=35000  --uBody=1000

rem Learjet 24
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Learjet24        --time-offset=-0:00:00

rem Pioneer at Aspen, CO
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Pioneer          --time-offset=-0:00:00 --airport-id=25U  --heading=270  --disable-clouds

rem Pioneer at Aspen, CO
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/Pioneer-TD       --time-offset=-0:00:00 --airport-id=25U  --heading=270  --disable-clouds

rem X-15 at Aspen, CO    ! DIFFICULT TO FLY !
rem %FG_ROOT%\BIN\FGFS.EXE --aircraft-dir=Aircraft-uiuc/X15              --time-offset=-0:00:00 --airport-id=25U  --disable-clouds


GOTO END

:ERROR1
ECHO Cannot find %FG_ROOT%\BIN\FGFS.EXE
GOTO END

:END
