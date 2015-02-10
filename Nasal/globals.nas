##
# Constants.
#
var D2R = math.pi / 180;               # degree to radian
var R2D = 180 / math.pi;               # radian to degree

var FT2M = 0.3048;                     # feet to meter
var M2FT = 1 / FT2M;
var IN2M = FT2M / 12;
var M2IN = 1 / IN2M;
var NM2M = 1852;                       # nautical miles to meter
var M2NM = 1 / NM2M;

var KT2MPS = 0.5144444444;             # knots to m/s
var MPS2KT = 1 / KT2MPS;

var FPS2KT = 0.5924838012958964;        # fps to knots
var KT2FPS = 1 / FPS2KT;

var LB2KG = 0.45359237;                # pounds to kg
var KG2LB = 1 / LB2KG;

var GAL2L = 3.785411784;               # US gallons to liter
var L2GAL = 1 / GAL2L;


# container for local variables, so as not to clutter the global namespace
var __ = {};

##
# Aborts execution if <condition> evaluates to false.
# Prints an optional message if present, or just "assertion failed!"
#
var assert = func (condition, message=nil) {
	message != nil or (message = "assertion failed!");
	condition or die(message);
}

##
# Returns true if the first object is an instance of the second
# (class) object.  Example: isa(someObject, props.Node)
#
var isa = func(obj, class) {
    if(typeof(obj) == "hash" and obj["parents"] != nil)
        foreach(var c; obj.parents)
            if(c == class or isa(c, class))
                return 1;
    return 0;
}

##
# Invokes a FlightGear command specified by the first argument.  The
# second argument specifies the property tree to be passed to the
# command as its argument.  It may be either a props.Node object or a
# string, in which case it specifies a path in the global property
# tree.
#
var fgcommand = func(cmd, node=nil) {
    if(isa(node, props.Node)) node = node._g;
    elsif(typeof(node) == 'hash')
        node = props.Node.new(node)._g;
    _fgcommand(cmd, node);
}

##
# Returns the SGPropertyNode argument to the currently executing
# function. Wrapper for the internal _cmdarg function that retrieves
# the ghost handle to the argument and wraps it in a
# props.Node object.
#
var cmdarg = func { props.wrapNode(_cmdarg()) }

##
# Utility.  Does what you think it does.
#
var abs = func(v) { return v < 0 ? -v : v }

##
# Convenience wrapper for the _interpolate function.  Takes a
# single string or props.Node object in arg[0] indicating a target
# property, and a variable-length list of time/value pairs.  Example:
#
#  interpolate("/animations/radar/angle",
#              180, 1, 360, 1, 0, 0,
#              180, 1, 360, 1, 0, 0,
#              180, 1, 360, 1, 0, 0,
#              180, 1, 360, 1, 0, 0,
#              180, 1, 360, 1, 0, 0,
#              180, 1, 360, 1, 0, 0,
#              180, 1, 360, 1, 0, 0,
#              180, 1, 360, 1, 0, 0);
#
# This will swing the "radar dish" smoothly through 8 revolutions over
# 16 seconds.  Note the use of zero-time interpolation between 360 and
# 0 to wrap the interpolated value properly.
#
var interpolate = func(node, val...) {
    if(isa(node, props.Node)) node = node._g;
    elsif(typeof(node) != "scalar" and typeof(node) != "ghost")
        die("bad argument to interpolate()");
    _interpolate(node, val);
}


##
# Wrapper for the _setlistener function. Takes a property path string
# or props.Node object in arg[0] indicating the listened to property,
# a function in arg[1], an optional bool in arg[2], which triggers the
# function initially if true, and an optional integer in arg[3], which
# sets the listener's runtime behavior to "only trigger on change" (0),
# "always trigger on write" (1), and "trigger even when children are
# written to" (2).
#
var setlistener = func(node, fn, init = 0, runtime = 1) {
    if(isa(node, props.Node)) node = node._g;
    elsif(typeof(node) != "scalar" and typeof(node) != "ghost")
        die("bad argument to setlistener()");
    var id = _setlistener(node, func(chg, lst, mode, is_child) {
        fn(props.wrapNode(chg), props.wrapNode(lst), mode, is_child);
    }, init, runtime);
    if(__.log_level <= 2) {
        var c = caller(1);
        printf("setting listener #%d in %s, line %s", id, c[2], c[3]);
    }
    return id;
}


##
# Returns true if the symbol name is defined in the caller, or the
# caller's lexical namespace.  (i.e. defined("varname") tells you if
# you can use varname in an expression without a undefined symbol
# error.
#
var defined = func(sym) {
    if (contains(caller(1)[0], sym)) return 1;
    var fn = caller(1)[1];
    for (var l=0; (var frame = closure(fn, l)) != nil; l+=1)
        if (contains(frame, sym)) return 1;
    return 0;
}


##
# Returns reference to calling function. This allows a function to
# reliably call itself from a closure, rather than the global function
# with the same name.
#
var thisfunc = func caller(1)[1];


##
# Just what it says it is.
#
var printf = func print(call(sprintf, arg));


##
# Returns vector of hash values.
#
var values = func(hash) {
    var vec = [];
    foreach(var key; keys(hash)) append(vec, hash[key]);
    return vec;
}


##
# Print log messages in appropriate --log-level.
# Usage: printlog("warn", "...");
# The underscore hash prevents helper functions/variables from
# needlessly polluting the global namespace.
#
__.dbg_types = { none:0, bulk:1, debug:2, info:3, warn:4, alert:5 };
__.log_level = __.dbg_types[getprop("/sim/logging/priority")];
var printlog = func(level) {
    if(__.dbg_types[level] >= __.log_level) call(print, arg);
}


##
# Load and execute ~/.fgfs/Nasal/*.nas files in alphabetic order
# after all $FG_ROOT/Nasal/*.nas files were loaded.
#
settimer(func {
    var path = getprop("/sim/fg-home") ~ "/Nasal";
    if((var dir = directory(path)) == nil) return;
    foreach(var file; sort(dir, cmp))
        if(size(file) > 4 and substr(file, -4) == ".nas")
            io.load_nasal(path ~ "/" ~ file, substr(file, 0, size(file) - 4));
}, 0);
