###############################################################################
##
## Nasal for dual control Zeppelin NT Envelope Pressure Indicator.
##
##  Copyright (C) 2010  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#  This module MUST be loaded as EPI.
#

# Slave button presses.
#  none.

# Properties
var l_base = "instrumentation/envelope-pressure-indicator/";
var l_gas_pressure = l_base ~ "indicated-gas-pressure-psf";
var l_fwd_ballonet_pressure = l_base ~ "indicated-fwd-ballonet-pressure-psf";
var l_aft_ballonet_pressure = l_base ~ "indicated-aft-ballonet-pressure-psf";

# The EPI instrument does not need a Nasal driver.

###########################################################################
# Create aliases to drive a EPI 3d model in an AI/MP model. 
var animate_aimodel = func(airoot) {
    # Assume the instrument is serviceable.
    props.globals.initNode(l_base ~ "/serviceable", 1, "BOOL");
    # Connect local nodes to aliases for the 3d model.
    foreach (var p;
             [l_base ~ "/serviceable",
              l_gas_pressure,
              l_fwd_ballonet_pressure,
              l_aft_ballonet_pressure]) {
        airoot.getNode(p, 1).alias(props.globals.getNode(p, 1));
    }
}


###########################################################################
# Create a TDMEncoder node array for sending the current EPI state to
# slaves.  
var master_send_state = func() {
    return
        [
         # 1 - 3 Pressures
         props.globals.getNode(l_gas_pressure),
         props.globals.getNode(l_fwd_ballonet_pressure),
         props.globals.getNode(l_aft_ballonet_pressure)
        ];
}



###########################################################################
# Create a TDMDecoder action array for processing the EPI state
# from the master.
var slave_receive_master_state = func() {
    return
        [
         # 1 - 3 Pressures
         func (v) {
             props.globals.getNode(l_gas_pressure).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_fwd_ballonet_pressure).setValue(v);
         },
         func (v) {
             props.globals.getNode(l_aft_ballonet_pressure).setValue(v);
         }
        ];
}
