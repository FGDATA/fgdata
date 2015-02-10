###############################################################################
##
## Zeppelin NT-07 airship
##
##  Copyright (C) 2008 - 2015  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

###############################################################################
var auto_weighoff = func {
    print("auto_weighoff not implemented.");
}

###############################################################################
# Debug display - stand in instrumentation.
var debug_display_view_handler = {
    init : func {
        if (contains(me, "left")) return;

        me.left  = screen.display.new(20, 10);
        me.left.format  = "%.5g";
        me.right = screen.display.new(-250, 20);
        me.right.format = "%.4g";
        # Static condition
        me.left.add
            ("/fdm/jsbsim/instrumentation/gas-pressure-psf");
        me.left.add
            ("/fdm/jsbsim/buoyant_forces/gas-cell/ballonet[0]/volume-ft3",
             "/fdm/jsbsim/buoyant_forces/gas-cell/ballonet[1]/volume-ft3");
        me.left.add("/fdm/jsbsim/static-condition/net-lift-lbs");
        # C.G.
        me.left.add("/fdm/jsbsim/inertia/cg-x-in");
#        me.left.add(static_trim_p);
#        me.left.add("/fdm/jsbsim/mooring/total-distance-ft");
        # Engines
        me.right.add("/fdm/jsbsim/fcs/etc/propeller-speed-cmd-rpm[0]",
                     "/fdm/jsbsim/propulsion/engine[0]/blade-angle");
        me.right.add("/fdm/jsbsim/fcs/etc/propeller-speed-cmd-rpm[1]",
                     "/fdm/jsbsim/propulsion/engine[1]/blade-angle");
        me.right.add("/fdm/jsbsim/fcs/etc/propeller-speed-cmd-rpm[2]",
                     "/fdm/jsbsim/propulsion/engine[2]/blade-angle");
        me.shown = 1;
        me.stop();
    },
    start  : func {
        if (!me.shown) {
            me.left.toggle();
            me.right.toggle();
        }
        me.shown = 1;
    },
    stop   : func {
        if (me.shown) {
            me.left.toggle();
            me.right.toggle();
        }
        me.shown = 0;
    }
};

# Install the debug display for some views.
setlistener("/sim/signals/fdm-initialized", func {
    view.manager.register("Pilot View", debug_display_view_handler);
    view.manager.register("Copilot View", debug_display_view_handler);
    print("Debug instrumentation ... check");
});

###############################################################################
# fake part of the electrical system.
var fake_electrical = func {
    setprop("/systems/electrical/ac-volts", 15);

    setprop("/systems/electrical/outputs/comm[0]", 24.0);
    setprop("/systems/electrical/outputs/comm[1]", 24.0);
    setprop("/systems/electrical/outputs/nav[0]", 24.0);
    setprop("/systems/electrical/outputs/nav[1]", 24.0);
    setprop("/systems/electrical/outputs/dme", 24.0);
    setprop("/systems/electrical/outputs/adf", 24.0);
    setprop("/systems/electrical/outputs/transponder", 24.0);
    setprop("/systems/electrical/outputs/instrument-lights", 24.0);
    setprop("/systems/electrical/outputs/gps", 24.0);
    setprop("/systems/electrical/outputs/KNS80", 24.0);

    setprop("/instrumentation/clock/flight-meter-hour",0);

    setprop("/controls/lighting/panel-norm", 1.0);
}

setlistener("/sim/signals/fdm-initialized", func {
    fake_electrical();
    # Disable the autopilot menu.
    gui.menuEnable("autopilot", 0);

    setprop("/fdm/jsbsim/instrumentation/gas-pressure-psf", -1);
});

###############################################################################
# About dialog.

var ABOUT_DLG = 0;

var dialog = {
#################################################################
    init : func (x = nil, y = nil) {
        me.x = x;
        me.y = y;
        me.bg = [0, 0, 0, 0.3];    # background color
        me.fg = [[1.0, 1.0, 1.0, 1.0]]; 
        #
        # "private"
        me.title = "About";
        me.dialog = nil;
        me.namenode = props.Node.new({"dialog-name" : me.title });
    },
#################################################################
    create : func {
        if (me.dialog != nil)
            me.close();

        me.dialog = gui.Widget.new();
        me.dialog.set("name", me.title);
        if (me.x != nil)
            me.dialog.set("x", me.x);
        if (me.y != nil)
            me.dialog.set("y", me.y);

        me.dialog.set("layout", "vbox");
        me.dialog.set("default-padding", 0);

        var titlebar = me.dialog.addChild("group");
        titlebar.set("layout", "hbox");
        titlebar.addChild("empty").set("stretch", 1);
        titlebar.addChild("text").set
            ("label",
             "About");
        var w = titlebar.addChild("button");
        w.set("pref-width", 16);
        w.set("pref-height", 16);
        w.set("legend", "");
        w.set("default", 0);
        w.set("key", "esc");
        w.setBinding("nasal", "ZLTNT.dialog.destroy(); ");
        w.setBinding("dialog-close");
        me.dialog.addChild("hrule");

        var content = me.dialog.addChild("group");
        content.set("layout", "vbox");
        content.set("halign", "center");
        content.set("default-padding", 5);
        props.globals.initNode("sim/about/text",
             "Zeppelin NT07 airship for FlightGear\n" ~
             "Copyright (C) 2008 - 2015  Anders Gidenstam\n\n" ~
             "FlightGear flight simulator\n" ~
             "Copyright (C) 1997 - 2015  http://www.flightgear.org\n\n" ~
             "This is free software, and you are welcome to\n" ~
             "redistribute it under certain conditions.\n" ~
             "See the GNU GENERAL PUBLIC LICENSE Version 2 for the details.",
             "STRING");
        var text = content.addChild("textbox");
        text.set("halign", "fill");
        #text.set("slider", 20);
        text.set("pref-width", 400);
        text.set("pref-height", 300);
        text.set("editable", 0);
        text.set("property", "sim/about/text");

        #me.dialog.addChild("hrule");

        fgcommand("dialog-new", me.dialog.prop());
        fgcommand("dialog-show", me.namenode);
    },
#################################################################
    close : func {
        fgcommand("dialog-close", me.namenode);
    },
#################################################################
    destroy : func {
        ABOUT_DLG = 0;
        me.close();
        delete(gui.dialog, "\"" ~ me.title ~ "\"");
    },
#################################################################
    show : func {
        if (!ABOUT_DLG) {
            ABOUT_DLG = 1;
            me.init(400, getprop("/sim/startup/ysize") - 500);
            me.create();
        }
    }
};
###############################################################################

# Popup the about dialog.
var about = func {
    dialog.show();
}
