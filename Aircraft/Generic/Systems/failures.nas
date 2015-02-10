# Failure simulation library
#
# Collection of generic Triggers and FailureActuators for programming the
# FailureMgr Nasal module.
#
# Copyright (C) 2014 Anton Gomez Alvedro
# Based on previous work by Stuart Buchanan, Erobo & John Denker
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.


#
# Functions for generating FailureActuators
# ------------------------------------------

##
# Returns an actuator object that will set the serviceable property at
# the given node to zero when the level of failure is > 0.

var set_unserviceable = func(path) {

	var prop = path ~ "/serviceable";

	if (props.globals.getNode(prop) == nil)
		props.globals.initNode(prop, 1, "BOOL");

	return {
		parents: [FailureMgr.FailureActuator],
		set_failure_level: func(level) setprop(prop, level > 0 ? 0 : 1),
		get_failure_level: func { getprop(prop) ? 0 : 1 }
	}
}

##
# Returns an actuator object that will make the given property read only.
# This prevents any other system from updating it, and effectively jamming
# whatever it is that is controlling.

var set_readonly = func(property) {
	return {
		parents: [FailureMgr.FailureActuator],

		set_failure_level: func(level) {
			var pnode = props.globals.getNode(property);
			pnode.setAttribute("writable", level > 0 ? 0 : 1);
		},

		get_failure_level: func {
			var pnode = props.globals.getNode(property);
			pnode.getAttribute("writable") ? 0 : 1;
		}
	}
}

##
# Returns an an actuator object the manipulates engine controls (magnetos &
# cutoff) to simulate an engine failure. Sets these properties to read only
# while the system is failed.

var fail_engine = func(engine) {
	return {
		parents: [FailureMgr.FailureActuator],
		level: 0,
		magnetos: props.globals.getNode("/controls/engines/" ~ engine ~ "/magnetos", 1),
		cutoff: props.globals.getNode("/controls/engines/" ~ engine ~ "/cutoff", 1),

		get_failure_level: func me.level,

		set_failure_level: func(level) {
			if (level) {
				# Switch off the engine, and disable writing to it.
				me.magnetos.setValue(0);
				me.magnetos.setAttribute("writable", 0);
				me.cutoff.setValue(1);
				me.cutoff.setAttribute("writable", 0);
			}
			else {
				# Enable the properties, but don't set the magnetos, as they may
				# be off for a reason.
				me.magnetos.setAttribute("writable", 1);
				me.cutoff.setAttribute("writable", 1);
				me.cutoff.setValue(0);
			}
			me.level = level;
		}
	}
}


#
# Triggers
# ---------

##
# Returns a random number from a Normal distribution with given mean and
# standard deviation.

var norm_rand = func(mean, std) {
	var r = -2 * math.ln(1 - rand());
	var a = 2 * math.pi * (1 - rand());
	return mean + (math.sqrt(r) * math.sin(a) * std);
};

##
# Trigger object that will fire when aircraft altitude is between
# min and max, both specified in feet. One of min or max may be nil for
# expressing "altitude > x" or "altitude < x" conditions.

var AltitudeTrigger = {

	parents: [FailureMgr.Trigger],
	requires_polling: 1,

	new: func(min, max) {
		min != nil or max != nil or
			die("AltitudeTrigger.new: either min or max must be specified");

		var m = FailureMgr.Trigger.new();
		m.parents = [AltitudeTrigger];
		m.params["min-altitude-ft"] = min;
		m.params["max-altitude-ft"] = max;
		m._altitude_prop = "/position/altitude-ft";
		return m;
	},

	to_str: func {
		# TODO: Handle min or max == nil
		sprintf("Altitude between %d and %d ft",
			int(me.params["min-altitude-ft"]), int(me.params["max-altitude-ft"]))
	},

	update: func {
		var alt = getprop(me._altitude_prop);

		var min = me.params["min-altitude-ft"];
		var max = me.params["max-altitude-ft"];

		me.fired = min != nil ? min < alt : 1;
		me.fired = max != nil ? me.fired and alt < max : me.fired;
	}
};

##
# Trigger object that fires when the aircraft's position is within a certain
# distance of a given waypoint.

var WaypointTrigger = {

	parents: [FailureMgr.Trigger],
	requires_polling: 1,

	new: func(lat, lon, distance) {
		var wp = geo.Coord.new();
		wp.set_latlon(lat, lon);

		var m = FailureMgr.Trigger.new();
		m.parents = [WaypointTrigger];
		m.params["latitude-deg"] = lat;
		m.params["longitude-deg"] = lon;
		m.params["distance-nm"] = distance;
		m.waypoint = wp;
		return m;
	},

	reset: func {
		call(FailureMgr.Trigger.reset, [], me);
		me.waypoint.set_latlon(me.params["latitude-deg"],
		                       me.params["longitude-deg"]);
	},

	to_str: func {
		sprintf("Within %.2f miles of %s", me.params["distance-nm"],
			    geo.format(me.waypoint.lat, me.waypoint.lon));
	},

	update: func {
		var d = geo.aircraft_position().distance_to(me.waypoint) * M2NM;
		me.fired = d < me.params["distance-nm"];
	}
};

##
# Trigger object that will fire on average after the specified time.

var MtbfTrigger = {

	parents: [FailureMgr.Trigger],
	# TODO: make this trigger async
	requires_polling: 1,

	new: func(mtbf) {
		var m = FailureMgr.Trigger.new();
		m.parents = [MtbfTrigger];
		m.params["mtbf"] = mtbf;
		m.fire_time = 0;
		m._time_prop = "/sim/time/elapsed-sec";
		return m;
	},

	reset: func {
		call(FailureMgr.Trigger.reset, [], me);
		# TODO: use an elapsed time prop that accounts for speed-up and pause
		me.fire_time = getprop(me._time_prop)
		               + norm_rand(me.params["mtbf"], me.params["mtbf"] / 10);
	},

	to_str: func {
		sprintf("Mean time between failures: %f.1 mins", me.params["mtbf"] / 60);
	},

	update: func {
		me.fired = getprop(me._time_prop) > me.fire_time;
	}
};

##
# Trigger object that will fire exactly after the given timeout.

var TimeoutTrigger = {

	parents: [FailureMgr.Trigger],
	# TODO: make this trigger async
	requires_polling: 1,

	new: func(timeout) {
		var m = FailureMgr.Trigger.new();
		m.parents = [TimeoutTrigger];
		m.params["timeout-sec"] = timeout;
		fire_time = 0;
		return m;
	},

	reset: func {
		call(FailureMgr.Trigger.reset, [], me);
		# TODO: use an elapsed time prop that accounts for speed-up and pause
		me.fire_time = getprop("/sim/time/elapsed-sec")
		               + me.params["timeout-sec"];
	},

	to_str: func {
		sprintf("Fixed delay: %d minutes", me.params["timeout-sec"] / 60);
	},

	update: func {
		me.fired = getprop("/sim/time/elapsed-sec") > me.fire_time;
	}
};

##
# Simple approach to count usage cycles for a given property. Every time
# the propery variation changes in direction, we count half a cycle.
# If the property represents aileron angular position, for example, this
# would count roughly the number of times the aileron has been actuated.

var CycleCounter = {

	new: func(property, on_update = nil) {
		return {
			parents: [CycleCounter],
			cycles: 0,
			_property: property,
			_on_update: on_update,
			_prev_value: getprop(property),
			_prev_delta: 0,
			_lsnr: nil
		};
	},

	enable: func {
		if (me._lsnr == nil)
			me._lsnr = setlistener(me._property, func (p) me._on_prop_change(p), 0, 0);
	},

	disable: func {
		if (me._lsnr != nil) removelistener(me._lsnr);
	},

	reset: func {
		me.cycles = 0;
		me._prev_value = getprop(me._property);
		me._prev_delta = 0;
	},

	_on_prop_change: func(prop) {

		# TODO: Implement a filter for avoiding spureous values.

		var value = prop.getValue();
		var delta = value - me._prev_value;
		if (delta == 0) return;

		if (delta * me._prev_delta < 0) {
			# Property variation has changed direction
			me.cycles += 0.5;
			if (me._on_update != nil) me._on_update(me.cycles);
		}

		me._prev_delta = delta;
		me._prev_value = value;
	}
};

##
# Trigger object that will fire on average after a property has gone through
# mcbf (mean cycles between failures) cycles.

var McbfTrigger = {

	parents: [FailureMgr.Trigger],
	requires_polling: 0,

	new: func(property, mcbf) {
		var m = FailureMgr.Trigger.new();
		m.parents = [McbfTrigger];
		m.params["mcbf"] = mcbf;
		m.counter = CycleCounter.new(property, func(c) call(m._on_cycle, [c], m));
		m.activation_cycles = 0;
		m.enabled = 0;
		return m;
	},

	enable: func {
		me.counter.enable();
		me.enabled = 1;
	},

	disable: func {
		me.counter.disable();
		me.enabled = 0;
	},

	reset: func {
		call(FailureMgr.Trigger.reset, [], me);
		me.counter.reset();
		me.activation_cycles =
			norm_rand(me.params["mcbf"], me.params["mcbf"] / 10);

		me.enabled and me.counter.enable();
	},

	to_str: func {
		sprintf("Mean cycles between failures: %.2f", me.params["mcbf"]);
	},

	_on_cycle: func(cycles) {
		if (!me.fired and cycles > me.activation_cycles) {
			# TODO: Why this doesn't work?
			# me.counter.disable();
			me.fired = 1;
			me.on_fire();
		}
	}
};
