# AltitudeTrigger unit tests
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

io.include("Aircraft/Generic/Systems/Tests/test.nas");
io.include("Aircraft/Generic/Systems/failures.nas");

var TestFailureMode = {

	parents: [TestSuite],

	setup: func {
		props.globals.initNode("/test");
	},

	cleanup: func {
		me.mode = nil;
		props.globals.getNode("/test").remove();
	},

	test_binding: func {
		var actuator = { parents: [FailureMgr.FailureActuator] };
		setprop("/test/foreign-property", 25);

		me.mode = FailureMgr.FailureMode.new(
			id: "instruments/compass",
			description: "a description",
			actuator: actuator);

		me.mode.bind("/test/");
		assert_prop_exists("/test/instruments/compass/failure-level");

		me.mode.unbind();
		fail_if_prop_exists("/test/instruments/compass/failure-level");
		fail_if_prop_exists("/test/instruments/compass");
		assert_prop_exists("/test/foreign-property");
	},

	test_set_failure_level_calls_actuator: func {
		var level = 0;
		var actuator = {
			parents: [FailureMgr.FailureActuator],
			set_failure_level: func (l) { level = l },
		};

		me.mode = FailureMgr.FailureMode.new(
			id: "instruments/compass",
			description: "a description",
			actuator: actuator);
		me.mode.bind("/test/");

		me.mode.set_failure_level(1);
		assert(level == 1);
	},

	test_actuator_gets_called_from_prop: func {
		var level = 0;
		var actuator = {
			parents: [FailureMgr.FailureActuator],
			set_failure_level: func (l) { level = l },
		};

		me.mode = FailureMgr.FailureMode.new(
			id: "instruments/compass",
			description: "a description",
			actuator: actuator);

		me.mode.bind("/test/");
		setprop("/test/instruments/compass/failure-level", 1);
		assert(level == 1);
	},

	test_setting_level_from_nasal_is_shown_in_prop: func {
		var level = 0;
		var actuator = {
			parents: [FailureMgr.FailureActuator],
			set_failure_level: func (l) { level = l },
		};

		me.mode = FailureMgr.FailureMode.new(
			id: "instruments/compass",
			description: "a description",
			actuator: actuator);

		me.mode.bind("/test/");

		me.mode.set_failure_level(1);
		assert(level == 1);

		var prop_value = getprop("/test/instruments/compass/failure-level");
		assert(prop_value == 1);

		me.mode.set_failure_level(0.5);
		assert(level == 0.5);

		prop_value = getprop("/test/instruments/compass/failure-level");
		assert(prop_value == 0.5);
	}
};
