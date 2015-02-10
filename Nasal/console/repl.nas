var _REPL_dbg_level = "debug";
#var _REPL_dbg_level = "alert";

var REPL = {
	df_status: 0,
	whitespace: [" ", "\t", "\n", "\r"],
	end_statement: [";", ","],
	statement_types: [
		"for", "foreach", "forindex",
		"while", "else", "func", "if", "elsif"
	],
	operators_binary_unary: [
		"~", "+", "-", "*", "/",
		"!", "?", ":", ".", ",",
		"<", ">", "=", "|", "&", "^"
	],
	brackets: {
		"(":")",
		"[":"]",
		"{":"}",
	},
	str_chars: ["'", '"', "`"],
	brackets_rev: {},
	brackets_start: [], brackets_end: [],
	new: func(placement, name="<repl>", keep_history=1, namespace=nil) {
		if (namespace == nil) namespace = {};
		elsif (typeof(namespace) == 'scalar') namespace = globals[namespace];
		if (typeof(namespace) != 'hash') die("bad namespace!");
		var m = {
			parents: [REPL],
			placement: placement,
			name: name,
			keep_history: keep_history,
			namespace: namespace,
			history: [],
			current: nil,
		};
		return m;
	},
	execute: func() {
		var code = string.join("\n", me.current.line);

		me.current = nil;

		printlog(_REPL_dbg_level, "compiling code..."~debug.string(code));

		var fn = call(func compile(code, me.name), nil, var err=[]);
		if (size(err)) {
			var msg = err[0];
			var prefix = "Parse error: ";
			if (substr(msg, 0, size(prefix)) == prefix)
				msg = substr(msg, size(prefix));
			var (msg, line) = split(" at line ", msg);
			#debug.dump(err);
			me.placement.handle_parse_error(msg, me.name, line); # message, (file)name, line number
			return 0;
		}
		var res = call(bind(fn, globals), nil, nil, me.namespace, err);
		if (size(err)) {
			me.placement.handle_runtime_error(err); # err vec
			return 0;
		}
		me.placement.display_result(res);
		return 1;
	},
	_is_str_char: func(char) {
		foreach (var c; me.str_chars)
			if (c == char or c[0] == char) return 1;
		return 0;
	},
	_handle_level: func(level, str, line_number) {
		if (size(str) != 1)
			var str = substr(str, 0, 1);
		if (contains(me.brackets, str)) {
			append(level, str);
			printlog(_REPL_dbg_level, "> level add "~str);
			return 1;
		} elsif (contains(me.brackets_rev, str)) {
			var l = pop(level);
			if (l == nil) {
				me.placement.handle_parse_error("extra closing bracket "'"'~str~'"', me.name, line_number);
				return nil;
			} elsif (me.brackets[l] != str) {
				me.placement.handle_parse_error("bracket mismatch: "~me.brackets[l]~" vs "~str, me.name, line_number);
				return nil;
			} else {
				printlog(_REPL_dbg_level, "< level pop "~str);
				return 1;
			}
		}
		return 0;
	},
	get_input: func() {
		var lines = me.placement.get_line();
		if (lines == nil or string.trim(lines) == "") return me.df_status;
		var ls = split("\n", lines); var lines = [];
		foreach (var l; ls) lines ~= split("\r", l);
		foreach (var line; lines) {
			var len = size(line);
			if (me.current == nil)
				me.current = {
					line: [],
					brackets: [],
					level: [],
					statement: nil,
					statement_level: nil,
					last_operator: nil,
				};
			for (var i=0; i<len; i+=1) {
				if (string.isxspace(line[i])) continue;
				if (size(me.current.level) and me._is_str_char(me.current.level[-1])) {
					me.current.last_operator = nil;
					if (line[i] == `\\`) {
						i += 1; # skip the next character
						printlog(_REPL_dbg_level, "  skip backslash");
					} elsif (line[i] == me.current.level[-1][0]) {
						printlog(_REPL_dbg_level, "< out of string with "~me.current.level[-1]);
						pop(me.current.level);
					}
					continue;
				}
				if (line[i] == `#`) {
					while(i<len and line[i] != `\n` and line[i] != `\r`) i+=1;
					continue;
				}
				if (me.current.statement != nil) {
					me.current.last_operator = nil;
					if (me.current.statement_level == size(me.current.level) and
						     (line[i] == `;` or line[i] == `,`)) {
						printlog(_REPL_dbg_level, "statement ended by ;/,");
						me.current.statement = nil;
						me.current.statement_level = nil;
					} else {
						var ret = me._handle_level(me.current.level, chr(line[i]), size(me.current.line)+1);
						if (ret == nil) {# error
							me.current = nil;
							return 0;
						} elsif (me.current.statement_level > size(me.current.level)) {
							printlog(_REPL_dbg_level, "statement ended by level below");
							# cancel out of statement
							me.current.statement = nil;
							me.current.statement_level = nil;
						} elsif (line[i] == `{`) {
							# cancel out of looking for `;`, because we have a real block here
							printlog(_REPL_dbg_level, "statement ended by braces");
							me.current.statement = nil;
							me.current.statement_level = nil;
						}
					}
					continue;
				} elsif (string.isalpha(line[i])) {
					me.current.last_operator = nil;
					foreach (var stmt; me.statement_types) {
						if (substr(line, i, size(stmt)) == stmt and
							(i+size(stmt) >= len
							 or !string.isalnum(line[i+size(stmt)])
							 and line[i+size(stmt)] != `_`)) {
							printlog(_REPL_dbg_level, "found: "~stmt);
							me.current.statement = stmt;
							me.current.statement_level = size(me.current.level);
							i += size(stmt)-1;
							break;
						}
					}
				} elsif (me._is_str_char(line[i])) {
					me.current.last_operator = nil;
					append(me.current.level, chr(line[i]));
					printlog(_REPL_dbg_level, "> into string with "~me.current.level[-1]);
				} else {
					var ret = me._handle_level(me.current.level, chr(line[i]), size(me.current.line)+1);
					me.current.last_operator = nil;
					if (ret == nil) # error
						return 0;
					elsif (ret == 0) {
						foreach (var o; me.operators_binary_unary)
							if (line[i] == o[0])
							{ me.current.last_operator = o; printlog(_REPL_dbg_level, "found operator "~o); break }
					}
				}
			}
			append(me.current.line, line);
			if (me.keep_history)
				append(me.history, {
					type: "input",
					line: line,
				});
		}
		var execute = (me.current.statement == nil and me.current.last_operator == nil and !size(me.current.level));
		if (execute) {
			me.df_status = 0;
			return me.execute();
		} else
		return (me.df_status = -1);
	},
};
foreach (var b; keys(REPL.brackets)) {
	var v = REPL.brackets[b];
	append(REPL.brackets_start, b);
	append(REPL.brackets_end,   v);
	REPL.brackets_rev[v] = b;
}

var CanvasPlacement = {
	instances: [],
	current_instance: nil,
	keys: [
		"ESC",         "Exit/close this dialog",
		"Ctrl-d",      "Same as ESC",
		"Ctrl-v",      "Insert text (at the end of the current line)",
		"Ctrl-c",      "Copy the current line of text",
		"Ctrl-x",      "Copy and delete the current line of text",
		"Up",          "Previous line in history",
		"Down",        "Next line in history",
		"Left",         nil,
		"Right",        nil,
		"Shift+Left",   nil,
		"Shift+Right",  nil,
	],
	translations: {
		"bad-result": "[Error: cannot display output]",
		"key-not-mapped": "[Not Implemented]",
		"help": "Welcome to the Nasal REPL Interpreter. Press any key to "
		        "exit this message, ESC to exit the dialog (at any time "
		        "afterwards), and type away to test code :).\n\nNote: "
		        "this dialog will capture nearly all key-presses, so don't "
		        "try to fly with the keyboard while this is open!"
		        "\n\nImportant keys:",
	},
	styles: {
		"default": {
			size: [600, 300],
			separate_lines: 1,
			window_style: "default",
			padding: 5,
			max_output_chars: 200,
			colors: {
				# TODO: integrate colors from debug.nas?
				text: [1,1,1],
				text_fill: nil,
				background: [0.1,0.06,0.4,0.3],
				error: [1,0.2,0.1],
			},
			font_size: 17,
			font_file: "LiberationFonts/LiberationMono-Bold.ttf",
			font_aspect_ratio: 1.5,
			font_max_width: nil,
		},
		"transparent-blue": {
			size: [600, 300],
			separate_lines: 1,
			window_style: nil,
			padding: 5,
			max_output_chars: 200,
			colors: {
				text: [1,1,1],
				text_fill: nil,
				background: [0.1,0.06,0.4,0.3],
				error: [1,0.2,0.1],
			},
			font_size: 17,
			font_file: "LiberationFonts/LiberationMono-Bold.ttf",
			font_aspect_ratio: 1.5,
			font_max_width: nil,
		},
		"transparent-red": {
			size: [600, 300],
			separate_lines: 1,
			window_style: nil,
			padding: 5,
			max_output_chars: 200,
			colors: {
				text: [1,1,1],
				text_fill: nil,
				background: [0.8,0.06,0.07,0.4],
				error: [1,0.2,0.1],
			},
			font_size: 17,
			font_file: "LiberationFonts/LiberationMono-Bold.ttf",
			font_aspect_ratio: 1.5,
			font_max_width: nil,
		},
		"canvas-default": {
			size: [600, 300],
			separate_lines: 1,
			window_style: "default",
			padding: 5,
			max_output_chars: 87,
			colors: {
				text: [0.8,0.86,0.8],
				text_fill: nil,
				background: [0.05,0.03,0.2],
				error: [1,0.2,0.1],
			},
			font_size: 17,
			font_file: "LiberationFonts/LiberationMono-Bold.ttf",
			font_aspect_ratio: 1.5,
			font_max_width: nil,
			#font_max_width: 588,
		},
	},
	new: func(name="<canvas-repl>", style="canvas-default") {
		if (typeof(style) == 'scalar') {
			style = CanvasPlacement.styles[style];
		}
		if (typeof(style) != 'hash') die("bad style");
		var m = {
			parents: [CanvasPlacement, style],
			state: "startup",
			listeners: [],
			window: canvas.Window.new(style.size, style.window_style, "REPL-interpreter-"~name),
			lines_of_text: [],
			history: [],
			curr: 0,
			completion_pos: 0,
			#tabs: [], # TODO: support multiple tabs
		};
		m.window.set("title", "Nasal REPL Interpreter");
		#debug.dump(m.window._node);
		m.window.del = func() {
			delete(me, "del");
			me.del(); # inherited canvas.Window.del();
			m.window = nil;
			m.del();
		};
		if (m.window_style != nil) m.window.setBool("resize", 1);
		m.canvas = m.window.createCanvas()
		                   .setColorBackground(m.colors.background);
		m.group = m.canvas.createGroup("content");
		m.vbox = canvas.VBoxLayout.new();
		m.window.setLayout(m.vbox);
		m.scroll = canvas.gui.widgets
		          .ScrollArea.new(m.group, canvas.style, {});
		m.scroll.setColorBackground(m.colors.background);
		m.vbox.addItem(m.scroll);
		m.group = m.scroll.getContent();
		m.create_msg();
		m.text_group = m.group.createChild("group", "text-display");
		m.text = nil;
		m.cursor = m.group.createChild("path")
			.moveTo(0, -m.padding)
			.lineTo(0, -11-m.padding)
			.setStrokeLineWidth(2)
			.setColor(m.colors.text)
			.hide();
		m.repl = REPL.new(placement:m, name:name);
		m.window.addEventListener("keydown", func(event) {
			var modifiers = {
				"shift":event.shiftKey,
				"ctrl":event.ctrlKey,
				"alt":event.altKey,
				"meta":event.metaKey
			};
			if (m.handle_key(event.key, modifiers, event.keyCode))
				#keyN.setValue(-1);           # drop key event
		});
		m.update();
		append(CanvasPlacement.instances, m);
		return m;
	},
	del: func() {
		if (me.window != nil)
		{ me.window.del(); me.window = nil }
		foreach (var l; me.listeners)
			removelistener(l);
		setsize(me.listeners, 0);
		forindex (var i; CanvasPlacement.instances)
			if (CanvasPlacement.instances[i] == me) {
				CanvasPlacement.instances[i] = CanvasPlacement.instances[-1];
				pop(CanvasPlacement.instances);
				break;
			}
	},
	add_char: func(char, reset_view=0) {
		me.reset_input_from_history();
		me.input ~= chr(char);
		me.text.appendText(chr(char));
		if (reset_view) me.reset_view();
		return nil;
	},
	add_text: func(text, reset_view=0) {
		me.reset_input_from_history();
		me.input ~= text;
		me.text.appendText(text);
		if (reset_view) me.reset_view();
		return nil;
	},
	remove_char: func(reset_view=0) {
		me.reset_input_from_history();
		me.input = substr(me.input, 0, size(me.input) - 1);
		var t = me.text.get("text");
		if (size(t) <= me.text.stop) return nil;
		me.text.setText(substr(t, 0, size(t)-1));
		if (reset_view) me.reset_view();
		return t[-1];
	},
	clear_input: func(reset_view=0) {
		me.reset_input_from_history();
		var ret = me.input;
		me.input = "";
		var t = me.text.get("text");
		me.text.setText(substr(t, 0, me.text.stop));
		if (reset_view) me.reset_view();
		return ret;
	},
	replace_line: func(replacement, replace_input=1, reset_view=0) {
		if (replace_input) me.input = replacement;
		var t = me.text.get("text");
		me.text.setText(substr(t, 0, me.text.stop)~replacement);
		if (reset_view) me.reset_view();
		return nil;
	},
	add_line: func(text, reset_text=1, reset_view=0) {
		me.create_line(reset_text);
		me.text.appendText(text);
		if (reset_view) me.reset_view();
	},
	new_prompt: func() {
		me.add_line(">>> ");
		me.text.stop = size(me.text.get("text"));
	},
	continue_line: func(reset_text=1) {
		me.add_line("... ", reset_text);
		me.text.stop = size(me.text.get("text"));
	},
	reset_input_from_history: func(reset_view=0) {
		if (me.curr < size(me.history)) {
			me.input = me.history[me.curr];
			me.curr = size(me.history);
		}
		if (reset_view) me.reset_view();
	},
	reset_view: func() {
		me.group.update();
		me.scroll.scrollToLeft().scrollToBottom();
	},
	set_line_color: func(color) {
		if (me.separate_lines)
			# Only change colors if this is its own line
			me.text.setColor(color);
	},
	set_line_font: func(font) {
		if (me.separate_lines)
			# Only change font if this is its own line
			me.text.setFont(font);
	},
	clear: func() {
		me.text.del();
		foreach (var t; me.lines_of_text)
			t.del();
		setsize(me.history, 0);
		me.curr = 0;
		me.input = "";
		me.text = nil;
		setsize(me.lines_of_text, 0);
		me.reset_view();
	},
	create_msg: func() {
		# Text drawing mode: text and maybe a bounding box
		var draw_mode = canvas.Text.TEXT + (me.colors.text_fill != nil ? canvas.Text.FILLEDBOUNDINGBOX : 0);

		me.msg = me.group.createChild("group", "startup-message");
		me.msg.text = me.msg.createChild("text", "help")
			.setTranslation(me.padding, me.padding+10)
			.setAlignment("left-baseline")
			.setFontSize(me.font_size, me.font_aspect_ratio)
			.setFont(me.font_file)
			.setColor(me.colors.text)
			.setDrawMode(draw_mode)
			.setMaxWidth(me.window.get("content-size[0]") - me.padding)
			.setText(me.gettranslation("help"));
		if (me.colors.text_fill != nil)
			me.msg.text.setColorFill(me.colors.text_fill);
		me.msg.text.update();
		#debug.dump(me.msg.text.getTransformedBounds());
		me.msg.left_col = me.msg.createChild("text", "keys")
			.setTranslation(me.padding, me.msg.text.getTransformedBounds()[3] + 30)
			.setAlignment("left-baseline")
			.setFontSize(me.font_size, me.font_aspect_ratio)
			.setFont(me.font_file)
			.setColor(me.colors.text)
			.setDrawMode(draw_mode);
		if (me.colors.text_fill != nil)
			me.msg.left_col.setColorFill(me.colors.text_fill);
		me.msg.left_col.update();
		for (var i=0; i<size(me.keys); i+=2) {
			if (i) me.msg.left_col.appendText("\n");
			me.msg.left_col.appendText("- "~me.keys[i]);
		}
		#debug.dump(me.msg.left_col.getTransformedBounds());
		me.msg.right_col = me.msg.createChild("text", "keys")
			.setTranslation(me.msg.left_col.getTransformedBounds()[2] + 20,
			                me.msg.text.getTransformedBounds()[3] + 30)
			.setAlignment("left-baseline")
			.setFontSize(me.font_size, me.font_aspect_ratio)
			.setFont(me.font_file)
			.setColor(me.colors.text)
			.setDrawMode(draw_mode);
		if (me.colors.text_fill != nil)
			me.msg.right_col.setColorFill(me.colors.text_fill);
		for (var i=0; i<size(me.keys); i+=2) {
			if (i) me.msg.right_col.appendText("\n");
			desc = me.keys[i+1];
			if (desc == nil) desc = me.gettranslation("key-not-mapped");
			elsif (desc[-1] != `.`) desc ~= ".";
			me.msg.right_col.appendText(desc);
		}
	},
	create_line: func(reset_text=1) {
		# c.f. above, in me.create_msg()
		var draw_mode = canvas.Text.TEXT + (me.colors.text_fill != nil ? canvas.Text.FILLEDBOUNDINGBOX : 0);

		if (reset_text) me.input = "";
		# If we only use one line, and one exists, things are simple:
		if (!me.separate_lines and me.text != nil) {
			me.text.appendText("\n");
			return;
		}
		# Else, we have to create a new line
		if (me.text != nil)
			append(me.lines_of_text, me.text);
		me.text = me.text_group
			.createChild("text", "input"~size(me.lines_of_text))
			.setAlignment("left-baseline")
			.setFontSize(me.font_size, me.font_aspect_ratio)
			.setFont(me.font_file)
			.setColor(me.colors.text)
			.setDrawMode(draw_mode)
			.setText(size(me.lines_of_text) ? ">" : ""); # FIXME: hack, canvas::Text needs a printing character
			                                             # on the first line in order to recognize the newlines ?
		if (me.colors.text_fill != nil)                       
			me.text.setColorFill(me.colors.text_fill);
		if (me.font_max_width != nil)
			if (me.font_max_width < 0)
				me.text.setMaxWidth(me.window.get("content-size[0]") - me.font_max_width);
			else
				me.text.setMaxWidth(me.font_max_width);

		foreach (var t; me.lines_of_text)
			me.text.appendText("\n");
	},
	update: func() {
		#debug.dump(me.text.getTransformedBounds());
		if (me.state != "startup")
			me.cursor.setTranslation(
				me.text.getTransformedBounds()[2] + 6,
				me.text.getTransformedBounds()[3] + 5
			).show();
		me.scroll.update();
	},
	handle_key: func(key, modifiers, keyCode) {
		var modifier_str = "";
		foreach (var m; keys(modifiers)) {
			if (modifiers[m])
				modifier_str ~= substr(m,0,1);
		}
		if (me.state == "startup") {
			me.msg.del(); me.msg = nil;
			me.new_prompt(); # initialize a new line
			me.text.stop = size(me.text.get("text"));
			me.state = "accepting input";

		} elsif (!contains({"s":,"c":,"":}, modifier_str)) {
			return 0; # had extra modifiers, reject this event

		} elsif (modifiers.ctrl) {
			if (keyCode == `c`) {
				printlog(_REPL_dbg_level, "ctrl+c: "~debug.string(me.input));
				me.reset_input_from_history();
				if( size(me.input) and !clipboard.setText(me.input) )
					print("Failed to write to clipboard");
			} elsif (keyCode == `x`) {
				printlog(_REPL_dbg_level, "ctrl+x");
				me.reset_input_from_history();
				if( size(me.input) and !clipboard.setText(me.clear_input()) )
					print("Failed to write to clipboard");
			} elsif (keyCode == `v`) {
				var input = clipboard.getText();
				printlog(_REPL_dbg_level, "ctrl+v: "~debug.string(input));
				me.reset_input_from_history();
				var abnormal = func string.iscntrl(input[j]) or (string.isxspace(input[j]) and input[j] != ` `) or !string.isascii(input[j]);
				var i=0;
				while (i<size(input)) {
					for (var j=i; j<size(input); j+=1)
						if (abnormal()) break;
					if (j != i) me.add_text(substr(input, i, j-i));
					while (j<size(input) and abnormal()) {
						# replace tabs with spaces
						if (input[j] == `\t`)
							me.add_char(` `);
						# handle newlines like they're shift+space, i.e. continue don't evaluate
						elsif (input[j] == `\n` or input[j] == `\r`) {
							if (j<size(input)-1 and input[j+1] == `\n`)
								j+=1;
							me.input ~= "\n"; me.continue_line(reset_text:0);
						}
						# skip other non-ascii characters
						j += 1;
					}
					i=j;
				}
			} elsif (keyCode == `d`) { # ctrl-D/EOF
				printlog(_REPL_dbg_level, "EOF");
				me.del();
				return 1;
			} else return 0;

		} elsif (key == "Enter") {
			printlog(_REPL_dbg_level, "return (key: "~key~", shift: "~modifiers.shift~")");
			me.reset_input_from_history();
			var reset_text = 1;
			if (modifiers.shift) {
				var res = -1;
				me.input ~= "\n";
				reset_text = 0;
			} else {
				if (size(string.trim(me.input))) {
					append(me.history, me.input);
					me.curr += 1; # simplified version of: me.curr = size(me.history);
					if (me.curr != size(me.history)) die(me.curr~" vs "~size(me.history));
				}
				CanvasPlacement.current_instance = me;
				var res = me.repl.get_input();
				CanvasPlacement.current_instance = nil;
				printlog(_REPL_dbg_level, "return code: "~debug.string(res));
			}
			if (res == -1)
				me.continue_line(reset_text:reset_text);
			else me.new_prompt();

		} elsif (key == "Backspace") {               # backspace
			printlog(_REPL_dbg_level, "back");
			me.reset_input_from_history();
			if (me.remove_char() == nil) return 1; # nothing happened, since the input
			                                       # field was blank, but capture the event
			me.completion_pos = -1;

		} elsif (key == "Up") {             # up
			printlog(_REPL_dbg_level, "up");
			if (me.curr == 0) return 1;
			me.curr -= 1;
			if (me.curr == size(me.history))
				me.replace_line(me.input, 0);
			else
				me.replace_line(me.history[me.curr], 0);
			me.completion_pos = -1;

		} elsif (key == "Down") {             # down
			printlog(_REPL_dbg_level, "down");
			if (me.curr == size(me.history)) return 1;
			me.curr += 1;
			if (me.curr == size(me.history))
				me.replace_line(me.input, 0);
			else
				me.replace_line(me.history[me.curr], 0);
			me.completion_pos = -1;

		} elsif (key == "Escape") {  # escape -> cancel
			printlog(_REPL_dbg_level, "esc");
			me.del();
			return 1;

		} elsif (key == "Tab") {            # tab
			printlog(_REPL_dbg_level, "tab");
			return 0;
			me.reset_input_from_history();
			if (size(text) and text[0] == `/`) {
				me.input = me.complete(me.input, modifiers.shift ? -1 : 1);
			}

		} elsif (size(key) > 1 or !string.isprint(key[0])) {
			printlog(_REPL_dbg_level, "other key: "~key);
			return 0;                  # pass other funny events

		} else {
			printlog(_REPL_dbg_level, "key: "~key[0]~" (`"~key~"`)");
			me.add_char(key[0]);
			me.completion_pos = -1;
		}

		#printlog(_REPL_dbg_level, "  -> "~me.input);

		me.update();
		me.reset_view();

		return 1;                                # discard key event
	},
	get_line: func() {
		return me.input;
	},
	display_result: func(res=nil) {
		if (res == nil) return 1; # don't display NULL results
		var res = call(debug.string, [res, 0], var err=[]);
		if (size(err)) {
			me.add_line(me.gettranslation("bad-result"));
			me.set_line_color(me.colors.error);
			if (me.font_file == "LiberationFonts/LiberationMono-Bold.ttf")
				me.set_line_font("LiberationFonts/LiberationMono-BoldItalic.ttf");
			return 1;
		}
		if (size(res) > me.max_output_chars)
			res = substr(res, 0, me.max_output_chars-5)~". . .";
		me.add_line(res);
		return 1;
	},
	handle_runtime_error: func(err) {
		debug.printerror(err);
		me.add_line("Runtime error: "~err[0]);
		me.set_line_color(me.colors.error);
		for (var i=1; i<size(err); i+=2) {
			me.add_line("   at "~err[i]~", line "~err[i+1]);
		}
	},
	handle_parse_error: func(msg, file, line) {
		print("Parse error: "~msg~" on line "~line~" in "~file);
		me.add_line("Parse error: "~msg~" on line "~line~" in "~file);
		me.set_line_color(me.colors.error);
	},
	gettranslation: func(k) me.translations[k] or "[Error: no translation for key "~k~"]",
};

var print2 = func(i) {
	console.CanvasPlacement.current_instance.display_result(i);
	return nil; # just to suppress output
}
#CanvasPlacement.new("<styled-canvas-repl>", "canvas-default");

