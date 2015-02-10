var dialog = nil;
var namenode = nil;

var close = func {
    zkv500.isOn = 0;
    fgcommand("dialog-close", namenode);
    delete(gui.dialog, "\"zkv500\"");
    dialog = nil;
}

var _title = func {
    var titlebar = dialog.addChild("group");
    titlebar.set("layout", "hbox");
        var wdg = titlebar.addChild("text");
        wdg.set("label", "test zkv500");
    titlebar.addChild("empty").set("stretch", 1);
        var wdg = titlebar.addChild("button");
        wdg.node.setValues({"pref-width": 16, "pref-height": 16, legend: "", default: 0});
        wdg.setBinding("nasal", "zkv_dbg.close()");
}

var _top_buttons = func {
    dialog.addChild("hrule");
    var buttons = dialog.addChild("group");
    buttons.set("layout", "hbox");
	var wdg = buttons.addChild("button");
        wdg.node.setValues({legend: "P", "pref-height": 20});
        wdg.setBinding("nasal", "zkv500.left_knob(1)");
	var wdg = buttons.addChild("button");
	wdg.node.setValues({legend: "en", "pref-height": 20});
	wdg.setBinding("nasal", "zkv500.enter_button()");
	var wdg = buttons.addChild("button");
	wdg.node.setValues({legend: "es", "pref-height": 20});
	wdg.setBinding("nasal", "zkv500.escape_button()");
	var wdg = buttons.addChild("button");
	wdg.node.setValues({legend: "st", "pref-height": 20});
	wdg.setBinding("nasal", "zkv500.start_button()");
	var wdg = buttons.addChild("button");
	wdg.node.setValues({legend: "S", "pref-height": 20});
	wdg.setBinding("nasal", "zkv500.right_knob(1)");
}

var _content = func {
    dialog.addChild("hrule");
    var content = dialog.addChild("group");
    content.set("layout", "table");
    content.set("default-padding", 0);
    for (var i = 0; i < 5; i += 1) {
	var line = content.addChild("text");
	line.node.setValues({"row":i,"col":0,"label":" "});
	var line = content.addChild("text");
	line.node.setValues({
	    "row": i,
	    "col": 1,
	    "property": "/instrumentation/zkv500/line["~i~"]",
	    "halign": "left",
	    "live": 1
	});
	var line = content.addChild("text");
	line.node.setValues({"row":i,"col":2,"label":" "});
    }
}

var _bottom_buttons = func {
    dialog.addChild("hrule");
    var buttons = dialog.addChild("group");
    buttons.set("layout", "hbox");
        var wdg = buttons.addChild("button");
        wdg.node.setValues({legend: "M", "pref-height": 20});
        wdg.setBinding("nasal", "zkv500.select_mode(1)");
    buttons.addChild("empty").set("stretch", 1);
        var wdg = buttons.addChild("button");
        wdg.node.setValues({legend: "0/1", "pref-height": 20});
        wdg.setBinding("nasal", "zkv500.switch_ON_OFF()");
}

var reload_zkv_code = func {
    var zkv500_dir = getprop("/sim/fg-root") ~ "/Aircraft/Instruments-3d/zkv500/";
    io.load_nasal(zkv500_dir ~ "ZKV500.nas","zkv500");
    print("debugger: zkv500 loaded");
    zkv500.init();
}

var test = func {
    dialog == nil or close();
    reload_zkv_code();

    namenode = props.Node.new({"dialog-name" : "zkv500" });
    dialog = gui.Widget.new();
    dialog.set("name", "zkv500");

    dialog.set("layout", "vbox");
    dialog.set("default-padding", 0);

    _title();
    _top_buttons();
    _content();
    _bottom_buttons();

    fgcommand("dialog-new", dialog.prop());
    fgcommand("dialog-show", namenode);
    print("debugger: zkv500 testing interface loaded");
}
