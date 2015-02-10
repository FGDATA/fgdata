##
# Century III Autopilot System
# Tries to behave like the Century III autopilot
# two axis 
#
# One would also need the autopilot configuration file
# CENTURYIII.xml and the panel instrument configuration file
#
# Written by Dave Perry to match functionality described in
#
#        CENTURY III
#  AUTOPILOT FLIGHT SYSTEM
# PILOT'S OPERATING HANDBOOK
#    NOVEMBER 1998 68S25
#
# Draws heavily from the kap140 system written by Roy Vegard Ovesen
##

# Properties

var locks = "/autopilot/CENTURYIII/locks";
var settings = "/autopilot/CENTURYIII/settings";
var internal = "/autopilot/internal";
var flightControls = "/controls/flight";
var autopilotControls = "/autopilot/CENTURYIII/controls";

# locks
var propLocks = props.globals.getNode(locks, 1);

var lockAltHold   = propLocks.getNode("alt-hold", 1);
var lockPitchHold = propLocks.getNode("pitch-hold", 1);
var lockAprHold   = propLocks.getNode("apr-hold", 1);
var lockGsHold    = propLocks.getNode("gs-hold", 1);
var lockHdgHold   = propLocks.getNode("hdg-hold", 1);
var lockNavHold   = propLocks.getNode("nav-hold", 1);
var lockOmniHold  = propLocks.getNode("omni-hold", 1);
var lockRevHold   = propLocks.getNode("rev-hold", 1);
var lockRollAxis  = propLocks.getNode("roll-axis", 1);
var lockRollMode  = propLocks.getNode("roll-mode", 1);
var lockPitchAxis = propLocks.getNode("pitch-axis", 1);
var lockPitchMode = propLocks.getNode("pitch-mode", 1);
var lockRollArm   = propLocks.getNode("roll-arm", 1);
var lockPitchArm  = propLocks.getNode("pitch-arm", 1);


var rollModes     = { "OFF" : 0, "ROL" : 1, "HDG" : 2, "OMNI" : 3, "NAV" : 4, "REV" : 5, "APR" : 6 };
var pitchModes    = { "OFF" : 0, "VS" : 1, "ALT" : 2, "GS" : 3, "AOA" : 4 };
var rollArmModes  = { "OFF" : 0, "NAV" : 1, "OMNI" : 2, "APR" : 3, "REV" : 4 };
var pitchArmModes = { "OFF" : 0, "ALT" : 1, "GS" : 2 };

# settings
var propSettings = props.globals.getNode(settings, 1);

var settingTargetAltPressure    = propSettings.getNode("target-alt-pressure", 1);
var settingTargetInterceptAngle = propSettings.getNode("target-intercept-angle", 1);
var settingTargetPressureRate   = propSettings.getNode("target-pressure-rate", 1);
var settingTargetRollDeg        = propSettings.getNode("target-roll-deg", 1);
var settingRollKnobDeg          = propSettings.getNode("roll-knob-deg", 1);
var settingTargetPitchDeg       = propSettings.getNode("target-pitch-deg", 1);
var settingPitchWheelDeg        = propSettings.getNode("pitch-wheel-deg", 1);
var settingAutoPitchTrim        = propSettings.getNode("auto-pitch-trim", 1);
var settingGScaptured           = propSettings.getNode("gs-captured", 1);
var settingDeltaPitch           = propSettings.getNode("delta-pitch", 1);

#Flight controls
var propFlightControls = props.globals.getNode(flightControls, 1);

var elevatorControl         = propFlightControls.getNode("elevator", 1);
var elevatorTrimControl     = propFlightControls.getNode("elevator-trim", 1);

#Autopilot controls
var propAutopilotControls   = props.globals.getNode(autopilotControls, 1);

var rollControl             = propAutopilotControls.getNode("roll", 1);
# values 0 (ROLL switch off) 1 (ROLL switch on)

var hdgControl              = propAutopilotControls.getNode("hdg", 1);
# values 0 (HDG switch off)  1 (HDG switch on)

var modeControl             = propAutopilotControls.getNode("mode", 1);

var altControl              = propAutopilotControls.getNode("alt", 1);
# values 0 (ALT switch off)  1 (ALT switch on)

var pitchControl            = propAutopilotControls.getNode("pitch", 1);
# values 0 (PITCH switch off)  1 (PITCH switch on)

var headingNeedleDeflection = "/instrumentation/nav/heading-needle-deflection";
var gsInRange = "/instrumentation/nav/gs-in-range";
var gsNeedleDeflection = "/instrumentation/nav/gs-needle-deflection-deg";
var elapsedTimeSec = "/sim/time/elapsed-sec";
var indicatedPitchDeg =  "/instrumentation/attitude-indicator/indicated-pitch-deg";
var staticPressure = "/systems/static/pressure-inhg";
var altitudePressure = "/autopilot/CENTURYIII/settings/target-alt-pressure";
var power="/systems/electrical/outputs/autopilot";
var enableAutoTrim = "/sim/model/enable-auto-trim";
var filteredHeadingNeedleDeflection = "/autopilot/internal/filtered-heading-needle-deflection";

var pressureUnits = { "inHg" : 0, "hPa" : 1 };
var altPressure = 0.0;
var valueTest = 0;
var lastValue = 0;
var newValue = 0;
var minVoltageLimit = 8.0;
var newMode = 2;
var oldMode = 2;
var deviation = 0;
var LocModeTimeSec = 0;
var AltTimeSec = 0;
rollControl.setDoubleValue(0.0);
hdgControl.setDoubleValue(0.0);
altControl.setDoubleValue(0.0);
pitchControl.setDoubleValue(0.0);
modeControl.setDoubleValue(2.0);
settingTargetPitchDeg.setDoubleValue(0.0);
settingPitchWheelDeg.setDoubleValue(0.0);
settingDeltaPitch.setDoubleValue(0.0);
settingTargetPressureRate.setDoubleValue(0.0);
settingGScaptured.setDoubleValue(0.0);
#  If you need to be able to enable/disable auto trim, make is a menu toggle.
#  Auto trim enabled by default
setprop(enableAutoTrim, 1);
var autoPitchTrim = 0.0;

var apInit = func {
  ##print("ap init");

  ##
  # Initialises the autopilot.
  ##

  lockAltHold.setBoolValue(0);
  lockAprHold.setBoolValue(0);
  lockGsHold.setBoolValue(0);
  lockHdgHold.setBoolValue(0);
  lockNavHold.setBoolValue(0);
  lockOmniHold.setBoolValue(0);
  lockRevHold.setBoolValue(0);
  lockRollAxis.setBoolValue(0);
  lockRollMode.setIntValue(rollModes["OFF"]);
  lockPitchAxis.setBoolValue(0);
  lockPitchHold.setBoolValue(0);
  lockPitchMode.setIntValue(pitchModes["OFF"]);
  lockRollArm.setIntValue(rollArmModes["OFF"]);
  lockPitchArm.setIntValue(pitchArmModes["OFF"]);
#  Reset the memory for power down or power up
  settingTargetAltPressure.setDoubleValue(0.0);
  settingTargetPitchDeg.setDoubleValue(0.0);
  settingTargetPressureRate.setDoubleValue(0.0);
  settingTargetInterceptAngle.setDoubleValue(0.0);
  settingTargetRollDeg.setDoubleValue(0.0);
  settingAutoPitchTrim.setDoubleValue(0.0);
  settingGScaptured.setDoubleValue(0.0);
  settingRollKnobDeg.setDoubleValue(0.0);

}

var apPower = func {

## Monitor autopilot power
## Call apInit if the power is too low

  if (getprop(power) < minVoltageLimit) {
    newValue = 0;
  } else {
    newValue = 1;
  }

  valueTest = newValue - lastValue;
#  print("v_test = ", v_test);
  if (valueTest > 0.5) {
    # autopilot just powered up
    print("CENTURYIII power up");
    apInit();
  } elsif (valueTest < -0.5) {
    # autopilot just lost power
    print("CENTURYIII power lost");
    apInit();
    # note: all button and knobs disabled in functions below
  }
  lastValue = newValue;

  # Update difference between pitch wheel target and indicated pitch.
  # Used to animate the Pitch Trim meter to the left of pitch wheel
  if (rollControl.getValue() ) {
    settingDeltaPitch.setDoubleValue(settingPitchWheelDeg.getValue() 
                                      - getprop(indicatedPitchDeg));
  } else {
    settingDeltaPitch.setDoubleValue(0.0);
  }
  var inrange0 = getprop("/instrumentation/nav[0]/in-range");
  # Shut off autopilot if HDG switch on and mode != 2 when NAV flag is on
  if ( !inrange0 ) {
     if ( hdgControl.getValue() and (modeControl.getValue() != 2)) {
        rollControl.setDoubleValue(0.0);
        apRollControl();
     }
  }
  settimer(apPower, 0.5);
}

var apRollControl = func {

  if (rollControl.getValue() ) {
     rollButton(1);
  } else {
     #  A/P on/off switch was turned off, so turn off other AP switches
     hdgControl.setDoubleValue(0.0);   #hdgButton(0);
     altControl.setDoubleValue(0.0);   #altButton(0);
     pitchControl.setDoubleValue(0.0); #pitchButton(0);
#    rollButton(0);
     apInit();
  }
}

var apHdgControl = func {

  if (hdgControl.getValue() ) {
     # hdg switch turned on sets roll
     rollControl.setDoubleValue(1.0);
     rollButton(1);
     ##
     # hdg switch is on so check which roll mode is set
     ##
     apModeControlsSet();
  } else {
     # hdg switch turned off resets alt and pitch
     hdgControl.setDoubleValue(0.0);   hdgButton(0);
     altControl.setDoubleValue(0.0);   altButton(0);
     pitchControl.setDoubleValue(0.0); pitchButton(0);
  }
}
 
var apAltControl = func {

  if ( altControl.getValue() ){
     # Alt switch on so set ROLL, HDG, and PITCH
     rollControl.setDoubleValue(1.0);
     rollButton(1);
     hdgControl.setDoubleValue(1.0);
     # roll and hdg switches on so check which roll mode is set
     apModeControlsSet();
     pitchControl.setDoubleValue(1.0);
     pitchButton(1);     
     altButton(1);
  } else {
     altButton(0);
  }
}
      
var apPitchControl = func {

  if ( pitchControl.getValue() ) {
     # Pitch switch on so set ROLL and HDG
     rollControl.setDoubleValue(1.0);
     rollButton(1); 
     hdgControl.setDoubleValue(1.0);
     # roll and hdg switches on so check which roll mode is set
     apModeControlsSet();
     pitchButton(1);
  } else {
     altControl.setDoubleValue(0.0);
     altButton(0);
     pitchButton(0);
  }
}

var rollKnobUpdate = func {
  if ( rollControl.getValue() and !hdgControl.getValue() ) {
    settingTargetRollDeg.setDoubleValue( settingRollKnobDeg.getValue() );
  }
} 


var pitchWheelUpdate = func {
  if ( rollControl.getValue() and !altControl.getValue() ) {
    settingTargetPitchDeg.setDoubleValue( settingPitchWheelDeg.getValue() );
  }
}


var apModeControlsChange = func {
  ##
  #  Delay mode change to allow time for multi-mode rotation
  ##
  settimer(apModeControlsSet, 2);
}

var apModeControlsSet = func {
  newMode = modeControl.getValue();

  ##
  # Decouple GS if the mode selector is switched from LOC NORM
  ##
  if (oldMode == rollModes["APR"] and newMode != rollModes["APR"])
  {
     if (lockPitchMode.getValue() == pitchModes["GS"])
     {
        lockPitchMode.setIntValue(pitchModes["OFF"]);
     }
     if (lockPitchArmModes.getValue() == pitchArmModes["GS"])
     {
        lockPitchArmMode.setIntValue(pitchModes["OFF"]);
     }
     lockGsHold.setBoolValue(0);
     settingGScoupled.setDoubleValue(0.0);
  }   

  oldMode = newMode;

  #All modes entered from hdg mode
  if ( hdgControl.getValue() ) {
     hdgButton(1);
     if (newMode == 0 ){
        navButton();
     } elsif (newMode == 1 ) { 
        omniButton();
     } elsif (newMode == 3 ) {
        aprButton();
     } elsif(newMode == 4 ) {
        revButton();
     }
  } else {
     return;
  }
}

var rollButton = func(switch_on) {
  ##print("rollButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if ( switch_on ) {
  ##
  # Engage the autopilot in Wings level mode (ROL) and set the turn rate
  # from the "ROLL Knob".
  ##

    lockAprHold.setBoolValue(0);
    lockHdgHold.setBoolValue(0);
    lockNavHold.setBoolValue(0);
    lockOmniHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["ROL"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
  } else {
    lockAprHold.setBoolValue(0);
    lockHdgHold.setBoolValue(0);
    lockNavHold.setBoolValue(0);
    lockOmniHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockRollAxis.setBoolValue(0);
    lockRollMode.setIntValue(rollModes["OFF"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
  }
}


var hdgButton = func(switch_on) {
  ##print("hdgButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (switch_on) {
  ##
  # Engage the heading mode (HDG).
  ##
    lockAprHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockOmniHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["HDG"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);

    settingTargetInterceptAngle.setDoubleValue(0.0);

  } else {
    lockHdgHold.setBoolValue(0);
    rollKnobUpdate();
    if ( rollControl.getValue() ) {
       lockRollMode.setIntValue(rollModes["ROL"]);
    } else { 
       lockRollMode.setIntValue(rollModes["OFF"]);
    }
  }   
}

var navButton = func {
  ##print("navButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  ##
  # The Mode Selector and DG Course Selector should be set before switching the HDG 
  # rocker switch to "on".  The DG Course Selector should be set to the OBS "to" or
  # "from" bearing.
  # Set up NAV mode and switch to the 45 degree angle intercept NAV mode
  ##
    lockAprHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockOmniHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["NAV"]);
    lockRollMode.setIntValue(rollModes["NAV"]);

    navArmFromHdg();
}

var navArmFromHdg = func
{
  ##
  # Abort the NAV-ARM mode if something has changed the arm mode to something
  # else than NAV-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["NAV"])
  {
    return;
  }

  ##
  # Activate the nav-hold controller and check the needle deviation.
  ##
  lockNavHold.setBoolValue(1);
  deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 9.95 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 9.95)
  {
    #print("deviation");
    settimer(navArmFromHdg, 5);
    return;
  }
  ##
  # If the deviation is less than 10 degrees turn off the NAV-ARM. End of NAV-ARM sequence.
  ##
  elsif (abs(deviation) < 10.0)
  {
    #print("capture");
    lockRollArm.setIntValue(rollArmModes["OFF"]);
  }
}

var omniButton = func {
  ##print("navButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  ##
  # The Mode Selector and DG Course Selector should be set before switching the HDG 
  # rocker switch to "on".  The DG Course Selector should be set to the OBS "to" or
  # "from" bearing.
  # Set up OMNI mode and switch to the 45 degree angle intercept OMNI mode
  ##
    lockAprHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockOmniHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["OMNI"]);
    lockRollMode.setIntValue(rollModes["OMNI"]);

    omniArmFromHdg(); 
}


var omniArmFromHdg = func
{
  ##
  # Abort the OMNI-ARM mode if something has changed the arm mode to something
  # else than OMNI-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["OMNI"])
  {
    return;
  }

  ##
  # Activate the omni-hold controller and check the needle deviation.
  ##
  lockOmniHold.setBoolValue(1);
  deviation = getprop(filteredHeadingNeedleDeflection);
  ##
  # If the deflection is more than 9.95 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 9.95)
  {
    #print("deviation");
    settimer(omniArmFromHdg, 5);
    return;
  }
  ##
  # If the deviation is less than 10 degrees turn off the OMNI-ARM. End of OMNI-ARM sequence.
  ##
  elsif (abs(deviation) < 10.0)
  {
    #print("capture");
    lockRollArm.setIntValue(rollArmModes["OFF"]);
  }
}


var aprButton = func {
  ##print("aprButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }
  ##
  #  Save the elapsed time when mode switch was set to LOC Norm.
  #  This is used to delay the gsArm at least 20 sec after the mode is set to LOC Norm.
  #  See comment by Figure 24, page 30 in "CENTURY II Autopilot Flight System POH".
  ##  
  LocModeTimeSec = getprop(elapsedTimeSec);

  ##
  # The Mode Selector and DG Course Selector should be set before switching the HDG 
  # rocker switch to "on". Set the DG Course Selector to the LOC inbound heading. 
  # Set up APR mode and switch to the 45 degree angle intercept APR mode
  ##
    lockAprHold.setBoolValue(1);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockOmniHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["APR"]);
    lockRollMode.setIntValue(rollModes["APR"]);

    aprArmFromHdg();
}

var aprArmFromHdg = func
{
  ##
  # Abort the APR-ARM mode if something has changed the arm mode to something
  # else than APR-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["APR"]
      or !lockAltHold.getValue())
  {
    return;
  }

  ##
  # Activate the apr-hold controller and check the needle deviation.
  ##
  lockAprHold.setBoolValue(1);
  deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 2.5 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 2.495)
  {
    #print("deviation");
    settimer(aprArmFromHdg, 5);
    return;
  }
  ##
  # If the deviation is less than 2.5 degrees, start the GS-ARM sequence
  ##
  elsif (abs(deviation) < 2.5)
  {
    lockPitchArm.setIntValue(pitchArmModes["GS"]);

    gsArm();
  }
}

var gsArm = func {
  ##
  # Abort the GS-ARM mode if something has changed the arm mode to something
  # else than GS-ARM.
  ##
  if (lockPitchArm.getValue() != pitchArmModes["GS"])
  {
    return;
  }
  ##
  #  Loop until the LOC Norm mode has been set for at least 20 seconds
  #  and the Alt switch has been on for at least 20 seconds.
  #  See page 30 in "CENTURY II Autopilot Flight System POH".
  ##
  if ( (getprop(elapsedTimeSec) - LocModeTimeSec) < 20 
    or (getprop(elapsedTimeSec) - AltTimeSec) < 20 )
  {
    settimer(gsArm, 2);
    return;
  }
  ##
  #  Loop until gs is in range
  ##
  if (!getprop(gsInRange))
  {
    settimer(gsArm, 2);
    return;
  }
  deviation = getprop(gsNeedleDeflection);
  ##
  #  Abort if above the glide slope as you have passed the gs intercept
  if (deviation < 0)
  {
    return;
  }
  ##
  # If the deflection is more than 0.1 degrees wait 2 seconds and check again.
  ##
  if (abs(deviation) > 0.1)
  {
    #print("deviation");
    settimer(gsArm, 2);
    return;
  }
  ##
  # The deviation is less than 0.1 then activate the GS pitch mode.
  ##
  else
  {
    #print("capture");
    lockAltHold.setBoolValue(0);
    lockGsHold.setBoolValue(1);
    lockPitchMode.setIntValue(pitchModes["GS"]);
    lockPitchArm.setIntValue(pitchArmModes["OFF"]);
    settingGScaptured.setDoubleValue(1.0);
  }
}


var revButton = func {
  ##print("revButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  ##
  # The Mode Selector and DG Course Selector should be set before switching the HDG 
  # rocker switch to "on". Set the DG Course Selector to the LOC outbound
  # (or reverse) heading.  
  # Set up REV mode and switch to the 45 degree angle intercept REV mode
  ##
    lockAprHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockOmniHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["REV"]);

    revArmFromHdg(); 
}


var revArmFromHdg = func
{
  ##
  # Abort the REV-ARM mode if something has changed the arm mode to something
  # else than REV-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["REV"])
  {
    return;
  }

  ##
  # Activate the rev-hold controller and check the needle deviation.
  ##
  lockRevHold.setBoolValue(1);
  deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 2.5 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 2.495)
  {
    #print("deviation");
    settimer(revArmFromHdg, 5);
    return;
  }
  ##
  # If the deviation is less than 2.5 - End of REV-ARM sequence.
  ##
  elsif (abs(deviation) < 2.5)
  {
    #print("capture");
    lockRollArm.setIntValue(rollArmModes["OFF"]);
    lockAprHold.setBoolValue(0);
    lockRevHold.setBoolValue(1);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockOmniHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["REV"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
  }
}


var altButton = func(switch_on) {
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (switch_on) {
    ##
    #  Save the elapsed time when Alt switch was turned on.
    #  This is used to delay the gsArm at least 20 sec after the Alt switch is turned on.
    #  See comment by Figure 25, page 30 in "CENTURY II Autopilot Flight System POH".
    ##  
    AltTimeSec = getprop(elapsedTimeSec);
    lockAltHold.setBoolValue(1);
    lockPitchAxis.setBoolValue(1);
#    lockPitchMode.setIntValue(pitchModes["ALT"]);

    altPressure = getprop(staticPressure);
    settingTargetAltPressure.setDoubleValue(altPressure);
#    print("enableAutoTrim = ", getprop(enableAutoTrim));
    if ( getprop(enableAutoTrim) ) {
       settingAutoPitchTrim.setDoubleValue(1);
    }
    ##
    #  Handle case where mode is LOC Norm and ALT switch is turned off and then back on.
    #  e.g. When descending to a lower GS intercept altitude in a step-down approach
    ##
    if (oldMode == 3) { apModeControlsSet(); }
  } else {
    lockAltHold.setBoolValue(0);
    lockPitchAxis.setBoolValue(0);
    lockPitchMode.setIntValue(pitchModes["OFF"]);
    lockPitchArm.setIntValue(pitchArmModes["OFF"]);
    pitchWheelUpdate();
    settingTargetPressureRate.setDoubleValue(0.0);
    # alt switch is off so make sure the glide slope is disabled
    settingGScaptured.setDoubleValue(0.0);
    lockGsHold.setBoolValue(0);
  }  
}

var pitchButton = func(switch_on) {
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (switch_on) {
    lockPitchHold.setBoolValue(1);
#    lockPitchAxis.setBoolValue(1);
#    lockPitchMode.setIntValue(pitchModes["AOA"]);
#    print("enableAutoTrim = ", getprop(enableAutoTrim));
    if ( getprop(enableAutoTrim) ) {
       settingAutoPitchTrim.setDoubleValue(1);
    }
  } else {
    lockPitchHold.setBoolValue(0);
    lockPitchAxis.setBoolValue(0);
    lockPitchMode.setIntValue(pitchModes["OFF"]);
    settingAutoPitchTrim.setDoubleValue(0);
  }
}

var touchPower = func{
   setprop(power,apVolts);
}

var apVolts = getprop(power);

if ( apVolts == nil or apVolts < minVoltageLimit ) {
   # Wait for autopilot to be powered up
   var L = setlistener(power, func {
   apPower();
   removelistener(L);
   });
} else {
   # Skip the setlistener since autopilot is already powered up
   settimer(touchPower ,10);
   apPower();
}


