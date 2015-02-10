var startEngine = func(v = 1, which...) {
    if (!v and !size(which))
        return props.setAll("/controls/engines/engine", "starter", 0);
    if(size(which)) {
        foreach(var i; which)
            foreach(var e; engines)
                if(e.index == i)
                    e.controls.getNode("starter").setBoolValue(v);
    } else {
        foreach(var e; engines)
            if(e.selected.getValue())
                e.controls.getNode("starter").setBoolValue(v);
    }
}

var selectEngine = func(which) {
    foreach(var e; engines) e.selected.setBoolValue(which == e.index);
}

# Selects (state=1) or deselects (state=0) a list of engines, or all
# engines if no list is specified. Example:  selectEngines(1, 1, 3, 5);
#
var selectEngines = func (state, which...) {
    if(size(which)) {
        foreach(var i; which)
            foreach(var e; engines)
                if(e.index == i)
                    e.selected.setBoolValue(state);
    } else {
        foreach(var e; engines)
            e.selected.setBoolValue(state);
    }
}

var selectAllEngines = func {
    foreach(var e; engines) e.selected.setBoolValue(1);
}

var stepMagnetos = func(change) {
    if (!change)
        return;
    foreach(var e; engines) {
        if(e.selected.getValue()) {
            var mag = e.controls.getNode("magnetos", 1);
            mag.setIntValue(mag.getValue() + change);
        }
    }
}

var centerFlightControls = func {
    setprop("/controls/flight/elevator", 0);
    setprop("/controls/flight/aileron", 0);
    setprop("/controls/flight/rudder", 0);
}

var throttleMouse = func {
    if(!getprop("/devices/status/mice/mouse[0]/button[1]")) return;
    var delta = cmdarg().getNode("offset").getValue() * -4;
    foreach(var e; engines) {
        if(!e.selected.getValue()) continue;
        var throttle = e.controls.getNode("throttle");
        var val = throttle.getValue() + delta;
        if(size(arg) > 0) val = -val;
        throttle.setDoubleValue(val);
    }
}

# Joystick axis handlers (use cmdarg).  Shouldn't be called from
# other contexts.  A non-null argument reverses the axis direction.
var axisHandler = func(pre, post) {
    func(invert = 0) {
        var val = cmdarg().getNode("setting").getValue();
        if(invert) val = -val;
        foreach(var e; engines)
            if(e.selected.getValue())
                setprop(pre ~ e.index ~ post, (1 - val) / 2);
    }
}
var throttleAxis = axisHandler("/controls/engines/engine[", "]/throttle");
var mixtureAxis = axisHandler("/controls/engines/engine[", "]/mixture");
var propellerAxis = axisHandler("/controls/engines/engine[", "]/propeller-pitch");
var carbHeatAxis = axisHandler("/controls/anti-ice/engine[", "]/carb-heat");
var conditionAxis = axisHandler("/controls/engines/engine[", "]/condition");

# Joystick axis handler for controlling subsets of similar properties.
# Shouldn't be called from other contexts.
# The argument engine can be either an index number or a list of
# index numbers.
# Use only when perEngineSelectedAxisHandler() below will not do.
var perIndexAxisHandler = func(pre, post) {
    return
        func(index, invert = 0) {
            var val = cmdarg().getNode("setting").getValue();
            if(invert) val = -val;
            if (typeof(index) == "scalar") {
                setprop(pre ~ index ~ post, (1 - val) / 2);
            } else {
                foreach (var e; index) {
                    setprop(pre ~ e ~ post, (1 - val) / 2);
                }
            }
        };
}

# Joystick axis handler for controlling a selected axis on specific engines.
# Shouldn't be called from other contexts.
# The argument mode can be
#   0  - throttle
#   1  - mixture
#   2  - propeller-pitch
# The argument engine to the returned function can be either an
# engine number or a list of engine numbers.
# Usage example (controlling the mixture of engines 1 and 2):
#   <script>
#     controls.perEngineSelectedAxisHandler(1)([1,2]);
#   </script>
var _axisMode = {
  0: perIndexAxisHandler("/controls/engines/engine[",
                         "]/throttle"),
  1: perIndexAxisHandler("/controls/engines/engine[",
                         "]/mixture"),
  2: perIndexAxisHandler("/controls/engines/engine[",
                         "]/propeller-pitch")
};
var perEngineSelectedAxisHandler = func(mode) {
    return _axisMode[mode];
}


##
# Wrapper around stepProps() which emulates the "old" flap behavior for
# configurations that aren't using the new mechanism.
#
var flapsDown = func(step) {
    if(step == 0) return;
    if(props.globals.getNode("/sim/flaps") != nil) {
        stepProps("/controls/flight/flaps", "/sim/flaps", step);
        return;
    }
    # Hard-coded flaps movement in 3 equal steps:
    var val = 0.3333334 * step + getprop("/controls/flight/flaps");
    setprop("/controls/flight/flaps", val > 1 ? 1 : val < 0 ? 0 : val);
}

var wingSweep = func(step) {
    if(step == 0) return;
    if(props.globals.getNode("/sim/wing-sweep") != nil) {
        stepProps("/controls/flight/wing-sweep", "/sim/wing-sweep", step);
        return;
    }
    # Hard-coded wing movement in 5 equal steps:
    var val = 0.20 * step + getprop("/controls/flight/wing-sweep");
    setprop("/controls/flight/wing-sweep", val > 1 ? 1 : val < 0 ? 0 : val);
}

var wingsDown = func(v) {
    if(v) setprop("/controls/flight/wing-fold", v > 0);
}

var stepSpoilers = func(step) {
    if(props.globals.getNode("/sim/spoilers") != nil) {
        stepProps("/controls/flight/spoilers", "/sim/spoilers", step);
        return;
    }
    # Hard-coded spoilers movement in 4 equal steps:
    var val = 0.25 * step + getprop("/controls/flight/spoilers");
    setprop("/controls/flight/spoilers", val > 1 ? 1 : val < 0 ? 0 : val);
}

var stepSlats = func(step) {
    if(props.globals.getNode("/sim/slats") != nil) {
        stepProps("/controls/flight/slats", "/sim/slats", step);
        return;
    }
    # Hard-coded slats movement in 4 equal steps:
    var val = 0.25 * step + getprop("/controls/flight/slats");
    setprop("/controls/flight/slats", val > 1 ? 1 : val < 0 ? 0 : val);
}

##
# Steps through an "array" of property settings.  The first argument
# specifies a destination property.  The second is a string containing
# a global property tree.  This tree should contain an array of
# indexed <setting> children.  This function will maintain a
# <current-setting> child, which contains the index of the currently
# active setting.  The third argument specifies an integer delta,
# indicating how many steps to move through the setting array.
# Note that because of the magic of the property system, this
# mechanism works for all scalar property types (bool, int, double,
# string).
#
# TODO: This interface could easily be extended to allow for wrapping,
# in addition to clamping, allowing a "cycle" of settings to be
# defined.  It could also be hooked up with the interpolate() call,
# which would allow the removal of the transition-time feature from
# YASim.  Finally, other pre-existing features (the views and engine
# magnetos, for instance), work similarly but not compatibly, and
# could be integrated.
#
var stepProps = func(dst, array, delta) {
    dst = props.globals.getNode(dst);
    array = props.globals.getNode(array);
    if(dst == nil or array == nil) { return; }

    var sets = array.getChildren("setting");

    var curr = array.getNode("current-setting", 1).getValue();
    if(curr == nil) { curr = 0; }
    curr = curr + delta;
    if   (curr < 0)           { curr = 0; }
    elsif(curr >= size(sets)) { curr = size(sets) - 1; }

    array.getNode("current-setting").setIntValue(curr);
    dst.setValue(sets[curr].getValue());
}

##
# "Slews" a property smoothly, without dependence on the simulator
# frame rate.  The first argument is the property name.  The second is
# a rate, in units per second.  NOTE: this modifies the property for
# the current frame only; it is intended to be called by bindings
# which repeat each frame.  If you want to cause motion over time, see
# interpolate(). Returns new value.
#
var slewProp = func(prop, delta) {
    delta *= getprop("/sim/time/delta-realtime-sec");
    setprop(prop, getprop(prop) + delta);
    return getprop(prop); # must read again because of clamping
}

# Standard trim rate, in units per second.  Remember that the full
# range of a trim axis is 2.0.  Should probably read this out of a
# property...
var TRIM_RATE = 0.045;

##
# Handlers.  These are suitable for binding to repeatable button press
# events.  They are *not* good for binding to the keyboard, since (at
# least) X11 synthesizes its own key repeats.
#
var elevatorTrim = func(speed) {
    slewProp("/controls/flight/elevator-trim", speed * TRIM_RATE); }
var aileronTrim = func(speed) {
    slewProp("/controls/flight/aileron-trim", speed * TRIM_RATE); }
var rudderTrim = func(speed) {
    slewProp("/controls/flight/rudder-trim", speed * TRIM_RATE); }

var THROTTLE_RATE = 0.33;

var adjThrottle = func(speed) {
    adjEngControl("throttle", speed); }
var adjMixture = func(speed) {
    adjEngControl("mixture", speed); }
var adjCondition = func(speed) {
    adjEngControl("condition", speed); }
var adjPropeller = func(speed) {
    adjEngControl("propeller-pitch", speed); }

var adjEngControl = func(prop, speed) {
    var delta = speed * THROTTLE_RATE * getprop("/sim/time/delta-realtime-sec");
    var (value, count) = (0, 0);
    foreach(var e; engines) {
        if(e.selected.getValue()) {
            var node = e.controls.getNode(prop, 1);
            node.setValue(node.getValue() + delta);
            value += node.getValue(); # must read again because of clamping
            count += 1;
        }
    }
    return value / count;
}

##
# arg[0] is the throttle increment
# arg[1] is the auto-throttle target speed increment
var incThrottle = func {
    var passive = getprop("/autopilot/locks/passive-mode");
    var locked = getprop("/autopilot/locks/speed");
    # Note: passive/locked may be nil on aircraft without A/P
    if ((passive == 0) and (locked))
    {
        var node = props.globals.getNode("/autopilot/settings/target-speed-kt", 1);
        if (node.getValue() == nil) {
            node.setValue(0.0);
        }
        node.setValue(node.getValue() + arg[1]);
        if (node.getValue() < 0.0) {
            node.setValue(0.0);
        }
    }
    else
    {
        foreach(var e; engines)
        {
            if(e.selected.getValue())
            {
                var node = e.controls.getNode("throttle", 1);
                var val = node.getValue() + arg[0];
                node.setValue(val < -1.0 ? -1.0 : val > 1.0 ? 1.0 : val);
            }
        }
    }
}

##
# arg[0] is the aileron increment
# arg[1] is the autopilot target heading increment
var incAileron = func {
    var passive = getprop("/autopilot/locks/passive-mode");
    var locked = getprop("/autopilot/locks/heading");
    # Note: passive/locked may be nil on aircraft without A/P
    if ((passive == 0) and (locked == "dg-heading-hold"))
    {
        var node = props.globals.getNode("/autopilot/settings/heading-bug-deg", 1);
        if (node.getValue() == nil) {
            node.setValue(0.0);
        }
        node.setValue(node.getValue() + arg[1]);
        if (node.getValue() < 0.0) {
            node.setValue(node.getValue() + 360.0);
        }
        if (node.getValue() > 360.0) {
            node.setValue(node.getValue() - 360.0);
        }
    }
    else if ((passive == 0) and (locked == "true-heading-hold"))
    {
        var node = props.globals.getNode("/autopilot/settings/true-heading-deg", 1);
        if (node.getValue() == nil) {
            node.setValue(0.0);
        }
        node.setValue(node.getValue() + arg[1]);
        if (node.getValue() < 0.0) {
            node.setValue(node.getValue() + 360.0);
        }
        if (node.getValue() > 360.0) {
            node.setValue(node.getValue() - 360.0);
        }
    }
    else
    {
        var aileron = props.globals.getNode("/controls/flight/aileron");
        if (aileron.getValue() == nil) {
           aileron.setValue(0.0);
        }
        aileron.setValue(aileron.getValue() + arg[0]);
        if (aileron.getValue() < -1.0) {
            aileron.setValue(-1.0);
        }
        if (aileron.getValue() > 1.0) {
            aileron.setValue(1.0);
        }
    }
}

##
# arg[0] is the elevator increment
# arg[1] is the autopilot target altitude increment
var incElevator = func {
    var passive = getprop("/autopilot/locks/passive-mode");
    var locked = getprop("/autopilot/locks/altitude");
    # Note: passive/locked may be nil on aircraft without A/P
    if ((passive == 0) and (locked =="altitude-hold"))
    {
        var node = props.globals.getNode("/autopilot/settings/target-altitude-ft", 1);
        if (node.getValue() == nil) {
            node.setValue(0.0);
        }
        node.setValue(node.getValue() + arg[1]);
        if (node.getValue() < 0.0) {
            node.setValue(0.0);
        }
    }
    else
    {
        var elevator = props.globals.getNode("/controls/flight/elevator");
        if (elevator.getValue() == nil) {
            elevator.setValue(0.0);
        }
        elevator.setValue(elevator.getValue() + arg[0]);
        if (elevator.getValue() < -1.0) {
            elevator.setValue(-1.0);
        }
        if (elevator.getValue() > 1.0) {
            elevator.setValue(1.0);
        }
    }
}

##
# Joystick axis handlers.  Don't call from other contexts.
#
var elevatorTrimAxis = func { elevatorTrim(cmdarg().getNode("setting").getValue()); }
var aileronTrimAxis = func { aileronTrim(cmdarg().getNode("setting").getValue()); }
var rudderTrimAxis = func { rudderTrim(cmdarg().getNode("setting").getValue()); }

##
# Gear handling.
#
var gearDown = func(v) {
    if (v < 0) {
      setprop("/controls/gear/gear-down", 0);
    } elsif (v > 0) {
      setprop("/controls/gear/gear-down", 1);
    }
}
var gearToggle = func { gearDown(getprop("/controls/gear/gear-down") > 0 ? -1 : 1); }

##
# Brake handling.
#
var fullBrakeTime = 0.5;
var applyBrakes = func(v, which = 0) {
    if (which <= 0) { interpolate("/controls/gear/brake-left", v, fullBrakeTime); }
    if (which >= 0) { interpolate("/controls/gear/brake-right", v, fullBrakeTime); }
}

var applyParkingBrake = func(v) {
    if (!v) { return; }
    var p = "/controls/gear/brake-parking";
    setprop(p, var i = !getprop(p));
    return i;
}

# 1: Deploy, -1: Release
var deployChute = func(v) setprop("/controls/flight/drag-chute", v);

##
# Weapon handling.
#
var trigger = func(b) setprop("/controls/armament/trigger", b);
var weaponSelect = func(d) {
    var ws = props.globals.getNode("/controls/armament/selected", 1);
    var n = ws.getValue();
    if (n == nil) { n = 0; }
    ws.setIntValue(n + d);
}

##
# Communication.
#
var ptt = func(b) setprop("/instrumentation/comm/ptt", b);

##
# Lighting.
#
var toggleLights = func {
    if (getprop("/controls/switches/panel-lights")) {
        setprop("/controls/switches/panel-lights-factor", 0);
        setprop("/controls/switches/panel-lights", 0);
        setprop("/controls/switches/landing-light", 0);
        setprop("/controls/switches/flashing-beacon", 0);
        setprop("/controls/switches/strobe-lights", 0);
        setprop("/controls/switches/map-lights", 0);
        setprop("/controls/switches/cabin-lights", 0);
        setprop("/controls/switches/nav-lights", 0);
    } else {
        setprop("/controls/electric/battery-switch", 1);
        setprop("/controls/electric/alternator-switch", 1);
        setprop("/controls/switches/panel-lights-factor", 0.1);
        setprop("/controls/switches/panel-lights", 1);
        setprop("/controls/switches/landing-light", 1);
        setprop("/controls/switches/flashing-beacon", 1);
        setprop("/controls/switches/strobe-lights", 1);
        setprop("/controls/switches/map-lights", 1);
        setprop("/controls/switches/cabin-lights", 1);
        setprop("/controls/switches/nav-lights", 1);
    }
}

##
# Initialization.
#
var engines = [];
_setlistener("/sim/signals/fdm-initialized", func {
    var sel = props.globals.getNode("/sim/input/selected", 1);
    var engs = props.globals.getNode("/controls/engines").getChildren("engine");

    # need to reset engine list on every FDM reset
    engines = [];
    # process all engines
    foreach(var e; engs) {
        var index = e.getIndex();
        var s = sel.getChild("engine", index, 1);
        if(s.getType() == "NONE") s.setBoolValue(1);
        append(engines, { index: index, controls: e, selected: s });
    }
});

var replaySkip = func(skip_time)
{
    var t = getprop("/sim/replay/time");
    if (t != "")
    {
        t+=skip_time;
        if (t>getprop("/sim/replay/end-time"))
            t = getprop("/sim/replay/end-time");
        if (t<0)
            t=0;
        setprop("/sim/replay/time", t);
    }
}

var speedup = func(speed_up)
{
    var t = getprop("/sim/speed-up");
    if (speed_up < 0)
    {
        t = (t > 1/32) ? t/2 : 1/32;
    }
    else
    {
        t = (t < 32) ? t*2 : 32;
    }
    setprop("/sim/speed-up", t);
    
    # reformat as a string, this is borrowed from replay.xml
    
		if (t<0.9)
		{
			t=1/t; # invert the value
			t = "1/" ~ t; # convert to a string and show inverted
		}
        
    gui.popupTip("Time speed-up: " ~ t ~ "x");
}

# mouse-mode handling 

var cycleMouseMode = func(node)
{
    var reason = node.getChild("reason").getValue();
    if (reason == "right-click") {
        if (!getprop("/sim/mouse/right-button-mode-cycle-enabled")) {
            return;
        }
    }
    
    var modeNode = props.globals.getNode('/devices/status/mice/mouse[0]/mode');    
    var mode = modeNode.getValue() + 1;
    
    if ((mode == 1) and getprop('/sim/mouse/skip-flight-controls-mode')) {
        mode +=1;
    }
    
    if (mode == 3) mode = 0;
    modeNode.setIntValue(mode);
    
    # this is really a 'show on-screen hints' control
    if (getprop('/sim/view-name-popup') == 0)
      return;
    
    # some people like popups but strongly object to this one. As you wish. 
    if (getprop('/sim/mouse/cycle-mode-popup') == 0)
      return;
      
    if (mode == 0) {
      fgcommand("clear-message", props.Node.new({ "id":"mouse-mode" }));
      return;
    }
    
    var msg = "";
    if (mode == 1)
        msg = "Mouse is controlling flight controls. Press TAB to change.";
    else
        msg = "Mouse is controlling view direction. Press TAB to change.";
    
  	fgcommand("show-message", props.Node.new({ "label": msg, "id":"mouse-mode" }));
}

addcommand("cycle-mouse-mode", cycleMouseMode);
