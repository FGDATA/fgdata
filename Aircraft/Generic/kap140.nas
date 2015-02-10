##
# Bendix/King KAP140 Autopilot System
# Tries to behave like the Bendix/King KAP140 autopilot
# two axis w/altitude preselect.
#
# One would also need the autopilot configuration file
# KAP140.xml and the panel instrument configuration file
#
# Written by Roy Vegard Ovesen
# "Power-check" edits by Dave Perry
##

# Properties

var locks = "/autopilot/KAP140/locks";
var settings = "/autopilot/KAP140/settings";
var annunciators = "/autopilot/KAP140/annunciators";
var internal = "/autopilot/internal";
var power="/systems/electrical/outputs/autopilot";
var encoder =  "/instrumentation/altimeter";
var flightControls = "/controls/flight";

# locks
var propLocks = props.globals.getNode(locks, 1);

var lockAltHold   = propLocks.getNode("alt-hold", 1);
var lockAprHold   = propLocks.getNode("apr-hold", 1);
var lockGsHold    = propLocks.getNode("gs-hold", 1);
var lockHdgHold   = propLocks.getNode("hdg-hold", 1);
var lockNavHold   = propLocks.getNode("nav-hold", 1);
var lockRevHold   = propLocks.getNode("rev-hold", 1);
var lockRollAxis  = propLocks.getNode("roll-axis", 1);
var lockRollMode  = propLocks.getNode("roll-mode", 1);
var lockPitchAxis = propLocks.getNode("pitch-axis", 1);
var lockPitchMode = propLocks.getNode("pitch-mode", 1);
var lockRollArm   = propLocks.getNode("roll-arm", 1);
var lockPitchArm  = propLocks.getNode("pitch-arm", 1);


var rollModes     = { "OFF" : 0, "ROL" : 1, "HDG" : 2, "NAV" : 3, "REV" : 4, "APR" : 5 };
var pitchModes    = { "OFF" : 0, "VS" : 1, "ALT" : 2, "GS" : 3 };
var rollArmModes  = { "OFF" : 0, "NAV" : 1, "APR" : 2, "REV" : 3 };
var pitchArmModes = { "OFF" : 0, "ALT" : 1, "GS" : 2 };

# settings
var propSettings = props.globals.getNode(settings, 1);

var settingTargetAltPressure    = propSettings.getNode("target-alt-pressure", 1);
var settingTargetInterceptAngle = propSettings.getNode("target-intercept-angle", 1);
var settingTargetPressureRate   = propSettings.getNode("target-pressure-rate", 1);
var settingTargetTurnRate       = propSettings.getNode("target-turn-rate", 1);
var settingTargetAltFt          = propSettings.getNode("target-alt-ft", 1);
var settingBaroSettingInhg      = propSettings.getNode("baro-setting-inhg", 1);
var settingBaroSettingHpa       = propSettings.getNode("baro-setting-hpa", 1);
var settingAutoPitchTrim        = propSettings.getNode("auto-pitch-trim", 1);

#annunciators
var propAnnunciators = props.globals.getNode(annunciators, 1);

var annunciatorRol          = propAnnunciators.getNode("rol", 1);
var annunciatorHdg          = propAnnunciators.getNode("hdg", 1);
var annunciatorNav          = propAnnunciators.getNode("nav", 1);
var annunciatorNavArm       = propAnnunciators.getNode("nav-arm", 1);
var annunciatorApr          = propAnnunciators.getNode("apr", 1);
var annunciatorAprArm       = propAnnunciators.getNode("apr-arm", 1);
var annunciatorRev          = propAnnunciators.getNode("rev", 1);
var annunciatorRevArm       = propAnnunciators.getNode("rev-arm", 1);
var annunciatorVs           = propAnnunciators.getNode("vs", 1);
var annunciatorVsNumber     = propAnnunciators.getNode("vs-number", 1);
var annunciatorFpm          = propAnnunciators.getNode("fpm", 1);
var annunciatorAlt          = propAnnunciators.getNode("alt", 1);
var annunciatorAltArm       = propAnnunciators.getNode("alt-arm", 1);
var annunciatorAltNumber    = propAnnunciators.getNode("alt-number", 1);
var annunciatorAltAlert     = propAnnunciators.getNode("alt-alert", 1);
var annunciatorApr          = propAnnunciators.getNode("apr", 1);
var annunciatorGs           = propAnnunciators.getNode("gs", 1);
var annunciatorGsArm        = propAnnunciators.getNode("gs-arm", 1);
var annunciatorPtUp         = propAnnunciators.getNode("pt-up", 1);
var annunciatorPtDn         = propAnnunciators.getNode("pt-dn", 1);
var annunciatorBsHpaNumber  = propAnnunciators.getNode("bs-hpa-number", 1);
var annunciatorBsInhgNumber = propAnnunciators.getNode("bs-inhg-number", 1);
var annunciatorAp           = propAnnunciators.getNode("ap", 1);
var annunciatorBeep         = propAnnunciators.getNode("beep", 1);

#flashers
var altAlertBeeper  = aircraft.light.new(annunciatorBeep, [0.5, 0.25]).switch(0);
var altAlertFlasher = aircraft.light.new(annunciatorAltAlert, [0.5, 0.25]).switch(0);
var hdgFlasher      = aircraft.light.new(annunciatorHdg, [0.5, 0.25]).switch(0);
var apFlasher       = aircraft.light.new(annunciatorAp, [1.0, 0.5]).switch(0);

#Flight controls
var propFlightControls = props.globals.getNode(flightControls, 0);

var elevatorControl         = propFlightControls.getNode("elevator", 0);
var elevatorTrimControl     = propFlightControls.getNode("elevator-trim", 0);

var headingNeedleDeflection = "/instrumentation/nav/heading-needle-deflection";
var gsNeedleDeflection = "/instrumentation/nav/gs-needle-deflection-norm";
var staticPressure = "systems/static/pressure-inhg";

var pressureUnits = { "inHg" : 0, "hPa" : 1 };
var baroSettingUnit = pressureUnits["inHg"];
var baroSettingInhg = 29.92;
var baroSettingHpa = baroSettingInhg * 0.03386389;
var baroSettingAdjusting = 0;
var baroButtonDown = 0;
var baroTimerRunning = 0;

var altPreselect = 0;
var altButtonTimerRunning = 0;
var altButtonTimerIgnore = 0;
var altAlertOn = 0;
var altCaptured = 0;
var altDifference = 0.0;

var valueTest = 0;
var lastValue = 0;
var newValue = 0;
var baroOffset = 0.0;
var baroChange = 1;
var minVoltageLimit = 8.0;


var ptCheck = func {
  ##print("pitch trim check");

  if (lockPitchMode.getValue() == pitchModes["OFF"])
  {
    annunciatorPtUp.setBoolValue(0);
    annunciatorPtDn.setBoolValue(0);
    return;
  }

  else
  {
    var autoPitchTrim = settingAutoPitchTrim.getValue();
    # Flash the pitch trim up annunciator
    if (elevatorControl.getValue() < -0.01)
    {
      if (annunciatorPtUp.getValue() == 0)
      {
        annunciatorPtUp.setBoolValue(1);
      }
      elsif (annunciatorPtUp.getValue() == 1)
      {
        annunciatorPtUp.setBoolValue(0);
      }
      annunciatorPtDn.setBoolValue(0);
      # Automatic pitch trim
      if (autoPitchTrim == 1)
      {
        elevatorTrimControl.setDoubleValue(
          elevatorTrimControl.getValue() - 0.001);
      }
    }
    # Flash the pitch trim down annunciator
    elsif (elevatorControl.getValue() > 0.01)
    {
      if (annunciatorPtDn.getValue() == 0)
      {
        annunciatorPtDn.setBoolValue(1);
      }
      elsif (annunciatorPtDn.getValue() == 1)
      {
        annunciatorPtDn.setBoolValue(0);
      }
      annunciatorPtUp.setBoolValue(0);
      # Automatic pitch trim
      if (autoPitchTrim == 1)
      {
        elevatorTrimControl.setDoubleValue(
          elevatorTrimControl.getValue() + 0.001);
      }
    }

    else
    {
      annunciatorPtUp.setBoolValue(0);
      annunciatorPtDn.setBoolValue(0);
    }
  }

  settimer(ptCheck, 0.5);
}


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
  lockRevHold.setBoolValue(0);
  lockRollAxis.setBoolValue(0);
  lockRollMode.setIntValue(rollModes["OFF"]);
  lockPitchAxis.setBoolValue(0);
  lockPitchMode.setIntValue(pitchModes["OFF"]);
  lockRollArm.setIntValue(rollArmModes["OFF"]);
  lockPitchArm.setIntValue(pitchArmModes["OFF"]);
#  Reset the memory for power down or power up
  altPreselect = 0;
  baroSettingInhg = 29.92;
  adjustBaroSettingInhg(0.0);
  settingTargetAltFt.setDoubleValue(altPreselect);
  settingTargetAltPressure.setDoubleValue(0.0);
  settingTargetInterceptAngle.setDoubleValue(0.0);
  settingTargetPressureRate.setDoubleValue(0.0);
  settingTargetTurnRate.setDoubleValue(0.0);

  annunciatorRol.setBoolValue(0);
  annunciatorHdg.getNode("state").setBoolValue(0);
  annunciatorNav.setBoolValue(0);
  annunciatorNavArm.setBoolValue(0);
  annunciatorApr.setBoolValue(0);
  annunciatorAprArm.setBoolValue(0);
  annunciatorRev.setBoolValue(0);
  annunciatorRevArm.setBoolValue(0);
  annunciatorVs.setBoolValue(0);
  annunciatorVsNumber.setBoolValue(0);
  annunciatorFpm.setBoolValue(0);
  annunciatorAlt.setBoolValue(0);
  annunciatorAltArm.setBoolValue(0);
  annunciatorAltNumber.setBoolValue(0);
  annunciatorGs.setBoolValue(0);
  annunciatorGsArm.setBoolValue(0);
  annunciatorPtUp.setBoolValue(0);
  annunciatorPtDn.setBoolValue(0);
  annunciatorBsHpaNumber.setBoolValue(0);
  annunciatorBsInhgNumber.setBoolValue(0);
  annunciatorAp.getNode("state").setBoolValue(0);
  annunciatorBeep.setBoolValue(0);

#  settimer(altAlert, 5.0);
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
    print("KAP140 power up");
    apInit();
    altAlert();
  } elsif (valueTest < -0.5) {
    # autopilot just lost power
    print("KAP140 power lost");
    apInit();
    annunciatorAltAlert.getNode("state").setBoolValue(0);
    annunciatorBeep.getNode("state").setBoolValue(0);
    # note: all button and knobs disabled in functions below
  }
  lastValue = newValue;
  settimer(apPower, 0.5);
}

var apButton = func {
  ##print("apButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  ##
  # Engages the autopilot in Wings level mode (ROL) and Vertical speed hold
  # mode (VS).
  ##
  if (lockRollMode.getValue() == rollModes["OFF"] and
      lockPitchMode.getValue() == pitchModes["OFF"])
  {

    lockAltHold.setBoolValue(0);
    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockHdgHold.setBoolValue(0);
    lockNavHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["ROL"]);
    lockPitchAxis.setBoolValue(1);
    lockPitchMode.setIntValue(pitchModes["VS"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
    lockPitchArm.setIntValue(pitchArmModes["OFF"]);

    annunciatorRol.setBoolValue(1);
    annunciatorVs.setBoolValue(1);
    annunciatorVsNumber.setBoolValue(1);

    settingTargetTurnRate.setDoubleValue(0.0);

    ptCheck();

    var pressureRate = getprop(internal, "pressure-rate");
    #print(pressureRate);
    var fpm = -pressureRate * 58000;
    #print(fpm);
    if (fpm > 0.0)
    {
      fpm = int(fpm/100 + 0.5) * 100;
    }
    else
    {
      fpm = int(fpm/100 - 0.5) * 100;
    }
    #print(fpm);

    settingTargetPressureRate.setDoubleValue(-fpm / 58000);

    if (altButtonTimerRunning == 0)
    {
      settimer(altButtonTimer, 3.0);
      altButtonTimerRunning = 1;
      altButtonTimerIgnore = 0;
      annunciatorAltNumber.setBoolValue(0);
    }
  }
  ##
  # Disengages all modes.
  ##
  elsif (lockRollMode.getValue() != rollModes["OFF"] and
         lockPitchMode.getValue() != pitchModes["OFF"])
  {

    lockAltHold.setBoolValue(0);
    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockHdgHold.setBoolValue(0);
    lockNavHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockRollAxis.setBoolValue(0);
    lockRollMode.setIntValue(rollModes["OFF"]);
    lockPitchAxis.setBoolValue(0);
    lockPitchMode.setIntValue(pitchModes["OFF"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
    lockPitchArm.setIntValue(pitchArmModes["OFF"]);

    settingTargetAltPressure.setDoubleValue(0.0);
    settingTargetInterceptAngle.setDoubleValue(0.0);
    settingTargetPressureRate.setDoubleValue(0.0);
    settingTargetTurnRate.setDoubleValue(0.0);

    annunciatorRol.setBoolValue(0);
    annunciatorHdg.getNode("state").setBoolValue(0);
    annunciatorNav.setBoolValue(0);
    annunciatorNavArm.setBoolValue(0);
    annunciatorApr.setBoolValue(0);
    annunciatorAprArm.setBoolValue(0);
    annunciatorRev.setBoolValue(0);
    annunciatorRevArm.setBoolValue(0);
    annunciatorVs.setBoolValue(0);
    annunciatorVsNumber.setBoolValue(0);
    annunciatorAlt.setBoolValue(0);
    annunciatorAltArm.setBoolValue(0);
    annunciatorAltNumber.setBoolValue(0);
    annunciatorApr.setBoolValue(0);
    annunciatorGs.setBoolValue(0);
    annunciatorGsArm.setBoolValue(0);
    annunciatorPtUp.setBoolValue(0);
    annunciatorPtDn.setBoolValue(0);

    apFlasher.blink(5).switch(0).switch(1);
  }
}


var hdgButton = func {
  ##print("hdgButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  ##
  # Engages the heading mode (HDG) and vertical speed hold mode (VS). The
  # commanded vertical speed is set to the vertical speed present at button
  # press.
  ##
  if (lockRollMode.getValue() == rollModes["OFF"] and
      lockPitchMode.getValue() == pitchModes["OFF"])
  {
    lockAltHold.setBoolValue(0);
    lockAprHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["HDG"]);
    lockPitchAxis.setBoolValue(1);
    lockPitchMode.setIntValue(pitchModes["VS"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
    lockPitchArm.setIntValue(pitchArmModes["OFF"]);

    annunciatorHdg.getNode("state").setBoolValue(1);
    annunciatorAlt.setBoolValue(0);
    annunciatorApr.setBoolValue(0);
    annunciatorGs.setBoolValue(0);
    annunciatorNav.setBoolValue(0);
    annunciatorVs.setBoolValue(1);
    annunciatorVsNumber.setBoolValue(1);

    settingTargetInterceptAngle.setDoubleValue(0.0);

    ptCheck();

    var pressureRate = getprop(internal, "pressure-rate");
    var fpm = -pressureRate * 58000;
    #print(fpm);
    if (fpm > 0.0)
    {
      fpm = int(fpm/100 + 0.5) * 100;
    }
    else
    {
      fpm = int(fpm/100 - 0.5) * 100;
    }
    #print(fpm);

    settingTargetPressureRate.setDoubleValue(-fpm / 58000);

    if (altButtonTimerRunning == 0)
    {
      settimer(altButtonTimer, 3.0);
      altButtonTimerRunning = 1;
      altButtonTimerIgnore = 0;
      annunciatorAltNumber.setBoolValue(0);
    }
  }
  ##
  # Switch from ROL to HDG mode, but don't change pitch mode.
  ##
  elsif (lockRollMode.getValue() == rollModes["ROL"])
  {
    lockAprHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["HDG"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);

    annunciatorApr.setBoolValue(0);
    annunciatorGs.setBoolValue(0);
    annunciatorHdg.getNode("state").setBoolValue(1);
    annunciatorNav.setBoolValue(0);
    annunciatorRol.setBoolValue(0);
    annunciatorRev.setBoolValue(0);

    settingTargetInterceptAngle.setDoubleValue(0.0);
  }
  ##
  # Switch to HDG mode, but don't change pitch mode.
  ##
  elsif ( (lockRollMode.getValue() == rollModes["NAV"] or
         lockRollArm.getValue() == rollArmModes["NAV"] or
         lockRollMode.getValue() == rollModes["REV"] or
         lockRollArm.getValue() == rollArmModes["REV"]) and
         !hdgFlasher.count)
  {
    lockAprHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["HDG"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);

    annunciatorApr.setBoolValue(0);
    annunciatorGs.setBoolValue(0);
    annunciatorHdg.getNode("state").setBoolValue(1);
    annunciatorNav.setBoolValue(0);
    annunciatorRol.setBoolValue(0);
    annunciatorRev.setBoolValue(0);
    annunciatorNavArm.setBoolValue(0);

    settingTargetInterceptAngle.setDoubleValue(0.0);
  }
  ##
  # If we already are in HDG mode switch to ROL mode. Again don't touch pitch
  # mode.
  ##
  elsif (lockRollMode.getValue() == rollModes["HDG"])
  {
    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockHdgHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["ROL"]);

    annunciatorApr.setBoolValue(0);
    annunciatorGs.setBoolValue(0);
    annunciatorHdg.getNode("state").setBoolValue(0);
    annunciatorNav.setBoolValue(0);
    annunciatorRol.setBoolValue(1);

    settingTargetTurnRate.setDoubleValue(0.0);
  }
  ##
  # If we are in APR mode we also have to change pitch mode.
  # TODO: Should we switch to VS or ALT mode? (currently VS)
  ##
  elsif ( (lockRollMode.getValue() == rollModes["APR"] or
         lockRollArm.getValue() == rollArmModes["APR"] or
         lockPitchMode.getValue() == pitchModes["GS"] or
         lockPitchArm.getValue() == pitchArmModes["GS"]) and
         !hdgFlasher.count)
  {
    lockAltHold.setBoolValue(0);
    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["HDG"]);
    lockPitchAxis.setBoolValue(1);
    lockPitchMode.setIntValue(pitchModes["VS"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
    lockPitchArm.setIntValue(pitchArmModes["OFF"]);

    annunciatorAlt.setBoolValue(0);
    annunciatorAltArm.setBoolValue(0);
    annunciatorHdg.getNode("state").setBoolValue(1);
    annunciatorRol.setBoolValue(0);
    annunciatorNav.setBoolValue(0);
    annunciatorApr.setBoolValue(0);
    annunciatorAprArm.setBoolValue(0);
    annunciatorGs.setBoolValue(0);
    annunciatorGsArm.setBoolValue(0);
    annunciatorVs.setBoolValue(1);
    annunciatorVsNumber.setBoolValue(1);

    settingTargetInterceptAngle.setDoubleValue(0.0);

    var pressureRate = getprop(internal, "pressure-rate");
    #print(pressureRate);
    var fpm = -pressureRate * 58000;
    #print(fpm);
    if (fpm > 0.0)
    {
      fpm = int(fpm/100 + 0.5) * 100;
    }
    else
    {
      fpm = int(fpm/100 - 0.5) * 100;
    }
    #print(fpm);

    settingTargetPressureRate.setDoubleValue(-fpm / 58000);

    if (altButtonTimerRunning == 0)
    {
      settimer(altButtonTimer, 3.0);
      altButtonTimerRunning = 1;
      altButtonTimerIgnore = 0;
      annunciatorAltNumber.setBoolValue(0);
    }
  }
}


var navButton = func {
  ##print("navButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  ##
  # If we are in HDG mode we switch to the 45 degree angle intercept NAV mode
  ##
  if (lockRollMode.getValue() == rollModes["HDG"])
  {
    hdgFlasher.blink(8, 1).switch(0).switch(1);

    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["NAV"]);
    lockRollMode.setIntValue(rollModes["NAV"]);

    annunciatorNavArm.setBoolValue(1);

    navArmFromHdg();
  }
  ##
  # If we are in ROL mode we switch to the all angle intercept NAV mode.
  ##
  elsif (lockRollMode.getValue() == rollModes["ROL"])
  {
    hdgFlasher.blink(8).switch(0).switch(1);

    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(0);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["NAV"]);
    lockRollMode.setIntValue(rollModes["NAV"]);

    annunciatorNavArm.setBoolValue(1);

    navArmFromRol();
  }
  ##
  # TODO:
  # NAV mode can only be armed if we are in HDG or ROL mode.
  # Can anyone verify that this is correct?
  ##
}

var navArmFromHdg = func
{
  ##
  # Abort the NAV-ARM mode if something has changed the arm mode to something
  # else than NAV-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["NAV"])
  {
    annunciatorNavArm.setBoolValue(0);
    return;
  }

  #annunciatorNavArm.setBoolValue(1);
  ##
  # Wait for the HDG annunciator flashing to finish.
  ##
  if (hdgFlasher.count)
  {
    #print("flashing...");
    settimer(navArmFromHdg, 2.5);
    return;
  }
  ##
  # Activate the nav-hold controller and check the needle deviation.
  ##
  lockNavHold.setBoolValue(1);
  deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 3 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 3.0)
  {
    #print("deviation");
    settimer(navArmFromHdg, 5);
    return;
  }
  ##
  # If the deviation is less than 3 degrees turn of the NAV-ARM annunciator
  # and show the NAV annunciator. End of NAV-ARM sequence.
  ##
  elsif (abs(deviation) < 3.1)
  {
    #print("capture");
    lockRollArm.setIntValue(rollArmModes["OFF"]);
    annunciatorNavArm.setBoolValue(0);
    annunciatorHdg.getNode("state").setBoolValue(0);
    annunciatorNav.setBoolValue(1);
  }
}

var navArmFromRol = func
{
  ##
  # Abort the NAV-ARM mode if something has changed the arm mode to something
  # else than NAV-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["NAV"])
  {
    annunciatorNavArm.setBoolValue(0);
    return;
  }
  ##
  # Wait for the HDG annunciator flashing to finish.
  ##
  #annunciatorNavArm.setBoolValue(1);
  if (hdgFlasher.count)
  {
    #print("flashing...");
    annunciatorRol.setBoolValue(0);
    settimer(navArmFromRol, 2.5);
    return;
  }
  ##
  # Turn the ROL annunciator back on and activate the ROL mode.
  ##
  annunciatorRol.setBoolValue(1);
  lockRollAxis.setBoolValue(1);
  settingTargetTurnRate.setDoubleValue(0.0);
  var deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 3 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 3.0)
  {
    #print("deviation");
    settimer(navArmFromRol, 5);
    return;
  }
  ##
  # If the deviation is less than 3 degrees turn of the NAV-ARM annunciator
  # and show the NAV annunciator. End of NAV-ARM sequence.
  ##
  elsif (abs(deviation) < 3.1)
  {
    #print("capture");
    annunciatorRol.setBoolValue(0);
    annunciatorNavArm.setBoolValue(0);
    annunciatorNav.setBoolValue(1);

    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(1);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["NAV"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
  }
}

var aprButton = func {
  ##print("aprButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  ##
  # If we are in HDG mode we switch to the 45 degree intercept angle APR mode
  ##
  if (lockRollMode.getValue() == rollModes["HDG"])
  {
    hdgFlasher.blink(8, 1).switch(0).switch(1);

    lockAprHold.setBoolValue(1);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["APR"]);
    lockRollMode.setIntValue(rollModes["APR"]);

    annunciatorAprArm.setBoolValue(1);

    aprArmFromHdg();
  }
  elsif (lockRollMode.getValue() == rollModes["ROL"])
  {
    hdgFlasher.blink(8).switch(0).switch(1);

    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(0);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["APR"]);
    lockRollMode.setIntValue(rollModes["APR"]);

    annunciatorAprArm.setBoolValue(1);

    aprArmFromRol();
  }
}

var aprArmFromHdg = func
{
  ##
  # Abort the APR-ARM mode if something has changed the arm mode to something
  # else than APR-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["APR"])
  {
    annunciatorAprArm.setBoolValue(0);
    return;
  }

  #annunciatorAprArm.setBoolValue(1);
  ##
  # Wait for the HDG annunciator flashing to finish.
  ##
  if (hdgFlasher.count)
  {
    #print("flashing...");
    settimer(aprArmFromHdg, 2.5);
    return;
  }
  ##
  # Activate the apr-hold controller and check the needle deviation.
  ##
  lockAprHold.setBoolValue(1);
  var deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 3 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 3.0)
  {
    #print("deviation");
    settimer(aprArmFromHdg, 5);
    return;
  }
  ##
  # If the deviation is less than 3 degrees turn of the APR-ARM annunciator
  # and show the APR annunciator. End of APR-ARM sequence. Start the GS-ARM
  # sequence.
  ##
  elsif (abs(deviation) < 3.1)
  {
    #print("capture");
    annunciatorAprArm.setBoolValue(0);
    annunciatorHdg.getNode("state").setBoolValue(0);
    annunciatorApr.setBoolValue(1);
    lockPitchArm.setIntValue(pitchArmModes["GS"]);

    gsArm();
  }
}

var aprArmFromRol = func
{
  ##
  # Abort the APR-ARM mode if something has changed the roll mode to something
  # else than APR-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["APR"])
  {
    annunciatorAprArm.setBoolValue(0);
    return;
  }

  #annunciatorAprArm.setBoolValue(1);
  ##
  # Wait for the HDG annunciator flashing to finish.
  ##
  if (hdgFlasher.count)
  {
    #print("flashing...");
    annunciatorRol.setBoolValue(0);
    settimer(aprArmFromRol, 2.5);
    return;
  }
  ##
  # Turn the ROL annunciator back on and activate the ROL mode.
  ##
  annunciatorRol.setBoolValue(1);
  lockRollAxis.setBoolValue(1);
  settingTargetTurnRate.setDoubleValue(0.0);
  var deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 3 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 3.0)
  {
    #print("deviation");
    settimer(aprArmFromRol, 5);
    return;
  }
  ##
  # If the deviation is less than 3 degrees turn of the APR-ARM annunciator
  # and show the APR annunciator. End of APR-ARM sequence. Start the GS-ARM
  # sequence.
  ##
  elsif (abs(deviation) < 3.1)
  {
    #print("capture");
    annunciatorRol.setBoolValue(0);
    annunciatorAprArm.setBoolValue(0);
    annunciatorApr.setBoolValue(1);

    lockAprHold.setBoolValue(1);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["APR"]);
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
    annunciatorGsArm.setBoolValue(0);
    return;
  }

  annunciatorGsArm.setBoolValue(1);

  var deviation = getprop(gsNeedleDeflection);
  ##
  # If the deflection is more than 50% (manual says '2 to 3 dots')
  ##
  if (abs(deviation) > 0.5)
  {
    #print("deviation");
    settimer(gsArm, 5);
    return;
  }
  ##
  # If the deviation is less than 50% turn off the GS-ARM annunciator
  # and show the GS annunciator. Activate the GS pitch mode.
  ##
  else
  {
    #print("capture");
    annunciatorAlt.setBoolValue(0);
    annunciatorVs.setBoolValue(0);
    annunciatorVsNumber.setBoolValue(0);
    annunciatorGsArm.setBoolValue(0);
    annunciatorGs.setBoolValue(1);

    lockAltHold.setBoolValue(0);
    lockGsHold.setBoolValue(1);
    lockPitchMode.setIntValue(pitchModes["GS"]);
    lockPitchArm.setIntValue(pitchArmModes["OFF"]);
  }

}


var revButton = func {
  ##print("revButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  ##
  # If we are in HDG mode we switch to the 45 degree intercept angle REV mode
  ##
  if (lockRollMode.getValue() == rollModes["HDG"])
  {
    hdgFlasher.blink(8, 1).switch(0).switch(1);

    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["REV"]);

    annunciatorRevArm.setBoolValue(1);

    revArmFromHdg();
  }
  elsif (lockRollMode.getValue() == rollModes["ROL"])
  {
    hdgFlasher.blink(8).switch(0).switch(1);

    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(0);
    lockHdgHold.setBoolValue(0);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["REV"]);

    annunciatorRevArm.setBoolValue(1);

    revArmFromRol();
  }
}


var revArmFromHdg = func
{
  ##
  # Abort the REV-ARM mode if something has changed the arm mode to something
  # else than REV-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["REV"])
  {
    annunciatorRevArm.setBoolValue(0);
    return;
  }

  #annunciatorRevArm.setBoolValue(1);
  ##
  # Wait for the HDG annunciator flashing to finish.
  ##
  if (hdgFlasher.count)
  {
    #print("flashing...");
    settimer(revArmFromHdg, 2.5);
    return;
  }
  ##
  # Activate the rev-hold controller and check the needle deviation.
  ##
  lockRevHold.setBoolValue(1);
  var deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 3 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 3.0)
  {
    #print("deviation");
    settimer(revArmFromHdg, 5);
    return;
  }
  ##
  # If the deviation is less than 3 degrees turn of the REV-ARM annunciator
  # and show the REV annunciator. End of REV-ARM sequence.
  ##
  elsif (abs(deviation) < 3.1)
  {
    #print("capture");
    annunciatorRevArm.setBoolValue(0);
    annunciatorHdg.getNode("state").setBoolValue(0);
    annunciatorRev.setBoolValue(1);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
    annunciatorRol.setBoolValue(0);
    annunciatorRevArm.setBoolValue(0);
    annunciatorRev.setBoolValue(1);

    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(1);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["REV"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
  }
}


var revArmFromRol = func
{
  ##
  # Abort the REV-ARM mode if something has changed the arm mode to something
  # else than REV-ARM.
  ##
  if (lockRollArm.getValue() != rollArmModes["REV"])
  {
    annunciatorRevArm.setBoolValue(0);
    return;
  }

  #annunciatorRevArm.setBoolValue(1);
  ##
  # Wait for the HDG annunciator flashing to finish.
  ##
  if (hdgFlasher.count)
  {
    #print("flashing...");
    annunciatorRol.setBoolValue(0);
    settimer(revArmFromRol, 2.5);
    return;
  }
  ##
  # Turn the ROL annunciator back on and activate the ROL mode.
  ##
  annunciatorRol.setBoolValue(1);
  lockRollAxis.setBoolValue(1);
  settingTargetTurnRate.setDoubleValue(0.0);
  var deviation = getprop(headingNeedleDeflection);
  ##
  # If the deflection is more than 3 degrees wait 5 seconds and check again.
  ##
  if (abs(deviation) > 3.0)
  {
    #print("deviation");
    settimer(revArmFromRol, 5);
    return;
  }
  ##
  # If the deviation is less than 3 degrees turn of the REV-ARM annunciator
  # and show the REV annunciator. End of REV-ARM sequence.
  ##
  elsif (abs(deviation) < 3.1)
  {
    #print("capture");
    annunciatorRol.setBoolValue(0);
    annunciatorRevArm.setBoolValue(0);
    annunciatorRev.setBoolValue(1);

    lockAprHold.setBoolValue(0);
    lockGsHold.setBoolValue(0);
    lockRevHold.setBoolValue(1);
    lockHdgHold.setBoolValue(1);
    lockNavHold.setBoolValue(0);
    lockRollAxis.setBoolValue(1);
    lockRollMode.setIntValue(rollModes["REV"]);
    lockRollArm.setIntValue(rollArmModes["OFF"]);
  }
}


var altButtonTimer = func {
  #print("alt button timer");
  #print(altButtonTimerIgnore);

  if (altButtonTimerIgnore == 0)
  {
      annunciatorVsNumber.setBoolValue(0);
      annunciatorAltNumber.setBoolValue(1);

      altButtonTimerRunning = 0;
  }
  elsif (altButtonTimerIgnore > 0)
  {
      altButtonTimerIgnore = altButtonTimerIgnore - 1;
  }
}


var altButton = func {
  ##print("altButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }


  if (lockPitchMode.getValue() == pitchModes["ALT"])
  {
    if (altButtonTimerRunning == 0)
    {
      settimer(altButtonTimer, 3.0);
      altButtonTimerRunning = 1;
      altButtonTimerIgnore = 0;
    }
    lockAltHold.setBoolValue(0);

    lockPitchAxis.setBoolValue(1);
    lockPitchMode.setIntValue(pitchModes["VS"]);

    annunciatorAlt.setBoolValue(0);
    annunciatorAltNumber.setBoolValue(0);
    annunciatorVs.setBoolValue(1);
    annunciatorVsNumber.setBoolValue(1);

    var pressureRate = getprop(internal, "pressure-rate");
    var fpm = -pressureRate * 58000;
    #print(fpm);
    if (fpm > 0.0)
    {
      fpm = int(fpm/100 + 0.5) * 100;
    }
    else
    {
      fpm = int(fpm/100 - 0.5) * 100;
    }
    #print(fpm);

    settingTargetPressureRate.setDoubleValue(-fpm / 58000);

  }
  elsif (lockPitchMode.getValue() == pitchModes["VS"])
  {
    lockAltHold.setBoolValue(1);
    lockPitchAxis.setBoolValue(1);
    lockPitchMode.setIntValue(pitchModes["ALT"]);

    annunciatorAlt.setBoolValue(1);
    annunciatorVs.setBoolValue(0);
    annunciatorVsNumber.setBoolValue(0);
    annunciatorAltNumber.setBoolValue(1);

    var altPressure = getprop(staticPressure);
    settingTargetAltPressure.setDoubleValue(altPressure);
  }
}


var downButton = func {
  ##print("downButton");#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (baroTimerRunning == 0)
  {
    if (lockPitchMode.getValue() == pitchModes["VS"])
    {
      if (altButtonTimerRunning == 0)
      {
        settimer(altButtonTimer, 3.0);
        altButtonTimerRunning = 1;
        altButtonTimerIgnore = 0;
      }
      elsif (altButtonTimerRunning == 1)
      {
          settimer(altButtonTimer, 3.0);
          altButtonTimerIgnore = altButtonTimerIgnore + 1;
      }
      targetVS = settingTargetPressureRate.getValue();
      settingTargetPressureRate.setDoubleValue(targetVS +
                                               0.0017241379310345);
      annunciatorAltNumber.setBoolValue(0);
      annunciatorVsNumber.setBoolValue(1);
    }
    elsif (lockPitchMode.getValue() == pitchModes["ALT"])
    {
      var targetPressure = getprop(settings, "target-alt-pressure");
      settingTargetAltPressure.setDoubleValue(targetPressure + 0.0206);
    }
  }
}

var upButton = func {
  ##print("upButton");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (baroTimerRunning == 0)
  {
    if (lockPitchMode.getValue() == pitchModes["VS"])
    {
      if (altButtonTimerRunning == 0)
      {
        settimer(altButtonTimer, 3.0);
        altButtonTimerRunning = 1;
        altButtonTimerIgnore = 0;
      }
      elsif (altButtonTimerRunning == 1)
      {
          settimer(altButtonTimer, 3.0);
          altButtonTimerIgnore = altButtonTimerIgnore + 1;
      }
      var targetVS = settingTargetPressureRate.getValue();
      settingTargetPressureRate.setDoubleValue(targetVS -
                                               0.0017241379310345);
      annunciatorAltNumber.setBoolValue(0);
      annunciatorVsNumber.setBoolValue(1);
    }
    elsif (lockPitchMode.getValue() == pitchModes["ALT"])
    {
      var targetPressure = getprop(settings, "target-alt-pressure");
      settingTargetAltPressure.setDoubleValue(targetPressure - 0.0206);
    }
  }
}

var armButton = func {
  #print("arm button");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  var pitchArm = lockPitchArm.getValue();

  if (pitchArm == pitchArmModes["OFF"])
  {
    lockPitchArm.setIntValue(pitchArmModes["ALT"]);

    annunciatorAltArm.setBoolValue(1);
  }
  elsif (pitchArm == pitchArmModes["ALT"])
  {
    lockPitchArm.setIntValue(pitchArmModes["OFF"]);

    annunciatorAltArm.setBoolValue(0);
  }
}


var baroButtonTimer = func {
  #print("baro button timer");

  baroTimerRunning = 0;
  if (baroButtonDown == 1)
  {
    baroSettingUnit = !baroSettingUnit;
    baroButtonDown = 0;
    baroButtonPress();
  }
  elsif (baroButtonDown == 0 and
         baroSettingAdjusting == 0)
  {
    annunciatorBsHpaNumber.setBoolValue(0);
    annunciatorBsInhgNumber.setBoolValue(0);
    annunciatorAltNumber.setBoolValue(1);
  }
  elsif (baroSettingAdjusting == 1)
  {
    baroTimerRunning = 1;
    baroSettingAdjusting = 0;
    settimer(baroButtonTimer, 3.0);
  }
}

var baroButtonPress = func {
  #print("baro putton press");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (baroButtonDown == 0 and
      baroTimerRunning == 0 and
      altButtonTimerRunning == 0)
  {
    baroButtonDown = 1;
    baroTimerRunning = 1;
    settimer(baroButtonTimer, 3.0);
    annunciatorAltNumber.setBoolValue(0);

    if (baroSettingUnit == pressureUnits["inHg"])
    {
      annunciatorBsInhgNumber.setBoolValue(1);
      annunciatorBsHpaNumber.setBoolValue(0);
    }
    elsif (baroSettingUnit == pressureUnits["hPa"])
    {
      annunciatorBsHpaNumber.setBoolValue(1);
      annunciatorBsInhgNumber.setBoolValue(0);
    }
  }
}


var baroButtonRelease = func {
  #print("baro button release");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  baroButtonDown = 0;
}


var pow = func(base, exponent) {
  #print(base,exponent);
  return math.exp(exponent*math.ln(base));
}


var pressureToHeight = func(p, p0) {
#
#   kollsman shift due to baroSettingInhg =
#       baroOffset = pressureToHeight(baroSettingInhg, 29.921260)
#
  #var p0 = p0;    # [Pa] or (p0 and p need to have the same units)
  #var p = p;     # [Pa] or (p0 and p need to have the same units)
  var t0 = 288.15;    # [K]       same as in atmosphere.?xx
  var LR = -0.0065;   # [K/m]     same as in atmosphere.?xx
  var g = -9.80665;   # [m/s²]    same as in atmosphere.?xx
  var Rd = 287.05307; # [J/kg K]  same as in atmosphere.?xx to 8 places
  var ftTom = 0.3048;
  var coefficient = t0/LR/ftTom;
#  coefficient = -145442.156;
  var exponent = Rd*LR/g;
#  exponent = 0.1902632365;

  var z = -coefficient * (1.0-pow((p/p0),exponent));
  return z;
}


var heightToPressure = func(z, p0) {
  #var p0 = p0;    # [Pa]
  #var z = z;     # [m]
  var t0 = 288.15;    # [K]
  var LR = -0.0065;    # [K/m]
  var g = -9.80665;    # [m/s²]
  var Rd = 287.05307; # [J/kg K]

  var p = p0 * pow(((t0+LR*z)/t0),(g/(Rd*LR)));
  return p;
}

var altAlert = func {
  #print("alt alert");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  var pressureAltitude = getprop(encoder, "pressure-alt-ft");

  if (baroChange) {
    baroOffset = pressureToHeight(baroSettingInhg, 29.921260);
    baroChange = 0;
  }

  var altFt = pressureAltitude - baroOffset;
  var prevAltDifference = altDifference;
  altDifference = abs(altPreselect - altFt);

  if (altDifference > 1000)
  {
    annunciatorAltAlert.getNode("state").setBoolValue(0);
  }
  elsif (altDifference < 1000 and
         altCaptured == 0)
  {
    if (!altAlertFlasher.count)
    {
      annunciatorAltAlert.getNode("state").setBoolValue(1);
    }
    if (!altAlertBeeper.count and prevAltDifference > 1000)
    {
      altAlertBeeper.blink(5).switch(0).switch(1);
    }
    if (altDifference < 200)
    {
      if (!altAlertFlasher.count)
      {
        annunciatorAltAlert.getNode("state").setBoolValue(0);
      }
      if (altDifference < 20)
      {
        #print("altCapture()");
        altCaptured = 1;

        if (lockPitchArm.getValue() == pitchArmModes["ALT"])
        {
          lockAltHold.setBoolValue(1);
          lockPitchAxis.setBoolValue(1);
          lockPitchMode.setIntValue(pitchModes["ALT"]);
          lockPitchArm.setIntValue(pitchArmModes["OFF"]);

          annunciatorAlt.setBoolValue(1);
          annunciatorAltArm.setBoolValue(0);
          annunciatorVs.setBoolValue(0);
          annunciatorVsNumber.setBoolValue(0);
          annunciatorAltNumber.setBoolValue(1);

          var altPressure = getprop(staticPressure);
          settingTargetAltPressure.setDoubleValue(altPressure);
        }

        altAlertFlasher.blink(1).switch(0).switch(1);
      }
    }
  }
  elsif (altDifference < 1000 and
         altCaptured == 1)
  {
    if (altDifference > 200)
    {
      altAlertFlasher.blink(5, 1).switch(0).switch(1);
      altAlertBeeper.blink(5).switch(0).switch(1);
      altCaptured = 0;
    }
  }
  settimer(altAlert, 2.0);
}

var adjustBaroSettingInhg = func(amount) {
  # Adjust baro setting inHg by amount,
  # and sync baro setting hPa.
  baroSettingInhg = baroSettingInhg + amount;
  baroSettingHpa = baroSettingInhg * 0.03386389;

  settingBaroSettingHpa.setDoubleValue(baroSettingHpa);
  settingBaroSettingInhg.setDoubleValue(baroSettingInhg);
  baroChange = 1;
}

var adjustbaroSettingHpa = func(amount) {
  # Adjust baro setting hPa by amount,
  # and sync baro setting inHg.
  baroSettingHpa = baroSettingHpa + amount;
  baroSettingInhg = baroSettingHpa / 0.03386389;

  settingBaroSettingHpa.setDoubleValue(baroSettingHpa);
  settingBaroSettingInhg.setDoubleValue(baroSettingInhg);
  baroChange = 1;
}

var knobSmallUp = func {
  #print("knob small up");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (baroTimerRunning == 1)
  {
    baroSettingAdjusting = 1;
    if (baroSettingUnit == pressureUnits["inHg"])
    {
      adjustBaroSettingInhg(0.01);
    }
    elsif (baroSettingUnit == pressureUnits["hPa"])
    {
      adjustbaroSettingHpa(0.001);
    }
  }
  elsif (baroTimerRunning == 0 and
         altButtonTimerRunning == 0)
  {
    altCaptured = 0;
    altPreselect = altPreselect + 20;
    settingTargetAltFt.setDoubleValue(altPreselect);

    if (lockRollMode.getValue() == rollModes["OFF"] and
        lockPitchMode.getValue() == pitchModes["OFF"])
    {
      annunciatorAltNumber.setBoolValue(1);
      if (altAlertOn == 0)
      {
        altAlertOn = 1;
      }
    }
    elsif (lockPitchArm.getValue() == pitchArmModes["OFF"])
    {
      lockPitchArm.setIntValue(pitchArmModes["ALT"]);
      annunciatorAltArm.setBoolValue(1);
    }
  }
}


var knobLargeUp = func {
  #print("knob large up");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (baroTimerRunning == 1)
  {
    baroSettingAdjusting = 1;
    if (baroSettingUnit == pressureUnits["inHg"])
    {
      adjustBaroSettingInhg(1.0);
    }
    elsif (baroSettingUnit == pressureUnits["hPa"])
    {
      adjustbaroSettingHpa(0.1);
    }
  }
  elsif (baroTimerRunning == 0 and
         altButtonTimerRunning == 0)
  {
    altCaptured = 0;
    altPreselect = altPreselect + 100;
    settingTargetAltFt.setDoubleValue(altPreselect);

    if (lockRollMode.getValue() == rollModes["OFF"] and
        lockPitchMode.getValue() == pitchModes["OFF"])
    {
      annunciatorAltNumber.setBoolValue(1);
      if (altAlertOn == 0)
      {
        altAlertOn = 1;
      }
    }
    elsif (lockPitchArm.getValue() == pitchArmModes["OFF"])
    {
      lockPitchArm.setIntValue(pitchArmModes["ALT"]);
      annunciatorAltArm.setBoolValue(1);
    }
  }
}


var knobSmallDown = func {
  #print("knob small down");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (baroTimerRunning == 1)
  {
    baroSettingAdjusting = 1;
    if (baroSettingUnit == pressureUnits["inHg"])
    {
      adjustBaroSettingInhg(-0.01);
    }
    elsif (baroSettingUnit == pressureUnits["hPa"])
    {
      adjustbaroSettingHpa(-0.001);
    }
  }
  elsif (baroTimerRunning == 0 and
         altButtonTimerRunning == 0)
  {
    altCaptured = 0;
    altPreselect = altPreselect - 20;
    settingTargetAltFt.setDoubleValue(altPreselect);

    if (lockRollMode.getValue() == rollModes["OFF"] and
        lockPitchMode.getValue() == pitchModes["OFF"])
    {
      annunciatorAltNumber.setBoolValue(1);
      if (altAlertOn == 0)
      {
        altAlertOn = 1;
      }
    }
    elsif (lockPitchArm.getValue() == pitchArmModes["OFF"])
    {
      lockPitchArm.setIntValue(pitchArmModes["ALT"]);
      annunciatorAltArm.setBoolValue(1);
    }
  }
}


var knobLargeDown = func {
  #print("knob large down");
#  Disable button if too little power
  if (getprop(power) < minVoltageLimit) { return; }

  if (baroTimerRunning == 1)
  {
    baroSettingAdjusting = 1;
    if (baroSettingUnit == pressureUnits["inHg"])
    {
      adjustBaroSettingInhg(-1.0);
    }
    elsif (baroSettingUnit == pressureUnits["hPa"])
    {
      adjustbaroSettingHpa(-0.1);
    }
  }
  elsif (baroTimerRunning == 0 and
         altButtonTimerRunning == 0)
  {
    altCaptured = 0;
    altPreselect = altPreselect - 100;
    settingTargetAltFt.setDoubleValue(altPreselect);

    if (lockRollMode.getValue() == rollModes["OFF"] and
        lockPitchMode.getValue() == pitchModes["OFF"])
    {
      annunciatorAltNumber.setBoolValue(1);
      if (altAlertOn == 0)
      {
        altAlertOn = 1;
      }
    }
    elsif (lockPitchArm.getValue() == pitchArmModes["OFF"])
    {
      lockPitchArm.setIntValue(pitchArmModes["ALT"]);
      annunciatorAltArm.setBoolValue(1);
    }
  }
}

var L = setlistener(power, func {
  apPower();
  removelistener(L);
});
