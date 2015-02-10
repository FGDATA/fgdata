# Dynamic Cockpit View manager. Tries to simulate the pilot's most likely
# deliberate view direction. Doesn't consider forced view changes due to
# acceleration.
#
# To override the default recipes, put something like this into one of
# your aircraft's Nasal files:
#
#   dynamic_view.register(func {
#           # me.default_plane();      # uncomment one of these if you want
#           # me.default_helicopter(); # to base your code on the defaults
#
#                                      # positive values rotate (deg) or move (m)
#           me.heading_offset = ...    #     left
#           me.pitch_offset = ...      #     up
#           me.roll_offset = ...       #     right
#           me.x_offset = ...          #     right     (transversal axis)
#           me.y_offset = ...          #     up        (vertical axis)
#           me.z_offset = ...          #     back/aft  (longitudinal axis)
#           me.fov_offset = ...        #     zoom out  (field of view)
#   });
#
# All offsets are by default 0, and you only need to set them if they should
# be non-zero. The registered function is called for each frame and the respective
# view parameters are set accordingly. The function can access all internal
# variables of the view_manager class, such as me.roll, me.pitch, etc., and it
# can, of course, also use module variables from the file where it's defined.
#
# The following commands move smoothly to a fixed view position and back.
# All values are relative to aircraft origin (absolute), not relative to
# the default cockpit view position. The time and field-of-view argument
# is optional.
#
#   dynamic_view.lookat(hdg, pitch, roll, x, y, z [, time=0.2 [, fov=55]]);
#   dynamic_view.resume();


var FREEZE_DURATION = 2;
var BLEND_TIME = 0.2;


var sin = func(a) math.sin(a * D2R);
var cos = func(a) math.cos(a * D2R);
var sigmoid = func(x) { 1 / (1 + math.exp(-x)) }
var nsigmoid = func(x) { 2 / (1 + math.exp(-x)) - 1 }
var pow = func(v, w) { v < 0 ? nil : v == 0 ? 0 : math.exp(math.ln(v) * w) }
var npow = func(v, w) { v == 0 ? 0 : math.exp(math.ln(abs(v)) * w) * (v < 0 ? -1 : 1) }
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var normatan = func(x) { math.atan2(x, 1) * 2 / math.pi }

var normdeg = func(a) {
	while (a >= 180)
		a -= 360;
	while (a < -180)
		a += 360;
	return a;
}



# Class that reads a property value, applies factor & offset, clamps to min & max,
# and optionally lowpass filters.
#
var Input = {
	new : func(prop = "/null", factor = 1, offset = 0, filter = 0, min = nil, max = nil) {
		var m = { parents : [Input] };
		m.prop = isa(props.Node, prop) ? prop : props.globals.getNode(prop, 1);
		m.factor = factor;
		m.offset = offset;
		m.min = min;
		m.max = max;
		m.lowpass = filter ? aircraft.lowpass.new(filter) : nil;
		return m;
	},
	get : func {
		var v = me.prop.getValue() * me.factor + me.offset;
		if (me.min != nil and v < me.min)
			v = me.min;
		if (me.max != nil and v > me.max)
			v = me.max;

		return me.lowpass == nil ? v : me.lowpass.filter(v);
	},
	set : func(v) {
		me.prop.setDoubleValue(v);
	},
};



# Class that maintains one sim/current-view/goal-*-offset-deg property.
#
var ViewAxis = {
	new : func(prop) {
		var m = { parents : [ViewAxis] };
		m.prop = props.globals.getNode(prop, 1);
		if (m.prop.getType() == "NONE")
			m.prop.setDoubleValue(0);

		m.reset();
		return m;
	},
	reset : func {
		me.applied_offset = 0;
	},
	add_offset : func {
		me.prop.setValue(me.prop.getValue() + me.applied_offset);
	},
	sub_offset : func {
		var raw = me.prop.getValue() - me.applied_offset;
		me.prop.setValue(raw);
		return raw;
	},
	apply : func(v) {
		var raw = me.prop.getValue() - me.applied_offset;
		me.applied_offset = v;
		me.prop.setDoubleValue(raw + me.applied_offset);
	},
	static : func(v) {
		normdeg(v - me.prop.getValue() + me.applied_offset);
	},
};



# Singleton class that manages a dynamic cockpit view by manipulating
# sim/current-view/goal-*-offset-deg properties.
#
var view_manager = {
	init : func {
		me.elapsedN = props.globals.getNode("/sim/time/elapsed-sec", 1);
		me.deltaN = props.globals.getNode("/sim/time/delta-realtime-sec", 1);

		me.headingN = props.globals.getNode("/orientation/heading-deg", 1);
		me.pitchN = props.globals.getNode("/orientation/pitch-deg", 1);
		me.rollN = props.globals.getNode("/orientation/roll-deg", 1);
		me.slipN = props.globals.getNode("/orientation/side-slip-deg", 1);
		me.speedN = props.globals.getNode("velocities/airspeed-kt", 1);

		me.wind_dirN = props.globals.getNode("/environment/wind-from-heading-deg", 1);
		me.wind_speedN = props.globals.getNode("/environment/wind-speed-kt", 1);

		me.axes = [
			me.heading_axis = ViewAxis.new("/sim/current-view/goal-heading-offset-deg"),
			me.pitch_axis = ViewAxis.new("/sim/current-view/goal-pitch-offset-deg"),
			me.roll_axis = ViewAxis.new("/sim/current-view/goal-roll-offset-deg"),
			me.x_axis = ViewAxis.new("/sim/current-view/x-offset-m"),
			me.y_axis = ViewAxis.new("/sim/current-view/y-offset-m"),
			me.z_axis = ViewAxis.new("/sim/current-view/z-offset-m"),
			me.fov_axis = ViewAxis.new("/sim/current-view/field-of-view"),
		];

		# accelerations are converted to G (Earth gravitation is omitted)
		me.ax = Input.new("/accelerations/pilot/x-accel-fps_sec", 0.03108095, 0, 0.58, 0);
		me.ay = Input.new("/accelerations/pilot/y-accel-fps_sec", 0.03108095, 0, 0.95);
		me.az = Input.new("/accelerations/pilot/z-accel-fps_sec", -0.03108095, -1, 0.46);

		# velocities are converted to knots
		me.vx = Input.new("/velocities/uBody-fps", 0.5924838, 0, 0.45);
		me.vy = Input.new("/velocities/vBody-fps", 0.5924838, 0);
		me.vz = Input.new("/velocities/wBody-fps", 0.5924838, 0);

		# turn WoW bool into smooth values ranging from 0 to 1
		me.wow = Input.new("/gear/gear/wow", 1, 0, 0.74);
		me.hdg_change = aircraft.lowpass.new(0.95);
		me.ubody = aircraft.lowpass.new(0.95);
		me.last_heading = me.headingN.getValue();
		me.size_factor = getprop("/sim/chase-distance-m") / -25;

		# "lookat" blending
		me.blendN = props.globals.getNode("/sim/view/dynamic/blend", 1);
		me.blendN.setDoubleValue(0);
		me.blendtime = BLEND_TIME;
		me.frozen = 0;

		if (props.globals.getNode("rotors", 0) != nil)
			me.calculate = me.default_helicopter;
		else
			me.calculate = me.default_plane;
		me.reset();
	},
	reset : func {
		me.heading_offset = me.heading = me.target_heading = 0;
		me.pitch_offset = me.pitch = me.target_pitch = 0;
		me.roll_offset = me.roll = me.target_roll = 0;
		me.x_offset = me.x = me.target_x = 0;
		me.y_offset = me.y = me.target_y = 0;
		me.z_offset = me.z = me.target_z = 0;
		me.fov_offset = me.fov = me.target_fov = 0;

		interpolate(me.blendN);
		me.blendN.setDoubleValue(0);
		foreach (var a; me.axes)
			a.reset();

		me.add_offset();
	},
	add_offset : func {
		me.heading_axis.add_offset();
		me.pitch_axis.add_offset();
		me.roll_axis.add_offset();
		me.fov_axis.add_offset();
	},
	apply : func {
		if (me.elapsedN.getValue() < me.frozen)
			return;
		elsif (me.frozen)
			me.unfreeze();

		me.pitch = me.pitchN.getValue();
		me.roll = me.rollN.getValue();

		me.calculate();

		var b = me.blendN.getValue();
		var B = 1 - b;
		me.heading = me.target_heading * b + me.heading_offset * B;
		me.pitch = me.target_pitch * b + me.pitch_offset * B;
		me.roll = me.target_roll * b + me.roll_offset * B;
		me.x = me.target_x * b + me.x_offset * B;
		me.y = me.target_y * b + me.y_offset * B;
		me.z = me.target_z * b + me.z_offset * B;
		me.fov = me.target_fov * b + me.fov_offset * B;

		me.heading_axis.apply(me.heading);
		me.pitch_axis.apply(me.pitch);
		me.roll_axis.apply(me.roll);
		me.x_axis.apply(me.x);
		me.y_axis.apply(me.y);
		me.z_axis.apply(me.z);
		me.fov_axis.apply(me.fov);
	},
	lookat : func(heading, pitch, roll, x, y, z, time, fov) {
		me.target_heading = me.heading_axis.static(heading);
		me.target_pitch = me.pitch_axis.static(pitch);
		me.target_roll = me.roll_axis.static(roll);
		me.target_x = me.x_axis.static(x);
		me.target_y = me.y_axis.static(y);
		me.target_z = me.z_axis.static(z);
		me.target_fov = me.fov_axis.static(fov);

		me.blendtime = time;
		me.blendN.setValue(0);
		interpolate(me.blendN, 1, me.blendtime);
	},
	resume : func {
		interpolate(me.blendN, 0, me.blendtime);
		me.blendtime = BLEND_TIME;
	},
	freeze : func {
		if (!me.frozen) {
			me.target_heading = me.heading;
			me.target_pitch = me.pitch;
			me.target_roll = me.roll;
			me.target_x = me.x;
			me.target_y = me.y;
			me.target_z = me.z;
			me.target_fov = me.fov;
			me.blendN.setDoubleValue(1);
		}
		me.frozen = me.elapsedN.getValue() + FREEZE_DURATION;
	},
	unfreeze : func {
		if (me.frozen) {
			me.frozen = 0;
			me.resume();
		}
	},
};



# default calculations for a plane
#
view_manager.default_plane = func {
	var wow = me.wow.get();

	# calculate steering factor
	var hdg = me.headingN.getValue();
	var hdiff = normdeg(me.last_heading - hdg);
	me.last_heading = hdg;
	var steering = 0; # normatan(me.hdg_change.filter(hdiff)) * me.size_factor;

	var az = me.az.get();
	var vx = me.vx.get();

	# calculate sideslip factor (zeroed when no forward ground speed)
	var wspd = me.wind_speedN.getValue();
	var wdir = me.headingN.getValue() - me.wind_dirN.getValue();
	var u = vx - wspd * cos(wdir);
	var slip = sin(me.slipN.getValue()) * me.ubody.filter(normatan(u / 10));

	me.heading_offset =							# view heading
		-15 * sin(me.roll) * cos(me.pitch)				#     due to roll
		+ 40 * steering * wow						#     due to ground steering
		+ 10 * slip * (1 - wow);					#     due to sideslip (in air)

	me.pitch_offset =							# view pitch
		10 * sin(me.roll) * sin(me.roll)				#     due to roll
		+ 30 * (1 / (1 + math.exp(2 - az))				#     due to G load
			- 0.119202922);						#         [move to origin; 1/(1+exp(2)) ]

	me.roll_offset = 0;
}



# default calculations for a helicopter
#
view_manager.default_helicopter = func {
	var lowspeed = 1 - normatan(me.speedN.getValue() / 20);

	me.heading_offset =							# view heading due to
		-50 * npow(sin(me.roll) * cos(me.pitch), 2);			#    roll

	me.pitch_offset =							# view pitch due to
		(me.pitch < 0 ? -35 : -40) * sin(me.pitch) * lowspeed		#    pitch
		+ 15 * sin(me.roll) * sin(me.roll);				#    roll

	me.roll_offset =							# view roll due to
		-15 * sin(me.roll) * cos(me.pitch) * lowspeed;			#    roll
}



# Update loop for the whole dynamic view manager. It only runs if
# /sim/current-view/dynamic-view is true.
#
var main_loop = func(id) {
	id == loop_id or return;
	if (cockpit_view and !panel_visible) {
		if (mouse_button)
			freeze();
		else
			view_manager.apply();
	}
	settimer(func { main_loop(id) }, 0);
}



var freeze = func {
	if (mouse_mode == 0)
		view_manager.freeze();
}

var register = func(f) {
	view_manager.calculate = f;
}

var reset = func {
	view_manager.reset();
}

var lookat = func {
	call(view_manager.lookat, arg, view_manager);
}

var resume = func {
	view_manager.resume();
}


var original_resetView = nil;
var panel_visibilityN = nil;
var dynamic_view = nil;

var cockpit_view = nil;
var panel_visible = nil;	# whether 2D panel is visible
var elapsedN = nil;
var mouse_mode = nil;
var mouse_button = nil;
var enabled = nil;

var loop_id = 0;


# Initialization.
#
_setlistener("/sim/signals/nasal-dir-initialized", func {
	# disable menu entry and return for inappropriate FDMs  (see Main/fg_init.cxx)
	var fdms = {
		acms:0, ada:0, balloon:0, external:0,
		jsb:1, larcsim:1, magic:0, network:0,
		null:0, pipe:0, ufo:0, yasim:1,
	};
	var fdm = getprop("/sim/flight-model");
	if (!contains(fdms, fdm) or !fdms[fdm])
		return;

	enabled = props.globals.getNode("/sim").getChildren("view");
	forindex (var i; enabled)
		enabled[i] = ((var n = enabled[i].getNode("config/dynamic-view")) != nil) and n.getBoolValue();

	# some properties may still be unavailable or nil
	props.globals.initNode("/accelerations/pilot/x-accel-fps_sec", 0);
	props.globals.initNode("/accelerations/pilot/y-accel-fps_sec", 0);
	props.globals.initNode("/accelerations/pilot/z-accel-fps_sec", -32);
	props.globals.initNode("/orientation/side-slip-deg", 0);
	props.globals.initNode("/gear/gear/wow", 1, "BOOL");
	elapsedN = props.globals.getNode("/sim/time/elapsed-sec", 1);

	# let listeners keep some variables up-to-date, so that they don't have
	# to be queried in the loop
	setlistener("/sim/panel/visibility", func(n) { panel_visible = n.getValue() }, 1);
	setlistener("/sim/current-view/view-number", func(n) { cockpit_view = enabled[n.getValue()] }, 1);
	setlistener("/devices/status/mice/mouse/button", func(n) { mouse_button = n.getValue() }, 1);
	setlistener("/devices/status/mice/mouse/x", freeze);
	setlistener("/devices/status/mice/mouse/y", freeze);
	setlistener("/devices/status/mice/mouse/mode", func(n) {
		if (mouse_mode = n.getValue())
			view_manager.unfreeze();
	}, 1);

	setlistener("/sim/signals/reinit", func(n) {
		n.getValue() and return;
		cockpit_view = enabled[getprop("/sim/current-view/view-number")];
		view_manager.reset();
	}, 0);

	view_manager.init();

	original_resetView = view.resetView;
	view.resetView = func {
		original_resetView();
		if (cockpit_view and dynamic_view)
			view_manager.add_offset();
	}

	settimer(func {
		setlistener("/sim/current-view/dynamic-view", func(n) {
			dynamic_view = n.getBoolValue();
			loop_id += 1;
			view.resetView();
			if (dynamic_view)
				main_loop(loop_id);
		}, 1);
	}, 0);
});


