###############################################################################
##
##  Oxygen system module for FlightGear.
##
##  Copyright (C) 2010  Vivian Meazza  (vivia.meazza(at)lineone.net)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################


# Properties under /consumables/fuel/tank[n]:
# + level_cu_ft     - Current free oxygen content.  Must be set by user code.
# + capacity_cu_ft  - Tank volume 
# + selected        - boolean indicating tank selection.
# + name ...........- string
# + pressure        - OUTPUT ONLY property, do not try to set

# Properties under /controls/oxygen/
# + altitude-norm       - the selected supply altitude normalized 0 - 100% oxygen 
# + flowrate_cu_ft_ps   - Max (100%) Oxygen flow rate

# + flowrate considerations:
#  ref http://en.wikipedia.org/wiki/Human_lung
#
# when maximum (100%) oxygen is selected, we wish to deliver enough oxygen to fill 
# the pilot's lungs, with slight overpressure. 
# 
# let  the tidal flow volume - that is the amount of gas which flows 
# into and out of the lungs on each breath = T ft^3;
# and the number of breaths per minute at rest= N min^-1;
# but we need to consider a pilot under stress factor = 1.5
# 
# so flowrate (ft^3.sec^-1) = (T*1.5*N)/60 
# 
# substituting the values from the reference
# 
# flowrate = 0.01765 * 1.5 * 20 / 60 = 0.008828
# 
# rounding up to provide overpressure 
# 
# flowrate = 0.01 (ft^3.sec^-1)


#========================= Initialize ===============================
var MAXTANKS = 20;
var INHG2PSI = 0.491154077497;

var initialize = func {

    print( "Initializing Oxygen System ..." );

    props.globals.initNode("/systems/oxygen/serviceable", 1, "BOOL");
    props.globals.initNode("/sim/freeze/oxygen", 0, "BOOL");
    props.globals.initNode("/controls/oxygen/altitude-norm", 0.0, "DOUBLE");
    props.globals.initNode("/controls/oxygen/flowrate-cu-ft-ps", 0.01, "DOUBLE");

    for (var i = 0; i < MAXTANKS; i += 1){
        props.globals.initNode("/consumables/oxygen/tank["~ i ~ "]/capacity-cu-ft", 0.01, "DOUBLE");
        props.globals.initNode("/consumables/oxygen/tank["~ i ~ "]/level-cu-ft", 0, "DOUBLE");
        props.globals.initNode("/consumables/oxygen/tank["~ i ~ "]/selected", 0, "BOOL");
        props.globals.initNode("/consumables/oxygen/tank["~ i ~ "]/pressure-psi", 50, "DOUBLE");
    }

    oxygen();

} #end init

#========================= Oxygen System ============================
var oxygen = func {

    var freeze = getprop("/sim/freeze/oxygen");
    var serviceable =getprop("/systems/oxygen/serviceable");

    if(freeze or !serviceable) { return; }

    var dt =  getprop("sim/time/delta-sec");
    var oxygen_alt = getprop("controls/oxygen/altitude-norm");
    var flowrate_cu_ft_ps = getprop("controls/oxygen/flowrate-cu-ft-ps");
    var Pa = getprop("environment/pressure-inhg") * INHG2PSI;

    var flow_cu_ft = flowrate_cu_ft_ps * oxygen_alt * dt;

    var contents = 0;
    var cap = 0;
    var availableTanks = [];
    var selected = 0;
    var pressure = 2000;

# Build a list of available tanks. An available tank is both selected, has 
# oxygen remaining.and pressure < ambient.
    var AllTanks = props.globals.getNode("consumables/oxygen").getChildren("tank");

    foreach( var t; AllTanks) {
        cap = t.getNode("capacity-cu-ft", 1).getValue();
        contents = t.getNode("level-cu-ft", 1).getValue();
        selected = t.getNode("selected", 1).getBoolValue();
        pressure = t.getNode("pressure-psi", 1).getValue();

        if(cap != nil and cap > 0.01 ) {
#            print ("Pressure ", pressure, " " , Pa); 

            if(selected and pressure > Pa) {
                append(availableTanks, t);
            }

        }

    }

#    print("flow_cu_ft ", flow_cu_ft," " ,size(availableTanks));

# Subtract flow_cu_ft from tanks, set auxilliary properties.  Set out-of-gas
# when all tanks are empty.
    var outOfGas = 0;

    if(size(availableTanks) == 0) {
        outOfGas = 1;
    } else {
        flowPerTank = flow_cu_ft / size(availableTanks);
        foreach( var t; availableTanks ) {
            cu_ft = t.getNode("level-cu-ft").getValue();
            cu_ft -= flowPerTank;
            cap = t.getNode("capacity-cu-ft", 1).getValue();

            if(cu_ft < 0) { cu_ft = 0;}

#            print ("pressure ", calcPressure(cu_ft, cap));
            
            t.getNode("level-cu-ft").setDoubleValue(cu_ft);
            t.getNode("pressure-psi").setDoubleValue(calcPressure(cu_ft, cap));
        }
    }

    settimer(oxygen, 0.3);

} #end oxygen

# We apply Boyle's Law to derive the pressure in the tank fom the capacity of the
# tank and the contents. We ignore the effects of temperature.

var calcPressure = func (cu_ft, cap){
    var Vc = cap;
    var Va = cu_ft;
    var Pa = 14.7;

#    print (Vc, " ", Va, " ", Pa);

    Pc = (Pa * Va)/Vc;
    return Pc;
} #end calcPressure

setlistener("sim/signals/fdm-initialized", initialize);

# end 

