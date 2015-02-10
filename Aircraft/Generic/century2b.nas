##
# Century IIB Autopilot System
# Models behavior of the Century IIB autopilot
# one axis.
#
# One would also need the autopilot configuration file
# CENTURYIIB.xml (in pa24-250/Systems) and the animation and panel 
# and .ac files in pa24-250/Models/Century-IIB.
#  
#
# Written by Dave Perry to match functionality described in
# 
#       CENTURY IIB
#  AUTOPILOT FLIGHT SYSTEM
# PILOT'S OPERATING HANDBOOK
#    MARCH 1981 68S75
#
# Draws heavily from the kap140 system written by Vegard Ovesen
##

# Properties

var locks = "/autopilot/CENTURYIIB/locks";
var settings = "/autopilot/CENTURYIIB/settings";
var internal = "/autopilot/internal";
var flightControls = "/controls/flight";
var autopilotControls = "/autopilot/CENTURYIIB/controls";

# locks
var propLocks = props.globals.getNode(locks, 1);

var lockAprHold   = propLocks.getNode("apr-hold", 1);
var lockHdgHold   = propLocks.getNode("hdg-hold", 1);
var lockNavHold   = propLocks.getNode("nav-hold", 1);
var lockOmniHold  = propLocks.getNode("omni-hold", 1);
var lockRevHold   = propLocks.getNode("rev-hold", 1);
var lockRollAxis  = propLocks.getNode("roll-axis", 1);
var lockRollMode  = propLocks.getNode("roll-mode", 1);
var lockRollArm   = propLocks.getNode("roll-arm", 1);


var rollModes     = { "OFF" : 0, "ROL" : 1, "HDG" : 2, "OMNI" : 3, "NAV" : 4, "REV" : 5, "APR" : 6 };
var rollArmModes  = { "OFF" : 0, "NAV" : 1, "OMNI" : 2, "APR" : 3, "REV" : 4 };

# settings
var propSettings = props.globals.getNode(settings, 1);

var settingTargetInterceptAngle = propSettings.getNode("target-intercept-angle", 1);
var settingTargetRollDeg        = propSettings.getNode("target-roll-deg", 1);
var settingRollKnobDeg          = propSettings.getNode("roll-knob-deg", 1);

#Flight controls
var propFlightControls = props.globals.getNode(flightControls, 1);

var elevatorControl             = propFlightControls.getNode("elevator", 1);
var elevatorTrimControl         = propFlightControls.getNode("elevator-trim", 1);

#Autopilot controls
var propAutopilotControls = props.globals.getNode(autopilotControls, 1);

var rollControl                 = propAutopilotControls.getNode("roll", 1);
#  values 0 (A/P switch off) and 1 (A/P switch on)
var hdgControl                  = propAutopilotControls.getNode("hdg", 1);
#  values 0 (hdg switch off) and 1 (hdg switch on)
var modeControl                 = propAutopilotControls.getNode("mode", 1);
#  values 0 NAV, 1 OMNI, 2 HDG, 3 LOC, 4 LOC REV 

var headingNeedleDeflection = "/instrumentation/nav/heading-needle-deflection";
var power="/systems/electrical/outputs/autopilot";
var filteredHeadingNeedleDeflection = "/autopilot/internal/filtered-heading-needle-deflection";

#  Initialize Variables
var valueTest = 0;
var lastValue = 0;
var newValue = 0;
var minVoltageLimit = 8.0;
var newMode = 2;
var oldMode = 2;
var deviation = 0;
rollControl.setDoubleValue(0.0);
hdgControl.setDoubleValue(0.0);
modeControl.setDoubleValue(2.0);

var apInit = func {
  ##print("ap init");

  ##
  # Initialises the autopilot.
  ##

  lockAprHold.setBoolValue(0);
  lockHdgHold.setBoolValue(0);
  lockNavHold.setBoolValue(0);
  lockOmniHold.setBoolValue(0);
  lockRevHold.setBoolValue(0);
  lockRollAxis.setBoolValue(0);
  lockRollMode.setIntValue(rollModes["OFF"]);
  lockRollArm.setIntValue(rollArmModes["OFF"]);
#  Reset the memory for power down or power up
  settingTargetInterceptAngle.setDoubleValue(0.0);
  settingTargetRollDeg.setDoubleValue(0.0);
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
    print("CENTURY IIB power up");
    apInit();
  } elsif (valueTest < -0.5) {
    # autopilot just lost power
    print("CENTURY IIB power lost");
    apInit();
    # note: all button and knobs disabled in functions below
  }
  lastValue = newValue;
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
     if (hdgControl.getValue() ) {
        ##
        # hdg switch already on so check which roll mode is set
        ##
        apModeControlsSet();
     } else {
        ##
        # roll switch on and hdg switch off
        ##
        rollButton(1);
     }
  } else {
     #  A/P on/off switch was turned off, so turn off other AP switches
     hdgControl.setDoubleValue(0.0);   #hdgButton(0);
#    rollButton(0);
     apInit();
  }
}


var apHdgControl = func {

  if (hdgControl.getValue() ) {
     ##
     # hdg switch is on so if roll switch is also on, check which roll mode is set
     ##
     if (rollControl.getValue() ) {
        apModeControlsSet();
     }
  } else {
     # hdg switch turned off 
     hdgControl.setDoubleValue(0.0);   hdgButton(0);
  }
}
 

var rollKnobUpdate = func {
  if ( rollControl.getValue() and !hdgControl.getValue() ) {
    settingTargetRollDeg.setDoubleValue( settingRollKnobDeg.getValue() );
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
  if (lockRollArm.getValue() != rollArmModes["APR"])
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


