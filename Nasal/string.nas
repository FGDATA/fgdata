var iscntrl = func(c) c >= 1 and c <= 31 or c == 127;
var isascii = func(c) c >= 0 and c <= 127;
var isupper = func(c) c >= `A` and c <= `Z`;
var islower = func(c) c >= `a` and c <= `z`;
var isdigit = func(c) c >= `0` and c <= `9`;
var isblank = func(c) c == ` ` or c == `\t`;
var ispunct = func(c) c >= `!` and c <= `/` or c >= `:` and c <= `@`
		or c >= `[` and c <= `\`` or c >= `{` and c <= `~`;

var isxdigit = func(c) isdigit(c) or c >= `a` and c <= `f` or c >= `A` and c <= `F`;
var isspace = func(c) c == ` ` or c >= `\t` and c <= `\r`;
var isalpha = func(c) isupper(c) or islower(c);
var isalnum = func(c) isalpha(c) or isdigit(c);
var isgraph = func(c) isalnum(c) or ispunct(c);
var isprint = func(c) isgraph(c) or c == ` `;

var toupper = func(c) islower(c) ? c + `A` - `a` : c;
var tolower = func(c) isupper(c) ? c + `a` - `A` : c;

var isxspace = func(c) isspace(c) or c == `\n`;


##
# trim spaces at the left (lr < 0), at the right (lr > 0), or both (lr = 0)
# An optional function argument defines which characters should be trimmed:
#
#  string.trim(a);                                    # trim spaces
#  string.trim(a, 1, string.isdigit);                 # trim digits at the right
#  string.trim(a, 0, func(c) c == `\\` or c == `/`);  # trim slashes/backslashes
#
var trim = func(s, lr = 0, istrim = nil) {
	if (istrim == nil)
		istrim = isspace;
	var l = 0;
	if (lr <= 0)
		for (; l < size(s); l += 1)
			if (!istrim(s[l]))
				break;
	var r = size(s) - 1;
	if (lr >= 0)
		for (; r >= 0; r -= 1)
			if (!istrim(s[r]))
				break;
	return r < l ? "" : substr(s, l, r - l + 1);
}


##
# return string converted to lower case letters
#
var lc = func(str) {
	var s = "";
	for (var i = 0; i < size(str); i += 1)
		s ~= chr(tolower(str[i]));
	return s;
}


##
# return string converted to upper case letters
#
var uc = func(str) {
	var s = "";
	for (var i = 0; i < size(str); i += 1)
		s ~= chr(toupper(str[i]));
	return s;
}


##
# case insensitive string compare and match functions
# (not very efficient -- converting the array to be sorted
# first is faster)
#
var icmp = func(a, b) cmp(lc(a), lc(b));
var imatch = func(a, b) match(lc(a), lc(b));




##
# Functions that are used in the IO security code (io.nas) are defined in a
# closure that holds safe copies of system functions. Later manipulation of
# append(), pop() etc. doesn't affect them. Of course, any security code
# must itself store safe copies of these tamper-proof functions before user
# code can redefine them, and the closure() command must be made inaccessible.
##

var match = nil;
var normpath = nil;
var join = nil;
var replace = nil;

(func {
	var append = append;
	var caller = caller;
	var pop = pop;
	var setsize = setsize;
	var size = size;
	var split = split;
	var substr = substr;
	var subvec = subvec;


##
# check if string <str> matches shell style pattern <patt>
#
# Rules:
# ?   stands for any single character
# *   stands for any number (including zero) of arbitrary characters
# \   escapes the next character and makes it stand for itself; that is:
#     \? stands for a question mark (not the "any single character" placeholder)
# []  stands for a group of characters:
#     [abc]      stands for letters a, b or c
#     [^abc]     stands for any character but a, b, and c  (^ as first character -> inversion)
#     [1-4]      stands for digits 1 to 4 (1, 2, 3, 4)
#     [1-4-]     stands for digits 1 to 4, and the minus
#     [-1-4]     same as above
#     [1-3-6]    stands for digits 1 to 3, minus, and 6
#     [1-3-6-9]  stands for digits 1 to 3, minus, and 6 to 9
#     [][]       stands for the closing and the opening bracket (']' must be first!)
#     [^^]       stands for all characters but the caret symbol
#     [\/]       stands for a backslash or a slash  (the backslash isn't an
#                escape character in a [] character group)
#
#     Note that a minus can't be a range delimiter, as in [a--e],
#     which would be interpreted as any of a, e, or minus.
#
# Example:
#     string.match(name, "*[0-9].xml"); ... true if 'name' ends with digit followed by ".xml"
#
match = func(str, patt) {
	var s = 0;
	for (var p = 0; p < size(patt) and s < size(str); ) {
		if (patt[p] == `\\`) {
			if ((p += 1) >= size(patt))
				return 0;  # pattern ends with backslash

		} elsif (patt[p] == `?`) {
			s += 1;
			p += 1;
			continue;

		} elsif (patt[p] == `*`) {
			for (; p < size(patt); p += 1)
				if (patt[p] != `*`)
					break;
			if (p >= size(patt))
				return 1;

			for (; s < size(str); s += 1)
				if (caller(0)[1](substr(str, s), substr(patt, p)))
					return 1;
			continue;

		} elsif (patt[p] == `[`) {
			setsize(var x = [], 256);
			var invert = 0;
			if ((p += 1) < size(patt) and patt[p] == `^`) {
				p += 1;
				invert = 1;
			}
			for (var i = 0; p < size(patt); p += 1) {
				if (patt[p] == `]` and i)
					break;
				x[patt[p]] = 1;
				i += 1;

				if (p + 2 < patt[p] and patt[p] != `-` and patt[p + 1] == `-`
						and patt[p + 2] != `]` and patt[p + 2] != `-`) {
					var from = patt[p];
					var to = patt[p += 2];
					for (var c = from; c <= to; c += 1)
						x[c] = 1;
				}
			}
			if (invert ? !!x[str[s]] : !x[str[s]])
				return 0;
			s += 1;
			p += 1;
			continue;
		}

		if (str[s] != patt[p])
			return 0;
		s += 1;
		p += 1;
	}
	return s == size(str) and p == size(patt);
}


##
# Removes superfluous slashes, empty and "." elements,
# expands all ".." elements keeping relative paths,
# and turns all backslashes into slashes.
# The result will start with a slash if it started with a slash or backslash,
# it will end without slash.
#
normpath = func(path) {
	path = replace(path, "\\", "/");
	var prefix = size(path) and path[0] == `/` ? "/" : "";

	var stack = [];
	var relative = 1;

	foreach (var e; split("/", path)) {
		if (e == "." or e == "")
			continue;
		elsif (e == ".." and !relative)
			pop(stack);
		else {
			append(stack, e);
			relative = 0;
		}
	}
	return size(stack) ? prefix ~ join("/", stack) : "/";
}


##
# Join all elements of a list inserting a separator between every two of them.
#
join = func(sep, list) {
	if (!size(list))
		return "";
	var str = list[0];
	foreach (var s; subvec(list, 1))
		str ~= sep ~ s;
	return str;
}


##
# Replace all occurrences of 'old' by 'new'.
#
replace = func(str, old, new) {
	return join(new, split(old, str));
}

})(); # end tamper-proof environment


##
# Get a function out of a string template for fast insertion of template
# parameters. This allows to use the same templates as with most available tile
# mapping engines (eg. Leaflet, Polymaps). Return a callable function object on
# success, and nil if parsing the templated fails. See string._template_getargs
# for more on calling a compile object.
#
# Example (Build MapQuest tile url):
#
#    var makeUrl = string.compileTemplate(
#      "http://otile1.mqcdn.com/tiles/1.0.0/map/{z}/{x}/{y}.jpg"
#    );
#    print( makeUrl({x: 5, y: 4, z: 3}) );
#
# Output:
#
#    http://otile1.mqcdn.com/tiles/1.0.0/map/3/5/4.jpg
#
var compileTemplate = func(template, type=nil) {
	var code = 'func(__ENV=nil) { string._template_getargs();';
	var len = size(template);
	var start = 0;
	var end = 0;
	if (type == nil or type == "simple_names") {
		# See http://james.padolsey.com/javascript/straight-up-interpolation/
		while( (start = template.find('{', end)) >= 0 )
		{
			if( end > 0 )
				code ~= '~';
			code ~= '"' ~ substr(template, end, start - end) ~ '"';
			if( (end = template.find('}', start)) < 0 )
			{
				debug.warn("string.compileTemplate: unclosed brace pair (" ~ template ~ ")");
				return nil;
			}

			code ~= '~__ENV["' ~ substr(template, start + 1, end - start - 1) ~ '"]';
			end += 1;
		}
		if( end < len )
			code ~= '~"' ~ substr(template, end, len - end) ~ '"';
	} elsif (type == "nasal_expression") {
		var level = 0;
		for (var i=0; i<len; i+=1) {
			if (template[i] != `{`) continue;
			start = i;
			if ( end > 0 )
				code ~= "~";
			code ~= '"' ~ substr(template, end, start - end) ~ '"';
			level = 1; var skip = 0;
			for (var j=i+1; j<len and level > 0; j+=1)
				if (template[j] == `{`) level += 1;
				elsif (template[j] == `}`) level -= 1;
				elsif (template[j] == `"`)
					if    (skip == `"`) skip = 0;
					elsif (skip != `'`) skip = `"`;
				elsif (template[j] == `'`)
					if    (skip == `'`) skip = 0;
					elsif (skip != '"') skip = `'`;
				elsif (skip)
					if ((skip == `'` or skip == `"`) and template[j] == `\\`)
						skip = `\\`;
					elsif (skip == `\\` and template[j] == `\\`)
						skip = skip;
					else
						skip = 0;
			if (level)
				die("string.compileTemplate: unclosed brace pair (" ~ template ~ ")");
			end = j;
			code ~= '~(' ~ substr(template, start + 1, end - start - 1)~")";
			end += 1;
			i = end;
		}
		if( end < len )
			code ~= '~"' ~ substr(template, end, len - end) ~ '"';
	}
	code ~= "}";
	var fn = compile(code)(); # get the inside function with the argument __ENV=nil
	var (ns,fn1) = caller(1);
	return bind(fn, ns, fn1);
}

##
# Private function used by string.naCompileTemplate. Expands any __ENV parameter
# into the locals of the caller. This allows both named arguments and manual hash
# arguments via __ENV.
#
# Examples using (format = func(__ENV) {string._template_getargs()}):
#
# Pass arguments as hash:
#   format({a: 1, "b ":2});
# Or:
#   format(__ENV:{a: 1, "b ":2});
# Pass arguments as named:
#   format(a: 1, "b ":2);
# Pass arguments as both named and hash, using
# __ENV to specify the latter:
#   format(a: 1, __ENV:{"b ": 2});
#
var _template_getargs = func() {
	var ns = caller(1)[0];
	if (contains(ns, "__ENV")) {
		var __ENV = ns.__ENV;
		if (__ENV != nil)
			foreach (var k; keys(__ENV))
				ns[k] = __ENV[k];
	}
	ns.__ENV = ns;
}


##
# Simple scanf function. Takes an input string, a pattern, and a
# vector. It returns 0 if the format didn't match, and appends
# all found elements to the given vector. Return values:
#
# -1 string matched format ending with % (i.e. more chars than format cared about)
#  0 string didn't match format
#  1 string matched, but would still match if the right chars were added
#  2 string matched, and would not if any character would be added
#
#   var r = string.scanf("comm3freq123.456", "comm%ufreq%f", var result = []);
#
# The result vector will be set to [3, 123.456].
#
var Scan = {
	new : func(s) {{ str: s, pos: 0, parents: [Scan] }},
	getc : func {
		if (me.pos >= size(me.str))
			return nil;
		var c = me.str[me.pos];
		me.pos += 1;
		return c;
	},
	ungetc : func { me.pos -= 1 },
	rest : func { substr(me.str, me.pos) },
};


var scanf = func(test, format, result) {
	if (find("%", format) < 0)
		return cmp(test, format) ? 0 : 2;

	var success = 0;
	var str = Scan.new(test);
	var format = Scan.new(format);

	while (1) {
		var f = format.getc();
		if (f == nil) {
			break;

		} elsif (f == `%`) {
			success = 1;		# unsafe match
			f = format.getc();
			if (f == nil)
				return -1;	# format ended with %
			if (f == `%`) {
				if (str.getc() != `%`)
					return 0;
				success = 2;
				continue;
			}

			if (isdigit(f)) {
				var fnum = f - `0`;
				while ((f = format.getc()) != nil and isdigit(f))
					fnum = fnum * 10 + f - `0`;
			} else {
				var fnum = -2; # because we add one if !prefix
			}

			var scanstr = "";
			var prefix = 0;
			var sign = 1;
			if (f == `d` or f == `f` or f == `u`) {
				var c = str.getc();
				if (c == nil) {
					return 0;
				} elsif (c == `+`) {
					prefix = 1;
				} elsif (c == `-`) {
					if (f == `u`)
						return 0;
					(prefix, sign) = (1, -1);
				} else {
					str.ungetc();
				}
				if (!prefix)
					fnum += 1;

				while ((var c = str.getc()) != nil and (fnum -= 1)) {
					if (f != `f` and c == `.`)
						break;
					elsif (num(scanstr ~ chr(c) ~ '0') != nil) # append 0 to digest e/E
						scanstr ~= chr(c);
					else
						break;
				}
				if (c != nil)
					str.ungetc();
				if (num(scanstr) == nil)
					return 0;
				if (!size(scanstr) and prefix)
					return 0;
				append(result, sign * num(scanstr));

			} elsif (f == `s`) {
				fnum += 1;
				while ((var c = str.getc()) != nil and c != ` ` and (fnum -= 1))
					scanstr ~= chr(c);

				if (c != nil)
					str.ungetc();
				if (!size(scanstr))
					return 0;

				append(result, scanstr);

			} else {
				die("scanf: bad format element %" ~ chr(f));
			}


		} elsif (isspace(f)) {
			while ((var c = str.getc()) != nil and isspace(c))
				nil;
			if (c != nil)
				str.ungetc();

		} elsif (f != (var c = str.getc())) {
			return 0;

		} else {
			success = 2;		# safe match
		}
	}
	return str.getc() == nil and format.getc() == nil ? success : 0;
}


##
# ANSI colors  (see $ man console_codes)
#
var setcolors = func(enabled) {
	color_enabled = (enabled and getprop("/sim/startup/stderr-to-terminal"));
}
var color = func(color, s, enabled=nil) {
	if (enabled == nil) enabled = color_enabled;
	return enabled ? "\x1b[" ~ color ~ "m" ~ s ~ "\x1b[m" : s;
}


##
# Add ANSI color codes to string, if terminal-ansi-colors are enabled and
# stderr prints to a terminal. Example:
#
#   print(string.color("31;1", "this is red"));
#
var color_enabled = 0;
_setlistener("/sim/signals/nasal-dir-initialized", func {
	setlistener("/sim/startup/terminal-ansi-colors", func(n) setcolors(n.getBoolValue()), 1, 0);
});


