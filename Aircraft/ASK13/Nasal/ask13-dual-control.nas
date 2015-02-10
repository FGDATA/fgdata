###############################################################################
## 
## Nasal for MP-passenger on the ASK-13 over the multiplayer network.
##
##  Copyright (C) 2010 Patrice Poly, based on dual control by
##  Anders Gidenstam  :  http://www.gidenstam.org/FlightGear/DualControl/
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Renaming (almost :)
var DCT = dual_control_tools;

######################################################################
# Pilot/copilot aircraft identifiers. Used by dual_control.
var pilot_type   = "Aircraft/ASK13/Models/ask13.xml";
var copilot_type = "";

props.globals.initNode("/sim/remote/pilot-callsign", "", "STRING");

######################################################################
# MP enabled properties.
# NOTE: These must exist very early during startup - put them
#       in the -set.xml file.


######################################################################
# Useful local property paths.

######################################################################
# Slow state properties for replication.


###############################################################################
# Pilot MP property mappings and specific copilot connect/disconnect actions.


######################################################################
# Used by dual_control to set up the mappings for the pilot.
var pilot_connect_copilot = func (copilot) {
    return 
        [
         ######################################################################
         # Process received properties.
         ######################################################################
         ######################################################################
         # Process properties to send.
         ######################################################################
        ];
}

######################################################################
var pilot_disconnect_copilot = func {
}


###############################################################################
# Copilot MP property mappings and specific pilot connect/disconnect actions.


######################################################################
# Used by dual_control to set up the mappings for the copilot.
var copilot_connect_pilot = func (pilot) {
    # Initialize Nasal wrappers for copilot pick anaimations.
    set_copilot_wrappers(pilot);

    return
        [
         ######################################################################
         # Process received properties.
         ######################################################################
         ######################################################################
         # Process properties to send.
         ######################################################################
        ];
}

######################################################################
var copilot_disconnect_pilot = func {
    # Reset local sound properties.

#    p = "/gear/gear[0]/wow";
#    props.globals.getNode(p).unalias();
#    props.globals.getNode(p).setValue(0);
#    p = "/gear/gear[1]/wow";
#    props.globals.getNode(p).unalias();
#    props.globals.getNode(p).setValue(0);
#    p = "/gear/gear[2]/wow";
#    props.globals.getNode(p).unalias();
#    props.globals.getNode(p).setValue(0);
    p = "/velocities/groundspeed-kt";
    props.globals.getNode(p).unalias();
    props.globals.getNode(p).setValue(0);
    p = "/velocities/airspeed-kt";
    props.globals.getNode(p).unalias();
    props.globals.getNode(p).setValue(0);
    p = "/position/altitude-ft";
    props.globals.getNode(p).unalias();
    props.globals.getNode(p).setValue(0);
#    p = "/surface-positions/speedbrake-pos-norm";
#    props.globals.getNode(p).unalias();
#    props.globals.getNode(p).setValue(0);
#    p = "/fdm/jsbsim/aero/alpha-rad[0]";
#    props.globals.getNode(p).unalias();
#    props.globals.getNode(p).setValue(0);
    p = "/velocities/vertical-speed-fps";
    props.globals.getNode(p).unalias();
    props.globals.getNode(p).setValue(0);
    p = "/velocities/speed-down-fps";
    props.globals.getNode(p).unalias();
    props.globals.getNode(p).setValue(0);
#    p = "/accelerations/pilot-gdamped";
#    props.globals.getNode(p).unalias();
#    props.globals.getNode(p).setValue(0);
#    p = "/orientation/pitch-rate-degps";
#    props.globals.getNode(p).unalias();
#    props.globals.getNode(p).setValue(0);
#    p = "/sim/hitches/winch/open";
#    props.globals.getNode(p).unalias();
#    props.globals.getNode(p).setValue(0);
}

######################################################################
# Copilot Nasal wrappers

var set_copilot_wrappers = func (pilot) {
    # Setup aliases to animate the MP 3d model.
    var p = "instrumentation/magnetic-compass/indicated-heading-deg";
    pilot.getNode(p,1).alias(props.globals.getNode(p));

    # Setup aliases to drive local sound.

#    p = "/gear/gear[0]/wow";
#    props.globals.getNode(p).alias(pilot.getNode(p));
#    p = "/gear/gear[1]/wow";
#    props.globals.getNode(p).alias(pilot.getNode(p));
#    p = "/gear/gear[2]/wow";
#    props.globals.getNode(p).alias(pilot.getNode(p));
    p = "/velocities/groundspeed-kt";
    props.globals.getNode(p).alias(pilot.getNode(p));
    p = "/velocities/airspeed-kt";
    props.globals.getNode(p).alias(pilot.getNode(p));
    p = "/position/altitude-ft";
    props.globals.getNode(p).alias(pilot.getNode(p));
#    p = "/surface-positions/speedbrake-pos-norm";
#    props.globals.getNode(p).alias(pilot.getNode(p));
#    p = "/fdm/jsbsim/aero/alpha-rad[0]";
#    props.globals.getNode(p).alias(pilot.getNode(p));
    p = "/velocities/vertical-speed-fps";
    props.globals.getNode(p).alias(pilot.getNode(p));
    p = "/velocities/speed-down-fps";
    props.globals.getNode(p).alias(pilot.getNode(p));
#    p = "/accelerations/pilot-gdamped";
#    props.globals.getNode(p).alias(pilot.getNode(p));
#    p = "/orientation/pitch-rate-degps";
#    props.globals.getNode(p).alias(pilot.getNode(p));
#    p = "/sim/hitches/winch/open";
#    props.globals.getNode(p).alias(pilot.getNode(p));
}
