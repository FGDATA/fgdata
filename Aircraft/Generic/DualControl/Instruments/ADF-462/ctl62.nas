###############################################################################
##
## Nasal for dual control of a ADF 462 radio over the multiplayer
## network.
##
##  Copyright (C) 2008 - 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#  This module MUST be loaded as ADF462.
#

# Slave button presses.
var swap_btn    = "frq-swap-btn";
var freq_decS   = "freq-decS-clicked";
var freq_incS   = "freq-incS-clicked";
var freq_decL   = "freq-decL-clicked";
var freq_incL   = "freq-incL-clicked";

# Settings
var freq_selected = "frequencies/selected-khz";
var freq_standby  = "frequencies/standby-khz";

var adf_base = ["instrumentation/adf[0]",
                "instrumentation/adf[1]"];

###########################################################################
var master_ctl62 = {
  new : func(n) {
    var obj = {};
    obj.parents = [master_ctl62];
    obj.adf_base = props.globals.getNode(adf_base[n]);
    return obj;
  },
  swap : func() {
    var tmp = me.adf_base.getNode(freq_selected).getValue();
    me.adf_base.getNode(freq_selected).setValue
      (me.adf_base.getNode(freq_standby).getValue());
    me.adf_base.getNode(freq_standby).setValue(tmp);
  },
  adjust_frequency : func(d) {
    adjust_radio_frequency(
      me.adf_base.getNode(freq_standby),
      d,
      190.0,
      1800.0);
  }
};

###########################################################################
var slave_ctl62 = {
  new : func(n, airoot) {
    var obj = {};
    obj.parents = [slave_ctl62];
    obj.root = airoot;
    obj.adf_base = props.globals.getNode(adf_base[n]);
    return obj;
  },
  swap : func() {
    var p = me.adf_base.getNode(swap_btn);
    print("ADF62[?].SWAP");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  adjust_frequency : func(d) {
    var p = 0;
    if (abs(d) < 5.0) {
      p = (d < 0) ? me.adf_base.getNode(freq_decS)
                  : me.adf_base.getNode(freq_incS);
    } else {
      p = (d < 0) ? me.adf_base.getNode(freq_decL)
                  : me.adf_base.getNode(freq_incL);
    }
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  }
};

###########################################################################
#  The ADF 462 pick animations default to master.
#  NOTE: Use make_master() and make_slave_to().
#        Do NOT change ctl62 directly.
var ctl62 = [master_ctl62.new(0), master_ctl62.new(1)];


###########################################################################
# API for pick animations and dual control setup.
###########################################################################

###########################################################################
# n - Adf#
var make_master = func(n) {
  ctl62[n] = master_ctl62.new(n);
}

###########################################################################
# n - Adf#
var make_slave_to = func(n, airoot) {
  ctl62[n] = slave_ctl62.new(n, airoot);
}

###########################################################################
# n - Adf#
var swap = func(n) {
  ctl62[n].swap();
}

###########################################################################
# n - Adf#
# d - adjustment
var adjust_frequency = func(n, d) {
  ctl62[n].adjust_frequency(d);
}

###########################################################################
# Create aliases to drive a radio 3d model in an AI/MP model. 
# n - Adf#
var animate_aimodel = func(n, airoot) {
  var p = "systems/electrical/outputs/adf["~ n ~"]";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = "instrumentation/adf["~ n ~"]/serviceable";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = adf_base[n] ~ "/" ~ freq_selected;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = adf_base[n] ~ "/" ~ freq_standby;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
}

###########################################################################
# Create a TDMEncoder node array for sending the current radio state to
# slaves.  
# n - Adf#
var master_send_state = func(n) {
  var b = props.globals.getNode(adf_base[n]);
  return
    [
     b.getNode(freq_selected),
     b.getNode(freq_standby)
    ];
}

###########################################################################
# Create a SwitchDecoder action array for processing button presses
# from a slave.  
# n - Adf#
var master_receive_slave_buttons = func(n) {
  return
    [
     func (b) {
         if (b) { swap(n); }
     },
     func (b) {
         if (b) { adjust_frequency(n, -1.0); }
     },
     func (b) {
         if (b) { adjust_frequency(n, 1.0); }
     },
     func (b) {
         if (b) { adjust_frequency(n, -10.0); }
     },
     func (b) {
         if (b) { adjust_frequency(n, 10.0); }
     }
    ];
}

###########################################################################
# Create a TDMDecoder action array for processing the radio state
# from the master.
# n - Adf#
var slave_receive_master_state = func(n) {
  var b = props.globals.getNode(adf_base[n]);
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
# n - Adf#
var slave_send_buttons = func(n) {
  var b = props.globals.getNode(adf_base[n]);
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
# (Not so) Generic frequency stepper.
#  f   - frequency property
#  d   - change
#  min - min frequency
#  max - max frequency
var adjust_radio_frequency = func(f, d, min, max) {
  var old = f.getValue();
  var new = old + d;
  if (new < min - 0.05) {
    new = max + (new - min);
    if ((max - new) >= -d) new += -d;
  }
  if (new > max + 0.05) {
    new = min + (new - max);
    if ((new - min) >= d) new -= d;
  }
#  print("Old: " ~ old ~ "  Intermediate: " ~ (old + d) ~ "  New: " ~ new);
  f.setValue(new);
}
