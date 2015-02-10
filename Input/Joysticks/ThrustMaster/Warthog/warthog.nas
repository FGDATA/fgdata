# Hardware Interface (currently Linux/HIDRAW-only)
# see README and http://members.aon.at/mfranz/warthog.html


if (io.stat("/dev/input") != nil and io.stat("/dev/input/hidraw") == nil) {
	print("warthog: read file $FG_ROOT/Input/Joysticks/ThrustMaster/Warthog/README");
	print("         for how to enable FlightGear to set backlight and LEDs etc.");
}


var device = {
	new: func(path, bufsize) {
		var m = { parents: [device] };
		m.path = path;
		m.bufsize = bufsize;
		m.data = bits.buf(m.bufsize);
		var stat = io.stat(m.path);
		if (stat == nil or stat[11] != "chr")
			m.send = m.receive = func {};
		return m;
	},
	send: func {
		var buf = bits.buf(me.bufsize);
		forindex (var i; arg)
			buf[i] = arg[i];
		var file = io.open(me.path, "wb");
		io.write(file, buf);
		io.close(file);
	},
	receive: func {
		var file = io.open(me.path, "rb");
		io.read(file, me.data, me.bufsize);
		io.close(file);
	},
};


var joystick = {
	parents: [device.new("/dev/input/hidraw/Thustmaster_Joystick_-_HOTAS_Warthog", 12)],
	init: func {
		me.receive();
	},
};


var throttle = {
	parents: [device.new("/dev/input/hidraw/Thrustmaster_Throttle_-_HOTAS_Warthog", 36)],
	init: func {
		me.receive();
		me.leds = me.data[26];
		me.brightness = me.data[27];
	},
	set_leds: func(state, which...) { # on/off, list of leds (0: background, 1-5)
		var leds = me.leds;
		foreach (var w; which)
			me.leds = bits.switch(me.leds, me._ledmap[w], state);
		if (me.leds != leds)
			me.send(1, 6, me.leds, me.brightness);
	},
	toggle_leds: func(which...) {
		foreach (var w; which)
			me.leds = bits.toggle(me.leds, me._ledmap[w]);
		me.send(1, 6, me.leds, me.brightness);
	},
	set_brightness: func(v) { # clamped to [0,5], where 0 is off and 5 is bright
		if (v != me.brightness)
			me.send(1, 6, me.leds, me.brightness = v < 0 ? 0 : v > 5 ? 5 : v);
	},
	brighter: func {
		me.leds = bits.set(me.leds, me._ledmap[0]);
		me.set_brightness(me.brightness + 1);
	},
	darker: func {
		me.leds = bits.set(me.leds, me._ledmap[0]);
		me.set_brightness(me.brightness - 1);
	},
	_ledmap: {0: 3, 1: 2, 2: 1, 3: 4, 4: 0, 5: 6},
};


joystick.init();
throttle.init();                # read configuration

throttle.set_brightness(1);     # LEDs dark (but on)
throttle.set_leds(1, 0);        # backlight on
setlistener("/sim/signals/exit", func throttle.set_leds(0, 1, 2, 3, 4, 5), 1); # other LEDs off (now and at exit)
