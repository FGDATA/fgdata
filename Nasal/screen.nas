# on-screen displays
#==============================================================================


##
# convert string for output; replaces tabs by spaces, and skips
# delimiters and the voice part in "{text|voice}" constructions
#
var sanitize = func(s, newline = 0) {
	var r = "";
	var skip = 0;
	s ~= "";
	for (var i = 0; i < size(s); i += 1) {
		var c = s[i];
		if (c == `\t`)
			r ~= ' ';
		elsif (c == `{`)
			nil;
		elsif (c == `|`)
			skip = 1;
		elsif (c == `}`)
			skip = 0;
		elsif (c == `\n` and newline)
			r ~= "\\n";
		elsif (!skip)
			r ~= chr(c);
	}
	return r;
}



var theme_font = nil;



# screen.window
#------------------------------------------------------------------------------
# Class that manages a dialog with fixed number of lines, where you can push in
# text at the bottom, which then (optionally) scrolls up after some time.
#
# simple use:
#
#     var window = screen.window.new();
#     window.write("message in the middle of the screen");
#
#
# advanced use:
#
#     var window = screen.window.new(nil, -100, 3, 10);
#     window.fg = [1, 1, 1, 1];    # choose white default color
#     window.align = "left";
#
#     window.write("first line");
#     window.write("second line (red)", 1, 0, 0);
#
#
#
# arguments:
#            x ... x coordinate
#            y ... y coordinate
#                  positive coords position relative to the left/lower corner,
#                  negative coords from the right/upper corner, nil centers
#     maxlines ... max number of displayed lines; if more are pushed into the
#                  screen, then the ones on top fall off
#   autoscroll ... seconds that each line should be shown; can be less if
#                  a message falls off; if 0 then don't scroll at all
#
var window = {
	id : 0,
	new : func(x = nil, y = nil, maxlines = 10, autoscroll = 10) {
		var m = { parents: [window] };
		#
		# "public"
		m.x = x;
		m.y = y;
		m.maxlines = maxlines;
		m.autoscroll = autoscroll;	# display time in seconds
		m.sticky = 0;			# reopens on old place
		m.font = nil;
		m.bg = [0, 0, 0, 0];		# background color
		m.fg = [0.9, 0.4, 0.2, 1];	# default foreground color
		m.align = "center";		# "left", "right", "center"
		#
		# "private"
		m.name = "__screen_window_" ~ (window.id += 1) ~ "__";
		m.lines = [];
		m.skiptimer = 0;
		m.dialog = nil;
		m.namenode = props.Node.new({ "dialog-name": m.name });
		m.writebuffer = [];
		m.MAX_BUFFER_SIZE = 50;
		setlistener("/sim/startup/xsize", func m._redraw_());
		setlistener("/sim/startup/ysize", func m._redraw_());
		return m;
	},
	write : func(msg, r = nil, g = nil, b = nil, a = nil) {
		if (me.namenode == nil)
			return;
		if (size(me.writebuffer) > me.MAX_BUFFER_SIZE)
			return;
		if (r == nil)
			r = me.fg[0];
		if (g == nil)
			g = me.fg[1];
		if (b == nil)
			b = me.fg[2];
		if (a == nil)
			a = me.fg[3];
		var lines = [];
		foreach (var line; split("\n", string.trim(msg ~ ""))) {
			line = sanitize(string.trim(line));
			append(lines, [line, r, g, b, a]);
		}
		if (size(me.writebuffer) == 0)
			settimer(func { me._write_(); } , 0, 1);
		append(me.writebuffer, lines);
	},
	clear : func() {
	  me.lines = [];
	  me.writebuffer = [];
	  me.show();
	},
	show : func {
		if (me.dialog != nil)
			me.close();

		me.dialog = gui.Widget.new();
		me.dialog.set("name", me.name);
		if (me.x != nil)
			me.dialog.set("x", me.x);
		if (me.y != nil)
			me.dialog.set("y", me.y);
		me.dialog.set("layout", "vbox");
		me.dialog.set("default-padding", 2);
		if (me.font != nil)
			me.dialog.setFont(me.font);
		elsif (theme_font != nil)
			me.dialog.setFont(theme_font);

		me.dialog.setColor(me.bg[0], me.bg[1], me.bg[2], me.bg[3]);

		foreach (var line; me.lines) {
			var w = me.dialog.addChild("text");
			w.set("halign", me.align);
			w.set("label", line[0]);
			w.setColor(line[1], line[2], line[3], line[4]);
		}

		fgcommand("dialog-new", me.dialog.prop());
		fgcommand("dialog-show", me.namenode);
	},
	close : func {
		fgcommand("dialog-close", me.namenode);
		if (me.dialog != nil and me.sticky) {
			me.x = me.dialog.prop().getNode("lastx").getValue();
			me.y = me.dialog.prop().getNode("lasty").getValue();
		}
	},
	_write_ : func() {
		if (size(me.writebuffer) == 0)
			return;
		foreach (var msg; me.writebuffer) {
			foreach (var line; msg) {
				append(me.lines, line);
				if (size(me.lines) > me.maxlines) {
					me.lines = subvec(me.lines, 1);
					if (me.autoscroll)
						me.skiptimer += 1;
				}
				if (me.autoscroll)
					settimer(func me._timeout_(), me.autoscroll, 1);
			}
		}
		me.writebuffer = [];
		me.show();
	},
	_timeout_ : func {
		if (me.skiptimer > 0) {
			me.skiptimer -= 1;
			return;
		}
		if (size(me.lines) > 1) {
			me.lines = subvec(me.lines, 1);
			me.show();
		} else {
			me.close();
			me.dialog = nil;
			me.lines = [];
		}
	},
	_redraw_ : func {
		if (me.dialog != nil) {
			me.close();
			me.show();
		}
	},
};



# screen.display
#------------------------------------------------------------------------------
# Class that manages a dialog, which displays an arbitrary number of properties
# periodically updating the values. Property names are abbreviated to the
# shortest possible unique part.
#
# Example:
#
#     var dpy = screen.display.new(20, 10);    # x/y coordinate
#     dpy.setcolor(1, 0, 1);                   # magenta (default: white)
#     dpy.setfont("SANS_12B");                 # see $FG_ROOT/gui/styles/*.xml
#
#     dpy.add("/position/latitude-deg", "/position/longitude-deg");
#     dpy.add(props.globals.getNode("/orientation").getChildren());
#
#
# The add() method takes one or more property paths or props.Nodes, or a vector
# containing those, or a hash with properties, or vectors with properties, etc.
# Internal "public" parameters may be set directly:
#
#     dpy.interval = 0;                        # update every frame
#     dpy.format = "%.3g";                     # max. 3 digits fractional part
#     dpy.tagformat = "%-12s";                 # align prop names to 12 spaces
#     dpy.redraw();                            # pick up new settings
#
#
# The open() method should only be used to undo a close() call. In all other
# cases this is done implicitly. redraw() is automatically called by an add(),
# but can be used to let the dialog pick up new settings of internal variables.
#
#
# Methods add(), setfont() and setcolor() can be appended to the new()
# constructor (-> show big yellow frame rate counter in upper right corner):
#
#     screen.display.new(-15, -5, 0).setfont("TIMES_24").setcolor(1, 0.9, 0).add("/sim/frame-rate");
#
var display = {
	id : 0,
	new : func(x, y, show_tags = 1) {
		var m = { parents: [display] };
		#
		# "public"
		m.x = x;
		m.y = y;
		m.tags = show_tags;
		m.font = "HELVETICA_14";
		m.color = [1, 1, 1, 1];
		m.tagformat = "%s";
		m.format = "%.12g";
		m.interval = 0.1;
		#
		# "private"
		m.loopid = 0;
		m.dialog = nil;
		m.name = "__screen_display_" ~ (display.id += 1) ~ "__";
		m.base = props.globals.getNode("/sim/gui/dialogs/property-display-" ~ display.id, 1);
		m.namenode = props.Node.new({ "dialog-name": m.name });
		setlistener("/sim/startup/xsize", func m.redraw());
		setlistener("/sim/startup/ysize", func m.redraw());
		m.reset();
		return m;
	},
	setcolor : func(r, g, b, a = 1) {
		me.color = [r, g, b, a];
		me.redraw();
		me;
	},
	setfont : func(font) {
		me.font = font;
		me.redraw();
		me;
	},
	_create_ : func {
		me.dialog = gui.Widget.new();
		me.dialog.set("name", me.name);
		me.dialog.set("x", me.x);
		me.dialog.set("y", me.y);
		me.dialog.set("layout", "vbox");
		me.dialog.set("default-padding", 2);
		me.dialog.setFont(me.font);
		me.dialog.setColor(0, 0, 0, 0);

		foreach (var e; me.entries) {
			var w = me.dialog.addChild("text");
			w.set("halign", "left");
			w.set("label", "M");    # mouse-grab sensitive area
			w.set("property", e.target.getPath());
			w.set("format", me.tags ? e.tag ~ " = %s" : "%s");
			w.set("live", 1);
			w.setColor(me.color[0], me.color[1], me.color[2], me.color[3]);
		}
		fgcommand("dialog-new", me.dialog.prop());
	},
	# add() opens already, so call open() explicitly only after close()!
	open : func {
		if (me.dialog != nil) {
			fgcommand("dialog-show", me.namenode);
			me._loop_(me.loopid += 1);
		}
	},
	close : func {
		if (me.dialog != nil) {
			fgcommand("dialog-close", me.namenode);
			me.loopid += 1;
			me.dialog = nil;
		}
	},
	toggle : func {
		me.dialog == nil ? me.redraw() : me.close();
	},
	reset : func {
		me.close();
		me.loopid += 1;
		me.entries = [];
	},
	redraw : func {
		me.close();
		me._create_();
		me.open();
	},
	add : func(p...) {
		foreach (nextprop; var n; props.nodeList(p)) {
			var path = n.getPath();
			foreach (var e; me.entries) {
				if (e.node.getPath() == path)
					continue nextprop;
				e.parent = e.node;
				e.tag = sprintf(me.tagformat, me.nameof(e.node));
			}
			append(me.entries, { node: n, parent: n,
					tag: sprintf(me.tagformat, me.nameof(n)),
					target: me.base.getChild("entry", size(me.entries), 1) });
		}

		# extend names to the left until they are unique
		while (me.tags) {
			var uniq = {};
			foreach (var e; me.entries) {
				if (contains(uniq, e.tag))
					append(uniq[e.tag], e);
				else
					uniq[e.tag] = [e];
			}

			var done = 1;
			foreach (var u; keys(uniq)) {
				if (size(uniq[u]) == 1)
					continue;
				done = 0;
				foreach (var e; uniq[u]) {
					e.parent = e.parent.getParent();
					if (e.parent != nil)
						e.tag = me.nameof(e.parent) ~ '/' ~ e.tag;
				}
			}
			if (done)
				break;
		}
		me.redraw();
		me;
	},
	update : func {
		foreach (var e; me.entries) {
			var type = e.node.getType();
			if (type == "NONE")
				var val = "nil";
			elsif (type == "BOOL")
				var val = e.node.getValue() ? "true" : "false";
			elsif (type == "STRING" or type == "UNSPECIFIED")
				var val = "'" ~ sanitize(e.node.getValue(), 1) ~ "'";
			else
				var val = sprintf(me.format, e.node.getValue());
			e.target.setValue(val);
		}
	},
	_loop_ : func(id) {
		id != me.loopid and return;
		me.update();
		settimer(func me._loop_(id), me.interval);
	},
	nameof : func(n) {
		var name = n.getName();
		if (var i = n.getIndex())
			name ~= '[' ~ i ~ ']';
		return name;
	},
};




var listener = {};
var log = nil;
var property_display = nil;
var controls = nil;


# Shift-click       in the property browser adds the selected property to the property display
# Shift-Alt-click   adds all children of the selected property to the property display
# Shift-Ctrl-click  removes all properties from the display
#
_setlistener("/sim/signals/nasal-dir-initialized", func {
	property_display = display.new(5, -25);
	listener.display = setlistener("/sim/gui/dialogs/property-browser/selected", func(n) {
		var n = n.getValue();
		if (n != "" and getprop("/devices/status/keyboard/shift")) {
			if (getprop("/devices/status/keyboard/ctrl"))
				return property_display.reset();
			n = props.globals.getNode(n);
			if (!n.getAttribute("children"))
				property_display.add(n);
			elsif (getprop("/devices/status/keyboard/alt"))
				property_display.add(n.getChildren());
		}
	});

	setlistener("/sim/gui/current-style", func {
		var theme = getprop("/sim/gui/current-style");
		theme_font = getprop("/sim/gui/style[" ~ theme ~ "]/fonts/message-display/name");
	}, 1);

	log = window.new(nil, -30, 10, 10);
	log.sticky = 0;  # don't turn on; makes scrolling up messages jump left and right

	var b = "/sim/screen/";
	setlistener(b ~ "black",   func(n) log.write(n.getValue(), 0,   0,   0));
	setlistener(b ~ "white",   func(n) log.write(n.getValue(), 1,   1,   1));
	setlistener(b ~ "red",     func(n) log.write(n.getValue(), 0.8, 0,   0));
	setlistener(b ~ "green",   func(n) log.write(n.getValue(), 0,   0.6, 0));
	setlistener(b ~ "blue",    func(n) log.write(n.getValue(), 0,   0,   0.8));
	setlistener(b ~ "yellow",  func(n) log.write(n.getValue(), 0.8, 0.8, 0));
	setlistener(b ~ "magenta", func(n) log.write(n.getValue(), 0.7, 0,   0.7));
	setlistener(b ~ "cyan",    func(n) log.write(n.getValue(), 0,   0.6, 0.6));
});



# --prop:display=sim/frame-rate         ... adds this property to the property display
# --prop:display=position/              ... adds all properties under /position/  (ends with slash!)
# --prop:display=position/,orientation/ ... separate multiple properties with comma
#
var fdm_init_listener = _setlistener("/sim/signals/fdm-initialized", func {
	removelistener(fdm_init_listener); # uninstall, so we're only called once
	foreach (var n; props.globals.getChildren("display")) {
		foreach (var p; split(",", n.getValue())) {
			if (!size(p))
				continue;
			if (find('%', p) >= 0)
				property_display.format = p;
			elsif (p[-1] == `/`)
				property_display.add(props.globals.getNode(p, 1).getChildren());
			else
				property_display.add(p);
		}
	}
	props.globals.removeChildren("display");
});



var search_name_in_msg = func(msg, call) {
	var matching = 0;
	var found = 0;
	for(var i = 0; i < size(msg); i = i + 1) {
		if (msg[i] == ` ` or msg[i] == `,` or msg[i] == `.` or msg[i] == `;` or msg[i] == `:` or msg[i] == `>`) {
			if (matching == size(call)) {
				found = 1;
				break;
			}
			matching = 0;
			continue;
		}
		if (matching >= size(call)) {
			matching = matching + 1;
			continue;
		}
		if (call[matching] == msg[i]) {
			matching = matching + 1;
		} else {
			matching = 0;
		}
	}
	if (found == 1 or matching == size(call))
		return 1;
	else
		return 0;
}
##############################################################################
# functions that make use of the window class (and don't belong anywhere else)
##############################################################################

# highlights messages with the multiplayer callsign in the text
var msg_mp = func (n) {
	if (!getprop("/sim/multiplay/chat-display"))
		return;
	var msg = string.lc(n.getValue());
	var call = string.lc(getprop("/sim/multiplay/callsign"));
	var highlight = getprop("/sim/multiplay/chat_highlight");
	if (search_name_in_msg(msg, call) or (highlight != nil and search_name_in_msg(msg, string.lc(highlight))))
		screen.log.write(n.getValue(), 1.0, 0.5, 0.5);
	else
		screen.log.write(n.getValue(), 0.5, 0.0, 0.8);
}

var msg_repeat = func {
	if (getprop("/sim/tutorials/running")) {
		var last = getprop("/sim/tutorials/last-message");
		if (last == nil)
			return;

		setprop("/sim/messages/pilot", "Say again ...");
		settimer(func setprop("/sim/messages/copilot", last), 1.5);

	} else {
		var last = atc.getValue();
		if (last == nil)
			return;

		setprop("/sim/messages/pilot", "This is " ~ callsign.getValue() ~ ". Say again, over.");
		settimer(func atc.setValue(atclast.getValue()), 6);
	}
}


var atc = nil;
var callsign = nil;
var atclast = nil;

_setlistener("/sim/signals/nasal-dir-initialized", func {
	# set /sim/screen/nomap=true to prevent default message mapping
	var nomap = getprop("/sim/screen/nomap");
	if (nomap != nil and nomap)
		return;

	callsign = props.globals.getNode("/sim/user/callsign", 1);
	atc = props.globals.getNode("/sim/messages/atc", 1);
	atclast = props.globals.getNode("/sim/messages/atc-last", 1);
	atclast.setValue("");

	# let ATC tell which runway was automatically chosen after startup/teleportation
	settimer(func {
		setlistener("/sim/atc/runway", func(n) { # set in src/Main/fg_init.cxx
			var rwy = n.getValue();
			if (rwy == nil)
				return;
			if (getprop("/sim/presets/airport-id") == "KSFO" and rwy == "28R")
				return;
			if ((var agl = getprop("/position/altitude-agl-ft")) != nil and agl > 100)
				return;
			screen.log.write("You are on runway " ~ rwy, 0.7, 1.0, 0.7);
		}, 1);
	}, 5);

	setlistener("/gear/launchbar/state", func(n) {
		if (n.getValue() == "Engaged")
			setprop("/sim/messages/copilot", "Engaged!");
	}, 0, 0);

	# map ATC messages to the screen log and to the voice subsystem
	var map = func(type, msg, r, g, b, cond = nil) {
		printlog("info", "{", type, "} ", msg);
		setprop("/sim/sound/voices/" ~ type, msg);

		if (cond == nil or cond())
			screen.log.write(msg, r, g, b);

		# save last ATC message for user callsign, unless this was already
		# a repetition; insert "I say again" appropriately
		if (type == "atc") {
			var cs = callsign.getValue();
			if (find(", I say again: ", atc.getValue()) < 0
					and (var pos = find(cs, msg)) >= 0) {
				var m = substr(msg, 0, pos + size(cs));
				msg = substr(msg, pos + size(cs));

				if ((pos = find("Tower, ", msg)) >= 0) {
					m ~= substr(msg, 0, pos + 7);
					msg = substr(msg, pos + 7);
				} else {
					m ~= ", ";
				}
				m ~= "I say again: " ~ msg;
				atclast.setValue(m);
				printlog("debug", "ATC_LAST_MESSAGE: ", m);
			}
		}
	}

	var m = "/sim/messages/";
	listener.atc = setlistener(m ~ "atc",
			func(n) map("atc",      n.getValue(), 0.7, 1.0, 0.7));
	listener.approach = setlistener(m ~ "approach",
			func(n) map("approach", n.getValue(), 0.7, 1.0, 0.7));
	listener.ground = setlistener(m ~ "ground",
			func(n) map("ground",   n.getValue(), 0.7, 1.0, 0.7));

	listener.pilot = setlistener(m ~ "pilot",
			func(n) map("pilot",    n.getValue(), 1.0, 0.8, 0.0));
	listener.copilot = setlistener(m ~ "copilot",
			func(n) map("copilot",  n.getValue(), 1.0, 1.0, 1.0));
	listener.ai_plane = setlistener(m ~ "ai-plane",
			func(n) map("ai-plane", n.getValue(), 0.9, 0.4, 0.2));
	listener.mp_plane = setlistener(m ~ "mp-plane", msg_mp);
});


