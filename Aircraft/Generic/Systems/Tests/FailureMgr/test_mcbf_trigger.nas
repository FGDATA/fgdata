# McbfTrigger unit tests
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

var TestMcbfTrigger = {

	parents: [TestSuite],

	setup: func {
		props.globals.initNode("/test");
	},

	cleanup: func {
		me.trigger = nil;
		props.globals.getNode("/test").remove();
	},

	_do_one_cycle: func (prop) {
		setprop(prop, 10);
		setprop(prop, -10);
		setprop(prop, 0);
	},

	test_binding: func {
		setprop("/test/property", 0);

		me.trigger = McbfTrigger.new("/test/property", 3);
		me.trigger.bind("/test/");

		assert_prop_exists("/test/reset");
		assert_prop_exists("/test/mcbf");

		me.trigger.unbind();
		fail_if_prop_exists("/test/reset");
		fail_if_prop_exists("/test/mcbf");
		assert_prop_exists("/test/property");
	},

	test_trigger_fires_after_activation_cycles: func {
		setprop("/test/property", 25);
		me.trigger = McbfTrigger.new("/test/property", 3);
		me.trigger.activation_cycles = 3;
		me.trigger.enable();

		assert(!me.trigger.fired);

		for (var i = 1; i < 5; i += 1) {
			me._do_one_cycle("/test/property");
			assert(me.trigger.fired == (i > 3));
		}
	},

	test_trigger_notifies_observer_once: func {
		var observer_called = 0;
		var on_fire = func observer_called += 1;

		setprop("/test/property", 25);
		me.trigger = McbfTrigger.new("/test/property", 3);
		me.trigger.activation_cycles = 3;
		me.trigger.on_fire = on_fire;
		me.trigger.enable();

		assert(!me.trigger.fired);

		for (var i = 1; i < 5; i += 1)
			me._do_one_cycle("/test/property");

		assert(observer_called == 1);
	},

	test_reset: func {
		setprop("/test/property", 25);
		me.trigger = McbfTrigger.new("/test/property", 3);
		me.trigger.activation_cycles = 3;
		me.trigger.bind("/test");
		me.trigger.enable();

		for (var i = 1; i < 5; i += 1)
			me._do_one_cycle("/test/property");

		assert(me.trigger.fired);

		me.trigger.reset();
		me.trigger.activation_cycles = 3;

		assert(!me.trigger.fired);

		for (var i = 1; i < 5; i += 1) {
			me._do_one_cycle("/test/property");
			assert(me.trigger.fired == (i > 3));
		}
	},

	test_to_str: func {
		me.trigger = McbfTrigger.new("/test/property", 3);
		call(me.trigger.to_str, [], me.trigger, var err = []);
		assert(size(err) == 0);
	}
};
