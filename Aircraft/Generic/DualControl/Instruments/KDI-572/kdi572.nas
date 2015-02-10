###############################################################################
## $Id$
##
## Nasal for KDI 572 DME.
##
##  Copyright (C) 2006 - 2008  Syd Adams
##  Adapted for dual control by Anders Gidenstam
##
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Note:
#  This module MUST be loaded as KDI572.
#

var base = ["instrumentation/dme[0]",
            "instrumentation/dme[1]"];

###########################################################################
# API for pick animations.
###########################################################################

var dme_step = func(stp) {
    var switch= getprop("instrumentation/dme/switch-position");
    switch += stp;
    if (switch >3) switch=3;
    if (switch <0) switch=0;
    setprop("instrumentation/dme/switch-position", switch);

    if (switch==0) {
        setprop("instrumentation/dme/frequencies/source",
                "instrumentation/dme/frequencies/selected-mhz");
    } elsif (switch==1) {
        setprop("instrumentation/dme/frequencies/source",
                "instrumentation/nav[0]/frequencies/selected-mhz");
    } elsif (switch==2) {
        setprop("instrumentation/dme/frequencies/source",
                "instrumentation/dme/frequencies/selected-mhz");
    } elsif (switch==3) {
        setprop("instrumentation/dme/frequencies/source",
                "instrumentation/nav[1]/frequencies/selected-mhz");
    }
}

###########################################################################
# API for dual control setup.
###########################################################################

###########################################################################
# Create aliases to drive a KDI-572 3d model in an AI/MP model. 
# n - unit#
var animate_aimodel = func(n, airoot) {
    var p = "systems/electrical/outputs/dme";
    airoot.getNode(p, 1).alias(props.globals.getNode(p));
    p = base[n] ~ "/switch-position";
    airoot.getNode(p, 1).alias(props.globals.getNode(p));
    p = base[n] ~ "/in-range";
    airoot.getNode(p, 1).alias(props.globals.getNode(p));
    p = base[n] ~ "/indicated-distance-nm";
    airoot.getNode(p, 1).alias(props.globals.getNode(p));
    p = base[n] ~ "/indicated-ground-speed-kt";
    airoot.getNode(p, 1).alias(props.globals.getNode(p));
    p = base[n] ~ "/indicated-time-min";
    airoot.getNode(p, 1).alias(props.globals.getNode(p));
}
