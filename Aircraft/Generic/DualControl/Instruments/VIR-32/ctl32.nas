###############################################################################
##
## Nasal for dual control of a VIR 32 Nav radio over the multiplayer
## network.
##
##  Copyright (C) 2008 - 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#  This module MUST be loaded as VIR32.
#

# Slave button presses.
var swap_btn    = "frq-swap-btn";
var freq_decS   = "freq-decS-clicked";
var freq_incS   = "freq-incS-clicked";
var freq_decL   = "freq-decL-clicked";
var freq_incL   = "freq-incL-clicked";

# Settings
var freq_selected = "frequencies/selected-mhz";
var freq_standby  = "frequencies/standby-mhz";

var nav_base = ["instrumentation/nav[0]",
                "instrumentation/nav[1]"];

###########################################################################
var master_ctl32 = {
  new : func(n) {
    var obj = {};
    obj.parents = [master_ctl32];
    obj.nav_base = props.globals.getNode(nav_base[n]);
    return obj;
  },
  swap : func() {
    var tmp = me.nav_base.getNode(freq_selected).getValue();
    me.nav_base.getNode(freq_selected).setValue
      (me.nav_base.getNode(freq_standby).getValue());
    me.nav_base.getNode(freq_standby).setValue(tmp);
  },
  adjust_frequency : func(d) {
    adjust_radio_frequency(
      me.nav_base.getNode(freq_standby),
      d,
      108,
      117.975);
  }
};

###########################################################################
var slave_ctl32 = {
  new : func(n, airoot) {
    var obj = {};
    obj.parents = [slave_ctl32];
    obj.root = airoot;
    obj.nav_base = props.globals.getNode(nav_base[n]);
    return obj;
  },
  swap : func() {
    var p = me.nav_base.getNode(swap_btn);
    print("VIR32[?].SWAP");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  adjust_frequency : func(d) {
    var p = 0;
    if (abs(d) < 0.99) {
      p = (d < 0) ? me.nav_base.getNode(freq_decS)
                  : me.nav_base.getNode(freq_incS);
    } else {
      p = (d < 0) ? me.nav_base.getNode(freq_decL)
                  : me.nav_base.getNode(freq_incL);
    }
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  }
};

###########################################################################
#  The VIR-32 pick animations default to master.
#  NOTE: Use make_master() and make_slave_to().
#        Do NOT change ctl32 directly.
var ctl32 = [master_ctl32.new(0), master_ctl32.new(1)];


###########################################################################
# API for pick animations and dual control setup.
###########################################################################

###########################################################################
# n - Nav#
var make_master = func(n) {
  ctl32[n] = master_ctl32.new(n);
}

###########################################################################
# n - Nav#
var make_slave_to = func(n, airoot) {
  ctl32[n] = slave_ctl32.new(n, airoot);
}

###########################################################################
# n - Nav#
var swap = func(n) {
  ctl32[n].swap();
}

###########################################################################
# n - Nav#
# d - adjustment
var adjust_frequency = func(n, d) {
  ctl32[n].adjust_frequency(d);
}

###########################################################################
# Create aliases to drive a radio 3d model in an AI/MP model.
# n - Nav#
var animate_aimodel = func(n, airoot) {
  var p = "systems/electrical/outputs/nav["~ n ~"]";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = "instrumentation/nav["~ n ~"]/serviceable";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = nav_base[n] ~ "/" ~ freq_selected;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = nav_base[n] ~ "/" ~ freq_standby;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
}

###########################################################################
# Create a TDMEncoder node array for sending the current radio state to
# slaves.  
# n - Nav#
var master_send_state = func(n) {
  var b = props.globals.getNode(nav_base[n]);
  return
    [
     b.getNode(freq_selected),
     b.getNode(freq_standby)
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
         if (b) { swap(n); }
     },
     func (b) {
         if (b) { adjust_frequency(n, -0.05); }
     },
     func (b) {
         if (b) { adjust_frequency(n, 0.05); }
     },
     func (b) {
         if (b) { adjust_frequency(n, -1.0); }
     },
     func (b) {
         if (b) { adjust_frequency(n, 1.0); }
     }
    ];
}

###########################################################################
# Create a TDMDecoder action array for processing the radio state
# from the master.
# n - Nav#
var slave_receive_master_state = func(n) {
  var b = props.globals.getNode(nav_base[n]);
  return
    [
     func (v) {
         b.getNode(freq_selected).setValue(v);
     },
     func (v) {
         b.getNode(freq_standby).setValue(v);
     }
    ];
}

###########################################################################
# Create a SwitchEncoder node array for sending button presses
# to the master
# n - Nav#
var slave_send_buttons = func(n) {
  var b = props.globals.getNode(nav_base[n]);
  return
    [
     b.getNode(swap_btn, 1),
     b.getNode(freq_decS, 1),
     b.getNode(freq_incS, 1),
     b.getNode(freq_decL, 1),
     b.getNode(freq_incL, 1),
    ];
}



###########################################################################
# Generic frequency stepper.
#  f   - frequency property
#  d   - change
#  min - min frequency
#  max - max frequency
var adjust_radio_frequency = func(f, d, min, max) {
  var old = f.getValue();
  var new = old + d;
  if (new < min - 0.005) { new = int(max) + (new - int(new)); }
  if (new > max + 0.005) {
      new = int(min) + (new - int(new));
      if (int(new + 0.005) > min) new -= 1;
  }
#  print("Old: " ~ old ~ "  Intermediate: " ~ (old + d) ~ "  New: " ~ new);
  f.setValue(new);
}
