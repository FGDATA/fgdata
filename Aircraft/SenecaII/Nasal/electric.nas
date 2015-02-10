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

var BaseElement = {};

BaseElement.new = func(n) {
  var obj = {};
  obj.parents = [BaseElement];
  obj.node = n;
  return obj;
}

BaseElement.baseElementUpdate = func {
}

BaseElement.update = func(dt) {
  me.baseElementUpdate(dt);
}

BaseElement.insert = func(vector, object, position = 0) {
  setsize( vector, size(vector) + 1 );
  for( var i = size(vector)-1; i > position; i = i - 1 ) {
    vector[i] = vector[i-1];
  }
  vector[position] = object;
}

BaseElement.interpolate = func( x, pairs ) {
  n = size(pairs)-1;
  if( x <= pairs[0][0] ) {
    return pairs[0][1];
  }
  if( x >= pairs[n][0] ) {
    return pairs[n][1];
  }
  for( var i = 0; i < n; i = i + 1 ) {
    if( x > pairs[i][0] and x <= pairs[i+1][0] ) {
      var x1 = pairs[i][0];
      var x2 = pairs[i+1][0];
      var y1 = pairs[i][1];
      var y2 = pairs[i+1][1];
      return (x - x1)/(x2-x1)*(y2-y1)+y1;
    }
  }
  return pairs[i][1];
}

BaseElement.getLowPass = func(current, target, timeratio) {
  if ( timeratio < 0.0 ) {
    if ( timeratio < -1.0 ) {
      #time went backwards; kill the filter
      current = target;
    } else {
      # ignore mildly negative time
    }
    return current;
  } 
  if ( timeratio < 0.2 ) {
    # Normal mode of operation; fast
    #  approximation to exp(-timeratio)
    current = current * (1.0 - timeratio) + target * timeratio;
    return current;
  } 

  if ( timeratio > 5.0 ) {
    # Huge time step; assume filter has settled
    current = target;
  } else {
    # Moderate time step; non linear response
    var keep = math.exp(-timeratio);
    current = current * keep + target * (1.0 - keep);
  }
  return current;
}


#############################################################################
# a simple linear element, resistors, lights, batteries, generators etc.
#############################################################################
LinearElement = {};

# create a new linear element
# args: node ri [u0]
LinearElement.new = func(n, ri, u0 = 0) {
  var obj = BaseElement.new(n);
  obj.insert( obj.parents, LinearElement );
  obj.ri = ri;
  obj.u0 = u0;
  # the current, that runs into our ri
  # so a load (drain) has a positive sign here and
  # a generator/battery (source) has a negative sign
  obj.i  = 0;

  obj.riNode = obj.node.initNode("ri", 0.0 );
  obj.u0Node = obj.node.initNode("u0", 0.0 );
  var s = obj.node.getNode( "i-property" );
  if( s != nil ) {
    obj.iNode  = props.globals.initNode(s.getValue(), 0 );
  } else {
    obj.iNode  = obj.node.initNode("i", 0.0 );
  }

  return obj;
}

LinearElement.linearElementUpdate = func {
  me.baseElementUpdate();
  var u = me.node.getParent().getNode("u-volts").getValue();
  if( me.isConnected() ) {
    me.i = (u - me.u0) / me.ri;
  } else {
    me.i = 0;
  }
  me.riNode.setDoubleValue( me.ri );
  me.u0Node.setDoubleValue( me.u0 );
  me.iNode.setDoubleValue( me.i );
}

LinearElement.update = func(dt) {
  me.linearElementUpdate(dt);
}

LinearElement.isConnected = func {
  return 1;
}

#############################################################################
# a simple load element 
#############################################################################
LoadElement = {};

LoadElement.new = func(n) {
  var p = n.getNode("load-watts").getValue();
  var u = n.getParent().getNode("volts").getValue();
  var r = 1e99;
  if( p != 0 ) {
    r = u * u / p;
  }

  var obj = {};
  obj = LinearElement.new( n, r );
  obj.insert( obj.parents, LoadElement );

  var s = n.getNode("switch-property").getValue();
  obj.switchProperty = props.globals.initNode( s, 0, "BOOL" );

  return obj;
}

LoadElement.isConnected = func {
  return me.switchProperty.getValue();
}

#############################################################################
# a simple generator element 
#############################################################################
GeneratorElement = {};

GeneratorElement.new = func(node) {
  var obj = {};
  obj = LinearElement.new( node, 1, 0 );
  obj.insert( obj.parents, GeneratorElement );

  var s = node.getNode("switch-property").getValue();
  obj.switchProperty = props.globals.getNode( s );

  s = node.getNode( "rpm-source" ).getValue();
  obj.rpmNode = props.globals.getNode( s, 1 );
  obj.maxVoltsNode = node.getNode( "max-volts" );
  obj.minVoltsNode = node.getNode( "min-volts" );
  obj.maxAmpsNode  = node.getNode( "max-amps" );
  obj.maxRPMNode   = node.getNode( "max-rpm" );
  obj.minRPMNode   = node.getNode( "min-rpm" );

  obj.lastupdate = 0;

  return obj;
}

GeneratorElement.generatorElementUpdate = func {
  me.linearElementUpdate();

  # if disconnected, it's just a high-ohm load
  if( !me.isConnected() ) {
    me.u0 = 0.0;
    me.ri = 1e6;
    return;
  }

  # if we where just connected, start with a low ri
  if( me.u0 == 0.0 ) {
    me.ri = 10;
  }

  var rpm = me.rpmNode.getValue();
  if( rpm == nil ) {
    rpm = 0;
  }
  var minRPM = me.minRPMNode.getValue();
  var maxRPM = me.maxRPMNode.getValue();
  var minVolts = me.minVoltsNode.getValue();
  var maxVolts = me.maxVoltsNode.getValue();

  #if the output is above regulator voltage, switch generator off
  var u = me.node.getParent().getNode("u-volts").getValue();


  if( rpm < minRPM ) {
    me.u0 = 0.0;
    me.ri = 10;
  } else {

    me.u0 = rpm/minRPM * minVolts;
    if( me.i > (u-maxVolts)/(me.ri+0.5) ) {
      var dri = (u-maxVolts) / me.i;
      me.ri = me.ri - dri;
    } else {
        me.ri = 0.5;
    }
  }
#print("RPM=", rpm, ", U=", u, , ", U0=", me.u0, ", RI=", me.ri );
}

GeneratorElement.update = func(dt) {
  me.generatorElementUpdate(dt);
}

GeneratorElement.isConnected = func {
  return me.switchProperty.getValue();
}

#############################################################################
# a simple battery element 
#############################################################################
BatteryElement = {};

BatteryElement.new = func(node) {

  var u = node.getParent().getNode("volts").getValue();
  var c  = node.getNode("capacity-ah").getValue();

  var obj = {};
  obj = LinearElement.new( node, 0.03 / c, u );
  obj.insert( obj.parents, BatteryElement );

  obj.charge_curve = [[0.0,0.0],[0.2,0.8],[0.9,1.1],[1.4,1.35]];

  obj.capacityNode = obj.node.getNode("capacity-ah","true");
  obj.capacityNormNode = obj.node.getNode("capacity-norm", "true" );
  obj.voltsNormNode = obj.node.getNode("volts-norm", "true" );

  obj.capacityNormNode.setDoubleValue( 1.0 );
  obj.voltsNormNode.setDoubleValue( 1.0 );


  obj.ri_factor = 0.03;
  obj.design_volts = u;
  obj.design_capacity = c;
  obj.lastupdate = 0;

  return obj;
}

BatteryElement.batteryElementUpdate = func(dt) {
  me.linearElementUpdate();

  # i is negative for discharging
  var factor = 1.0;
  if( me.i > 0 ) {
    factor = 0.8;
  }
  var usedAh = me.i * factor * dt / 3600.0;

  var c = me.design_capacity * me.capacityNormNode.getValue() + usedAh;

  if( c < 0 ) {
    c = 0;
  }

  var capacity_norm = c / me.design_capacity;
  me.capacityNormNode.setDoubleValue( capacity_norm );

  var volts_norm = me.interpolate( capacity_norm, me.charge_curve );
  me.voltsNormNode.setDoubleValue( volts_norm );
  me.u0 = me.design_volts * volts_norm;

  if( c > me.ri_factor/100 ) {
    me.ri = me.ri_factor / c;
  } else {
    me.ri = 100;
  }
}

BatteryElement.update = func(dt) {
  me.batteryElementUpdate(dt);
}

#############################################################################
# a Bus
#############################################################################
Bus = {};

Bus.new = func(n,idx) {
  var obj = BaseElement.new( n );
  obj.insert( obj.parents, Bus );

  obj.idx = idx;

  obj.elements = [];
  
  obj.load = 0; # the total load of the bus in Siemens
  obj.u = 0;    # the computed voltage on the bus
  obj.i  = 0;   # the computed load of the bus in Ampere

  obj.loadNode = obj.node.getNode( "load-siemens", "true" );
  obj.uNode = obj.node.getNode( "u-volts", "true" );
  obj.iNode = obj.node.getNode( "i-ampere", "true" );

  var elementNodes = obj.node.getChildren( "element" );
  foreach( var elementNode; elementNodes ) {
    var element = obj.createElement(elementNode);
    if( element != nil )
      append( obj.elements, element );
  }
  return obj;
}

Bus.createElement= func(n) {
  var node = n;

  var type = node.getNode("type",1).getValue();

  if( type == "battery" ) {
    return BatteryElement.new( node );
  } 

  if( type == "generator" ) {
    return GeneratorElement.new( node );
  } 


  if( type == "load" ) {
    return LoadElement.new( node );
  } 

  print("unknown element type ", type == nil ? "<nil>" : type );
  return nil;
}

Bus.busUpdate = func(dt) {
  me.baseElementUpdate();

  me.load = 0.0;
  var itot    = 0.0;
  var gitot   = 0.0;
  foreach( element; me.elements ) {
    if( element.isConnected() == 1 ) {
      # a source
      var itot = itot + element.u0 / element.ri;
      var gitot = gitot + 1 / element.ri;

      if( element.u0 == 0 ) {
        # passive load
        me.load = me.load + 1/element.ri;
      }
    }
  }
  me.loadNode.setDoubleValue( me.load );

  if( gitot != 0 ) { # check for empty bus
    me.u = itot / gitot;
  } else {
    me.u = 0;
  }

  me.i = me.u * me.load;

  me.uNode.setDoubleValue( me.u );
  me.iNode.setDoubleValue( me.i );

  foreach( element; me.elements ) {
    element.update(dt);
  }
}

Bus.update = func(dt) {
  me.busUpdate(dt);
}

#############################################################################
# the electrical system
#############################################################################
ElectricSystem = {};

ElectricSystem.new = func(n) {
  var obj = {};
  obj.parents = [ElectricSystem];

  obj.bus = [];

  obj.electricSystemNode = props.globals.getNode( n );

  var busNodes = obj.electricSystemNode.getChildren( "bus" );
  for( var i = 0; i < size(busNodes); i = i + 1 ) {
    append( obj.bus, Bus.new( busNodes[i], i ));
  }

  return obj;
}

ElectricSystem.update = func(dt) {
  foreach( bus; me.bus ) {
    bus.update(dt);
  }
}

#############################################################################
#

var electricSystem = ElectricSystem.new("/systems/electrical");
var elapsedTimeNode = props.globals.getNode( "/sim/time/elapsed-sec" );

var t_last = 0;
var update_electrical = func {

  var t_now = elapsedTimeNode.getValue();
  var dt = t_now - t_last;
  t_last = t_now;
  
  electricSystem.update(dt);
  settimer( update_electrical, 0.1 );
}

setlistener("/sim/signals/fdm-initialized", update_electrical );

