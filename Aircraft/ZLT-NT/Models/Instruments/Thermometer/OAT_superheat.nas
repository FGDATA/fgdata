###############################################################################
##
## Nasal for dual control of Zeppelin NT OAT and Superheat Indicator.
##
##  Copyright (C) 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#  This module MUST be loaded as OAT_superheat.
#

# Slave button presses.
#  none.

# Properties
var l_oat_base = "instrumentation/oat-indicator/";
var l_superheat_base = "instrumentation/superheat-indicator/";
var l_oat       = l_oat_base ~ "indicated-oat-degf";
var l_superheat = l_superheat_base ~ "indicated-superheat-degf";


# The OAT and Superheat instrument does not need a Nasal driver.

###########################################################################
# Create aliases to drive a OAT and superheat 3d model in an AI/MP model. 
var animate_aimodel = func(airoot) {
    # Assume the instrument is serviceable.
    props.globals.initNode(l_oat_base ~ "/serviceable", 1, "BOOL");
    props.globals.initNode(l_superheat_base ~ "/serviceable", 1, "BOOL");
    # Connect local nodes to aliases for the 3d model.
    foreach (var p;
             [l_oat_base ~ "/serviceable",
              l_superheat_base ~ "/serviceable",
              l_oat,
              l_superheat]) {
        airoot.getNode(p, 1).alias(props.globals.getNode(p, 1));
    }
}


###########################################################################
# Create a TDMEncoder node array for sending the current instrument state to
# slaves.  
var master_send_state = func() {
    return
        [
         # 1 - 2 Temperatures
         props.globals.getNode(l_oat),
         props.globals.getNode(l_superheat)
        ];
}



###########################################################################
# Create a TDMDecoder action array for processing the instrument state
# from the master.
var slave_receive_master_state = func() {
    return
        [
         # 1 - 2 Temperatures
         func (v) {
             props.globals.getNode(l_oat).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_superheat).setValue(v);
         }
        ];
}
