# debug.nas -- debugging helpers
#------------------------------------------------------------------------------
#
# debug.dump(<variable>)               ... dumps contents of variable to terminal;
#                                          abbreviation for print(debug.string(v))
#
# debug.local([<frame:int>])           ... dump local variables of current
#                                          or given frame
#
# debug.backtrace([<comment:string>]}  ... writes backtrace with local variables
#                                          (similar to gdb's "bt full)
#
# debug.proptrace([<property [, <frames>]]) ... trace property write/add/remove
#                                          events under the <property> subtree for
#                                          a number of frames. Defaults are "/" and
#                                          2 frames (of which the first one is incomplete).
#
# debug.tree([<property> [, <mode>])   ... dump property tree under property path
#                                          or props.Node hash (default: root). If
#                                          <mode> is unset or 0, use flat mode
#                                          (similar to props.dump()), otherwise
#                                          use space indentation
#
# debug.bt()                           ... abbreviation for debug.backtrace()
#
# debug.string(<variable>)             ... returns contents of variable as string
#
# debug.attributes(<property> [, <verb>]) ... returns attribute string for a given property.
#                                          <verb>ose is by default 1, and suppressed the
#                                          node's refcounter if 0.
#
# debug.isnan()                            returns 1 if argument is an invalid number (NaN),
#                                          0 if it's a valid number, and nil in all other cases
#
# debug.benchmark(<label:string>, <func> [, <repeat:int> [, <output:vector>]])
#                                      ... runs function <repeat> times (default: nil)
#                                          and prints total execution time in seconds,
#                                          prefixed with <label>, while adding results
#                                          to <output>, or returning the only result
#                                          if <repeat> is nil.
#
# debug.benchmark_time(<func> [, <repeat:int> [, <output:vector>]])
#                                      ... like debug.benchmark, but returns total
#                                          execution time and does not print anything.
#
# debug.rank(<list:vector> [, <repeat:int>])
#                                      ... sorts the list of functions based on execution
#                                          time over <repeat> samples (default: 1).
#
# debug.print_rank(<result:vector>, <names:int>)
#                                      ... prints the <result> of debug.rank with <names>
#                                          (which can be a vector of [name, func] or
#                                          [func, name], or a hash of name:func).
#
# debug.printerror(<err-vector>)       ... prints error vector as set by call()
#
# debug.warn(<message>, <level>)       ... generate debug message followed by caller stack trace
#                                          skipping <level> caller levels (default: 0).
#
# debug.propify(<variable>)            ... turn about everything into a props.Node
#
# CAVE: this file makes extensive use of ANSI color codes. These are
#       interpreted by UNIX shells and MS Windows with ANSI.SYS extension
#       installed. If the color codes aren't interpreted correctly, then
#       set property /sim/startup/terminal-ansi-colors=0
#

# ANSI color code wrappers  (see  $ man console_codes)
#
var _title       = func(s, color=nil) globals.string.color("33;42;1", s, color); # backtrace header
var _section     = func(s, color=nil) globals.string.color("37;41;1", s, color); # backtrace frame
var _error       = func(s, color=nil) globals.string.color("31;1",    s, color); # internal errors
var _bench       = func(s, color=nil) globals.string.color("37;45;1", s); # benchmark info

var _nil         = func(s, color=nil) globals.string.color("32", s, color);      # nil
var _string      = func(s, color=nil) globals.string.color("31", s, color);      # "foo"
var _num         = func(s, color=nil) globals.string.color("31", s, color);      # 0.0
var _bracket     = func(s, color=nil) globals.string.color("", s, color);        # [ ]
var _brace       = func(s, color=nil) globals.string.color("", s, color);        # { }
var _angle       = func(s, color=nil) globals.string.color("", s, color);        # < >
var _vartype     = func(s, color=nil) globals.string.color("33", s, color);      # func ghost
var _proptype    = func(s, color=nil) globals.string.color("34", s, color);      # BOOL INT LONG DOUBLE ...
var _path        = func(s, color=nil) globals.string.color("36", s, color);      # /some/property/path
var _internal    = func(s, color=nil) globals.string.color("35", s, color);      # me parents
var _varname     = func(s, color=nil) s;                                         # variable_name


##
# Turn p into props.Node (if it isn't yet), or return nil.
#
var propify = func(p, create = 0) {
	var type = typeof(p);
	if (type == "ghost" and ghosttype(p) == "prop")
		return props.wrapNode(p);
	if (type == "scalar" and num(p) == nil)
		return props.globals.getNode(p, create);
	if (isa(p, props.Node))
		return p;
	return nil;
}


var tree = func(n = "", graph = 1) {
	n = propify(n);
	if (n == nil)
		return dump(n);
	_tree(n, graph);
}


var _tree = func(n, graph = 1, prefix = "", level = 0) {
	var path = n.getPath();
	var children = n.getChildren();
	var s = "";

	if (graph) {
		s = prefix ~ n.getName();
		var index = n.getIndex();
		if (index)
			s ~= "[" ~ index ~ "]";
	} else {
		s = n.getPath();
	}

	if (size(children)) {
		s ~= "/";
		if (n.getType() != "NONE")
			s ~= " = " ~ debug.string(n.getValue()) ~ " " ~ attributes(n)
					~ "    " ~ _section(" PARENT-VALUE ");
	} else {
		s ~= " = " ~ debug.string(n.getValue()) ~ " " ~ attributes(n);
	}

	if ((var a = n.getAliasTarget()) != nil)
		s ~= "  " ~ _title(" alias to ") ~ "  " ~ a.getPath();

	print(s);

	if (n.getType() != "ALIAS")
		forindex (var i; children)
			_tree(children[i], graph, prefix ~ ".   ", level + 1);
}


var attributes = func(p, verbose = 1, color=nil) {
	var r = p.getAttribute("readable")    ? "" : "r";
	var w = p.getAttribute("writable")    ? "" : "w";
	var R = p.getAttribute("trace-read")  ? "R" : "";
	var W = p.getAttribute("trace-write") ? "W" : "";
	var A = p.getAttribute("archive")     ? "A" : "";
	var U = p.getAttribute("userarchive") ? "U" : "";
	var P = p.getAttribute("preserve")    ? "P" : "";
	var T = p.getAttribute("tied")        ? "T" : "";
	var attr = r ~ w ~ R ~ W ~ A ~ U ~ P ~ T;
	var type = "(" ~ p.getType();
	if (size(attr))
		type ~= ", " ~ attr;
	if (var l = p.getAttribute("listeners"))
		type ~= ", L" ~ l;
	if (verbose and (var c = p.getAttribute("references")) > 2)
		type ~= ", #" ~ (c - 2);
	return _proptype(type ~ ")", color);
}


var _dump_prop = func(p, color=nil) {
	_path(p.getPath(), color) ~ " = " ~ debug.string(p.getValue(), color)
                            ~  " "  ~ attributes(p, 1, color);
}


var _dump_var = func(v, color=nil) {
	if (v == "me" or v == "parents")
		return _internal(v, color);
	else
		return _varname(v, color);
}


var _dump_string = func(str, color=nil) {
	var s = "'";
	for (var i = 0; i < size(str); i += 1) {
		var c = str[i];
		if (c == `\``)
			s ~= "\\`";
		elsif (c == `\n`)
			s ~= "\\n";
		elsif (c == `\r`)
			s ~= "\\r";
		elsif (c == `\t`)
			s ~= "\\t";
		elsif (globals.string.isprint(c))
			s ~= chr(c);
		else
			s ~= sprintf("\\x%02x", c);
	}
	return _string(s ~ "'", color);
}


# dump hash keys as variables if they are valid variable names, or as string otherwise
var _dump_key = func(s, color=nil) {
	if (num(s) != nil)
		return _num(s, color);
	if (!size(s))
		return _dump_string(s, color);
	if (!globals.string.isalpha(s[0]) and s[0] != `_`)
		return _dump_string(s, color);
	for (var i = 1; i < size(s); i += 1)
		if (!globals.string.isalnum(s[i]) and s[i] != `_`)
			return _dump_string(s, color);
	_dump_var(s, color);
}


var string = func(o, color=nil) {
	var t = typeof(o);
	if (t == "nil") {
		return _nil("nil", color);

	} elsif (t == "scalar") {
		return num(o) == nil ? _dump_string(o, color) : _num(o~"", color);

	} elsif (t == "vector") {
		var s = "";
		forindex (var i; o)
			s ~= (i == 0 ? "" : ", ") ~ debug.string(o[i], color);
		return _bracket("[", color) ~ s ~ _bracket("]", color);

	} elsif (t == "hash") {
		if (contains(o, "parents") and typeof(o.parents) == "vector"
				and size(o.parents) == 1 and o.parents[0] == props.Node)
			return _angle("<", color) ~ _dump_prop(o, color) ~ _angle(">", color);

		var k = keys(o);
		var s = "";
		forindex (var i; k)
			s ~= (i == 0 ? "" : ", ") ~ _dump_key(k[i], color) ~ ": " ~ debug.string(o[k[i]], color);
		return _brace("{", color) ~ " " ~ s ~ " " ~ _brace("}", color);

	} elsif (t == "ghost") {
		return _angle("<", color) ~ _nil(ghosttype(o), color) ~ _angle(">", color);

	} else {
		return _angle("<", color) ~ _vartype(t, color) ~ _angle(">", color);
	}
}


var dump = func(vars...) {
	if (!size(vars))
		return local(1);
	if (size(vars) == 1)
		return print(debug.string(vars[0]));
	forindex (var i; vars)
		print(globals.string.color("33;40;1", "#" ~ i) ~ " ", debug.string(vars[i]));
}


var local = func(frame = 0) {
	var v = caller(frame + 1);
	print(v == nil ? _error("<no such frame>") : debug.string(v[0]));
	return v;
}


var backtrace = func(desc = nil) {
	var d = desc == nil ? "" : " '" ~ desc ~ "'";
	print("\n" ~ _title("\n### backtrace" ~ d ~ " ###"));
	for (var i = 1; 1; i += 1) {
		if ((var v = caller(i)) == nil)
			return;
		print(_section(sprintf("#%-2d called from %s, line %s:", i - 1, v[2], v[3])));
		dump(v[0]);
	}
}
var bt = backtrace;


var proptrace = func(root = "/", frames = 2) {
	var events = 0;
	var trace = setlistener(propify(root), func(this, base, type) {
		events += 1;
		if (type > 0)
			print(_nil("ADD "), this.getPath());
		elsif (type < 0)
			print(_num("DEL "), this.getPath());
		else
			print("SET ", this.getPath(), " = ", debug.string(this.getValue()), " ", attributes(this));
	}, 0, 2);
	var mark = setlistener("/sim/signals/frame", func {
		print("-------------------- FRAME --------------------");
		if (!frames) {
			removelistener(trace);
			removelistener(mark);
			print("proptrace: stop (", events, " calls)");
		}
		frames -= 1;
	});
}


##
# Executes function fn "repeat" times and prints execution time in seconds. If repeat
# is an integer and an optional "output" argument is specified, each test's result
# is appended to that vector, then the vector is returned. If repeat is nil, then
# the funciton is run once and the result returned. Otherwise, the result is discarded.
# Examples:
#
#     var test = func { getprop("/sim/aircraft"); }
#     debug.benchmark("test()/1", test, 1000);
#     debug.benchmark("test()/2", func setprop("/sim/aircraft", ""), 1000);
#
#     var results = debug.benchmark("test()", test, 1000, []);
#     print("  Results were:");
#     print("    ", debug.string(results));
#
var benchmark = func(label, fn, repeat = nil, output=nil) {
	var start = var end = nil;
	if (repeat == nil) {
		start = systime();
		output = fn();
	} elsif (typeof(output) == 'vector') {
		start = systime();
		for (var i = 0; i < repeat; i += 1)
			append(output, fn());
	} else {
		start = systime();
		for (var i = 0; i < repeat; i += 1)
			fn();
	}
	end = systime();
	print(_bench(sprintf(" %s --> %.6f s ", label, end - start)));
	return output;
}

var benchmark_time = func(fn, repeat = 1, output = nil) {
	var start = var end = nil;
	if (repeat == nil) {
		start = systime();
		output = fn();
	} elsif (typeof(output) == 'vector') {
		start = systime();
		for (var i = 0; i < repeat; i += 1)
			append(output, fn());
	} else {
		start = systime();
		for (var i = 0; i < repeat; i += 1)
			fn();
	}
	end = systime();
	return end - start;
}

##
# Executes each function in the list and returns a sorted vector with the fastest
# on top (i.e. first). Each position in the result is a vector of [func, time].
#
var rank = func(list, repeat = nil) {
	var result = [];
	foreach (var fn; list) {
		var time = benchmark_time(fn, repeat);
		append(result, [fn, time]);
	}
	return sort(result, func(a,b) a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0);
}

var print_rank = func(label, list, names) {
	var _vec = (typeof(names) == 'vector');
	print("Test results for "~label);
	var first = 1;
	var longest = list[-1][1];
	foreach (var item; list) {
		var (fn, time) = item;
		var name = nil;
		if (_vec) {
			foreach (var l; names) {
				if (l[1] == fn) {
					name = l[0]; break;
				} elsif (l[0] == fn) {
					name = l[1]; break;
				}
			}
		} else {
			foreach (var name; keys(names)) {
				if (names[name] == fn) break;
				else name = nil;
			}
		}
		if (name == nil) die("function not found");
		print("  "~name~(first?" (fastest)":"")~" took "~(time*1000)~" ms ("~(time/longest*100)~"%) time");
		first = 0;
	}
	return list;
}


##
# print error vector as set by call(). By using call() one can execute
# code that catches "exceptions" (by a die() call or errors). The Nasal
# code doesn't abort in this case. Example:
#
#     var possibly_buggy = func { ... }
#     call(possibly_buggy, nil, var err = []);
#     debug.printerror(err);
#
var printerror = func(err) {
	if (!size(err))
		return;
	printf("%s:\n at %s, line %d", err[0], err[1], err[2]);
	for (var i = 3; i < size(err); i += 2)
		printf("  called from: %s, line %d", err[i], err[i + 1]);
}


# like die(), but code execution continues. The level argument defines
# how many caller() levels to omit. One is automatically omitted, as
# this would only point to debug.warn(), where the event in question
# didn't happen.
#
var warn = func(msg, level = 0) {
	var c = caller(level += 1);
	if (c == nil)
		die("debug.warn with invalid level argument");
	printf("%s:\n  at %s, line %d", msg, c[2], c[3]);
	while ((c = caller(level += 1)) != nil)
		printf("  called from: %s, line %d", c[2], c[3]);
}


var isnan = func {
	call(math.sin, arg, var err = []);
	return !!size(err);
}


# --prop:debug=1 enables debug mode with additional warnings
#
_setlistener("sim/signals/nasal-dir-initialized", func {
	if (!getprop("debug"))
		return;
	var writewarn = func(f, p, r) {
		if (!r) {
			var hint = "";
			if ((var n = props.globals.getNode(p)) != nil) {
				if (!n.getAttribute("writable"))
					hint = " (write protected)";
				elsif (n.getAttribute("tied"))
					hint = " (tied)";
			}
			warn("Warning: " ~ f ~ " -> writing to " ~ p ~ " failed" ~ hint, 2);
		}
		return r;
	}
	setprop = (func { var _ = setprop; func writewarn("setprop",
			globals.string.join("", arg[:-2]), call(_, arg)) })();
	props.Node.setDoubleValue = func writewarn("setDoubleValue", me.getPath(),
			props._setDoubleValue(me._g, arg));
	props.Node.setBoolValue = func writewarn("setBoolValue", me.getPath(),
			props._setBoolValue(me._g, arg));
	props.Node.setIntValue = func writewarn("setIntValue", me.getPath(),
			props._setIntValue(me._g, arg));
	props.Node.setValue = func writewarn("setValue", me.getPath(),
			props._setValue(me._g, arg));
});


