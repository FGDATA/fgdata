# Failure Manager implementation
#
# Monitors trigger conditions periodically and fires failure modes when those
# conditions are met. It also provides a central access point for publishing
# failure modes to the user interface and the property tree.
#
# Copyright (C) 2014 Anton Gomez Alvedro
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


##
# Represents one way things can go wrong, for example "a blown tire".

var FailureMode = {

	##
	# id:          Unique identifier for this failure mode.
	#              eg: "engine/carburetor-ice"
	#
	# description: Short text description, suitable for printing to the user.
	#              eg: "Ice in the carburetor"
	#
	# actuator:    Object implementing the FailureActuator interface.
	#              Used by the failure manager to apply a certain level of
	#              failure to the failure mode.

	new: func(id, description, actuator) {
		return {
			parents: [FailureMode],
			id: id,
			description: description,
			actuator: actuator,
			_path: nil
		};
	},

	##
	# Applies a certain level of failure to this failure mode.
	# level: Floating point number in the range [0, 1] zero being no failure
	#        and 1 total failure.

	set_failure_level: func(level) {
		me._path != nil or
			die("FailureMode.set_failure_level: Unbound failure mode");

		setprop(me._path ~ me.id ~ "/failure-level", level);
	},

	##
	# Internal version that actually does the job.

	_set_failure_level: func(level) {
		me.actuator.set_failure_level(level);
		me._log_failure(sprintf("%s failure level %d%%",
		                        me.description, level*100));
	},

	##
	# Returns the level of failure currently being simulated.

	get_failure_level: func me.actuator.get_failure_level(),

	##
	# Creates an interface for this failure mode in the property tree at the
	# given location. Currently the interface is just:
	#
	# path/failure-level (double, rw)

	bind: func(path) {
		me._path == nil or die("FailureMode.bind: mode already bound");

		var prop = path ~ me.id ~ "/failure-level";
		props.globals.initNode(prop, me.actuator.get_failure_level(), "DOUBLE");
		setlistener(prop, func (p) me._set_failure_level(p.getValue()), 0, 0);
		me._path = path;
	},

	##
	# Remove bound properties from the property tree.

	unbind: func {
		me._path != nil and props.globals.getNode(me._path ~ me.id).remove();
		me._path = nil;
	},

	##
	# Send a message to the logging facilities, currently the screen and
	# the console.

	_log_failure: func(message) {
		print(getprop("/sim/time/gmt-string") ~ " : " ~ message);
		if (getprop(proproot ~ "/display-on-screen"))
			screen.log.write(message, 1.0, 0.0, 0.0);
	},
};

##
# Implements the FailureMgr functionality.
#
# It is wrapped into an object to leave the door open to several evolution
# approaches, for example moving the implementation down to the C++ engine,
# or supporting several independent instances of the failure manager.
# Additionally, it also serves to isolate low level implementation details
# into its own namespace.

var _failmgr = {

	timer: nil,
	update_period: 10, # 0.1 Hz
	failure_modes: {},
	pollable_trigger_count: 0,

	init: func {
		me.timer = maketimer(me.update_period, func me._update());
		setlistener("sim/signals/reinit", func me._on_reinit());

		props.globals.initNode(proproot ~ "display-on-screen", 1, "BOOL");
		props.globals.initNode(proproot ~ "enabled", 1, "BOOL");
		setlistener(proproot ~ "enabled",
		            func (n) { n.getValue() ? me._enable() : me._disable() });
	},

	##
	# Subscribe a new failure mode to the system.
	# mode: FailureMode object.

	add_failure_mode: func(mode) {
		contains(me.failure_modes, mode.id) and
			die("add_failure_mode: failure mode already exists: " ~ id);

		me.failure_modes[mode.id] = { mode: mode, trigger: nil };
		mode.bind(proproot);
	},

	##
	# Remove a failure mode from the system.
	# id: FailureMode id string, e.g. "systems/pitot"

	remove_failure_mode: func(id) {
		contains(me.failure_modes, id) or
			die("remove_failure_mode: failure mode does not exist: " ~ mode_id);

		var trigger = me.failure_modes[id].trigger;
		if (trigger != nil)
			me._discard_trigger(trigger);

		me.failure_modes[id].unbind();
		props.globals.getNode(proproot ~ id).remove();
		delete(me.failure_modes, id);
	},

	##
	# Removes all failure modes from the system.

	remove_all: func {
		foreach(var id; keys(me.failure_modes))
			me.remove_failure_mode(id);
	},

	##
	# Attach a trigger to the given failure mode. Discards the current trigger
	# if any.
	#
	# mode_id: FailureMode id string, e.g. "systems/pitot"
	# trigger: Trigger object or nil.

	set_trigger: func(mode_id, trigger) {
		contains(me.failure_modes, mode_id) or
			die("set_trigger: failure mode does not exist: " ~ mode_id);

		var mode = me.failure_modes[mode_id];

		if (mode.trigger != nil)
			me._discard_trigger(mode.trigger);

		mode.trigger = trigger;
		if (trigger == nil) return;

		trigger.bind(proproot ~ mode_id);
		trigger.on_fire = func _failmgr.on_trigger_activated(trigger);
		trigger.reset();

		if (trigger.requires_polling) {
			me.pollable_trigger_count += 1;

			if (me.enabled() and !me.timer.isRunning)
				me.timer.start();
		}

		trigger.enable();
	},

	##
	# Returns the trigger object attached to the given failure mode.
	# mode_id: FailureMode id string, e.g. "systems/pitot"

	get_trigger: func(mode_id) {
		contains(me.failure_modes, mode_id) or
			die("get_trigger: failure mode does not exist: " ~ mode_id);

		return me.failure_modes[mode_id].trigger;
	},

	##
	# Observer interface. Called from asynchronous triggers when they fire.
	# trigger: Reference to the calling trigger.

	on_trigger_activated: func(trigger) {
		var found = 0;

		foreach (var id; keys(me.failure_modes)) {
			if (me.failure_modes[id].trigger == trigger) {
				me.failure_modes[id].mode.set_failure_level(1);
				found = 1;
				break;
			}
		}

		found or die("FailureMgr.on_trigger_activated: trigger not found");
	},

	##
	# Enable the failure manager.

	_enable: func {
		foreach(var id; keys(me.failure_modes)) {
			var trigger = me.failure_modes[id].trigger;
			trigger != nil and trigger.enable();
		}

		if (me.pollable_trigger_count > 0)
			me.timer.start();
	},

	##
	# Suspends failure manager activity. Pollable triggers will not be updated
	# and all triggers will be disabled.

	_disable: func {
		me.timer.stop();

		foreach(var id; keys(me.failure_modes)) {
			var trigger = me.failure_modes[id].trigger;
			trigger != nil and trigger.disable();
		}

	},

	##
	# Returns enabled status.

	enabled: func {
		getprop(proproot ~ "enabled");
	},

	##
	# Poll loop. Updates pollable triggers and applies a failure level
	# when they fire.

	_update: func {
		foreach (var id; keys(me.failure_modes)) {
			var failure = me.failure_modes[id];

			if (failure.trigger != nil and !failure.trigger.fired) {
				var level = failure.trigger.update();
				if (level > 0 and level != failure.mode.get_failure_level())
					failure.mode.set_failure_level(level);
			}
		}
	},

	##
	# Detaches a trigger from the system.

	_discard_trigger: func(trigger) {
		trigger.disable();
		trigger.unbind();

		if (trigger.requires_polling) {
			me.pollable_trigger_count -= 1;
			me.pollable_trigger_count == 0 and me.timer.stop();
		}
	},

	##
	# Reinit listener. Sets all failure modes to "working fine".

	_on_reinit: func {
		foreach (var id; keys(me.failure_modes)) {
			var failure = me.failure_modes[id];

			failure.mode.set_failure_level(0);

			if (failure.trigger != nil) {
				me._discard_trigger(failure.trigger);
				failure.trigger = nil;
			}
		}
	}
};

##
# Module initialization

var _init = func {
	removelistener(lsnr);
	_failmgr.init();

	# Load legacy failure modes for backwards compatibility
	io.load_nasal(getprop("/sim/fg-root") ~
	              "/Aircraft/Generic/Systems/compat_failure_modes.nas");
}

var lsnr = setlistener("/nasal/FailureMgr/loaded", _init);
