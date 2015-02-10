###############################################################################
##
## Nasal for dual control of a KAP 140 autopilot over the multiplayer
## network.
##
##  Copyright (C) 2008 - 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#  This module MUST be loaded as kap140.
#

# Load the real KAP 140 module as kap140_implementation.
if (!contains(globals, "kap140_implementation")) {
    io.load_nasal(getprop("/sim/fg-root") ~
                  "/Aircraft/Generic/kap140.nas",
                  "kap140_implementation");
}

# Slave button presses.
var ap_btn    = "ap-btn";
var hdg_btn   = "hdg-btn";
var nav_btn   = "nav-btn";
var apr_btn   = "apr-btn";
var alt_btn   = "alt-btn";
var rev_btn   = "rev-btn";
var down_btn  = "down-btn";
var up_btn    = "up-btn";
var arm_btn   = "arm-btn";
var baro_press_btn    = "baro-press-btn";
var baro_release_btn  = "baro-release-btn";

var base = "autopilot/kap140/";
var buttons = base ~ "buttons/";

###############################################################################
# API function wrappers.

var apButton = func {
    kap140.apButton();
}

var hdgButton = func {
    kap140.hdgButton();
}

var navButton = func {
    kap140.navButton();
}

var aprButton = func {
    kap140.aprButton();
}

var altButton = func {
    kap140.altButton();
}

var revButton = func {
    kap140.revButton();
}

var downButton = func {
    kap140.downButton();
}

var upButton = func {
    kap140.upButton();
}

var armButton = func {
    kap140.armButton();
}

var baroButtonPress = func {
    kap140.baroButtonPress();
}

var baroButtonRelease = func {
    kap140.baroButtonRelease();
}

var knobSmallDown = func {
    kap140.knobSmallDown();
}

var knobSmallUp = func {
    kap140.knobSmallUp();
}

var knobLargeDown = func {
    kap140.knobLargeDown();
}

var knobLargeUp = func {
    kap140.knobLargeUp();
}

###############################################################################

###########################################################################
# The master is just the standard implementation. 
var master_kap140 =
    contains(globals, "kap140_implementation") ? kap140_implementation : nil;

###########################################################################
var slave_kap140 = {
  new : func(airoot) {
    var obj = {};
    obj.parents = [slave_kap140];
    obj.root = airoot;
    obj.base = props.globals.getNode("/autopilot/kap140/buttons", 1);
    return obj;
  },
  apButton : func {
    var p = me.base.getNode(ap_btn);
    print("KAP140.AP");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  hdgButton : func {
    var p = me.base.getNode(hdg_btn);
    print("KAP140.HDG");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  navButton : func {
    var p = me.base.getNode(nav_btn);
    print("KAP140.NAV");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  aprButton : func {
    var p = me.base.getNode(apr_btn);
    print("KAP140.APR");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  altButton : func {
    var p = me.base.getNode(alt_btn);
    print("KAP140.ALT");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  revButton : func {
    var p = me.base.getNode(rev_btn);
    print("KAP140.REV");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  downButton : func {
    var p = me.base.getNode(down_btn);
    print("KAP140.DN");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  upButton : func {
    var p = me.base.getNode(up_btn);
    print("KAP140.UP");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  armButton : func {
    var p = me.base.getNode(arm_btn);
    print("KAP140.ARM");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  baroButtonPress : func {
    var p = me.base.getNode(baro_press_btn);
    print("KAP140.BARO_PRESS");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  baroButtonRelease : func {
    var p = me.base.getNode(baro_release_btn);
    print("KAP140.BARO_RELEASE");
    if (!p.getValue()) {
      p.setValue(1);
      settimer(func { p.setValue(0); },
               1.0);
    }
  },
  knobSmallDown : func {
  },
  knobSmallUp : func {
  },
  knobLargeDown : func {
  },
  knobLargeUp : func {
  },
};

###########################################################################
#  The KAP140 pick animations default to master.
var kap140 = master_kap140;

###########################################################################
# API for dual control setup.
###########################################################################

###########################################################################
var make_master = func {
  master_kap140 =
   contains(globals, "kap140_implementation") ? kap140_implementation : nil;
}

###########################################################################
var make_slave_to = func(airoot) {
  kap140 = slave_kap140.new(airoot);
}

###########################################################################
# Create aliases to drive the KAP 140 3d model in an AI/MP model. 
var animate_aimodel = func(airoot) {
#  var p = base ~ "/data-is-valid";
#  airoot.getNode(p, 1).alias(props.globals.getNode(p));
}

###########################################################################
# Create a TDMEncoder node array for sending the current state to
# slaves.  
var master_send_state = func {
  return
    [
    ];
}

###########################################################################
# Create a SwitchDecoder action array for processing button presses
# from a slave.  
var master_receive_slave_buttons = func {
  return
    [
     func (b) {
         if (b) { kap140.apButton(); }
     },
     func (b) {
         if (b) { kap140.hdgButton(); }
     },
     func (b) {
         if (b) { kap140.navButton(); }
     },
     func (b) {
         if (b) { kap140.aprButton(); }
     },
     func (b) {
         if (b) { kap140.altButton(); }
     },
     func (b) {
         if (b) { kap140.revButton(); }
     },
     func (b) {
         if (b) { kap140.downButton(); }
     },
     func (b) {
         if (b) { kap140.upButton(); }
     },
     func (b) {
         if (b) { kap140.armButton(); }
     },
     func (b) {
         if (b) { kap140.baroButtonPress(); }
     },
     func (b) {
         if (b) { kap140.baroButtonRelease(); }
     }
    ];
}

###########################################################################
# Create a TDMDecoder action array for processing the state
# from the master.
var slave_receive_master_state = func {
  return
    [
    ];
}

###########################################################################
# Create a SwitchEncoder node array for sending button presses
# to the master
var slave_send_buttons = func {
  return
    [
     props.globals.getNode(buttons ~ ap_btn, 1),
     props.globals.getNode(buttons ~ hdg_btn, 1),
     props.globals.getNode(buttons ~ nav_btn, 1),
     props.globals.getNode(buttons ~ apr_btn, 1),
     props.globals.getNode(buttons ~ alt_btn, 1),
     props.globals.getNode(buttons ~ rev_btn, 1),
     props.globals.getNode(buttons ~ down_btn, 1),
     props.globals.getNode(buttons ~ up_btn, 1),
     props.globals.getNode(buttons ~ arm_btn, 1),
     props.globals.getNode(buttons ~ baro_press_btn, 1),
     props.globals.getNode(buttons ~ baro_release_btn, 1)
    ];
}
