# Failure Manager public interface
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


var proproot = "sim/failure-manager/";


##
# Subscribe a new failure mode to the system.
#
# id:          Unique identifier for this failure mode.
#              eg: "engine/carburetor-ice"
#
# description: Short text description, suitable for printing to the user.
#              eg: "Ice in the carburetor"
#
# actuator:    Object implementing the FailureActuator interface.
#              Used by the failure manager to apply a certain level of
#              failure to the failure mode.

var add_failure_mode = func(id, description, actuator) {
	_failmgr.add_failure_mode(
		FailureMode.new(id, description, actuator));
}

##
# Remove a failure mode from the system.
# id: FailureMode id string, e.g. "systems/pitot"

var remove_failure_mode = func(id) {
	_failmgr.remove_failure_mode(id);
}

##
# Removes all failure modes from the failure manager.

var remove_all = func {
	_failmgr.remove_all();
}

##
# Attaches a trigger to the given failure mode. Discards the current trigger
# if any.
#
# mode_id: FailureMode id string, e.g. "systems/pitot"
# trigger: Trigger object or nil. Nil will just detach the current trigger

var set_trigger = func(mode_id, trigger) {
	_failmgr.set_trigger(mode_id, trigger);
}

##
# Returns the trigger object attached to the given failure mode.
# mode_id: FailureMode id string, e.g. "systems/pitot"

var get_trigger = func(mode_id) {
	_failmgr.get_trigger(mode_id);
}

##
# Applies a certain level of failure to this failure mode.
#
# mode_id: Failure mode id string.
# level:   Floating point number in the range [0, 1]
#          Zero represents no failure and one means total failure.

var set_failure_level = func (mode_id, level) {
	setprop(proproot ~ mode_id ~ "/failure-level", level);
}

##
# Allows applications to disable the failure manager and restore it later on.
# While disabled, no failure modes will be activated from the failure manager.

var enable = func setprop(proproot ~ "enabled", 1);
var disable = func setprop(proproot ~ "enabled", 0);

##
# Encapsulates a condition that when met, will make the failure manager to
# apply a certain level of failure to the failure mode it is bound to.
#
# Two types of triggers are supported: pollable and asynchronous.
#
# Pollable triggers require periodic check for trigger conditions. For example,
# an altitude trigger will need to poll current altitude until the fire
# condition is reached.
#
# Asynchronous trigger do not require periodic updates. They can detect
# the firing condition by themselves by using timers or listeners.
# Async triggers must call the inherited method on_fire() to let the Failure
# Manager know about the fired condition.
#
# See Aircraft/Generic/Systems/failures.nas for concrete examples of triggers.

var Trigger = {

	# 1 for pollable triggers, 0 for async triggers.
	requires_polling: 0,

	new: func {
		return {
			parents: [Trigger],
			params: {},
			fired: 0,

			##
			# Async triggers shall call the on_fire() callback when their fire
			# conditions are met to notify the failure manager.
			on_fire: func 0,

			_path: nil
		};
	},

	##
	# Enables/disables the trigger. While a trigger is disabled, any timer
	# or listener that could potentially own shall be disabled.

	enable: func,
	disable: func,

	##
	# Forces a check of the firing conditions. Returns 1 if the trigger fired,
	# 0 otherwise.

	update: func 0,

	##
	# Returns a printable string describing the trigger condition.

	to_str: func "undefined trigger",

	##
	# Modify a trigger parameter. Parameters will take effect after the next
	# call to reset()

	set_param: func(param, value) {
		contains(me.params, param) or
			die("Trigger.set_param: undefined param: " ~ param);

		me._path != nil or
			die("Trigger.set_param: Unbound trigger");

		setprop(sprintf("%s/%s",me._path, param), value);
	},

	##
	# Reload trigger parameters and reset internal state, i.e. start from
	# scratch. If the trigger was fired, the trigger is set to not fired.

	reset: func {
		me._path or die("Trigger.reset: unbound trigger");

		foreach (var p; keys(me.params))
			me.params[p] = getprop(sprintf("%s/%s", me._path, p));

		me.fired = 0;
		me._path != nil and setprop(me._path ~ "/reset", 0);
	},

	##
	# Creates an interface for the trigger in the property tree.
	# Every parameter in the params hash will be exposed, in addition to
	# a path/reset property for resetting the trigger from the prop tree.

	bind: func(path) {
		me._path == nil or
			die("Trigger.bind(): attempt to bind an already bound trigger");

		me._path = path;
		props.globals.getNode(path) != nil or props.globals.initNode(path);
		props.globals.getNode(path).setValues(me.params);

		var reset_prop = path ~ "/reset";
		props.globals.initNode(reset_prop, 0, "BOOL");
		setlistener(reset_prop, func me.reset(), 0, 0);
	},

	##
	# Removes this trigger's interface from the property tree.

	unbind: func {
		props.globals.getNode(me._path ~ "/reset").remove();
		foreach (var p; keys(me.params))
			props.globals.getNode(me._path ~ "/" ~ p).remove();

		me._path = nil;
	}
};

##
# FailureActuators encapsulate the actions required for activating the actual
# failure simulation.
#
# Traditionally this action was just manipulating a "serviceable" property
# somewhere, but the FailureActuator gives you more flexibility, allowing you
# to touch several properties at once or call other Nasal scripts, for example.
#
# See Aircraft/Generic/Systems/failure.nas and
# Aircraft/Generic/Systems/compat_failures.nas for some examples of actuators.

var FailureActuator = {

	##
	# Called from the failure manager to activate a certain level of failure.
	# level: Target level of failure [0 to 1].

	set_failure_level: func(level) 0,

	##
	# Returns the level of failure that is currently being simulated.

	get_failure_level: func 0,
};
