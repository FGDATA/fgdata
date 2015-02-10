#############################################################################
# This file is part of FlightGear, the free flight simulator
# http://www.flightgear.org/
#
# Copyright (C) 2009 Torsten Dreyer, Torsten (at) t3r _dot_ de
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#############################################################################

if( getprop("/sim/presets/onground") == 0 ) {
  print("starting in air");
  setprop("/sim/presets/running",1);
  setprop("/consumables/fuel/tank[2]/level-m3", getprop("/consumables/fuel/tank[2]/capacity-m3"));
  setprop("/consumables/fuel/tank[3]/level-m3", getprop("/consumables/fuel/tank[3]/capacity-m3"));
  setprop("/controls/engines/engine[0]/magneto[0]", 1 );
  setprop("/controls/engines/engine[0]/magneto[1]", 1 );
  setprop("/controls/engines/engine[1]/magneto[0]", 1 );
  setprop("/controls/engines/engine[1]/magneto[1]", 1 );
  setprop("/controls/engines/engine[0]/magnetos", 3 );
  setprop("/controls/engines/engine[1]/magnetos", 3 );
  setprop("/controls/engines/engine[0]/throttle", 0.75 );
  setprop("/controls/engines/engine[1]/throttle", 0.75 );
  setprop("/controls/engines/engine[0]/propeller-pitch", 0.9 );
  setprop("/controls/engines/engine[1]/propeller-pitch", 0.9 );
  setprop("controls/fuel/tank[0]/fuel_selector-position", 1 );
  setprop("controls/fuel/tank[1]/fuel_selector-position", 1 );

  setprop("/controls/gear/brake-parking", 0 );
  setprop("/controls/gear/gear-down", 0 );
}

var updateClients = [];
var timeNode = props.globals.getNode( "/sim/time/elapsed-sec", 1 );
var lastRun = timeNode.getValue();
var timedUpdate = func {
  var dt = timeNode.getValue() - lastRun;
  foreach( var n; updateClients ) {
    n.update( dt );
  }
  settimer( timedUpdate, 0 );
};

var seneca_init = func {

  props.globals.initNode( "autopilot/CENTURYIII/controls/mode", 2, "INT" );
  props.globals.initNode( "autopilot/CENTURYIII/controls/manual-trim", 0, "INT" );
  props.globals.initNode( "autopilot/CENTURYIII/controls/disconnect", 0, "BOOL" );

  ki266.new(0);

  updateClients = [];
  foreach( var n; props.globals.getNode("/systems/fuel").getChildren( "fuel-pump" ) ) {
      append( updateClients, FuelPump.new( n ) );
  }

  SetFuelSelector( 0 );
  SetFuelSelector( 1 );

  timedUpdate();

  if( getprop("/sim/presets/onground") == 0 ) {
    ## Fly on A/P after 3 seconds
    settimer( func {
      setprop("/autopilot/CENTURYIII/controls/roll/button-state", 1 );
      setprop("/autopilot/CENTURYIII/controls/pitch/button-state", 1 );
      setprop("/autopilot/CENTURYIII/controls/alt/button-state", 1 );
    }, 3 );
  }
};

setlistener("/sim/signals/fdm-initialized", seneca_init );

var beacon = aircraft.light.new( "/sim/model/lights/beacon", [0.05, 0.05, 0.05, 0.45 ], "/controls/lighting/beacon" );
var strobe = aircraft.light.new( "/sim/model/lights/strobe", [0.05, 0.05, 0.05, 0.05, 0.05, 0.35 ], "/controls/lighting/strobe" );

setprop( "/instrumentation/nav[0]/ident", 0 );
setprop( "/instrumentation/nav[1]/ident", 0 );

########################################
# Sync the magneto switches with magneto properties
########################################
var setmagneto = func(eng,mag) {
  var on = props.globals.getNode( "/controls/engines/engine[" ~ eng ~ "]/magneto[" ~ mag ~ "]" ).getValue();
  var m = props.globals.getNode( "/controls/engines/engine[" ~ eng ~ "]/magnetos" );

  var v = m.getValue();

  # I wish nasal had binary operators...
  if( on ) {
    if( mag == 0 ) {
      if( v == 0 or v == 2 ) {
        v = v + 1;
      }
    }
    if( mag == 1 ) {
      if( v == 0 or v == 1 ) {
        v = v + 2;
      }
    }
  } else {
    if( mag == 0 ) {
      if( v == 1 or v == 3 ) {
        v = v - 1;
      }
    }
    if( mag == 1 ) {
      if( v ==2 or v == 3 ) {
        v = v - 2;
      }
    }
  }

  m.setIntValue( v );
}

var magnetolistener = func(m) {

  var eng = m.getParent();
  var m2 = eng.getChildren("magneto");
  var v = m.getValue();
  if( v == 0 ) {
    m2[0].setBoolValue( 0 );
    m2[1].setBoolValue( 0 );
  }
  if( v == 1 ) {
    m2[0].setBoolValue( 1 );
    m2[1].setBoolValue( 0);
  }
  if( v == 2 ) {
    m2[0].setBoolValue( 0 );
    m2[1].setBoolValue( 1 );
  }
  if( v == 3 ) {
    m2[0].setBoolValue( 1 );
    m2[1].setBoolValue( 1 );
  }
};

var magnetoswitchlistener = func(m) {
  setmagneto( m.getParent().getIndex(), m.getIndex() );
};

setlistener( "/controls/engines/engine[0]/magnetos", magnetolistener );
setlistener( "/controls/engines/engine[1]/magnetos", magnetolistener );
setlistener( "/controls/engines/engine[0]/magneto[0]", magnetoswitchlistener, 1, 0 );
setlistener( "/controls/engines/engine[0]/magneto[1]", magnetoswitchlistener, 1, 0 );
setlistener( "/controls/engines/engine[1]/magneto[0]", magnetoswitchlistener, 1, 0 );
setlistener( "/controls/engines/engine[1]/magneto[1]", magnetoswitchlistener, 1, 0 );

########################################
# Sync the dimmer controls with the according properties
########################################

var instrumentsFactorNode = props.globals.initNode( "/sim/model/material/instruments/factor", 1.0 );
var dimmerlistener = func(n) {
  if( n != nil )
    instrumentsFactorNode.setValue( n.getValue() );
}

setlistener( "/controls/lighting/instruments-norm", dimmerlistener, 1, 0 );

####################################################################

var SetFuelSelector = func( side ) {
  var pos = getprop("controls/fuel/tank[" ~ side ~ "]/fuel_selector-position"); 
  var n = getprop( "/systems/fuel/fuel-pump[" ~ side ~ "]/source-tank" );
  if( side == 0 ) {
    if( pos == 1 )  n = 0;
    else if( pos == -1 ) n = 1;
    else n = -1;
  } else if( side == 1 ) {
    if( pos == 1 )  n = 1;
    else if( pos == -1 ) n = 0;
    else n = -1;
  }
  setprop( "/systems/fuel/fuel-pump[" ~ side ~ "]/source-tank", n );
}

var FuelTank = {};

FuelTank.new = func(nr) {
  var obj = {};
  obj.parents = [FuelTank];
  obj.baseN = props.globals.getNode( "/consumables/fuel/tank[" ~ nr ~ "]", 1 );
  obj.emptyN = obj.baseN.initNode("empty", 0, "BOOL" );
  obj.capacityN = obj.baseN.initNode("capacity-gal_us", 0.0 );
  obj.contentN = obj.baseN.initNode("level-gal_us", 0.0 );

  return obj;
};

FuelTank.empty = func() {
  return me.emptyN.getValue() == 1;
};

FuelTank.level = func( level = nil ) {
  if( level != nil )
    me.contentN.setValue( level );
  return me.contentN.getValue();
};

FuelTank.capacity = func() {
  return me.capacityN.getValue();
};

var FuelPump = {};

FuelPump.new = func(base) {
  var obj = {};
  obj.parents = [FuelPump];
  obj.baseNode = base;

  var n = base.getNode( "enable-prop" );
  if( n != nil ) {
    obj.enableNode = props.globals.initNode( n.getValue(), 0, "BOOL" );
  } else {
    obj.enableNode = base.initNode( "enabled", 0, "BOOL" );
  }
  obj.serviceableNode = base.initNode( "serviceable", 1, "BOOL" );
  obj.sourceTankNode = base.initNode( "source-tank", -1, "INT" );

  obj.tanks = [];
  append( obj.tanks, FuelTank.new( 0 ) );
  append( obj.tanks, FuelTank.new( 1 ) );
  obj.destinationTank = FuelTank.new( base.getNode("destination-tank").getValue() );
  obj.fuel_flow_gphNode = base.getNode( "fuel-flow-gph", 1 );
  return obj;
};

FuelPump.update = func(dt) {
  #if its of, go away
  !me.enableNode.getValue() and return;
  #if its broken, go away
  !me.serviceableNode.getValue() and return;

  var sourceTank = me.sourceTankNode.getValue();
  if(sourceTank == nil or sourceTank < 0 or sourceTank >= size(me.tanks) ) return

  #if  source is empty, go away
  me.tanks[sourceTank].empty() and return;

  # compute fuel flow
  var flow_gph = me.fuel_flow_gphNode.getValue();

  # no flow - nothing to compute
  if( flow_gph == nil or flow_gph <= 0 ) return;

  var transfer_fuel = flow_gph * dt / 3600;

  #consume fuel, up to the available source-level 
  #and destination-space
  var source_level = me.tanks[sourceTank].level();
  if( transfer_fuel > source_level )
    transfer_fuel = source_level;

  var destination_space = me.destinationTank.capacity() - me.destinationTank.level();

  if( transfer_fuel > destination_space )
    transfer_fuel = destination_space;

  me.tanks[sourceTank].level( source_level - transfer_fuel );
  me.destinationTank.level( me.destinationTank.level() + transfer_fuel );
}

###############################################
# propagate the emergency gear extension switch 
# to the fcs of jsbsim
###############################################
var emergencyGearNode = props.globals.initNode( "controls/gear/gear-emergency-extend", 0, "BOOL" );
var normalGearNode = props.globals.initNode( "controls/gear/gear-down", 0, "BOOL" );
var fcsGearNode = props.globals.getNode( "fdm/jsbsim/gear/gear-cmd-emergency-norm", 1 );

# emergency extend at any time
setlistener( emergencyGearNode, func {
  if( emergencyGearNode.getValue() == 1 ) {
    fcsGearNode.setBoolValue( 1 );
  }
});

# remove emergency extend only if gear is down
setlistener( normalGearNode, func {
  if( normalGearNode.getValue() == 1 and emergencyGearNode.getValue() == 0 ) {
    fcsGearNode.setBoolValue( 0 );
  }
});

# reset compass rose rotation for the ki228
setlistener( "/instrumentation/adf[0]/model", func(n) {
  if( n != nil ) {
    var v = n.getValue();
    if( v != nil and v == "ki228" )
      setprop("instrumentation/adf[0]/rotation-deg", 0 );
  }
}, 1, 0 );

var DMESources = {
  1 : "/instrumentation/nav[0]/frequencies/selected-mhz",
  2 : "/instrumentation/dme/frequencies/selected-mhz",
  3 : "/instrumentation/nav[1]/frequencies/selected-mhz"
};

setlistener( "/instrumentation/dme/switch-position", func(n) {
  var v = n.getValue();
  v == nil and return;
  n.getParent().getNode( "frequencies/source", 1 ).setValue(DMESources[v]);
}, 1, 0 );

var MouseHandler = {
  new : func() {
    var obj = { parents : [ MouseHandler ] };

    obj.property = nil;
    obj.factor = 1.0;

    obj.YListenerId = setlistener( "devices/status/mice/mouse/accel-y", 
      func(n) { obj.YListener(n); }, 1, 0 );

    return obj;
  },

  YListener : func(n) {
    me.property == nil and return;
    me.factor == 0 and return;
    n == nil and return;
    var v = n.getValue();
    v == nil and return;
    fgcommand("property-adjust", props.Node.new({ 
      "offset" : v,
      "factor" : me.factor,
      "property" : me.property
    }));
  },

  set : func( property = nil, factor = 1.0 ) {
    me.property = property;
    me.factor = factor;
  },

};

var mouseHandler = MouseHandler.new();
