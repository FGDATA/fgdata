README.txt

The Century IIb autopilot model is derived from the Century III development with the
pitch axis portions removed and a new 3D model in place of the Century III 3D model. 

Required files required not in this folder are: 

   Aircraft/Generic/century2b.nas, and 
   'your aircraft folder'/Systems/CENTURYIIB.xml  (the autopilot configuration).

The model and cascaded PID controller design attempt to recreate the performance 
and pilot interface described in

             CENTURY(R) FLIGHT SYSTEMS, INC.

                       CENTURY IIB
                 AUTOPILOT FLIGHT SYSTEM
               PILOT'S OPERATIONG HANDBOOK
                   March 1981, 68S75

This manual is available free as a pdf download from 
www.centuryflight.com.

Piper Aircraft used this autopilot from the mid 1960's through the mid 1970's.  
It is used by the pa24-250-CIIB in FlightGear and the real pa24-250 N7764P has a 
Century IIB autopilot.

The pa24-250-CIIB implementation uses the nasal file

   Aircraft/Generic/century2b.nas

and the following xml files: 

   Aircraft/Instruments-3d/Century-IIB/AutopilotMode.xml,
   Aircraft/Instruments-3d/Century-IIB/autopilotModePanel.xml,
   Aircraft/Instruments-3d/Century-IIB/Century-IIB.xml, and
   Aircraft/Instruments-3d/Century-IIB/Century-IIBPanel.xml.

The autopilot config file is Aircraft/pa24-250/Systems/CENTURYIIB.xml. 
