###############################################################################
##
## Nasal for dual control of a VHF 22 Comm radio over the multiplayer
## network.
##
##  Copyright (C) 2008 - 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license.
##
###############################################################################

# Note:
#  This module MUST be loaded as VHF22.
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

var comm_base = ["instrumentation/comm[0]",
                 "instrumentation/comm[1]"];

###########################################################################
var master_ctl22 = {
  new : func(n) {
    var obj = {};
    obj.parents = [master_ctl22];
    obj.comm_base = props.globals.getNode(comm_base[n]);
    return obj;
  },
  swap : func() {
    var tmp = me.comm_base.getNode(freq_selected).getValue();
    me.comm_base.getNode(freq_selected).setValue
      (me.comm_base.getNode(freq_standby).getValue());
    me.comm_base.getNode(freq_standby).setValue(tmp);
  },
  adjust_frequency : func(d) {
    adjust_radio_frequency(
      me.comm_base.getNode(freq_standby),
      d,
      118,
      135.975);
  }
};

###########################################################################
var slave_ctl22 = {
  new : func(n, airoot) {
    var obj = {};
    obj.parents = [slave_ctl22];
    obj.root = airoot;
    obj.comm_base = props.globals.getNode(comm_base[n]);
    return obj;
  },
  swap : func() {
    var p = me.comm_base.getNode(swap_btn);
    print("VHF22[?].SWAP");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  adjust_frequency : func(d) {
    var p = 0;
    if (abs(d) < 0.99) {
      p = (d < 0) ? me.comm_base.getNode(freq_decS)
                  : me.comm_base.getNode(freq_incS);
    } else {
      p = (d < 0) ? me.comm_base.getNode(freq_decL)
                  : me.comm_base.getNode(freq_incL);
    }
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  }
};

###########################################################################
#  The VHF-22 pick animations default to master.
#  NOTE: Use make_master() and make_slave_to().
#        Do NOT change ctl22 directly.
var ctl22 = [master_ctl22.new(0), master_ctl22.new(1)];


###########################################################################
# API for pick animations and dual control setup.
###########################################################################

###########################################################################
# n - Comm#
var make_master = func(n) {
  ctl22[n] = master_ctl22.new(n);
}

###########################################################################
# n - Comm#
var make_slave_to = func(n, airoot) {
  ctl22[n] = slave_ctl22.new(n, airoot);
}

###########################################################################
# n - Comm#
var swap = func(n) {
  ctl22[n].swap();
}

###########################################################################
# n - Comm#
# d - adjustment
var adjust_frequency = func(n, d) {
  ctl22[n].adjust_frequency(d);
}

###########################################################################
# Create aliases to drive a radio 3d model in an AI/MP model. 
# n - Comm#
var animate_aimodel = func(n, airoot) {
  var p = "systems/electrical/outputs/comm["~ n ~"]";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = comm_base[n] ~ "/serviceable";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = comm_base[n] ~ "/" ~ freq_selected;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = comm_base[n] ~ "/" ~ freq_standby;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
}

###########################################################################
# Create a TDMEncoder node array for sending the current radio state to
# slaves.  
# n - Comm#
var master_send_state = func(n) {
  var b = props.globals.getNode(comm_base[n]);
  return
    [
     b.getNode(freq_selected),
     b.getNode(freq_standby)
    ];
}

###########################################################################
# Create a SwitchDecoder action array for processing button presses
# from a slave.  
# n - Comm#
var master_receive_slave_buttons = func(n) {
  return
    [
     func (b) {
         if (b) { swap(n); }
     },
     func (b) {
         if (b) { adjust_frequency(n, -0.025); }
     },
     func (b) {
         if (b) { adjust_frequency(n, 0.025); }
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
# n - Comm#
var slave_receive_master_state = func(n) {
  var b = props.globals.getNode(comm_base[n]);
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
# n - Comm#
var slave_send_buttons = func(n) {
  var b = props.globals.getNode(comm_base[n]);
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
