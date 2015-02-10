# material dialog
# ===============
#
# Usage:  material.showDialog(<path>, [<title>], [<x>], [<y>]);
#
# the path should point to a property "directory" (usually set in
# the aircraft's *-set.xml file) that contains any of
# (shininess|transparency|texture) and (diffuse|ambient|specular|emission),
# whereby the latter four are directories containing any of
# (red|green|blue|factor|offset).
#
# If <title> is omitted or nil, then the last path component is used as title.
# If <x> and <y> are undefined, then the dialog is centered.
#
#
# Example:
#   <foo>
#       <diffuse>
#           <red>1.0</red>
#           <green>0.5</green>
#           <blue>0.5</blue>
#       </diffuse>
#       <transparency>0.5</transparency>
#       <texture>bar.rgb</texture>
#   </foo>
#
#
#   material.showDialog("/sim/model/foo/", "FOO");
#
#
#
# Of course, these properties are only used if a "material" animation
# references them via <*-prop> definition.
#
# Example:
#
#  <animation>
#      <type>material</type>
#      <object-name>foo</object-name>
#      <property-base>/sim/model/foo</property-base>
#      <diffuse>
#          <red-prop>diffuse/red</red-prop>
#          <green-prop>diffuse/green</green-prop>
#          <blue-prop>diffuse/blue</blue-prop>
#      </diffuse>
#      <transparency-prop>transparency</transparency-prop>
#      <texture-prop>texture</texture-prop>
#  </animation>
#

var dialog = nil;

var colorgroup = func(parent, name, base) {
	var undef = func(color) { props.globals.getNode(base ~ name ~ "/" ~ color) == nil };

	if (undef("red") and undef("green") and undef("blue")) {
		return 0;
	}

	if (base != nil) {
		parent.addChild("hrule").setColor(1, 1, 1, 0.5);
	}

	var grp = parent.addChild("group");
	grp.set("layout", "vbox");
	grp.addChild("text").set("label", name);

	foreach (var color; ["red", "green", "blue", "factor"]) {
		mat(parent, color, base ~ name ~ "/" ~ color, "%.3f");
	}
	mat(parent, "offset", base ~ name ~ "/" ~ "offset", "%.3f", -1.0, 1.0);
	return 1;
}


var mat = func(parent, name, path, format, min=nil, max=nil) {
	if (props.globals.getNode(path) != nil) {
		var grp = parent.addChild("group");
		grp.set("layout", "hbox");

		grp.addChild("empty").set("stretch", 1);
		grp.addChild("text").set("label", name);

		var slider = grp.addChild("slider");
		slider.set("property", path);
		slider.set("live", 1);
		if (min != nil and max != nil) {
			slider.set("min", min);
			slider.set("max", max);
		}
		slider.setBinding("dialog-apply");

		var number = grp.addChild("text");
		number.set("label", "-0.123");
		number.set("format", format);
		number.set("property", path);
		number.set("live", 1);
		number.setColor(1, 0, 0);
	}
}


var showDialog = func(base, title=nil, x=nil, y=nil) {
	while (size(base) and substr(base, size(base) - 1, 1) == "/") {
		base = substr(base, 0, size(base) - 1);
	}
	var parentdir = "";
	var b = base;
	while (size(b)) {
		c = substr(b, size(b) - 1, 1);
		if (c == "/") { break }
		b = substr(b, 0, size(b) - 1);
		parentdir = c ~ parentdir;
	}

	if (title == nil) var title = parentdir;
	var name = "material-" ~ parentdir;
	base = base ~ "/";

	dialog = gui.Widget.new();
	dialog.set("name", name);
	if (x != nil) dialog.set("x", x);
	if (y != nil) dialog.set("y", y);
	dialog.set("layout", "vbox");

	var titlebar = dialog.addChild("group");
	titlebar.set("layout", "hbox");
	var w = titlebar.addChild("text");
	w.set("label", "object \"" ~ title ~ "\"");
	titlebar.addChild("empty").set("stretch", 1);

	w = titlebar.addChild("button");
	w.set("pref-width", 16);
	w.set("pref-height", 16);
	w.set("legend", "");
	w.set("default", 1);
	w.set("keynum", 27);
	w.set("border", 1);
	w.setBinding("dialog-close");

	var h = 0;
	h += colorgroup(dialog, "diffuse", base, h);
	h += colorgroup(dialog, "ambient", base, h);
	h += colorgroup(dialog, "emission", base, h);
	h += colorgroup(dialog, "specular", base, h);

	var undef = func(prop) { props.globals.getNode(base ~ prop) == nil };
	if (!(undef("shininess") and undef("transparency/alpha") and undef("threshold"))) {
		if (h) {
			dialog.addChild("hrule").setColor(1, 1, 1, 0.5);
		}

		w = dialog.addChild("group");
		w.set("layout", "hbox");
		w.addChild("text").set("label", "misc");

		mat(dialog, "shi", base ~ "shininess", "%.0f", 0.0, 128.0);
		mat(dialog, "alpha", base ~ "transparency/alpha", "%.3f");
		mat(dialog, "thresh", base ~ "threshold", "%.3f");
		h += 1;
	}

	if (!undef("texture")) {
		if (h) {
			dialog.addChild("hrule").setColor(1, 1, 1, 0.5);
		}

		w = dialog.addChild("group");
		w.set("layout", "hbox");
		w.addChild("text").set("label", "texture");

		w = dialog.addChild("input");
		w.set("live", 1);
		w.set("pref-width", 200);
		w.set("property", base ~ "texture");
		w.setBinding("dialog-apply");
	}
	dialog.addChild("empty").set("pref-height", "3");

	dialog.setColor(0.6, 0.6, 0.6, 0.6);

	fgcommand("dialog-new", dialog.prop());
	gui.showDialog(name);
}


