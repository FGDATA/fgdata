###############################################################################
##
## Nasal for dual control of a KI-206 VOR indicator over the multiplayer
## network.
##
##  Copyright (C) 2007 - 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#   This module MUST be loaded as KI206.

# Slave button presses.
var radial_decS   = "radial-decS-clicked";
var radial_incS   = "radial-incS-clicked";
# Only one step size implemented.

var selected_radial = "radials/selected-deg";
var base = ["instrumentation/nav[0]",
            "instrumentation/nav[1]"];

###########################################################################
var master_ki206 = {
  new : func(n) {
    var obj = {};
    obj.parents = [master_ki206];
    obj.base = props.globals.getNode(base[n]);
    return obj;
  },  
  adjust_radial : func(d) {
    p = me.base.getNode(selected_radial);
    var v = p.getValue() + d;
    if (v < 0)   { v += 360; };
    if (v > 360) { v -= 360; };
    p.setValue(v);
  }
};

###########################################################################
var slave_ki206 = {
  new : func(n, airoot) {
    var obj = {};
    obj.parents = [slave_ki206];
    obj.root = airoot;
    obj.base = props.globals.getNode(base[n]);
    return obj;
  },
  adjust_radial : func(d) {
    var p = 0;
    if (abs(d) < 0.99) {
      p = (d < 0) ? me.base.getNode(radial_decS)
                  : me.base.getNode(radial_incS);
    } else {
      p = (d < 0) ? me.base.getNode(radial_decS)
                  : me.base.getNode(radial_incS);
    }
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  }
};

###########################################################################
# The KI-206 pick animations default to master.
# NOTE: Use make_master() and make_slave_to(). Do NOT change ki206 directly. 
var ki206 = [master_ki206.new(0), master_ki206.new(1)];

###########################################################################
# API for pick animations and dual control setup.
###########################################################################

###########################################################################
# n - Nav#
var make_master = func(n) {
  ki206[n] = master_ki206.new(n);
}

###########################################################################
# n - Nav#
var make_slave_to = func(n, airoot) {
  ki206[n] = KI206.slave_ki206.new(n, airoot);
}

###########################################################################
# n - Nav#
# d - adjustment delta
var adjust_radial = func(n, d) {
  ki206[n].adjust_radial(d);
}

###########################################################################
# Create aliases to drive the KI 206 3d model in an AI/MP model. 
# n - Nav#
var animate_aimodel = func(n, airoot) {
  var p = base[n] ~ "/data-is-valid";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/in-range";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/has-gs";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/to-flag";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/from-flag";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/" ~ selected_radial;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/heading-needle-deflection";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/gs-needle-deflection";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
}

###########################################################################
# Create a TDMEncoder node array for sending the current radio state to
# slaves.  
# n - Nav#
var master_send_state = func(n) {
  return
    [
     props.globals.getNode(base[n] ~ "/" ~ selected_radial)
    ];
}

###########################################################################
# Create a SwitchDecoder action array for processing button presses
# from a slave.  
# n - Nav#
var master_receive_slave_buttons = func(n) {
  return
    [
     func (b) {
         if (b) { KI206.adjust_radial(n, -1.0); }
     },
     func (b) {
         if (b) { KI206.adjust_radial(n, 1.0); }
     }
    ];
}

###########################################################################
# Create a TDMDecoder action array for processing the radio state
# from the master.
# n - Nav#
var slave_receive_master_state = func(n) {
  return
    [
     func (v) {
         props.globals.getNode(base[n] ~ "/" ~ selected_radial).setValue(v);
     }
    ];
}

###########################################################################
# Create a SwitchEncoder node array for sending button presses
# to the master
# n - Nav#
var slave_send_buttons = func(n) {
  return
    [
     props.globals.getNode(base[n] ~ "/" ~ radial_decS, 1),
     props.globals.getNode(base[n] ~ "/" ~ radial_incS, 1),
    ];
}
