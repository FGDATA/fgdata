###############################################################################
##
## Nasal for dual control Zeppelin NT Center MFD.
##
##  Copyright (C) 2009 - 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#  This module MUST be loaded as CenterMFD.
#

# Slave button presses.


# Properties
var l_base = "instrumentation/CenterMFD/";
#   Engines screen
var l_manifold_pressure =
    ["engines/engine[0]/mp-inhg",
     "engines/engine[1]/mp-inhg",
     "engines/engine[2]/mp-inhg"];
var l_EGT =
    ["engines/engine[0]/egt-degc",
     "engines/engine[1]/egt-degc",
     "engines/engine[2]/egt-degc"];
var l_CHT =
    ["engines/engine[0]/cht-degc",
     "engines/engine[1]/cht-degc",
     "engines/engine[2]/cht-degc"];
var l_oil_temperature =
    ["engines/engine[0]/oil-temperature-degc",
     "engines/engine[1]/oil-temperature-degc",
     "engines/engine[2]/oil-temperature-degc"];
var l_oil_pressure =
    ["engines/engine[0]/oil-pressure-psi",
     "engines/engine[1]/oil-pressure-psi",
     "engines/engine[2]/oil-pressure-psi"];
var l_fuel_quantity =
    ["consumables/fuel/tank[0]/level-lbs",
     "consumables/fuel/tank[1]/level-lbs",
     "consumables/fuel/tank[2]/level-lbs"];
var l_fuel_flow =
    ["engines/engine[0]/fuel-flow-gph",
     "engines/engine[1]/fuel-flow-gph",
     "engines/engine[2]/fuel-flow-gph"];
#  Controls screen
var l_propeller_pitch =
    ["fdm/jsbsim/propulsion/engine[0]/blade-angle",
     "fdm/jsbsim/propulsion/engine[1]/blade-angle",
     "fdm/jsbsim/propulsion/engine[2]/blade-angle"];
var l_engine_swivel =
    ["fdm/jsbsim/propulsion/engine[0]/pitch-angle-rad",
     "fdm/jsbsim/propulsion/engine[1]/pitch-angle-rad",
     "fdm/jsbsim/propulsion/engine[2]/pitch-angle-rad"];
var l_surfaces =
    [l_base ~ "controls/abs-rudder-pos-norm",
     l_base ~ "controls/rudder-pos-norm",
     l_base ~ "controls/abs-elevator-pos-norm",
     l_base ~ "controls/elevator-pos-norm"];
var l_rudder   = "surface-positions/rudder-pos-norm";
var l_elevator = "surface-positions/elevator-pos-norm";

###########################################################################
var master_CenterMFD = {
    new : func() {
        var obj = {};
        obj.parents = [master_CenterMFD];
        obj.loopid = 0;
        obj.base = props.globals.getNode(l_base, 1);
        obj.base.initNode("serviceable", 1, "BOOL");
        obj.base.initNode("controls/abs-rudder-pos-norm", 0.0, "DOUBLE");
        obj.base.initNode("controls/rudder-pos-norm", 0.0, "DOUBLE");
        obj.base.initNode("controls/abs-elevator-pos-norm", 0.0, "DOUBLE");
        obj.base.initNode("controls/elevator-pos-norm", 0.0, "DOUBLE");
        obj.reset();
        return obj;
    },
    reset : func {
        me.loopid += 1;
        me._loop_(me.loopid);
    },
    stop : func {
        me.loopid += 1;
    },
    update : func {
        me.base.getNode("controls/rudder-pos-norm").
            setValue(props.globals.getNode(l_rudder).getValue());
        me.base.getNode("controls/abs-rudder-pos-norm").
            setValue(abs(props.globals.getNode(l_rudder).getValue()));
        me.base.getNode("controls/abs-elevator-pos-norm").
            setValue(abs(props.globals.getNode(l_elevator).getValue()));
        me.base.getNode("controls/elevator-pos-norm").
            setValue(props.globals.getNode(l_elevator).getValue());
    },
    _loop_ : func(id) {
        id == me.loopid or return;
        me.update();
        settimer(func { me._loop_(id); }, 0);
    }
};

###########################################################################
var slave_CenterMFD = {
    new : func(airoot) {
        var obj = {};
        obj.parents = [slave_CenterMFD];
        obj.loopid = 0;
        obj.root = airoot;
        obj.base = props.globals.getNode(l_base, 1);
        obj.base.initNode("serviceable", 1, "BOOL");
        obj.base.initNode("controls/abs-rudder-pos-norm", 0.0, "DOUBLE");
        obj.base.initNode("controls/rudder-pos-norm", 0.0, "DOUBLE");
        obj.base.initNode("controls/abs-elevator-pos-norm", 0.0, "DOUBLE");
        obj.base.initNode("controls/elevator-pos-norm", 0.0, "DOUBLE");
        obj.reset();
        return obj;
    },
    reset : func {
        me.loopid += 1;
        me._loop_(me.loopid);
    },
    stop : func {
        me.loopid += 1;
    },
    update : func {
        me.base.getNode("controls/rudder-pos-norm").
            setValue(me.root.getNode(l_rudder).getValue());
        me.base.getNode("controls/abs-rudder-pos-norm").
            setValue(abs(me.root.getNode(l_rudder).getValue()));
        me.base.getNode("controls/abs-elevator-pos-norm").
            setValue(abs(me.root.getNode(l_elevator).getValue()));
        me.base.getNode("controls/elevator-pos-norm").
            setValue(me.root.getNode(l_elevator).getValue());
    },
    _loop_ : func(id) {
        id == me.loopid or return;
        me.update();
        settimer(func { me._loop_(id); }, 0);
    }
};

###########################################################################
#  The Center MFD pick animations default to master.
#  NOTE: Use make_master() and make_slave_to().
#        Do NOT change centerMFD directly.
var centerMFD = master_CenterMFD.new();


###########################################################################
# Create aliases to drive a Center MFD 3d model in an AI/MP model. 
var animate_aimodel = func(airoot) {
    # Connect local nodes to aliases for the 3d model.
    foreach (var p;
             [l_base ~ "/serviceable"] ~
             l_manifold_pressure ~ l_EGT ~ l_CHT ~ l_oil_temperature ~
             l_oil_pressure ~ l_fuel_quantity ~ l_fuel_flow ~
             l_propeller_pitch ~ l_surfaces) {
        airoot.getNode(p, 1).alias(props.globals.getNode(p, 1));
    }
    # Connect pilot AI nodes to local aliases.

    # Set the pick animations in slave mode.
    centerMFD.stop();
    centerMFD = slave_CenterMFD.new(airoot);
}


###########################################################################
# Create a TDMEncoder node array for sending the current Center MFD state to
# slaves.  
var master_send_state = func() {
    return
        [
         # 1 - 3 Manifold pressure
         props.globals.getNode(l_manifold_pressure[0]),
         props.globals.getNode(l_manifold_pressure[1]),
         props.globals.getNode(l_manifold_pressure[2]),
         # 4 - 6 EGT
         props.globals.getNode(l_EGT[0]),
         props.globals.getNode(l_EGT[1]),
         props.globals.getNode(l_EGT[2]),
         # 7 - 9 CHT
         props.globals.getNode(l_CHT[0]),
         props.globals.getNode(l_CHT[1]),
         props.globals.getNode(l_CHT[2]),
         # 10 - 12 Oil temperature
         props.globals.getNode(l_oil_temperature[0]),
         props.globals.getNode(l_oil_temperature[1]),
         props.globals.getNode(l_oil_temperature[2]),
         # 13 - 15 Oil pressure
         props.globals.getNode(l_oil_pressure[0]),
         props.globals.getNode(l_oil_pressure[1]),
         props.globals.getNode(l_oil_pressure[2]),
         # 16 - 18 Fuel quantity
         props.globals.getNode(l_fuel_quantity[0]),
         props.globals.getNode(l_fuel_quantity[1]),
         props.globals.getNode(l_fuel_quantity[2]),
         # 19 - 21 Fuel flow
         props.globals.getNode(l_fuel_flow[0]),
         props.globals.getNode(l_fuel_flow[1]),
         props.globals.getNode(l_fuel_flow[2]),
        ];
}



###########################################################################
# Create a TDMDecoder action array for processing the Center MFD state
# from the master.
var slave_receive_master_state = func() {
    return
        [
         # 1 - 3 Manifold pressure
         func (v) {
             props.globals.getNode(l_manifold_pressure[0]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_manifold_pressure[1]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_manifold_pressure[2]).setValue(v);
         },
         # 4 - 6 EGT
         func (v) {
             props.globals.getNode(l_EGT[0]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_EGT[1]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_EGT[2]).setValue(v);
         },
         # 7 - 9 CHT
         func (v) {
             props.globals.getNode(l_CHT[0]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_CHT[1]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_CHT[2]).setValue(v);
         },
         # 10 - 12 Oil temperature
         func (v) {
             props.globals.getNode(l_oil_temperature[0]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_oil_temperature[1]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_oil_temperature[2]).setValue(v);
         },
         # 13 - 15 Oil pressure
         func (v) {
             props.globals.getNode(l_oil_pressure[0]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_oil_pressure[1]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_oil_pressure[2]).setValue(v);
         },
         # 16 - 18 Fuel quantity
         func (v) {
             props.globals.getNode(l_fuel_quantity[0]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_fuel_quantity[1]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_fuel_quantity[2]).setValue(v);
         },
         # 19 - 21 Fuel flow
         func (v) {
             props.globals.getNode(l_fuel_flow[0]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_fuel_flow[1]).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_fuel_flow[2]).setValue(v);
         }
        ];
}
