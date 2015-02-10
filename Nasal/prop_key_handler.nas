# Property Key Handler
# ------------------------------------------------------------------
# This is an extension mainly targeted at developers. It implements
# some useful tools for dealing with internal properties if enabled
# (Menu->Debug->Configure Development Extensions). To use this feature,
# press the '/'-key, then type a property path (using the <TAB> key to
# complete property path elements if possible), or a search string ...
#
#
# Commands:
#
#   <property>=<value><CR> -> set property to value
#   <property><CR>         -> print property and value to screen and terminal
#   <property>*            -> print property and all children to terminal
#   <property>!            -> add property to display list  (reset list with  /!)
#   <property>:            -> open property browser in this property's directory
#   <string>?              -> print all properties whose path or value contains this string
#
#
# Keys:
#
#   <CR>              ... carriage return or enter, to confirm some operations
#   <TAB>             ... complete property path element (if possible), or
#                         cycle through available elements
#   <Shift-TAB>       ... like <TAB> but cycles backwards
#   <CurUp>/<CurDown> ... switch back/forth in the history
#   <Escape>          ... cancel the operation
#   <Shift-Backspace> ... remove last whole path element
#
#
# Colors:
#
#   white   ... syntactically correct path to not yet existing property
#   green   ... path to existing property
#   red     ... broken path syntax  (e.g. "/foo*bar" ... '*' not allowed)
#   yellow  ... while typing in value for a valid property path
#   magenta ... while typing search string (except when first character is '/')
#
#
# For example, to open the property browser in /position/, type '/p<TAB>:'.


var listener = nil;
var input = nil;   # what the user typed (doesn't contain unconfirmed autocompleted parts)
var text = nil;    # what is shown in the popup
var state = nil;

var completion = [];
var completion_pos = -1;
var history = [];
var history_pos = -1;


var start = func {
	state = parse_input(text = "");
	handle_key(`/`, 0);

	listener = setlistener("/devices/status/keyboard/event", func(event) {
		if (!event.getNode("pressed").getValue())
			return;
		var key = event.getNode("key");
		var shift = event.getNode("modifier/shift").getValue();
		if (handle_key(key.getValue(), shift))
			key.setValue(-1);           # drop key event
	});
}


var stop = func(save_history = 0) {
	removelistener(listener);
	if (save_history and (!size(history) or !streq(history[-1], text)))
		append(history, text);

	history_pos = size(history);
	gui.popdown();
}


var handle_key = func(key, shift) {
	if (key == 357) {                  # up
		set_history(-1);

	} elsif (key == 359) {             # down
		set_history(1);

	} elsif (key == `\n` or key == `\r`) {
		if (state.error)
			return 1;
		if (state.value != nil)
			setprop(state.path, state.value);

		var n = props.globals.getNode(state.path);
		var s = state.path;
		if (n != nil) {
			print_prop(n);
			var v = n.getValue();
			s ~= " = " ~ (v == nil ? "<nil>" : v);
		} else {
			s ~= " does not exist";
		}
		screen.log.write(s, 1, 1, 1);
		stop(1);
		return 1;

	} elsif (key == 27) {              # escape -> cancel
		stop(0);
		return 1;

	} elsif (key == `\t`) {            # tab
		if (size(text) and text[0] == `/`) {
			text = complete(input, shift ? -1 : 1);
			build_completion(input);
			var n = call(func { props.globals.getNode(text) }, [], var err = []);
			if (!size(err) and n != nil and n.getAttribute("children") and size(completion) == 1)
				handle_key(`/`, 0);
		}

	} elsif (key == 8) {               # backspace
		if (shift) {               #     + shift: remove one path element
			input = text = state.parent.getPath();
			if (text == "")
				handle_key(`/`, 0);
		} else {
			input = text = substr(text, 0, size(text) - 1);
			if (text == "")
				stop(); # nothing in our field? close the dialog
		}
		completion_pos = -1;

	} elsif (!string.isprint(key)) {
		return 0;                  # pass other funny events

	} elsif (key == `?` and state.value == nil) {
		print("\n-- property search: '", text, "' ----------------------------------");
		search(props.globals, text);
		print("-- done --\n");
		stop(0);
		return 1;

	} elsif (key == `!` and state.node != nil and state.value == nil) {
		if (!state.node.getPath()) {
			screen.property_display.reset();
			stop(0);
		} else {
			screen.property_display.add(state.node);
			stop(1);
		}
		return 1;

	} elsif (key == `*` and state.node != nil and state.value == nil) {
		debug.tree(state.node);
		stop(1);
		return 1;

	} elsif (key == `:` and state.node != nil and state.value == nil) {
		var n = state.node.getAttribute("children") ? state.node : state.parent;
		gui.property_browser(n);
		stop(1);
		return 1;

	} else {
		text ~= chr(key);
		input = text;
		completion_pos = -1;
		history_pos = size(history);
	}

	state = parse_input(text);
	build_completion(input);

	var color = nil;
	if (size(text) and text[0] != `/`)       # search mode (magenta)
		color = set_color(1, 0.4, 0.9);
	elsif (state.error)                      # error mode (red)
		color = set_color(1, 0.4, 0.4);
	elsif (state.value != nil)               # value edit mode (yellow)
		color = set_color(1, 0.8, 0);
	elsif (state.node != nil)                # existing node (green)
		color = set_color(0.7, 1, 0.7);

	gui.popupTip(text, 1000000, color);
	return 1;                                # discard key event
}


var parse_input = func(expr) {
	var path = expr;
	var value = nil;

	if ((var pos = find("=", expr)) >= 0) {
		path = substr(expr, 0, pos);
		value = substr(expr, pos + 1);
	}

	# split argument in parent and name
	var last = 0;
	while ((var pos = find("/", path, last + 1)) > 0)
		last = pos;
	var parent = substr(path, 0, last); # without trailing /
	var raw_name = substr(path, last + 1);
	var name = raw_name;
	if ((var pos = find("[", name)) >= 0)
		name = substr(name, 0, pos);
	var node = nil;

	# run dangerous operations in cage (the paths might be invalid)
	call(func {
		parent = props.globals.getNode(parent);
		node = props.globals.getNode(path);
	}, [], var error = []);

	return {
		error: size(error),
		path: path,
		value: value,
		raw_name: raw_name,  # "binding[1"
		name: name,          # "binding"
		parent: parent,
		node: node,
	};
}


var build_completion = func(in) {
	completion = [];
	var s = parse_input(in);
	if (s.error or s.parent == nil)
		return;

	foreach (var c; s.parent.getChildren()) {
		var index = c.getIndex();
		var name = c.getName();
		var fullname = name;
		if (index > 0)
			fullname ~= "[" ~ index ~ "]";
		if (substr(fullname, 0, size(s.raw_name)) == s.raw_name)
			append(completion, [fullname, name, index]);
	}
	completion = sort(completion, func(a, b) cmp(a[1], b[1]) or a[2] - b[2]);
	#print(debug.string([completion_pos, completion]), "\n");
}


var complete = func(in, step) {
	if (state.parent == nil or state.value != nil)
		return in;     # can't complete broken path or assignment

	completion_pos += step;
	if (completion_pos < 0)
		completion_pos = size(completion) - 1;
	elsif (completion_pos >= size(completion))
		completion_pos = 0;

	if (completion_pos < size(completion))
		in = state.parent.getPath() ~ "/" ~ completion[completion_pos][0];

	return in;
}


var set_history = func(step) {
	history_pos += step;
	if (history_pos < 0) {
		history_pos = 0;
	} elsif (history_pos >= size(history)) {
		history_pos = size(history);
		text = "";
	} else {
		text = history[history_pos];
	}
	input = text;
}


var set_color = func(r, g, b) {
	return { text: { color: { red: r, green: g, blue: b } }};
}


var print_prop = func(n) {
	print(n.getPath(), " = ", debug.string(n.getValue()), "  ", debug.attributes(n));
}


var search = func(n, s) {
	if (find(s, n.getPath()) >= 0)
		print_prop(n);
	elsif (n.getType() != "NONE" and find(s, "" ~ n.getValue()) >= 0)
		print_prop(n);
	foreach (var c; n.getChildren())
		search(c, s);
}


_setlistener("/sim/signals/nasal-dir-initialized", func {
	foreach (var p; props.globals.getNode("/sim/gui/prop-key-handler/history", 1).getChildren("entry"))
		append(history, p.getValue());
	var max = props.globals.initNode("/sim/gui/prop-key-handler/history-max-size", 30).getValue();
	if (size(history) > max)
		history = subvec(history, size(history) - max);
});


_setlistener("/sim/signals/exit", func {
	var max = props.globals.initNode("/sim/gui/prop-key-handler/history-max-size", 30).getValue();
	if (size(history) > max)
		history = subvec(history, size(history) - max);
	forindex (var i; history) {
		var p = props.globals.getNode("/sim/gui/prop-key-handler/history", 1).getChild("entry", i, 1);
		p.setValue(history[i]);
		p.setAttribute("userarchive", 1);
	}
});


