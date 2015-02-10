# CycleCounter unit tests
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

var TestCycleCounter = {

	parents: [TestSuite],

	setup: func {
		props.globals.initNode("/test");
	},

	cleanup: func {
		props.globals.getNode("/test").remove();
		me.counter = nil;
	},

	_shake_that_prop: func (pattern=nil) {

		if (pattern == nil)
			pattern = [0, -10, 10, -10, 10, -10, 10, 0];

		setprop("/test/property", pattern[0]);
		me.counter.reset();

		var i = 0;
		var value = pattern[0];
		var target = pattern[1];
		var delta = 0;

		while(i < size(pattern) - 1) {

			target = pattern[i+1];
			delta = pattern[i+1] > pattern[i] ? 1 : -1;

			while(value != target) {
				value += delta;
				setprop("/test/property", value);
			}

			i += 1;
		}
	},

	test_cycles_dont_grow_while_disabled: func {
		me.counter = CycleCounter.new("/test/property");
		me._shake_that_prop();
		assert(me.counter.cycles == 0);
	},

	test_cycles_grow_while_enabled: func {
		me.counter = CycleCounter.new("/test/property");

		me._shake_that_prop();
		assert(me.counter.cycles == 0);

		me.counter.enable();

		me._shake_that_prop();
		assert(me.counter.cycles == 3);
	},

	test_reset: func {
		me.counter = CycleCounter.new("/test/property");
		me.counter.enable();

		me._shake_that_prop();
		assert(me.counter.cycles > 0);

		me.counter.reset();
		assert(me.counter.cycles == 0);
	},

	test_callback_every_half_cycle: func {
		var count = 0;

		me.counter = CycleCounter.new(
			property: "/test/property",
			on_update: func (cycles) { count += 1 });

		me.counter.enable();
		me._shake_that_prop();

		assert(count == 6);
	},

	test_callback_reports_cycle_count: func {
		var count = 0;
		var cb = func (cycles) {
			count += 1;
			assert(cycles == count * 0.5);
		};

		me.counter = CycleCounter.new(
			property: "/test/property", on_update: cb);

		me.counter.enable();
		me._shake_that_prop();
	},

	test_counter_works_for_binary_props: func {
		me.counter = CycleCounter.new("/test/property");
		me.counter.enable();
		me._shake_that_prop([0, 1, 0, 1, 0, 1]);
		assert(me.counter.cycles == 2);
	}
};
