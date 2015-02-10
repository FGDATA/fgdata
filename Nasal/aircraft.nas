# This module provide basic functions and classes for use in aircraft specific
# Nasal context.



# helper functions
# ==============================================================================

# creates (if necessary) and returns a property node from arg[0],
# which can be a property node already, or a property path
#
var makeNode = func(n) {
	if (isa(n, props.Node))
		return n;
	else
		return props.globals.getNode(n, 1);
}


# returns args[index] if available and non-nil, or default otherwise
#
var optarg = func(args, index, default) {
	size(args) > index and args[index] != nil ? args[index] : default;
}



# door
# ==============================================================================
# class for objects moving at constant speed, with the ability to
# reverse moving direction at any point. Appropriate for doors, canopies, etc.
#
# SYNOPSIS:
#	door.new(<property>, <swingtime> [, <startpos>]);
#
#	property   ... door node: property path or node
#	swingtime  ... time in seconds for full movement (0 -> 1)
#	startpos   ... initial position      (default: 0)
#
# PROPERTIES:
#	./position-norm   (double)     (default: <startpos>)
#	./enabled         (bool)       (default: 1)
#
# EXAMPLE:
#	var canopy = aircraft.door.new("sim/model/foo/canopy", 5);
#	canopy.open();
#
var door = {
	new: func(node, swingtime, pos = 0) {
		var m = { parents: [door] };
		m.node = makeNode(node);
		m.swingtime = swingtime;
		m.enabledN = m.node.initNode("enabled", 1, "BOOL");
		m.positionN = m.node.initNode("position-norm", pos);
		m.target = pos < 0.5;
		return m;
	},
	# door.enable(bool)    ->  set ./enabled
	enable: func(v) {
		me.enabledN.setBoolValue(v);
		me;
	},
	# door.setpos(double)  ->  set ./position-norm without movement
	setpos: func(pos) {
		me.stop();
		me.positionN.setValue(pos);
		me.target = pos < 0.5;
		me;
	},
	# double door.getpos() ->  return current position as double
	getpos: func {
		me.positionN.getValue();
	},
	# door.close()         ->  move to closed state
	close: func {
		me.move(me.target = 0);
	},
	# door.open()          ->  move to open state
	open: func {
		me.move(me.target = 1);
	},
	# door.toggle()        ->  move to opposite end position
	toggle: func {
		me.move(me.target);
	},
	# door.stop()          ->  stop movement
	stop: func {
		interpolate(me.positionN);
	},
	# door.move(double)    ->  move to arbitrary position
	move: func(target) {
		var pos = me.getpos();
		if (pos != target) {
			var time = abs(pos - target) * me.swingtime;
			interpolate(me.positionN, target, time);
		}
		me.target = !me.target;
	},
};



# light
# ==============================================================================
# class for generation of pulsing values. Appropriate for controlling
# beacons, strobes, etc.
#
# SYNOPSIS:
#	light.new(<property>, <pattern> [, <switch>]);
#	light.new(<property>, <stretch>, <pattern> [, <switch>]);
#
#	property   ... light node: property path or node
#	stretch    ... multiplicator for all pattern values
#	pattern    ... array of on/off time intervals (in seconds)
#	switch     ... property path or node to use as switch   (default: ./enabled)
#                      instead of ./enabled
#
# PROPERTIES:
#	./state           (bool)   (default: 0)
#	./enabled         (bool)   (default: 0) except if <switch> given)
#
# EXAMPLES:
#	aircraft.light.new("sim/model/foo/beacon", [0.4, 0.4]);    # anonymous light
#-------
#	var strobe = aircraft.light.new("sim/model/foo/strobe", [0.05, 0.05, 0.05, 1],
#	                "controls/lighting/strobe");
#	strobe.switch(1);
#-------
#	var switch = props.globals.getNode("controls/lighting/strobe", 1);
#	var pattern = [0.02, 0.03, 0.02, 1];
#	aircraft.light.new("sim/model/foo/strobe-top", 1.001, pattern, switch);
#	aircraft.light.new("sim/model/foo/strobe-bot", 1.005, pattern, switch);
#
var light = {
	new: func {
		var m = { parents: [light] };
		m.node = makeNode(arg[0]);
		var stretch = 1.0;
		var c = 1;
		if (typeof(arg[c]) == "scalar") {
			stretch = arg[c];
			c += 1;
		}
		m.pattern = arg[c];
		c += 1;
		if (size(arg) > c and arg[c] != nil)
			m.switchN = makeNode(arg[c]);
		else
			m.switchN = m.node.getNode("enabled", 1);

		m.switchN.initNode(nil, 0, "BOOL");
		m.stateN = m.node.initNode("state", 0, "BOOL");

		forindex (var i; m.pattern)
			m.pattern[i] *= stretch;

		m.index = 0;
		m.loopid = 0;
		m.continuous = 0;
		m.lastswitch = 0;
		m.seqcount = -1;
		m.endstate = 0;
		m.count = nil;
		m.switchL = setlistener(m.switchN, func m._switch_(), 1);
		return m;
	},
	# class destructor
	del: func {
		removelistener(me.switchL);
	},
	# light.switch(bool)   ->  set light switch (also affects other lights
	#                          that use the same switch)
	switch: func(v) {
		me.switchN.setBoolValue(v);
		me;
	},
	# light.toggle()       ->  toggle light switch
	toggle: func {
		me.switchN.setBoolValue(!me.switchN.getValue());
		me;
	},
	# light.cont()         ->  continuous light
	cont: func {
		if (!me.continuous) {
			me.continuous = 1;
			me.loopid += 1;
			me.stateN.setBoolValue(me.lastswitch);
		}
		me;
	},
	# light.blink()        ->  blinking light  (default)
	# light.blink(3)       ->  when switched on, only run three blink sequences;
	#                          second optional arg defines state after the sequences
	blink: func(count = -1, endstate = 0) {
		me.seqcount = count;
		me.endstate = endstate;
		if (me.continuous) {
			me.continuous = 0;
			me.index = 0;
			me.stateN.setBoolValue(0);
			me.lastswitch and me._loop_(me.loopid += 1);
		}
		me;
	},
	_switch_: func {
		var switch = me.switchN.getBoolValue();
		switch != me.lastswitch or return;
		me.lastswitch = switch;
		me.loopid += 1;
		if (me.continuous or !switch) {
			me.stateN.setBoolValue(switch);
		} elsif (switch) {
			me.stateN.setBoolValue(0);
			me.index = 0;
			me.count = me.seqcount;
			me._loop_(me.loopid);
		}
	},
	_loop_: func(id) {
		id == me.loopid or return;
		if (!me.count) {
			me.loopid += 1;
			me.stateN.setBoolValue(me.endstate);
			return;
		}
		me.stateN.setBoolValue(me.index == 2 * int(me.index / 2));
		settimer(func me._loop_(id), me.pattern[me.index]);
		if ((me.index += 1) >= size(me.pattern)) {
			me.index = 0;
			if (me.count > 0)
				me.count -= 1;
		}
	},
};



# lowpass
# ==============================================================================
# class that implements a variable-interval EWMA (Exponentially Weighted
# Moving Average) lowpass filter with characteristics independent of the
# frame rate.
#
# SYNOPSIS:
#	lowpass.new(<coefficient>);
#
# EXAMPLE:
#	var lp = aircraft.lowpass.new(1.5);
#	print(lp.filter(10));  # prints 10
#	print(lp.filter(0));
#
var lowpass = {
	new: func(coeff) {
		var m = { parents: [lowpass] };
		m.coeff = coeff >= 0 ? coeff : die("aircraft.lowpass(): coefficient must be >= 0");
		m.value = nil;
		return m;
	},
	# filter(raw_value)    -> push new value, returns filtered value
	filter: func(v) {
		me.filter = me._filter_;
		me.value = v;
	},
	# get()                -> returns filtered value
	get: func {
		me.value;
	},
	# set()                -> sets new average and returns it
	set: func(v) {
		me.value = v;
	},
	_filter_: func(v) {
		var dt = getprop("/sim/time/delta-sec")*getprop("/sim/speed-up");
		var c = dt / (me.coeff + dt);
		me.value = v * c + me.value * (1 - c);
	},
};



# angular lowpass
# ==============================================================================
# same as above, but for angles. Filters sin/cos separately and calculates the
# angle again from them. This avoids unexpected jumps from 179.99 to -180 degree.
#
var angular_lowpass = {
	new: func(coeff) {
		var m = { parents: [angular_lowpass] };
		m.sin = lowpass.new(coeff);
		m.cos = lowpass.new(coeff);
		m.value = nil;
		return m;
	},
	filter: func(v) {
		v *= D2R;
		me.value = math.atan2(me.sin.filter(math.sin(v)), me.cos.filter(math.cos(v))) * R2D;
	},
	set: func(v) {
		v *= D2R;
		me.sin.set(math.sin(v));
		me.cos.set(math.cos(v));
	},
	get: func {
		me.value;
	},
};



# data
# ==============================================================================
# class that loads and saves properties to aircraft-specific data files in
# ~/.fgfs/aircraft-data/ (Unix) or %APPDATA%\flightgear.org\aircraft-data\.
# There's no public constructor, as the only needed instance gets created
# by the system.
#
# SYNOPSIS:
#	data.add(<properties>);
#	data.save([<interval>])
#
#	properties  ... about any combination of property nodes (props.Node)
#	                or path name strings, or lists or hashes of them,
#	                lists of lists of them, etc.
#	interval    ... save in <interval> minutes intervals, or only once
#	                if 'nil' or empty (and again at reinit/exit)
#
# SIGNALS:
#	/sim/signals/save   ... set to 'true' right before saving. Can be used
#	                        to update values that are to be saved
#
# EXAMPLE:
#	var p = props.globals.getNode("/sim/model", 1);
#	var vec = [p, p];
#	var hash = {"foo": p, "bar": p};
#
#	# add properties
#	aircraft.data.add("/sim/fg-root", p, "/sim/fg-home");
#	aircraft.data.add(p, vec, hash, "/sim/fg-root");
#
#	# now save only once (and at exit/reinit, which is automatically done)
#	aircraft.data.save();
#
#	# or save now and every 30 sec (and at exit/reinit)
#	aircraft.data.save(0.5);
#
var data = {
	init: func {
		me.path = getprop("/sim/fg-home") ~ "/aircraft-data/" ~ getprop("/sim/aircraft") ~ ".xml";
		me.signalN = props.globals.getNode("/sim/signals/save", 1);
		me.catalog = [];
		me.loopid = 0;
		me.interval = 0;

		setlistener("/sim/signals/reinit", func(n) { n.getBoolValue() and me._save_() });
		setlistener("/sim/signals/exit", func me._save_());
	},
	load: func {
		if (io.stat(me.path) != nil) {
			printlog("info", "loading aircraft data from ", me.path);
			io.read_properties(me.path, props.globals);
		}
	},
	save: func(v = nil) {
		me.loopid += 1;
		if (v == nil) {
			me._save_();
		} else {
			me.interval = 60 * v;
			me._loop_(me.loopid);
		}
	},
	_loop_: func(id) {
		id == me.loopid or return;
		me._save_();
		settimer(func me._loop_(id), me.interval);
	},
	_save_: func {
		size(me.catalog) or return;
		printlog("debug", "saving aircraft data to ", me.path);
		me.signalN.setBoolValue(1);
		var data = props.Node.new();
		foreach (var c; me.catalog) {
			if (c[0] == `/`)
				c = substr(c, 1);

			props.copy(props.globals.getNode(c, 1), data.getNode(c, 1));
		}
		io.write_properties(me.path, data);
	},
	add: func(p...) {
		foreach (var n; props.nodeList(p))
			append(me.catalog, n.getPath());
	},
};



# timer
# ==============================================================================
# class that implements timer that can be started, stopped, reset, and can
# have its value saved to the aircraft specific data file. Saving the value
# is done automatically by the aircraft.Data class.
#
# SYNOPSIS:
#	timer.new(<property> [, <resolution:double> [, <save:bool>]])
#
#	<property>   ... property path or props.Node hash that holds the timer value
#	<resolution> ... timer update resolution -- interval in seconds in which the
#	                 timer property is updated while running (default: 1 s)
#	<save>       ... bool that defines whether the timer value should be saved
#	                 and restored next time, as needed for Hobbs meters
#	                 (default: 1)
#
# EXAMPLES:
#	var hobbs_turbine = aircraft.timer.new("/sim/time/hobbs/turbine[0]", 60);
#	hobbs_turbine.start();
#	
#	aircraft.timer.new("/sim/time/hobbs/battery", 60).start();  # anonymous timer
#
var timer = {
	new: func(prop, res = 1, save = 1) {
		var m = { parents: [timer] };
		m.node = makeNode(prop);
		if (m.node.getType() == "NONE")
			m.node.setDoubleValue(0);

		me.systimeN = props.globals.getNode("/sim/time/elapsed-sec", 1);
		m.last_systime = nil;
		m.interval = res;
		m.loopid = 0;
		m.running = 0;
		m.reinitL = setlistener("/sim/signals/reinit", func(n) {
			if (n.getValue()) {
				m.stop();
				m.total = m.node.getValue();
			} else {
				m.node.setDoubleValue(m.total);
			}
		});
		if (save) {
			data.add(m.node);
			m.saveL = setlistener("/sim/signals/save", func m._save_());
		} else {
			m.saveL = nil;
		}
		return m;
	},
	del: func {
		me.stop();
		removelistener(me.reinitL);
		if (me.saveL != nil)
			removelistener(me.saveL);
	},
	start: func {
		me.running and return;
		me.last_systime = me.systimeN.getValue();
		if (me.interval != nil)
			me._loop_(me.loopid);
		me.running = 1;
		me;
	},
	stop: func {
		me.running or return;
		me.running = 0;
		me.loopid += 1;
		me._apply_();
		me;
	},
	reset: func {
		me.node.setDoubleValue(0);
		me.last_systime = me.systimeN.getValue();
	},
	_apply_: func {
		var sys = me.systimeN.getValue();
		me.node.setDoubleValue(me.node.getValue() + sys - me.last_systime);
		me.last_systime = sys;
	},
	_save_: func {
		if (me.running)
			me._apply_();
	},
	_loop_: func(id) {
		id != me.loopid and return;
		me._apply_();
		settimer(func me._loop_(id), me.interval);
	},
};



# livery
# =============================================================================
# Class that maintains livery XML files (see English Electric Lightning for an
# example). The last used livery is saved on exit and restored next time. Livery
# files are regular PropertyList XML files whose properties are copied to the
# main tree.
#
# SYNOPSIS:
#	livery.init(<livery-dir> [, <name-path> [, <sort-path>]]);
#
#	<livery-dir> ... directory with livery XML files, relative to $FG_ROOT
#	<name-path>  ... property path to the livery name in the livery files
#	                 and the property tree (default: sim/model/livery/name)
#	<sort-path>  ... property path to the sort criterion (default: same as
#	                 <name-path> -- that is: alphabetic sorting)
#
# EXAMPLE:
#	aircraft.livery.init("Aircraft/Lightning/Models/Liveries",
#	                     "sim/model/livery/variant",
#	                     "sim/model/livery/index");  # optional
#
#	aircraft.livery.dialog.toggle();
#	aircraft.livery.select("OEBH");
#	aircraft.livery.next();
#
var livery = {
	init: func(dir, nameprop = "sim/model/livery/name", sortprop = nil) {
		me.parents = [gui.OverlaySelector.new("Select Livery", dir, nameprop,
				sortprop, "sim/model/livery/file")];
		me.dialog = me.parents[0];
	},
};



# livery_update
# =============================================================================
# Class for maintaining liveries in MP aircraft. It is used in Nasal code that's
# embedded in aircraft animation XML files, and checks in intervals whether the
# parent aircraft has changed livery, in which case it changes the livery
# in the remote aircraft accordingly. This class is a wrapper for overlay_update.
#
# SYNOPSIS:
#	livery_update.new(<livery-dir> [, <interval:10> [, <func>]]);
#
#	<livery-dir> ... directory with livery files, relative to $FG_ROOT
#	<interval>   ... checking interval in seconds (default: 10)
#	<func>       ... callback function that's called with the ./sim/model/livery/file
#	                 contents as argument whenever the livery has changed. This can
#	                 be used for post-processing.
#
# EXAMPLE:
#	<nasal>
#		<load>
#			var livery_update = aircraft.livery_update.new(
#					"Aircraft/R22/Models/Liveries", 30,
#					func print("R22 livery update"));
#		</load>
#
#		<unload>
#			livery_update.stop();
#		</unload>
#	</nasal>
#
var livery_update = {
	new: func(liveriesdir, interval = 10.01, callback = nil) {
		var m = { parents: [livery_update, overlay_update.new()] };
		m.parents[1].add(liveriesdir, "sim/model/livery/file", callback);
		m.parents[1].interval = interval;
		return m;
	},
	stop: func {
		me.parents[1].stop();
	},
};



# overlay_update
# =============================================================================
# Class for maintaining overlays in MP aircraft. It is used in Nasal code that's
# embedded in aircraft animation XML files, and checks in intervals whether the
# parent aircraft has changed an overlay, in which case it copies the respective
# overlay to the aircraft's root directory.
#
# SYNOPSIS:
#	livery_update.new();
#	livery_update.add(<overlay-dir>, <property> [, <callback>]);
#
#	<overlay-dir> ... directory with overlay files, relative to $FG_ROOT
#	<property>    ... MP property where the overlay file name can be found
#	                  (usually one of the sim/multiplay/generic/string properties)
#	<callback>    ... callback function that's called with two arguments:
#	                  the file name (without extension) and the overlay directory
#
# EXAMPLE:
#	<nasal>
#		<load>
#			var update = aircraft.overlay_update.new();
#			update.add("Aircraft/F4U/Models/Logos", "sim/multiplay/generic/string");
#		</load>
#
#		<unload>
#			update.stop();
#		</unload>
#	</nasal>
#
var overlay_update = {
	new: func {
		var m = { parents: [overlay_update] };
		m.root = cmdarg();
		m.data = {};
		m.interval = 10.01;
		if (m.root.getName() == "multiplayer")
			m._loop_();
		return m;
	},
	add: func(path, prop, callback = nil) {
		var path = path ~ '/';
		me.data[path] = [me.root.initNode(prop, ""), "",
				typeof(callback) == "func" ? callback : func nil];
		return me;
	},
	stop: func {
		me._loop_ = func nil;
	},
	_loop_: func {
		foreach (var path; keys(me.data)) {
			var v = me.data[path];
			var file = v[0].getValue();
			if (file != v[1]) {
				io.read_properties(path ~ file ~ ".xml", me.root);
				v[2](v[1] = file, path);
			}
		}
		settimer(func me._loop_(), me.interval);
	},
};



# steering
# =============================================================================
# Class that implements differential braking depending on rudder position.
# Note that this overrides the controls.applyBrakes() wrapper. If you need
# your own version, then override it again after the steering.init() call.
#
# SYNOPSIS:
#	steering.init([<property> [, <threshold>]]);
#
#	<property>  ... property path or props.Node hash that enables/disables
#	                brake steering (usually bound to the js trigger button)
#	<threshold> ... defines range (+- threshold) around neutral rudder
#	                position in which both brakes are applied
#
# EXAMPLES:
#	aircraft.steering.init("/controls/gear/steering", 0.2);
#	aircraft.steering.init();
#
var steering = {
	init: func(switch = "/controls/gear/brake-steering", threshold = 0.3) {
		me.threshold = threshold;
		me.switchN = makeNode(switch);
		me.switchN.setBoolValue(me.switchN.getBoolValue());
		me.leftN = props.globals.getNode("/controls/gear/brake-left", 1);
		me.rightN = props.globals.getNode("/controls/gear/brake-right", 1);
		me.rudderN = props.globals.getNode("/controls/flight/rudder", 1);
		me.loopid = 0;

		controls.applyBrakes = func(v, w = 0) {
			if (w < 0)
				steering.leftN.setValue(v);
			elsif (w > 0)
				steering.rightN.setValue(v);
			else
				steering.switchN.setValue(v);
		}
		setlistener(me.switchN, func(n) {
			me.loopid += 1;
			if (n.getValue())
				me._loop_(me.loopid);
			else
				me.setbrakes(0, 0);
		}, 1);
	},
	_loop_: func(id) {
		id == me.loopid or return;
		var rudder = me.rudderN.getValue();
		if (rudder > me.threshold)
			me.setbrakes(0, rudder);
		elsif (rudder < -me.threshold)
			me.setbrakes(-rudder, 0);
		else
			me.setbrakes(1, 1);

		settimer(func me._loop_(id), 0);
	},
	setbrakes: func(left, right) {
		me.leftN.setDoubleValue(left);
		me.rightN.setDoubleValue(right);
	},
};



# autotrim
# =============================================================================
# Singleton class that supports quick trimming and compensates for the lack
# of resistance/force feedback in most joysticks. Normally the pilot trims such
# that no real or artificially generated (by means of servo motors and spring
# preloading) forces act on the stick/yoke and it is in a comfortable position.
# This doesn't work well on computer joysticks.
#
# SYNOPSIS:
#	autotrim.start();  # on key/button press
#	autotrim.stop();   # on key/button release (mod-up)
#
# USAGE:
#	(1) move the stick such that the aircraft is in an orientation that
#	    you want to trim for (forward flight, hover, ...)
#	(2) press autotrim button and keep it pressed
#	(3) move stick/yoke to neutral position (center)
#	(4) release autotrim button
#
var autotrim = {
	init: func {
		me.elevator = me.Trim.new("elevator");
		me.aileron = me.Trim.new("aileron");
		me.rudder = me.Trim.new("rudder");
		me.loopid = 0;
		me.active = 0;
	},
	start: func {
		me.active and return;
		me.active = 1;
		me.elevator.start();
		me.aileron.start();
		me.rudder.start();
		me._loop_(me.loopid += 1);
	},
	stop: func {
		me.active or return;
		me.active = 0;
		me.loopid += 1;
		me.update();
	},
	_loop_: func(id) {
		id == me.loopid or return;
		me.update();
		settimer(func me._loop_(id), 0);
	},
	update: func {
		me.elevator.update();
		me.aileron.update();
		me.rudder.update();
	},
	Trim: {
		new: func(name) {
			var m = { parents: [autotrim.Trim] };
			m.trimN = props.globals.getNode("/controls/flight/" ~ name ~ "-trim", 1);
			m.ctrlN = props.globals.getNode("/controls/flight/" ~ name, 1);
			return m;
		},
		start: func {
			me.last = me.ctrlN.getValue();
		},
		update: func {
			var v = me.ctrlN.getValue();
			me.trimN.setDoubleValue(me.trimN.getValue() + me.last - v);
			me.last = v;
		},
	},
};



# tyresmoke
# =============================================================================
# Provides a property which can be used to contol particles used to simulate tyre
# smoke on landing. Weight on wheels, vertical speed, ground speed, ground friction
# factor are taken into account. Tyre slip is simulated by low pass filters.
#
# Modifications to the model file are required.
#
# Generic XML particle files are available, but are not mandatory
# (see Hawker Seahawk for an example).
#
# SYNOPSIS:
#	aircraft.tyresmoke.new(gear index [, auto = 0])
#		gear index - the index of the gear to which the tyre smoke is attached
#		auto - enable automatic update (recommended). defaults to 0 for backward compatibility.
#	aircraft.tyresmoke.del()
#		destructor.
#	aircraft.tyresmoke.update()
#		Runs the update. Not required if automatic updates are enabled.
#
# EXAMPLE:
#	var tyresmoke_0 = aircraft.tyresmoke.new(0);
#	tyresmoke_0.update();
#
# PARAMETERS:
#
#    number: index of gear to be animated, i.e. "2" for /gear/gear[2]/...
#
#    auto: 1 when tyresmoke should start on update loop. 0 when you're going
#      to call the update method from one of your own loops.
#
#    diff_norm: value adjusting the necessary percental change of roll-speed
#      to trigger tyre smoke. Default value is 0.05. More realistic results can
#      be achieved with significantly higher values (i.e. use 0.8).
#
#    check_vspeed: 1 when tyre smoke should only be triggered when vspeed is negative
#      (usually doesn't work for all gear, since vspeed=0.0 after the first gear touches
#      ground). Use 0 to make tyre smoke independent of vspeed.
#      Note: in reality, tyre smoke doesn't depend on vspeed, but only on acceleration
#      and friction.
#

var tyresmoke = {
	new: func(number, auto = 0, diff_norm = 0.05, check_vspeed=1) {
		var m = { parents: [tyresmoke] };
		m.vertical_speed = (!check_vspeed) ? nil : props.globals.initNode("velocities/vertical-speed-fps");
		m.diff_norm = diff_norm;
		m.speed = props.globals.initNode("velocities/groundspeed-kt");
		m.rain = props.globals.initNode("environment/metar/rain-norm");

		var gear = props.globals.getNode("gear/gear[" ~ number ~ "]/");
		m.wow = gear.initNode("wow");
		m.tyresmoke = gear.initNode("tyre-smoke", 0, "BOOL");
		m.friction_factor = gear.initNode("ground-friction-factor", 1);
		m.sprayspeed = gear.initNode("sprayspeed-ms");
		m.spray = gear.initNode("spray", 0, "BOOL");
		m.spraydensity = gear.initNode("spray-density", 0, "DOUBLE");
		m.auto = auto;
		m.listener = nil;

		if (getprop("sim/flight-model") == "jsb") {
			var wheel_speed = "fdm/jsbsim/gear/unit[" ~ number ~ "]/wheel-speed-fps";
			m.rollspeed = props.globals.initNode(wheel_speed);
			m.get_rollspeed = func m.rollspeed.getValue() * 0.3043;
		} else {
			m.rollspeed = gear.initNode("rollspeed-ms");
			m.get_rollspeed = func m.rollspeed.getValue();
		}

		m.lp = lowpass.new(2);
		auto and m.update();
		return m;
	},
	del: func {
		if (me.listener != nil) {
			removelistener(me.listener);
			me.listener = nil;
		}
		me.auto = 0;
	},
	update: func {
		var rollspeed = me.get_rollspeed();
		var vert_speed = (me.vertical_speed) != nil ? me.vertical_speed.getValue() : -999;
		var groundspeed = me.speed.getValue();
		var friction_factor = me.friction_factor.getValue();
		var wow = me.wow.getValue();
		var rain = me.rain.getValue();

		var filtered_rollspeed = me.lp.filter(rollspeed);
		var diff = math.abs(rollspeed - filtered_rollspeed);
		var diff_norm = diff > 0 ? diff / rollspeed : 0;

		if (wow and vert_speed < -1.2
				and diff_norm > me.diff_norm
				and friction_factor > 0.7 and groundspeed > 50
				and rain < 0.20) {
			me.tyresmoke.setValue(1);
			me.spray.setValue(0);
			me.spraydensity.setValue(0);
		} elsif (wow and groundspeed > 5 and rain >= 0.20) {
			me.tyresmoke.setValue(0);
			me.spray.setValue(1);
			me.sprayspeed.setValue(rollspeed * 6);
			me.spraydensity.setValue(rain * groundspeed);
		} else {
			me.tyresmoke.setValue(0);
			me.spray.setValue(0);
			me.sprayspeed.setValue(0);
			me.spraydensity.setValue(0);
		}
		if (me.auto) {
			if (wow) {
				settimer(func me.update(), 0);
				if (me.listener != nil) {
					removelistener(me.listener);
					me.listener = nil;
				}
			} elsif (me.listener == nil) {
				me.listener = setlistener(me.wow, func me._wowchanged_(), 0, 0);
			}
		}
	},
	_wowchanged_: func() {
		if (me.wow.getValue()) {
			me.lp.set(0);
			me.update();
		}
	},
};

# tyresmoke_system
# =============================================================================
# Helper class to contain the tyresmoke objects for all the gears.
# Will update automatically, nothing else needs to be done by the caller.
#
# SYNOPSIS:
#	aircraft.tyresmoke_system.new(<gear index 1>, <gear index 2>, ...)
#		<gear index> - the index of the gear to which the tyre smoke is attached
#	aircraft.tyresmoke_system.del()
#		destructor
# EXAMPLE:
#	var tyresmoke_system = aircraft.tyresmoke_system.new(0, 1, 2, 3, 4);

var tyresmoke_system = {
	new: func {
		var m = { parents: [tyresmoke_system] };
		# preset array to proper size
		m.gears = [];
		setsize(m.gears, size(arg));
		for(var i = size(arg) - 1; i >= 0; i -= 1) {
			m.gears[i] = tyresmoke.new(arg[i], 1);
		}
		return m;
	},
	del: func {
		foreach(var gear; me.gears) {
			gear.del();
		}
	}
};

# rain
# =============================================================================
# Provides a property which can be used to control rain. Can be used to turn
# off rain in internal views, and or used with a texture on canopies etc.
# The output is co-ordinated with system precipitation:
#
#	/sim/model/rain/raining-norm  rain intensity
#	/sim/model/rain/flow-mps      drop flow speed [m/s]
#
# See Hawker Seahawk for an example.
#
# SYNOPSIS:
#	aircraft.rain.init();
#	aircraft.rain.update();
#
var rain = {
	init: func {
		me.elapsed_timeN = props.globals.getNode("sim/time/elapsed-sec");
		me.dtN = props.globals.getNode("sim/time/delta-sec");

		me.enableN = props.globals.initNode("sim/rendering/precipitation-aircraft-enable", 0, "BOOL");
		me.precip_levelN = props.globals.initNode("environment/params/precipitation-level-ft", 0);
		me.altitudeN = props.globals.initNode("position/altitude-ft", 0);
		me.iasN = props.globals.initNode("velocities/airspeed-kt", 0);
		me.rainingN = props.globals.initNode("sim/model/rain/raining-norm", 0);
		me.flowN = props.globals.initNode("sim/model/rain/flow-mps", 0);

		var canopyN = props.globals.initNode("gear/canopy/position-norm", 0);
		var thresholdN = props.globals.initNode("sim/model/rain/flow-threshold-kt", 15);

		setlistener(canopyN, func(n) me.canopy = n.getValue(), 1, 0);
		setlistener(thresholdN, func(n) me.threshold = n.getValue(), 1);
		setlistener("sim/rendering/precipitation-gui-enable", func(n) me.enabled = n.getValue(), 1);
		setlistener("environment/metar/rain-norm", func(n) me.rain = n.getValue(), 1);
		setlistener("sim/current-view/internal", func(n) me.internal = n.getValue(), 1);
	},
	update: func {
		var altitude = me.altitudeN.getValue();
		var precip_level = me.precip_levelN.getValue();

		if (me.enabled and me.internal and altitude < precip_level and me.canopy < 0.001) {
			var time = me.elapsed_timeN.getValue();
			var ias = me.iasN.getValue();
			var dt = me.dtN.getValue();

			me.flowN.setDoubleValue(ias < me.threshold ? 0 : time * 0.5 + ias * NM2M * dt / 3600);
			me.rainingN.setDoubleValue(me.rain);
			if (me.enableN.getBoolValue())
				me.enableN.setBoolValue(0);
		} else {
			me.flowN.setDoubleValue(0);
			me.rainingN.setDoubleValue(0);
			if (me.enableN.getBoolValue() != 1)
				me.enableN.setBoolValue(1);
		}
	},
};



# teleport
# =============================================================================
# Usage:  aircraft.teleport(lat:48.3, lon:32.4, alt:5000);
#
var teleport = func(airport = "", runway = "", lat = -9999, lon = -9999, alt = 0,
		speed = 0, distance = 0, azimuth = 0, glideslope = 0, heading = 9999) {
	setprop("/sim/presets/airport-id", airport);
	setprop("/sim/presets/runway", runway);
	setprop("/sim/presets/parkpos", "");
	setprop("/sim/presets/latitude-deg", lat);
	setprop("/sim/presets/longitude-deg", lon);
	setprop("/sim/presets/altitude-ft", alt);
	setprop("/sim/presets/airspeed-kt", speed);
	setprop("/sim/presets/offset-distance-nm", distance);
	setprop("/sim/presets/offset-azimuth-nm", azimuth);
	setprop("/sim/presets/glideslope-deg", glideslope);
	setprop("/sim/presets/heading-deg", heading);
	fgcommand("reposition");
}



# returns wind speed [kt] from given direction [deg]; useful for head-wind
#
var wind_speed_from = func(azimuth) {
	var dir = (getprop("/environment/wind-from-heading-deg") - azimuth) * D2R;
	return getprop("/environment/wind-speed-kt") * math.cos(dir);
}



# returns true airspeed for given indicated airspeed [kt] and altitude [m]
#
var kias_to_ktas = func(kias, altitude) {
	var seapress = getprop("/environment/pressure-sea-level-inhg");
	var seatemp = getprop("/environment/temperature-sea-level-degc");
	var coralt_ft = altitude * M2FT + (29.92 - seapress) * 910;
	return kias * (1 + 0.00232848233 * (seatemp - 15))
			* (1.0025 + coralt_ft * (0.0000153
			- kias * (coralt_ft * 0.0000000000003 + 0.0000000045)
			+ (0.0000119 * (math.exp(coralt_ft * 0.000016) - 1))));
}



# HUD control class to handle both HUD implementations
# ==============================================================================
#
var HUD = {
	init: func {
		me.vis1N = props.globals.getNode("/sim/hud/visibility[1]", 1);
		me.currcolN = props.globals.getNode("/sim/hud/current-color", 1);
		me.currentPathN = props.globals.getNode("/sim/hud/current-path", 1);
		me.hudN = props.globals.getNode("/sim/hud", 1);
		me.paletteN = props.globals.getNode("/sim/hud/palette", 1);
		me.brightnessN = props.globals.getNode("/sim/hud/color/brightness", 1);
		me.currentN = me.vis1N;
		
		# keep compatibility with earlier version of FG - hud/path[1] is
		# the default Hud
		me.currentPathN.setIntValue(1);
	},
	cycle_color: func {		# h-key
		if (!me.currentN.getBoolValue())		# if off, turn on
			return me.currentN.setBoolValue(1);

		var i = me.currcolN.getValue() + 1;		# if through, turn off
		if (i < 0 or i >= size(me.paletteN.getChildren("color"))) {
			me.currentN.setBoolValue(0);
			me.currcolN.setIntValue(0);
		} else {					# otherwise change color
			me.currentN.setBoolValue(1);
			me.currcolN.setIntValue(i);
		}
	},
	cycle_brightness: func {	# H-key
		me.is_active() or return;
		var br = me.brightnessN.getValue() - 0.2;
		me.brightnessN.setValue(br > 0.01 ? br : 1);
	},
    normal_type: func {		# i-key
	    me.currentPathN.setIntValue(1);
    },
    cycle_type: func {		# I-key
	    var i = me.currentPathN.getValue() + 1;	
		if (i < 1 or i > size(me.hudN.getChildren("path"))) {
		    # back to the start
			me.currentPathN.setIntValue(1);
		} else {	
			me.currentPathN.setIntValue(i);
		}
    },
	is_active: func {
		me.vis1N.getValue();
	},
};

# crossfeed_valve
# =============================================================================
# class that creates a fuel tank cross-feed valve. Designed for YASim aircraft;
# JSBSim aircraft can simply use systems code within the FDM (see 747-400 for
# an example).
#
# WARNING: this class requires the tank properties to be ready, so call new()
# after the FDM is initialized.
#
# SYNOPSIS:
#	crossfeed_valve.new(<max_flow_rate>, <property>, <tank>, <tank>, ... );
#	crossfeed_valve.open(<update>);
#	crossfeed_valve.close(<update>);
#
#	<max_flow_rate>	... maximum transfer rate between the tanks in lbs/sec
#	<property>	... property path to use as switch - pass nil to use no such switch
#	<tank>		... number of a tank to connect - can have unlimited number of tanks connected
#	<update>	... update switch property when opening/closing valve via Nasal - 0 or 1; by default, 1
#
#
# EXAMPLES:
#	aircraft.crossfeed_valve.new(0.5, "/controls/fuel/x-feed", 0, 1, 2);
#-------
#	var xfeed = aircraft.crossfeed_valve.new(1, nil, 0, 1);
#	xfeed.open();
#
var crossfeed_valve = {
	new: func(flow_rate, path) {
		var m = { parents: [crossfeed_valve] };
		m.valve_open = 0;
		m.interval = 0.5;
		m.loopid = -1;
		m.flow_rate = flow_rate;
		if (path != nil) {
			m.switch_node = props.globals.initNode(path, 0, "BOOL");
			setlistener(path, func(node) {
				if (node.getBoolValue()) m.open(0);
				else m.close(0);
			}, 1, 0);
		}
		m.tanks = [];
		for (var i = 0; i < size(arg); i += 1) {
			var tank = props.globals.getNode("consumables/fuel/tank[" ~ arg[i] ~ "]");
			if (tank.getChild("level-lbs") != nil) append(m.tanks, tank);
		}
		return m;
	},
	open: func(update_prop = 1) {
		if (me.valve_open == 1) return;
		if (update_prop and contains(me, "switch_node")) me.switch_node.setBoolValue(1);
		me.valve_open = 1;
		me.loopid += 1;
		settimer(func me._loop_(me.loopid), me.interval);
	},
	close: func(update_prop = 1) {
		if (update_prop and contains(me, "switch_node")) me.switch_node.setBoolValue(0);
		me.valve_open = 0;
	},
	_loop_: func(id) {
		if (id != me.loopid) return;
		var average_level = 0;
		var count = size(me.tanks);
		for (var i = 0; i < count; i += 1) {
			var level_node = me.tanks[i].getChild("level-lbs");
			average_level += level_node.getValue();
		}
		average_level /= size(me.tanks);
		var highest_diff = 0;
		for (var i = 0; i < count; i += 1) {
			var level = me.tanks[i].getChild("level-lbs").getValue();
			var diff = math.abs(average_level - level);
			if (diff > highest_diff) highest_diff = diff;
		}
		for (var i = 0; i < count; i += 1) {
			var level_node = me.tanks[i].getChild("level-lbs");
			var capacity = me.tanks[i].getChild("capacity-gal_us").getValue() * me.tanks[i].getChild("density-ppg").getValue();
			var diff = math.abs(average_level - level_node.getValue());
			var min_level = math.max(0, level_node.getValue() - me.flow_rate * diff / highest_diff);
			var max_level = math.min(capacity, level_node.getValue() + me.flow_rate * diff / highest_diff);
			var level = level_node.getValue() > average_level ? math.max(min_level, average_level) : math.min(max_level, average_level);
			level_node.setValue(level);
		}
		if (me.valve_open) settimer(func me._loop_(id), me.interval);
	}
};




# module initialization
# ==============================================================================
#
_setlistener("/sim/signals/nasal-dir-initialized", func {
	props.globals.initNode("/sim/time/elapsed-sec", 0);
	props.globals.initNode("/sim/time/delta-sec", 0);
	props.globals.initNode("/sim/time/delta-realtime-sec", 0.00000001);

	HUD.init();
	data.init();
	autotrim.init();

##### temporary hack to provide backward compatibility for /sim/auto-coordination
##### remove this code when all references to /sim/auto-coordination are gone
	var ac = props.globals.getNode("/sim/auto-coordination");
	if(ac != nil ) {
		printlog("alert", 
			"WARNING: using deprecated property /sim/auto-coordination. Please change to /controls/flight/auto-coordination" );
		ac.alias(props.globals.getNode("/controls/flight/auto-coordination", 1));
	}
#### end of temporary hack for /sim/auto-coordination

	if (!getprop("/sim/startup/restore-defaults")) {
		# load user-specific aircraft settings
		data.load();
		var n = props.globals.getNode("/sim/aircraft-data");
		if (n != nil)
			foreach (var c; n.getChildren("path"))
				if (c.getType() != "NONE")
					data.add(c.getValue());
	}
	if (!getprop("/sim/startup/save-on-exit"))
	{
		# prevent saving
		data._save_ = func nil;
		data._loop_ = func nil;
	}
});

