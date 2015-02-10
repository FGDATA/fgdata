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

var TestAltitudeTrigger = {

	parents: [TestSuite],

	setup: func {
		props.globals.initNode("/test");
	},

	cleanup: func {
		me.trigger = nil;
		props.globals.getNode("/test").remove();
	},

	test_binding: func {

		setprop("/test/foreign-property", 25);

		me.trigger = AltitudeTrigger.new(100, 200);
		me.trigger.bind("/test/");

		assert_prop_exists("/test/reset");
		assert_prop_exists("/test/min-altitude-ft");
		assert_prop_exists("/test/min-altitude-ft");

		me.trigger.unbind();

		fail_if_prop_exists("/test/reset");
		fail_if_prop_exists("/test/min-altitude-ft");
		fail_if_prop_exists("/test/min-altitude-ft");

		assert_prop_exists("/test/foreign-property");
	},

	test_props_are_read_on_reset: func {

		me.trigger = AltitudeTrigger.new(100, 200);
		me.trigger.bind("/test/");

		assert(me.trigger.params["min-altitude-ft"] == 100);
		assert(me.trigger.params["max-altitude-ft"] == 200);

		setprop("/test/min-altitude-ft", 1000);
		setprop("/test/max-altitude-ft", 2000);

		assert(me.trigger.params["min-altitude-ft"] == 100);
		assert(me.trigger.params["max-altitude-ft"] == 200);

		me.trigger.reset();

		assert(me.trigger.params["min-altitude-ft"] == 1000);
		assert(me.trigger.params["max-altitude-ft"] == 2000);
	},

	test_trigger_fires_within_min_and_max: func {

		me.trigger = AltitudeTrigger.new(100, 200);

		me.trigger._altitude_prop = "/test/fake-altitude-ft";
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 0);
		assert(me.trigger.update() == 0);
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 300);
		assert(me.trigger.update() == 0);
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 150);
		assert(me.trigger.update() == 1);
		assert(me.trigger.fired);
	},

	test_trigger_accepts_nil_max: func {

		me.trigger = AltitudeTrigger.new(500, nil);
		me.trigger._altitude_prop = "/test/fake-altitude-ft";
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", -250);
		assert(me.trigger.update() == 0);
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 0);
		assert(me.trigger.update() == 0);
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 250);
		assert(me.trigger.update() == 0);
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 750);
		assert(me.trigger.update() == 1);
		assert(me.trigger.fired);
	},

	test_trigger_accepts_nil_min: func {

		me.trigger = AltitudeTrigger.new(nil, 500);
		me.trigger._altitude_prop = "/test/fake-altitude-ft";
		me.trigger.bind("/test/trigger/");

		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 750);
		assert(me.trigger.update() == 0);
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 500);
		assert(me.trigger.update() == 0);
		assert(!me.trigger.fired);

		setprop("/test/fake-altitude-ft", 250);
		assert(me.trigger.update() == 1);
		assert(me.trigger.fired);

		me.trigger.reset();

		setprop("/test/fake-altitude-ft", -250);
		assert(me.trigger.update() == 1);
		assert(me.trigger.fired);
	},

	test_trigger_dies_if_both_params_are_nil: func {
		call(AltitudeTrigger.new, [nil, nil], AltitudeTrigger, var err = []);
		assert(size(err) > 0);
	},

	test_to_str: func {
		me.trigger = AltitudeTrigger.new(100, 200);
		call(me.trigger.to_str, [], me.trigger, var err = []);
		assert(size(err) == 0);
	}
};
