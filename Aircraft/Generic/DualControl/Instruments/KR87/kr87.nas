###############################################################################
##
## Nasal for dual control of a KR-87 ADF radio over the multiplayer
## network.
##
##  Copyright (C) 2007 - 2011  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#  This module MUST be loaded as KR87.
#

# Slave button presses.
var swap_btn    = "frq-btn";
var freq_decS   = "freq-decS-clicked";
var freq_incS   = "freq-incS-clicked";
var freq_decL   = "freq-decL-clicked";
var freq_incL   = "freq-incL-clicked";

var bfo_btn     = "bfo-btn";

# Settings
var freq_selected = "frequencies/selected-khz";
var freq_standby  = "frequencies/standby-khz";

var base = ["instrumentation/adf[0]",
            "instrumentation/adf[1]"];

###########################################################################
var master_kr87 = {
  new : func(n) {
    var obj = {};
    obj.parents = [master_kr87];
    obj.base    = props.globals.getNode(base[n]);
    if (obj.base == nil) return;
    obj.base.getNode("right-display", 1).
      setValue(obj.base.getNode(freq_standby).getValue());
    # Always show the standby frequency.
    obj.base.getNode("display-mode", 1).setValue(0);
    return obj;
  },
  swap : func() {
    var tmp = me.base.getNode(freq_selected).getValue();
    me.base.getNode(freq_selected).setValue
      (me.base.getNode(freq_standby).getValue());
    me.base.getNode(freq_standby).setValue(tmp);
    me.base.getNode("right-display").setValue(tmp);
  },
  adjust_frequency : func(d) {
    adjust_radio_frequency(
      me.base.getNode(freq_standby),
      d,
      200,
      1800);
    me.base.getNode("right-display").
      setValue(me.base.getNode(freq_standby).getValue());
  },
  toggle_BFO : func {
    var p = me.base.getNode(bfo_btn).getValue() ? 0 : 1;
    me.base.getNode(bfo_btn).setValue(p);
    me.base.getNode("ident-audible").setValue(p);
  }
};

###########################################################################
var slave_kr87 = {
  new : func(n, airoot) {
    var obj = {};
    obj.parents = [slave_kr87];
    obj.airoot  = airoot;
    obj.base    = props.globals.getNode(base[n]);
    if (obj.base == nil) return;
    obj.base.getNode("right-display", 1).
      setValue(obj.base.getNode(freq_standby).getValue());
    # Always show the standby frequency.
    obj.base.getNode(base[n] ~ "/display-mode", 1).setValue(0);
    return obj;
  },
  swap : func() {
    var p = me.base.getNode(swap_btn);
#    print("KR87[?].SWAP");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  adjust_frequency : func(d) {
    var p = 0;
    if (abs(d) < 50) {
      p = (d < 0) ? me.base.getNode(freq_decS)
                  : me.base.getNode(freq_incS);
    } else {
      p = (d < 0) ? me.base.getNode(freq_decL)
                  : me.base.getNode(freq_incL);
    }
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
};

###########################################################################
#  The KR-87 pick animations default to master.
#  NOTE: Use make_master() and make_slave_to().
#        Do NOT change kr87 directly.
var kr87 = [master_kr87.new(0), master_kr87.new(1)];

###########################################################################
# API for pick animations.
###########################################################################

###########################################################################
# n - ADF#
var swap = func(n) {
  kr87[n].swap();
}

###########################################################################
# n - ADF#
# d - adjustment
var adjust_frequency = func(n, d) {
  kr87[n].adjust_frequency(d);
}

###########################################################################
# n - ADF#
# p - pressed
var toggle_BFO = func(n) {
  kr87[n].toggle_BFO();
}

###########################################################################
# API for dual control setup.
###########################################################################

###########################################################################
# n - ADF#
var make_master = func(n) {
  kr87[n] = master_kr87.new(n);
}

###########################################################################
# n - ADF#
var make_slave_to = func(n, airoot) {
  kr87[n] = slave_kr87.new(n, airoot);
}

###########################################################################
# Create aliases to drive a KR-87 3d model in an AI/MP model. 
# n - ADF#
var animate_aimodel = func(n, airoot) {
  var p = "systems/electrical/outputs/adf["~ n ~"]";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = "instrumentation/adf["~ n ~"]/serviceable";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/" ~ freq_selected;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/" ~ freq_standby;
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/display-mode";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/right-display";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
  p = base[n] ~ "/power-btn";
  airoot.getNode(p, 1).alias(props.globals.getNode(p));
}

###########################################################################
# Create a TDMEncoder node array for sending the current radio state to
# slaves.  
# n - Adf#
var master_send_state = func(n) {
  var b = props.globals.getNode(base[n]);
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
         if (b) { adjust_frequency(n, -100.0); }
     },
     func (b) {
         if (b) { adjust_frequency(n, 100.0); }
     }
    ];
}

###########################################################################
# Create a TDMDecoder action array for processing the radio state
# from the master.
# n - Adf#
var slave_receive_master_state = func(n) {
  var b = props.globals.getNode(base[n]);
  return
    [
     func (v) {
         b.getNode(freq_selected).setValue(v);
     },
     func (v) {
         b.getNode(freq_standby).setValue(v);
         b.getNode("right-display").setValue(v);
     }
    ];
}

###########################################################################
# Create a SwitchEncoder node array for sending button presses
# to the master
# n - Adf#
var slave_send_buttons = func(n) {
  var b = props.globals.getNode(base[n]);
  return
    [
     b.getNode(swap_btn, 1),
     b.getNode(freq_decS, 1),
     b.getNode(freq_incS, 1),
     b.getNode(freq_decL, 1),
     b.getNode(freq_incL, 1),
#     b.getNode(bfo_btn, 1)
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

