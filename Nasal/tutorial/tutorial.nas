# Code to process XML-based tutorials. See $FG_ROOT/Docs/README.tutorials
# ---------------------------------------------------------------------------------------


var step_interval = 0;   # time between tutorial steps (default is set below)
var exit_interval = 0;   # time between fulfillment of a step and the start of the next step (default is set below)

var loop_id = 0;
var tutorialN = nil;
var steps = [];
var current_step = nil;
var is_first_step = nil;
var num_errors = nil;
var step_start_time = nil;
var step_iter_count = 0;    # number or step loop iterations
var last_step_time = nil;   # for set_targets() eta calculation
var audio_dir = nil;

#  Screen display.  On bottom of screen, with no auto-scroll.
var display = screen.window.new(nil, 30, 5, 0);
display.sticky = 0; # don't turn on; makes scrolling up messages jump left and right

# property nodes (to be initialized with listener)
var markerN = nil;
var headingN = nil;
var slipN = nil;
var time_elapsedN = nil;
var last_messageN = nil;
var step_countN = nil;
var step_timeN = nil;

_setlistener("/nasal/tutorial/loaded", func {
	markerN = props.globals.getNode("/sim/model/marker", 1);
	headingN = props.globals.getNode("/orientation/heading-deg", 1);
	slipN = props.globals.getNode("/orientation/side-slip-deg", 1);
	time_elapsedN = props.globals.getNode("/sim/time/elapsed-sec", 1);
	last_messageN = props.globals.getNode("/sim/tutorials/last-message", 1);
	step_countN = props.globals.getNode("/sim/tutorials/step-count", 1);
	step_timeN = props.globals.getNode("/sim/tutorials/step-time", 1);
	setlistener("/sim/crashed", stopTutorial);
});

var startTutorial = func {
	var name = getprop("/sim/tutorials/current-tutorial");
	if (name == nil) {
		screen.log.write("No tutorial selected");
		return;
	}

	tutorialN = nil;
	foreach (var c; props.globals.getNode("/sim/tutorials").getChildren("tutorial")) {
		if (c.getNode("name").getValue() == name) {
			tutorialN = c;
			break;
		}
	}

	if (tutorialN == nil) {
		screen.log.write('Unable to find tutorial "' ~ name ~ '"');
		return;
	}

	stopTutorial();
	screen.log.write('Loading tutorial "' ~ name ~ '" ...');
	view.point.save();
	init_nasal();

	current_step = 0;
	is_first_step = 1;
	num_errors = 0;
	last_step_time = time_elapsedN.getValue();
	steps = tutorialN.getChildren("step");

	step_interval = read_int(tutorialN, "step-time", 5); # time between tutorial steps
	exit_interval = read_int(tutorialN, "exit-time", 1); # time between fulfillment of steps
	run_nasal(tutorialN);
	set_models(tutorialN.getNode("models"));

	var dir = tutorialN.getNode("audio-dir");
	if (dir != nil)
		audio_dir = getprop("/sim/fg-root") ~ "/" ~ dir.getValue();
	else
		audio_dir = "";

	var presets = tutorialN.getChild("presets");
	if (presets != nil) {
		props.copy(presets, props.globals.getNode("/sim/presets"));
		fgcommand("reposition");

		if (getprop("/sim/presets/on-ground")) {
			var eng = props.globals.getNode("/controls/engines");
			if (eng != nil) {
				foreach (var c; eng.getChildren("engine")) {
					c.getNode("magnetos", 1).setIntValue(3);
					c.getNode("throttle", 1).setDoubleValue(0.5);
				}
			}
		}
	}

	var timeofday = tutorialN.getChild("timeofday");
	if (timeofday != nil)
		fgcommand("timeofday", props.Node.new({ "timeofday" : timeofday.getValue() }));

	# <init>
	do_group(tutorialN.getNode("init"));
	is_running(1);  # needs to be after "reposition"
	display.clear();
	display.show();

	# Pick up any weather conditions/scenarios set
	setprop("/environment/rebuild-layers", getprop("/environment/rebuild-layers") + 1);
	settimer(func { step_tutorial(loop_id += 1) }, step_interval);
}



var stopTutorial = func {
	loop_id += 1;
	if (is_running()) {
		var end = tutorialN.getNode("end");
		set_properties(end);
		run_nasal(end);
		set_view(end) or view.point.restore();
		say("Tutorial finished.");
		settimer(func() { if (!is_running()) { display.close(); } }, 10);
	}
	set_marker();
	is_running(0);
}




# - Gets the current step node from the tutorial
# - If this is the first time the step is entered, it displays the instruction message
# - Otherwise, it
#   - Checks if the exit conditions have been met. If so, it increments the step counter.
#   - Checks for any error conditions, in which case it displays a message to the screen and
#     increments an error counter
#   - Otherwise display the instructions for the step.
#
var step_tutorial = func(id) {

  # Check to ensure that this is the currently running tutorial.
	id == loop_id or return;

	var continue_after = func(n, w) {
		settimer(func { step_tutorial(id) }, w);
	}

	# <end>
	if (current_step >= size(steps)) {
		var end = tutorialN.getNode("end");
		stopTutorial();
		return;
	}

	var step = steps[current_step];
	set_marker(step);
	set_targets(tutorialN.getNode("targets"));

	# <step>
	if (is_first_step) {
		is_first_step = 0;
		step_start_time = time_elapsedN.getValue();
		step_timeN.setDoubleValue(0);
		step_countN.setIntValue(step_iter_count = 0);

		do_group(step, "Tutorial step " ~ current_step);

		# A <wait> tag affects only the initial entry to the step
		var w = read_int(step, "wait", step_interval);
		return continue_after(step, w);
	}

	step_countN.setIntValue(step_iter_count += 1);
	step_timeN.setDoubleValue(time_elapsedN.getValue() - step_start_time);

	# <abort>
	var abort = step.getNode("abort");
	if (abort != nil) {
		if (props.condition(abort.getNode("condition"))) {
			do_group(abort);
			current_step += 1;
			is_first_step = 1;
			return continue_after(abort, exit_interval);
		}
	}

	# <error>
	foreach (var error; shuffle(step.getChildren("error"))) {
		if (props.condition(error.getNode("condition"))) {
			num_errors += 1;
			do_group(error);
			return continue_after(error, step_interval);
		}
	}

	# <exit>
	var exit = step.getNode("exit");
	if (exit != nil) {
		if (!props.condition(exit.getNode("condition")))
		{
			if (time_elapsedN.getValue() - step_start_time > 15.0)
			{
				# What's going on? Repeat last message.
				last_messageN.setValue("");
				step_start_time = time_elapsedN.getValue();
				do_group(step, "Tutorial step " ~ current_step);
			}
			return continue_after(exit, step_interval);
		}

		do_group(exit);
	}

	# success!
	current_step += 1;
	is_first_step = 1;
	return continue_after(tutorialN, exit_interval);
}


##
# Do the stuff that's shared by <init>, <step>, <error>, <exit>, and <abort>.
# <end> doesn't use it.
#
var do_group = func(node, default_msg = nil) {
	say_message(node, default_msg);
	set_view(node);
	set_properties(node);
	run_nasal(node);
}

var read_int = func(node, child, default) {
	var c = node.getNode(child);
	if (c == nil)
		return default;
	c = int(c.getValue());
	return c != nil ? c : default;
}


##
# scan all <set> blocks and set their <property> to <value> or
# the value of a property that <property n="1"> points to
# <set>
#	 <property>/foo/bar</property>
#	 <value>woof</value>
# </set>
#
var set_properties = func(node) {
	node != nil or return;
	foreach (var c; node.getChildren("set")) {
		var dest = c.getChild("property", 0);
		var src = c.getChild("property", 1);
		var val = c.getChild("value");

		dest != nil or die("<set> without <property>");
		if (val != nil) {
			setprop(dest.getValue(), val.getValue());
		} elsif (src != nil) {
			src = getprop(src.getValue());
			src != nil or die("<property n=\"1\"> doesn't refer to defined property");
			setprop(dest.getValue(), src);
		} else {
			die("<set> without <value> or <property n=\"1\">");
		}
	}
}


##
# For each <target><*><longitude-deg|latitude-deg> calculate and update
# /sim/tutorials/targets/*/...
#   heading-deg   ... absolute heading to target  (0 -> North)
#   direction-deg ... relative angle to target    (0 -> ahead, 90 -> to the right)
#   distance-m    ... distance in meters
#   eta-min       ... estimated time of arrival (assuming aircraft flies in
#                     in current speed towards target)
#
var set_targets = func(node) {
	node != nil or return;

	var time = time_elapsedN.getValue();
	var dest = props.globals.getNode("/sim/tutorials/targets", 1);
	var aircraft = geo.aircraft_position();
	var hdg = headingN.getValue() + slipN.getValue();

	foreach (var t; node.getChildren()) {
		var lon = t.getNode("longitude-deg");
		var lat = t.getNode("latitude-deg");
		if (lon == nil or lat == nil)
			die("target coords undefined");

		var target = geo.Coord.new().set_latlon(lat.getValue(), lon.getValue());
		var dist = aircraft.distance_to(target);
		var course = aircraft.course_to(target);
		var angle = geo.normdeg(course - hdg);
		if (angle >= 180)
			angle -= 360;

		var d = dest.getChild(t.getName(), t.getIndex(), 1);
		d.getNode("heading-deg", 1).setDoubleValue(course);
		d.getNode("direction-deg", 1).setDoubleValue(angle);
		var distN = d.getNode("distance-m", 1);
		var lastdist = distN.getValue();
		distN.setDoubleValue(dist);
		if (lastdist != nil) {
			var speed = (lastdist - dist) / (time - last_step_time) + 0.00001;  # m/s
			d.getNode("eta-min", 1).setDoubleValue(dist / (speed * 60));
		}
	}
	last_step_time = time;
}


var models = [];
var set_models = func(node) {
	node != nil or return;

	var manager = props.globals.getNode("/models", 1);
	foreach (var src; node.getChildren("model")) {
		var i = 0;
		for (; 1; i += 1)
			if (manager.getChild("model", i, 0) == nil)
				break;

		var dest = manager.getChild("model", i, 1);
		props.copy(src, dest);
		dest.getNode("load", 1);  # makes the modelmgr load the model
		dest.removeChildren("load");
		append(models, dest);
	}
}


var remove_models = func {
	foreach (var m; models)
		m.getParent().removeChild(m.getName(), m.getIndex());

	models = [];
}


var set_view = func(node = nil) {
	node != nil or return;
	var v = node.getChild("view");
	if (v != nil) {
		# when changing view direction, switch to view 0 (captain's view),
		# unless another view is explicitly specified
		v.initNode("view-number", 0, "INT", 0);
		view.point.move(v);
		return 1;
	}
	return 0;
}


var set_marker = func(node = nil) {
	if (node != nil) {
		var loc = node.getNode("marker");
		if (loc != nil) {
			var s = loc.getNode("scale");
			markerN.setValues({
				"x/value": loc.getNode("x-m", 1).getValue(),
				"y/value": loc.getNode("y-m", 1).getValue(),
				"z/value": loc.getNode("z-m", 1).getValue(),
				"scale/value": s != nil ? s.getValue() : 1,
				"arrow-enabled": 1,
			});
			return;
		}
	}
	markerN.getNode("arrow-enabled", 1).setBoolValue(0);
}


# Set and return running state. Disable/enable stop menu.
#
var is_running = func(which = nil) {
	var prop = "/sim/tutorials/running";
	if (which != nil) {
		setprop(prop, which);
	}
	return getprop(prop);
}


# Output the message and optional sound recording.
#
var lastmsgcount = 0;
var say_message = func(node, default = nil) {
	var msg = default;
	var audio = nil;

	if (node != nil) {

		var m = node.getChildren("message");
		if (size(m))
			msg = m[rand() * size(m)].getValue();

		var a = node.getChildren("audio");
		if (size(a))
			audio = a[rand() * size(a)].getValue();
	}

	if (msg != last_messageN.getValue()) {
		# Messages are only displayed if they change
		if (audio != nil) {
			var prop = { path : audio_dir, file : audio, volume : 1.0 };
			fgcommand("play-audio-sample", props.Node.new(prop));
		}

		if (msg != nil) {
			display.write(msg, 1, 1, 1);
			last_messageN.setValue(msg);
		}
	}
}


var shuffle = func(vec) {
	var s = size(vec);
	forindex (var i; vec) {
		var j = rand() * s;
		if (i != j) {
			var swap = vec[j];
			vec[j] = vec[i];
			vec[i] = swap;
		}
	}
	return vec;
}


var run_nasal = func(node) {
	node != nil or return;
	foreach (var n; node.getChildren("nasal")) {
		if (n.getNode("module") == nil)
			n.getNode("module", 1).setValue("__tutorial");

		fgcommand("nasal", n);
	}
}


var say = func(what, who = "copilot", delay = 0) {
	settimer(func { display.write(what, 1, 1, 1) }, delay);
}


# Set up namespace "__tutorial" for embedded Nasal.
#
var init_nasal = func {
	globals.__tutorial = {
		say : say,   # just exporting tutorial.say as __tutorial.say
		next : func(n = 1) { current_step += n; is_first_step = 1; },
		previous : func(n = 1) {
			current_step -= n;
			is_first_step = 1;
			if (current_step < 0)
				current_step = 0;
		},
	};
}


var dialog = func {
	fgcommand("dialog-show", props.Node.new({ "dialog-name" : "marker-adjust" }));
}


##
# Tutorial loader for development purposes.
# Usage:  tutorial.load("Aircraft/bo105/Tutorials/foo.xml", 1)
# Loads this file to tutorial slot #1 (/sim/tutorials/tutorial[1])
#
var load = func(file, index = 0) {
	props.globals.getNode("/sim/tutorials", 1).removeChild("tutorial", index);
	io.read_properties(file, "/sim/tutorials/tutorial[" ~ index ~ "]/");
}


