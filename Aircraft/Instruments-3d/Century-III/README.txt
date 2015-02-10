README.txt

The Century III autopilot model is the joint effort of Torsten Dreyer (3D model) 
and Dave Perry (Aircraft/Generic/century3.nas, and Systems/CENTURYIII.xml).
The model and cascaded PID controller design attempt to recreate the performance 
and pilot interface described in

             CENTURY(R) FLIGHT SYSTEMS, INC.

                       CENTURY III
                 AUTOPILOT FLIGHT SYSTEM
               PILOT'S OPERATIONG HANDBOOK
                   NOVEMBER 1998, 68S25

This manual is available free as a pdf download from www.centuryflight.com.

Piper Aircraft used this autopilot relabled as the Altimatic IIIc from the mid 
1960's through the mid 1980's.  The Century III is used by the pa24-250 and the Altimatic IIIc is used by the SenecaII in FlightGear.  

From a pilot's point of view, there is one significant difference between the Century III and the Altimatic IIIc. The Altimatic IIIc couples to the HSI needle so the heading bug has no affect in modes other than HDG. With the Century III, the D.G. heading bug must be aligned with the NAV1 Omni Bearing Selector for the coupled modes Nav, and OMNI to function properly, and to the localizer bearing for LOC NORM mode to work properly.  For proper functioning in LOC REV mode, the heading bug should be set to the back course bearing (180 deg from the LOC bearing).

Both use the nasal file 

    Aircraft/Generic/century3.nas

and the following xml files:

    Aircraft/Instruments-3d/Century-III/AutopilotMode.xml,  
    Aircraft/Instruments-3d/Century-III/AutopilotModePanel.xml, and
    Aircraft/Instruments-3d/Century-III/AltimaticIIIcPanel.xml.

Because the 3d models differ, the Century III requires a model entry for

    Aircraft/Instruments-3d/Century-III/CenturyIII.xml

and the Altimatic IIIc requires a model entry for

    Aircraft/Instruments-3d/Century-III/AltimaticIIIc.xml

as well as the additional nasal link to the hsi

    hsiBugError.nas.
  
See the SenecaII/Nasal/hsiBugError.nas for an example. 

Additionally, the autopilot config files are different because of this heading bug difference.  See the /Systems/CENTURYIII.xml files for the pa24-250 and the SenecaII for examples of both. 
  
  
 
