# MtbfTrigger unit tests
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

var TestMtbfTrigger = {

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

		me.trigger = MtbfTrigger.new(60);
		me.trigger.bind("/test/");

		assert_prop_exists("/test/reset");
		assert_prop_exists("/test/mtbf");

		me.trigger.unbind();

		fail_if_prop_exists("/test/reset");
		fail_if_prop_exists("/test/mtbf");

		assert_prop_exists("/test/foreign-property");
	},

	test_props_are_read_on_reset: func {

		me.trigger = MtbfTrigger.new(60);
		me.trigger.bind("/test/");
		assert(me.trigger.params["mtbf"] == 60);

		setprop("/test/mtbf", 120);
		assert(me.trigger.params["mtbf"] == 60);

		me.trigger.reset();
		assert(me.trigger.params["mtbf"] == 120);
	},

	test_trigger_fires_after_fire_time: func {

		me.trigger = MtbfTrigger.new(60);
		me.trigger._time_prop = "/test/fake-time-sec";
		me.trigger.fire_time = 60;
		assert(!me.trigger.fired);

		setprop("/test/fake-time-sec", 50);
		assert(me.trigger.update() == 0);
		assert(!me.trigger.fired);

		setprop("/test/fake-time-sec", 70);
		assert(me.trigger.update() == 1);
		assert(me.trigger.fired);
	},

	test_to_str: func {
		me.trigger = MtbfTrigger.new(60);
		call(me.trigger.to_str, [], me.trigger, var err = []);
		assert(size(err) == 0);
	}
};
