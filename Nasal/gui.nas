##
# Pop up a "tip" dialog for a moment, then remove it.  The delay in
# seconds can be specified as the second argument.  The default is 4
# seconds.  The third argument can be a hash with override values.
# Note that the tip dialog is a shared resource.  If someone else
# comes along and wants to pop a tip up before your delay is finished,
# you lose. :)
#
var popupTip = func(label, delay = nil, override = nil)
{
    fgcommand("show-message", props.Node.new({ "label": label, "delay":delay }));


}

var showDialog = func(name) {
    fgcommand("dialog-show", props.Node.new({ "dialog-name" : name }));
}

##
# Enable/disable named menu entry
#
var menuEnable = func(searchname, state) {
    foreach (var menu; props.globals.getNode("/sim/menubar/default").getChildren("menu")) {
        foreach (var name; menu.getChildren("name")) {
            if (name.getValue() == searchname) {
                menu.getNode("enabled").setBoolValue(state);
            }
        }
        foreach (var item; menu.getChildren("item")) {
            foreach (var name; item.getChildren("name")) {
                if (name.getValue() == searchname) {
                    item.getNode("enabled").setBoolValue(state);
                }
            }
        }
    }
}

##
# Set the binding for a menu item to a Nasal script,
# typically a dialog open() command.
#
var menuBind = func(searchname, command) {
    foreach (var menu; props.globals.getNode("/sim/menubar/default").getChildren("menu")) {
        foreach (var item; menu.getChildren("item")) {
            foreach (var name; item.getChildren("name")) {
                if (name.getValue() == searchname) {
                    item.getNode("binding", 1).getNode("command", 1).setValue("nasal");
                    item.getNode("binding", 1).getNode("script", 1).setValue(command);
                    fgcommand("gui-redraw");
                }
            }
        }
    }
}

##
# Set mouse cursor coordinates and shape (number or name), and return
# current shape (number).
#
# Example:  var cursor = gui.setCursor();
#           gui.setCursor(nil, nil, "wait");
#
var setCursor = func(x = nil, y = nil, cursor = nil) {
    var args = props.Node.new();
    if (x != nil) args.getNode("x", 1).setIntValue(x);
    if (y != nil) args.getNode("y", 1).setIntValue(y);
    if (cursor != nil) {
        if (num(cursor) == nil)
            cursor = cursor_types[cursor];
        if (cursor == nil)
            die("cursor must be one of: " ~ string.join(", ", keys(cursor_types)));
        setprop("/sim/mouse/hide-cursor", cursor);
        args.getNode("cursor", 1).setIntValue(cursor);
    }
    fgcommand("set-cursor", args);
    return args.getValue("cursor");
}

##
# Supported mouse cursor types.
#
var cursor_types = { none: 0, pointer: 1, wait: 2, crosshair: 3, leftright: 4,
    topside: 5, bottomside: 6, leftside: 7, rightside: 8,
    topleft: 9, topright: 10, bottomleft: 11, bottomright: 12,
};

##
# Find a GUI element by given name.
# dialog: dialog root property.
# name: name of GUI element to be searched.
# Returns GUI element when found, nil otherwise.
#
var findElementByName = func(dialog,name) {
	foreach( var child; dialog.getChildren() ) {
		var n = child.getNode( "name" );
		if( n != nil and n.getValue() == name )
			return child;
		var f = findElementByName(child, name);
		if( f != nil ) return f;
	}
	return nil;
};


########################################################################
# Private Stuff:
########################################################################

##
# Initialize property nodes via a timer, to insure the props module is
# loaded.  See notes in view.nas.  Simply cache the screen height
# property and the argument for the "dialog-show" command.  This
# probably isn't really needed...
#
var fdm = getprop("/sim/flight-model");
var screenHProp = nil;
var autopilotDisableProps = [
  "/autopilot/hide-menu",
  "/autopilot/KAP140/locks",
  "/autopilot/CENTURYIIB/locks",
  "/autopilot/CENTURYIII/locks"
];

_setlistener("/sim/signals/nasal-dir-initialized", func {
    screenHProp = props.globals.getNode("/sim/startup/ysize");

    props.globals.getNode("/sim/help/debug", 1).setValues(debug_keys);
    props.globals.getNode("/sim/help/basic", 1).setValues(basic_keys);
    props.globals.getNode("/sim/help/common", 1).setValues(common_aircraft_keys);

    # enable/disable menu entries
    menuEnable("fuel-and-payload", fdm == "yasim" or fdm == "jsb");
    menuEnable("aircraft-checklists", props.globals.getNode("/sim/checklists") != nil);
    var isAutopilotMenuEnabled = func {
      foreach( var apdp; autopilotDisableProps ) {
        if( props.globals.getNode( apdp ) != nil )
          return 0;
      }
      return 1;
    }
    menuEnable("autopilot", isAutopilotMenuEnabled() );
    menuEnable("joystick-info", size(props.globals.getNode("/input/joysticks").getChildren("js")));
    menuEnable("rendering-buffers", getprop("/sim/rendering/rembrandt/enabled"));
    menuEnable("rembrandt-buffers-choice", getprop("/sim/rendering/rembrandt/enabled"));
    menuEnable("stereoscopic-options", !getprop("/sim/rendering/rembrandt/enabled"));
    menuEnable("sound-config", getprop("/sim/sound/working"));

    # frame-per-second display
    var fps = props.globals.getNode("/sim/rendering/fps-display", 1);
    setlistener(fps, fpsDisplay, 1);
    setlistener("/sim/startup/xsize", func {
        if (fps.getValue()) {
            fpsDisplay(0);
            fpsDisplay(1);
        }
    });

    # frame-latency display
    var latency = props.globals.getNode("/sim/rendering/frame-latency-display", 1);
    setlistener(latency, latencyDisplay, 1);
    setlistener("/sim/startup/xsize", func {
        if (latency.getValue()) {
            latencyDisplay(0);
            latencyDisplay(1);
        }
    });

    # only enable precipitation if gui *and* aircraft want it
    var p = "/sim/rendering/precipitation-";
    var precip_gui = getprop(p ~ "gui-enable");
    var precip_ac = getprop(p ~ "aircraft-enable");
    props.globals.getNode(p ~ "enable").setAttribute("userarchive", 0); # TODO remove later
    var set_precip = func setprop(p ~ "enable", precip_gui and precip_ac);
    setlistener(p ~ "gui-enable", func(n) set_precip(precip_gui = n.getValue()),1);
    setlistener(p ~ "aircraft-enable", func(n) set_precip(precip_ac = n.getValue()),1);

    # the autovisibility feature of the menubar
    # automatically show the menubar if the mouse is at the upper edge of the window
    # the menubar is hidden by a binding to a LMB click in mode 0 in mice.xml
    var menubarAutoVisibilityListener = nil;
    var menubarAutoVisibilityEdge = props.globals.initNode( "/sim/menubar/autovisibility/edge-size", 5, "INT" );
    var menubarVisibility = props.globals.initNode( "/sim/menubar/visibility", 0, "BOOL" );
    var currentMenubarVisibility = menubarVisibility.getValue();
    var mouseMode = props.globals.initNode( "/devices/status/mice/mouse/mode", 0, "INT" );

    setlistener( "/sim/menubar/autovisibility/enabled", func(n) {
      if( n.getValue() and menubarAutoVisibilityListener == nil ) {
        currentMenubarVisibility = menubarVisibility.getValue();
        menubarVisibility.setBoolValue( 0 );
        menubarAutoVisibilityListener = setlistener( "/devices/status/mice/mouse/y", func(n) {
          if( n.getValue() == nil ) return;
          if( mouseMode.getValue() != 0 ) return;

          if(  n.getValue() <= menubarAutoVisibilityEdge.getValue() )
            menubarVisibility.setBoolValue( 1 );

        }, 1, 0 );
      }

      # don't listen to the mouse position if this feature is enabled
      if( n.getValue() == 0 and menubarAutoVisibilityListener != nil ) {
        removelistener( menubarAutoVisibilityListener );
        menubarAutoVisibilityListener = nil;
        menubarVisibility.setBoolValue(currentMenubarVisibility);
      }
  }, 1, 0);

});


##
# Show/hide the fps display dialog.
#
var fpsDisplay = func(n) {
    var w = isa(n, props.Node) ? n.getValue() : n;
    fgcommand(w ? "dialog-show" : "dialog-close", props.Node.new({"dialog-name": "fps"}));
}
var latencyDisplay = func(n) {
    var w = isa(n, props.Node) ? n.getValue() : n;
    fgcommand(w ? "dialog-show" : "dialog-close", props.Node.new({"dialog-name": "frame-latency"}));
}

##
# Pop down the tip dialog, if it is visible.
#
var popdown = func { fgcommand("clear-message", props.Node.new({"id": canvas.tooltip.getTooltipId()})); }

# Marker for the "current" timer.  This value gets stored in the
# closure of the timer function, and is used to check that there
# hasn't been a more recent timer set that should override.
var currTimer = 0;

########################################################################
# Widgets & Layout Management
########################################################################

##
# A "widget" class that wraps a property node.  It provides useful
# helper methods that are difficult or tedious with the raw property
# API.  Note especially the slightly tricky addChild() method.
#
var Widget = {
    set : func(name, val) { me.node.getNode(name, 1).setValue(val); },
    prop : func { return me.node; },
    new : func { return { parents : [Widget], node : props.Node.new() } },
    addChild : func(type) {
        var idx = size(me.node.getChildren(type));
        var name = type ~ "[" ~ idx ~ "]";
        var newnode = me.node.getNode(name, 1);
        return { parents : [Widget], node : newnode };
    },
    setColor : func(r, g, b, a = 1) {
        me.node.setValues({ color : { red:r, green:g, blue:b, alpha:a } });
    },
    setFont : func(n, s = 13, t = 0) {
        me.node.setValues({ font : { name:n, "size":s, slant:t } });
    },
    setBinding : func(cmd, carg = nil) {
        var idx = size(me.node.getChildren("binding"));
        var node = me.node.getChild("binding", idx, 1);
        node.getNode("command", 1).setValue(cmd);
        if (cmd == "nasal") {
            node.getNode("script", 1).setValue(carg);
        } elsif (carg != nil and (cmd == "dialog-apply" or cmd == "dialog-update")) {
            node.getNode("object-name", 1).setValue(carg);
        }
    },
};


##
# Dialog class. Maintains one XML dialog.
#
# SYNOPSIS:
# (B) Dialog.new(<dialog-name>);   ... use dialog from $FG_ROOT/gui/dialogs/
#
# (A) Dialog.new(<prop>, <path> [, <dialog-name>]);
#                                  ... load aircraft specific dialog from
#                                      <path> under property <prop> and under
#                                      name <dialog-name>; if no name is given,
#                                      then it's taken from the XML dialog
#
#         prop        ... target node (name must be "dialog")
#         path        ... file path relative to $FG_ROOT
#         dialog-name ... dialog <name> of dialog in $FG_ROOT/gui/dialogs/
#
# EXAMPLES:
#
#     var dlg = gui.Dialog.new("/sim/gui/dialogs/foo-config/dialog",
#                              "Aircraft/foo/foo_config.xml");
#     dlg.open();
#     dlg.close();
#
#     var livery_dialog = gui.Dialog.new("livery-select");
#     livery_dialog.toggle();
#
var Dialog = {
    new: func(prop, path = nil, name = nil) {
        var m = { parents: [Dialog] };
        m.state = 0;
        m.listener = nil;
        if (path == nil) { # global dialog in $FG_ROOT/gui/dialogs/
            m.name = prop;
            m.prop = props.Node.new({ "dialog-name" : prop });
        } else {           # aircraft dialog with given path
            m.name = name;
            m.path = path;
            m.prop = isa(prop, props.Node) ? prop : props.globals.getNode(prop, 1);
            if (m.prop.getName() != "dialog")
                die("Dialog class: node name must end with '/dialog'");

            m.listener = setlistener("/sim/signals/reinit-gui", func m.load(), 1);
        }
        return Dialog.instance[m.name] = m;
    },
    del: func
    {
        if (me.listener != nil)
            removelistener(me.listener);
    },
    # doesn't need to be called explicitly, but can be used to force a reload
    load: func {
        var state = me.state;
        if (state)
            me.close();

        me.prop.removeChildren();
        io.read_properties(me.path, me.prop);

        var n = me.prop.getNode("name");
        if (n == nil)
            die("Dialog class: XML dialog must have <name>");

        if (me.name == nil)
            me.name = n.getValue();
        else
            n.setValue(me.name);

        me.prop.getNode("dialog-name", 1).setValue(me.name);
        fgcommand("dialog-new", me.prop);
        if (state)
            me.open();
    },
    # allows access to dialog-embedded Nasal variables/functions
    namespace: func {
        var ns = "__dlg:" ~ me.name;
        me.state and contains(globals, ns) ? globals[ns] : nil;
    },
    open: func {
        fgcommand("dialog-show", me.prop);
        me.state = 1;
    },
    close: func {
        fgcommand("dialog-close", me.prop);
        me.state = 0;
    },
    toggle: func {
        me.state ? me.close() : me.open();
    },
    is_open: func {
        me.state;
    },
    instance: {},
};


##
# Overlay selector. Displays a list of overlay XML files and copies the
# chosen one to the property tree. The class allows to select liveries,
# insignia, decals, variants, etc. Usually the overlay properties are
# fed to "select" and "material" animations.
#
# SYNOPSIS:
#       OverlaySelector.new(<title>, <dir>, <nameprop> [, <sortprop> [, <mpprop> [, <callback>]]]);
#
#       title    ... dialog title
#       dir      ... directory where to find the XML overlay files,
#                    relative to FG_ROOT
#       nameprop ... property in an overlay file that contains the name
#                    The result is written to this place in the
#                    property tree.
#       sortprop ... property in an overlay file that should be used
#                    as sorting criterion, if alphabetic sorting by
#                    name is undesirable. Use nil if you don't need
#                    this, but want to set a callback function.
#       mpprop   ... property path of MP node where the file name should
#                    be written to
#       callback ... function that's called after a new entry was chosen,
#                    with these arguments:
#
#                    callback(<number>, <name>, <sort-criterion>, <file>,  <path>)
#
# EXAMPLE:
#       aircraft.data.add("sim/model/pilot");  # autosave the pilot
#       var pilots_dialog = gui.OverlaySelector.new("Pilots",
#               "Aircraft/foo/Models/Pilots",
#               "sim/model/pilot");
#
#       pilots_dialog.open();  # or ... close(), or toggle()
#
#
var OverlaySelector = {
    new: func(title, dir, nameprop, sortprop = nil, mpprop = nil, callback = nil) {
        var name = "overlay-select-";
        var data = props.globals.getNode("/sim/gui/dialogs/", 1);
        for (var i = 1; 1; i += 1)
            if (data.getNode(name ~ i, 0) == nil)
                break;
        data = data.getNode(name ~= i, 1);

        var m = Dialog.new(data.getNode("dialog", 1), "gui/dialogs/overlay-select.xml", name);
        m.parents = [OverlaySelector, Dialog];

        # resolve the path in FG_ROOT, and --fg-aircraft dir, etc
        m.dir = resolvepath(dir) ~ "/";

        var relpath = func(p) substr(p, p[0] == `/`);
        m.nameprop = relpath(nameprop);
        m.sortprop = relpath(sortprop or nameprop);
        m.mpprop = mpprop;
        m.callback = callback;
        m.title = title;
        m.dialog_name = name;
        m.result = data.initNode("result", "");
        m.listener = setlistener(m.result, func(n) m.select(n.getValue()));
        if (m.mpprop != nil)
            aircraft.data.add(m.nameprop);
        m.reinit();
        # need to reinit again, whenever the GUI is reloaded
        m.reinit_listener = setlistener("/sim/signals/reinit-gui", func(n) m.reinit());
        return m;
    },
    reinit: func {
        me.prop.getNode("group/text/label").setValue(me.title);
        me.prop.getNode("group/button/binding/script").setValue('gui.Dialog.instance["' ~ me.dialog_name ~ '"].close()');
        me.list = me.prop.getNode("list");
        me.list.getNode("property").setValue(me.result.getPath());
        me.rescan();
        me.current = -1;
        me.select(getprop(me.nameprop) or "");
    },
    del: func {
        removelistener(me.listener);
        removelistener(me.reinit_listener);
        # call inherited 'del'
        me.parents = subvec(me.parents,1);
        me.del();
    },
    rescan: func {
        me.data = [];
        var files = directory(me.dir);
        if (size(files)) {
            foreach (var file; files) {
                if (substr(file, -4) != ".xml")
                    continue;
                var n = io.read_properties(me.dir ~ file);
                var name = n.getNode(me.nameprop, 1).getValue();
                var index = n.getNode(me.sortprop, 1).getValue();
                if (name == nil or index == nil)
                    continue;
                append(me.data, [name, index, substr(file, 0, size(file) - 4), me.dir ~ file]);
            }
            me.data = sort(me.data, func(a, b) num(a[1]) == nil or num(b[1]) == nil
                    ? cmp(a[1], b[1]) : a[1] - b[1]);
        }

        me.list.removeChildren("value");
        forindex (var i; me.data)
            me.list.getChild("value", i, 1).setValue(me.data[i][0]);
    },
    set: func(index) {
        var last = me.current;
        me.current = math.mod(index, size(me.data));
        io.read_properties(me.data[me.current][3], props.globals);
        if (last != me.current and me.callback != nil)
            call(me.callback, [me.current] ~ me.data[me.current], me);
        if (me.mpprop != nil)
            setprop(me.mpprop, me.data[me.current][2]);
    },
    select: func(name) {
        forindex (var i; me.data)
            if (me.data[i][0] == name)
                me.set(i);
    },
    next: func {
        me.set(me.current + 1);
    },
    previous: func {
        me.set(me.current - 1);
    },
};


##
# FileSelector class (derived from Dialog class).
#
# SYNOPSIS: FileSelector.new(<callback>, <title>, <button> [, <pattern> [, <dir> [, <file> [, <dotfiles>]]]])
#
#         callback ... callback function that gets return value as first argument
#         title    ... dialog title
#         button   ... button text (should say "Save", "Load", etc. and not just "OK")
#         pattern  ... array with shell pattern or nil (which is equivalent to "*")
#         dir      ... starting dir ($FG_ROOT if unset)
#         file     ... pre-selected default file name
#         dotfiles ... flag that decides whether UNIX dotfiles should be shown (1) or not (0)
#
# EXAMPLE:
#
#     var report = func(n) { print("file ", n.getValue(), " selected") }
#     var selector = gui.FileSelector.new(
#             report,                 # callback function
#             "Save Flight",          # dialog title
#             "Save",                 # button text
#             ["*.sav", "*.xml"],     # pattern for displayed files
#             "/tmp",                 # start dir
#             "flight.sav");          # default file name
#     selector.open();
#
#     selector.close();
#     selector.set_title("Save Another Flight");
#     selector.open();
#
var FileSelector = {
    new: func(callback, title, button, pattern = nil, dir = "", file = "", dotfiles = 0, show_files=1) {
        
        
        var usage = gui.FILE_DIALOG_OPEN_FILE;
        if (!show_files) {
            usage = gui.FILE_DIALOG_CHOOSE_DIR;
        } else if (button == 'Save') {
            # nasty, should make this explicit
            usage = gui.FILE_DIALOG_SAVE_FILE;
        }
        
        m = { parents:[FileSelector],
             _inner: gui._createFileDialog(usage)};
        
        m.set_title(title);
        m.set_button(button);
        m.set_directory(dir);
        m.set_file(file);
        m.set_dotfiles(dotfiles);
        m.set_pattern(pattern);
        
        m._inner.setCallback(func (path) {  
            var node = props.Node.new();
            node.setValue(path);
            callback(node); 
        }   );
        
        return m;
    },
    # setters only take effect after the next call to open()
    set_title: func(title) { me._inner.title = title },
    set_button: func(button) { me._inner.button = button },
    set_directory: func(dir) { me._inner.directory = directory },
    set_file: func(file) { me._inner.placeholder = file },
    set_dotfiles: func(dot) { me._inner.show_hidden = dot },
    set_pattern: func(pattern) { me._inner.pattern = (pattern == nil) ? [] : pattern },
    
    open: func() { me._inner.open(); },
    close: func() { me._inner.close(); },
    
    del: func {
        me._inner.close();
        me._inner = nil;
    },
};

##
# DirSelector - convenience "class" (indeed using a reconfigured FileSelector)
#
var DirSelector = {
  new: func(callback, title, button, dir = "") {
     return FileSelector.new(callback, title, button, nil, dir, "", 0, 0);
  }
};

##
# Save/load flight menu functions.
#
var save_flight_sel = nil;
var save_flight = func {
    foreach (var n; props.globals.getNode("/sim/presets").getChildren())
        n.setAttribute("archive", 1);
    var save = func(n) fgcommand("save", props.Node.new({ file: n.getValue() }));
    if (save_flight_sel == nil)
        save_flight_sel = FileSelector.new(save, "Save Flight", "Save",
                ["*.sav"], getprop("/sim/fg-home"), "flight.sav");
    save_flight_sel.open();
}


var load_flight_sel = nil;
var load_flight = func {
    var load = func(n) {
        fgcommand("load", props.Node.new({ file: n.getValue() }));
        fgcommand("reposition");
    }
    if (load_flight_sel == nil)
        load_flight_sel = FileSelector.new(load, "Load Flight", "Load",
                ["*.sav"], getprop("/sim/fg-home"), "flight.sav");
    load_flight_sel.open();
}

##
# Screen-shot directory menu function
#
var set_screenshotdir_sel = nil;
var set_screenshotdir = func {
    if (set_screenshotdir_sel == nil)
        set_screenshotdir_sel = gui.DirSelector.new(
            func(result) { setprop("/sim/paths/screenshot-dir", result.getValue()); },
            "Select Screenshot Directory", "Ok", getprop("/sim/paths/screenshot-dir"));
    set_screenshotdir_sel.open();
}

##
# Open property browser with given target path.
#
var property_browser = func(dir = nil) {
    if (dir == nil)
        dir = "/";
    elsif (isa(dir, props.Node))
        dir = dir.getPath();
    var dlgname = "property-browser";
    foreach (var module; keys(globals))
        if (find("__dlg:" ~ dlgname, module) == 0)
            return globals[module].clone(dir);

    setprop("/sim/gui/dialogs/" ~ dlgname ~ "/last", dir);
    fgcommand("dialog-show", props.Node.new({"dialog-name": dlgname}));
}


##
# Open one property browser per /browser[] property, where each contains
# the target path. On the command line use  --prop:browser=orientation
#
settimer(func {
    foreach (var b; props.globals.getChildren("browser"))
        if ((var browser = b.getValue()) != nil)
            foreach (var path; split(",", browser))
                if (size(path))
                    property_browser(string.trim(path));

    props.globals.removeChildren("browser");
}, 0);


##
# Apply whole dialog or list of widgets. This copies the widgets'
# visible contents to the respective <property>.
#
var dialog_apply = func(dialog, objects...) {
    var n = props.Node.new({ "dialog-name": dialog });
    if (!size(objects))
        return fgcommand("dialog-apply", n);

    var name = n.getNode("object-name", 1);
    foreach (var o; objects) {
        name.setValue(o);
        fgcommand("dialog-apply", n);
    }
}


##
# Update whole dialog or list of widgets. This makes the widgets
# adopt and display the value of their <property>.
#
var dialog_update = func(dialog, objects...) {
    var n = props.Node.new({ "dialog-name": dialog });
    if (!size(objects))
        return fgcommand("dialog-update", n);

    var name = n.getNode("object-name", 1);
    foreach (var o; objects) {
        name.setValue(o);
        fgcommand("dialog-update", n);
    }
}


##
# Searches a dialog tree for widgets with a particular <name> entry and
# sets their <enabled> flag.
#
var enable_widgets = func(node, name, enable = 1) {
    foreach (var n; node.getChildren())
        enable_widgets(n, name, enable);
    if ((var n = node.getNode("name")) != nil and n.getValue() == name)
        node.getNode("enabled", 1).setBoolValue(enable);
}



########################################################################
# GUI theming
########################################################################

var nextStyle = func {
    var curr = getprop("/sim/gui/current-style");
    var styles = props.globals.getNode("/sim/gui").getChildren("style");
    forindex (var i; styles)
        if (styles[i].getIndex() == curr)
            break;
    if ((i += 1) >= size(styles))
        i = 0;
    setprop("/sim/gui/current-style", styles[i].getIndex());
    fgcommand("gui-redraw");
}


########################################################################
# Dialog Boxes
########################################################################

var dialog = {};

var setWeight = func(wgt, opt) {
    var lbs = opt.getNode("lbs", 1).getValue();
    wgt.getNode("weight-lb", 1).setValue(lbs);

    # Weights can have "tank" indices which set the capacity of the
    # corresponding tank.  This code should probably be moved to
    # something like fuel.setTankCap(tank, gals)...
    if(wgt.getNode("tank",0) == nil) { return 0; }
    var ti = wgt.getNode("tank").getValue();
    var gn = opt.getNode("gals");
    var gals = gn == nil ? 0 : gn.getValue();
    var tn = props.globals.getNode("consumables/fuel/tank["~ti~"]", 1);
    var ppg = tn.getNode("density-ppg", 1).getValue();
    var lbs = gals * ppg;
    var curr = tn.getNode("level-gal_us", 1).getValue();
    curr = curr > gals ? gals : curr;
    tn.getNode("capacity-gal_us", 1).setValue(gals);
    tn.getNode("level-gal_us", 1).setValue(curr);
    tn.getNode("level-lbs", 1).setValue(curr * ppg);
    return 1;
}

# Checks the /sim/weight[n]/{selected|opt} values and sets the
# appropriate weights therefrom.
var setWeightOpts = func {
    var tankchange = 0;
    foreach(var w; props.globals.getNode("sim").getChildren("weight")) {
        var selected = w.getNode("selected");
        if(selected != nil) {
            foreach(var opt; w.getChildren("opt")) {
                if(opt.getNode("name", 1).getValue() == selected.getValue()) {
                    if(setWeight(w, opt)) { tankchange = 1; }
                    break;
                }
            }
        }
    }
    return tankchange;
}
# Run it at startup and on reset to make sure the tank settings are correct
_setlistener("/sim/signals/fdm-initialized", func { settimer(setWeightOpts, 0) });
_setlistener("/sim/signals/reinit", func(n) { props._getValue(n, []) or setWeightOpts() });


# Called from the F&W dialog when the user selects a weight option
var weightChangeHandler = func {
    var tankchanged = setWeightOpts();

    # This is unfortunate.  Changing tanks means that the list of
    # tanks selected and their slider bounds must change, but our GUI
    # isn't dynamic in that way.  The only way to get the changes on
    # screen is to pop it down and recreate it.
    if(tankchanged) {
        var p = props.Node.new({"dialog-name": "WeightAndFuel"});
        fgcommand("dialog-close", p);
        showWeightDialog();
    }
}



##
# Dynamically generates a weight & fuel configuration dialog specific to
# the aircraft.
#
var showWeightDialog = func {
    var name = "WeightAndFuel";
#   menu entry is "Fuel and Payload"
    var title = "Fuel and Payload Settings";

    #
    # General Dialog Structure
    #
    dialog[name] = Widget.new();
    dialog[name].set("name", name);
    dialog[name].set("layout", "vbox");

    var header = dialog[name].addChild("group");
    header.set("layout", "hbox");
    header.addChild("empty").set("stretch", "1");
    header.addChild("text").set("label", title);
    header.addChild("empty").set("stretch", "1");
    var w = header.addChild("button");
    w.set("pref-width", 16);
    w.set("pref-height", 16);
    w.set("legend", "");
    w.set("default", 0);
    # "Esc" causes dialog-close
    w.set("key", "Esc");
    w.setBinding("dialog-close");

    dialog[name].addChild("hrule");

    if (fdm != "yasim" and fdm != "jsb") {
        var msg = dialog[name].addChild("text");
        msg.set("label", "Not supported for this aircraft");
        var cancel = dialog[name].addChild("button");
        cancel.set("key", "Esc");
        cancel.set("legend", "Cancel");
        cancel.setBinding("dialog-close");
        fgcommand("dialog-new", dialog[name].prop());
        showDialog(name);
        return;
    }

    # FDM dependent settings
    if(fdm == "yasim") {
        var fdmdata = {
            grosswgt : "/yasim/gross-weight-lbs",
            payload  : "/sim",
            cg       : nil,
        };
    } elsif(fdm == "jsb") {
        var fdmdata = {
            grosswgt : "/fdm/jsbsim/inertia/weight-lbs",
            payload  : "/payload",
            cg       : "/fdm/jsbsim/inertia/cg-x-in",
        };
    }

    var contentArea = dialog[name].addChild("group");
    contentArea.set("layout", "hbox");
    contentArea.set("default-padding", 10);

    dialog[name].addChild("empty");

    var limits = dialog[name].addChild("group");
    limits.set("layout", "table");
    limits.set("halign", "center");
    var row = 0;

    var massLimits = props.globals.getNode("/limits/mass-and-balance");

    var tablerow = func(name, node, format ) {

        var n = isa( node, props.Node ) ? node : massLimits.getNode( node );
        if( n == nil ) return;

        var label = limits.addChild("text");
        label.set("row", row);
        label.set("col", 0);
        label.set("halign", "right");
        label.set("label", name ~ ":");

        var val = limits.addChild("text");
        val.set("row", row);
        val.set("col", 1);
        val.set("halign", "left");
        val.set("label", "0123457890123456789");
        val.set("format", format);
        val.set("property", n.getPath());
        val.set("live", 1);
          
        row += 1;
    }

    var grossWgt = props.globals.getNode(fdmdata.grosswgt);
    if(grossWgt != nil) {
        tablerow("Gross Weight", grossWgt, "%.0f lb");
    }

    if(massLimits != nil ) {
        tablerow("Max. Ramp Weight", "maximum-ramp-mass-lbs", "%.0f lb" );
        tablerow("Max. Takeoff  Weight", "maximum-takeoff-mass-lbs", "%.0f lb" );
        tablerow("Max. Landing  Weight", "maximum-landing-mass-lbs", "%.0f lb" );
        tablerow("Max. Arrested Landing  Weight", "maximum-arrested-landing-mass-lbs", "%.0f lb" );
        tablerow("Max. Zero Fuel Weight", "maximum-zero-fuel-mass-lbs", "%.0f lb" );
    }

    if( fdmdata.cg != nil ) { 
        var n = props.globals.getNode("/limits/mass-and-balance/cg/dimension");
        tablerow("Center of Gravity", props.globals.getNode(fdmdata.cg), "%.1f " ~ (n == nil ? "in" : n.getValue()));
    }

    dialog[name].addChild("hrule");

    var buttonBar = dialog[name].addChild("group");
    buttonBar.set("layout", "hbox");
    buttonBar.set("default-padding", 10);

    var close = buttonBar.addChild("button");
    close.set("legend", "Close");
    close.set("default", "true");
    close.set("key", "Enter");
    close.setBinding("dialog-close");

    # Temporary helper function
    var tcell = func(parent, type, row, col) {
        var cell = parent.addChild(type);
        cell.set("row", row);
        cell.set("col", col);
        return cell;
    }

    #
    # Fill in the content area
    #
    var fuelArea = contentArea.addChild("group");
    fuelArea.set("layout", "vbox");
    fuelArea.addChild("text").set("label", "Fuel Tanks");

    var fuelTable = fuelArea.addChild("group");
    fuelTable.set("layout", "table");

    fuelArea.addChild("empty").set("stretch", 1);

    tcell(fuelTable, "text", 0, 0).set("label", "Tank");
    tcell(fuelTable, "text", 0, 3).set("label", "Pounds");
    tcell(fuelTable, "text", 0, 4).set("label", "Gallons");
    tcell(fuelTable, "text", 0, 5).set("label", "Fraction");

    var tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
    for(var i=0; i<size(tanks); i+=1) {
        var t = tanks[i];
        var hidden=0;
        var tname = i ~ "";
        var hnode = t.getNode("hidden");
        if(hnode != nil) { hidden = hnode.getValue(); }# Check for <hidden> property ,skip adding tank if true#
        if(!hidden){
        var tnode = t.getNode("name");
        if(tnode != nil) { tname = tnode.getValue(); }

        var tankprop = "/consumables/fuel/tank["~i~"]";

        var cap = t.getNode("capacity-gal_us", 0);

        # Hack, to ignore the "ghost" tanks created by the C++ code.
        if(cap == nil ) { continue; }
        cap = cap.getValue();

        # Ignore tanks of capacity 0
        if (cap == 0) { continue; }

        var title = tcell(fuelTable, "text", i+1, 0);
        title.set("label", tname);
        title.set("halign", "right");

        var selected = props.globals.initNode(tankprop ~ "/selected", 1, "BOOL");
        if (selected.getAttribute("writable")) {
            var sel = tcell(fuelTable, "checkbox", i+1, 1);
            sel.set("property", tankprop ~ "/selected");
            sel.set("live", 1);
            sel.setBinding("dialog-apply");
        }

        var slider = tcell(fuelTable, "slider", i+1, 2);
        slider.set("property", tankprop ~ "/level-gal_us");
        slider.set("live", 1);
        slider.set("min", 0);
        slider.set("max", cap);
        slider.setBinding("dialog-apply");

        var lbs = tcell(fuelTable, "text", i+1, 3);
        lbs.set("property", tankprop ~ "/level-lbs");
        lbs.set("label", "0123456");
        lbs.set("format", cap < 1 ? "%.3f" : cap < 10 ? "%.2f" : "%.1f" );
        lbs.set("halign", "right");
        lbs.set("live", 1);

        var gals = tcell(fuelTable, "text", i+1, 4);
        gals.set("property", tankprop ~ "/level-gal_us");
        gals.set("label", "0123456");
        gals.set("format", cap < 1 ? "%.3f" : cap < 10 ? "%.2f" : "%.1f" );
        gals.set("halign", "right");
        gals.set("live", 1);

        var per = tcell(fuelTable, "text", i+1, 5);
        per.set("property", tankprop ~ "/level-norm");
        per.set("label", "0123456");
        per.set("format", "%.2f");
        per.set("halign", "right");
        per.set("live", 1);
        }
    }

    varbar = tcell(fuelTable, "hrule", size(tanks)+1, 0);
    varbar.set("colspan", 6);

    var total_label = tcell(fuelTable, "text", size(tanks)+2, 2);
    total_label.set("label", "Total:");
    total_label.set("halign", "right");

    var lbs = tcell(fuelTable, "text", size(tanks)+2, 3);
    lbs.set("property", "/consumables/fuel/total-fuel-lbs");
    lbs.set("label", "0123456");
    lbs.set("format", "%.1f" );
    lbs.set("halign", "right");
    lbs.set("live", 1);

    var gals = tcell(fuelTable, "text",size(tanks) +2, 4);
    gals.set("property", "/consumables/fuel/total-fuel-gal_us");
    gals.set("label", "0123456");
    gals.set("format", "%.1f" );
    gals.set("halign", "right");
    gals.set("live", 1);

    var per = tcell(fuelTable, "text", size(tanks)+2, 5);
    per.set("property", "/consumables/fuel/total-fuel-norm");
    per.set("label", "0123456");
    per.set("format", "%.2f");
    per.set("halign", "right");
    per.set("live", 1);

    var weightArea = contentArea.addChild("group");
    weightArea.set("layout", "vbox");
    weightArea.addChild("text").set("label", "Payload");

    var weightTable = weightArea.addChild("group");
    weightTable.set("layout", "table");

    weightArea.addChild("empty").set("stretch", 1);

    tcell(weightTable, "text", 0, 0).set("label", "Location");
    tcell(weightTable, "text", 0, 2).set("label", "Pounds");

    var payload_base = props.globals.getNode(fdmdata.payload);
    if (payload_base != nil)
        var wgts = payload_base.getChildren("weight");
    else
        var wgts = [];
    for(var i=0; i<size(wgts); i+=1) {
        var w = wgts[i];
        var wname = w.getNode("name", 1).getValue();
        var wprop = fdmdata.payload ~ "/weight[" ~ i ~ "]";

        var title = tcell(weightTable, "text", i+1, 0);
        title.set("label", wname);
        title.set("halign", "right");

        if(w.getNode("opt") != nil) {
            var combo = tcell(weightTable, "combo", i+1, 1);
            combo.set("property", wprop ~ "/selected");
            combo.set("pref-width", 300);

            # Simple code we'd like to use:
            #foreach(opt; w.getChildren("opt")) {
            #    var ent = combo.addChild("value");
            #    ent.prop().setValue(opt.getNode("name", 1).getValue());
            #}

            # More complicated workaround to move the "current" item
            # into the first slot, because dialog.cxx doesn't set the
            # selected item in the combo box.
            var opts = [];
            var curr = w.getNode("selected");
            curr = curr == nil ? "" : curr.getValue();
            foreach(opt; w.getChildren("opt")) {
                append(opts, opt.getNode("name", 1).getValue());
            }
            forindex(oi; opts) {
                if(opts[oi] == curr) {
                    var tmp = opts[0];
                    opts[0] = opts[oi];
                    opts[oi] = tmp;
                    break;
                }
            }
            foreach(opt; opts) {
                combo.addChild("value").prop().setValue(opt);
            }

            combo.setBinding("dialog-apply");
            combo.setBinding("nasal", "gui.weightChangeHandler()");
        } else {
            var slider = tcell(weightTable, "slider", i+1, 1);
            slider.set("property", wprop ~ "/weight-lb");
            var min = w.getNode("min-lb", 1).getValue();
            var max = w.getNode("max-lb", 1).getValue();
            slider.set("min", min != nil ? min : 0);
            slider.set("max", max != nil ? max : 100);
            slider.set("live", 1);
            slider.setBinding("dialog-apply");
        }

        var lbs = tcell(weightTable, "text", i+1, 2);
        lbs.set("property", wprop ~ "/weight-lb");
        lbs.set("label", "0123456");
        lbs.set("format", "%.0f");
        lbs.set("live", 1);
    }

    # All done: pop it up
    fgcommand("dialog-new", dialog[name].prop());
    showDialog(name);
}




##
# Dynamically generates a dialog from a help node.
#
# gui.showHelpDialog([<path> [, toggle]])
#
# path   ... path to help node
# toggle ... decides if an already open dialog should be closed
#            (useful when calling the dialog from a key binding; default: 0)
#
# help node
# =========
# each of <title>, <key>, <line>, <text> is optional; uses
# "/sim/description" or "/sim/aircraft" if <title> is omitted;
# only the first <text> is displayed
#
#
# <help>
#     <title>dialog title<title>
#     <key>
#         <name>g/G</name>
#         <desc>gear up/down</desc>
#     </key>
#
#     <line>one line</line>
#     <line>another line</line>
#
#     <text>text in
#           scrollable widget
#     </text>
# </help>
#
var showHelpDialog = func(path, toggle=0) {
    var node = props.globals.getNode(path);
    if (path == "/sim/help" and size(node.getChildren()) < 4) {
        node = node.getChild("common");
    }

    var name = node.getNode("title", 1).getValue();
    if (name == nil) {
        name = getprop("/sim/description");
        if (name == nil) {
            name = getprop("/sim/aircraft");
        }
    }
    var toggle = toggle > 0;
    if (toggle and contains(dialog, name)) {
        fgcommand("dialog-close", props.Node.new({ "dialog-name": name }));
        delete(dialog, name);
        return;
    }

    dialog[name] = Widget.new();
    dialog[name].set("layout", "vbox");
    dialog[name].set("default-padding", 0);
    dialog[name].set("name", name);

    # title bar
    var titlebar = dialog[name].addChild("group");
    titlebar.set("layout", "hbox");
    titlebar.addChild("empty").set("stretch", 1);
    titlebar.addChild("text").set("label", name);
    titlebar.addChild("empty").set("stretch", 1);

    var w = titlebar.addChild("button");
    w.set("pref-width", 16);
    w.set("pref-height", 16);
    w.set("legend", "");
    w.set("default", 1);
    w.set("key", "esc");
    w.setBinding("nasal", "delete(gui.dialog, \"" ~ name ~ "\")");
    w.setBinding("dialog-close");

    dialog[name].addChild("hrule");

    # key list
    var keylist = dialog[name].addChild("group");
    keylist.set("layout", "table");
    keylist.set("default-padding", 2);
    var keydefs = node.getChildren("key");
    var n = size(keydefs);
    var row = var col = 0;
    foreach (var key; keydefs) {
        if (n >= 60 and row >= n / 3 or n >= 16 and row >= n / 2) {
            col += 1;
            row = 0;
        }

        var w = keylist.addChild("text");
        w.set("row", row);
        w.set("col", 2 * col);
        w.set("halign", "right");
        w.set("label", " " ~ key.getNode("name").getValue());

        w = keylist.addChild("text");
        w.set("row", row);
        w.set("col", 2 * col + 1);
        w.set("halign", "left");
        w.set("label", "... " ~ key.getNode("desc").getValue() ~ "  ");
        row += 1;
    }

    # separate lines
    var lines = node.getChildren("line");
    if (size(lines)) {
        if (size(keydefs)) {
            dialog[name].addChild("empty").set("pref-height", 4);
            dialog[name].addChild("hrule");
            dialog[name].addChild("empty").set("pref-height", 4);
        }

        var g = dialog[name].addChild("group");
        g.set("layout", "vbox");
        g.set("default-padding", 1);
        foreach (var lin; lines) {
            foreach (var l; split("\n", lin.getValue())) {
                var w = g.addChild("text");
                w.set("halign", "left");
                w.set("label", " " ~ l ~ " ");
            }
        }
    }

    # scrollable text area
    if (node.getNode("text") != nil) {
        dialog[name].set("resizable", 1);
        dialog[name].addChild("empty").set("pref-height", 10);

        var width = [640, 800, 1152][col];
        var height = screenHProp.getValue() - (100 + (size(keydefs) / (col + 1) + size(lines)) * 28);
        if (height < 200) {
            height = 200;
        }

        var w = dialog[name].addChild("textbox");
        w.set("padding", 4);
        w.set("halign", "fill");
        w.set("valign", "fill");
        w.set("stretch", "true");
        w.set("slider", 20);
        w.set("pref-width", width);
        w.set("pref-height", height);
        w.set("editable", 0);
        w.set("property", node.getPath() ~ "/text");
    } else {
        dialog[name].addChild("empty").set("pref-height", 8);
    }
    fgcommand("dialog-new", dialog[name].prop());
    showDialog(name);
}


var debug_keys = {
    title: "Development Keys",
    key: [
       #{ name: "Ctrl-U",    desc: "add 1000 ft of emergency altitude" },
        { name: "Shift-F3",  desc: "load panel" },
        { name: "/",         desc: "open property browser" },
    ],
};

var basic_keys = {
    title: "Basic Keys",
    key: [
        { name: "?",         desc: "show/hide aircraft help dialog" },
       #{ name: "Tab",       desc: "show/hide aircraft config dialog" },
        { name: "Esc",       desc: "quit FlightGear" },
        { name: "Shift-Esc", desc: "reset FlightGear" },
        { name: "a/A",       desc: "increase/decrease speed-up" },
        { name: "c",         desc: "toggle 3D/2D cockpit" },
        { name: "Ctrl-C",    desc: "toggle clickable panel hotspots" },
        { name: "p",         desc: "pause/continue sim" },
        { name: "Ctrl-R",    desc: "activate instant replay system" },
        { name: "t/T",       desc: "increase/decrease warp delta" },
        { name: "v/V",       desc: "cycle views (forward/backward)" },
        { name: "Ctrl-V",    desc: "select cockpit view" },
        { name: "w/W",       desc: "increase/decrease warp" },
        { name: "x/X",       desc: "zoom in/out" },
        { name: "Ctrl-X",    desc: "reset zoom to default" },
        { name: "z/Z",       desc: "increase/decrease visibility" },
        { name: "Ctrl-Z",    desc: "reset visibility to default" },
        { name: "'",         desc: "display ATC setting dialog" },
        { name: "+",         desc: "let ATC/instructor repeat last message" },
        { name: "-",         desc: "open chat dialog" },
        { name: "_",         desc: "compose chat message" },
        { name: "F3",        desc: "capture screen" },
        { name: "F10",       desc: "toggle menubar" },
       #{ name: "Shift-F1",  desc: "load flight" },
       #{ name: "Shift-F2",  desc: "save flight" },
        { name: "Shift-F10", desc: "cycle through GUI styles" },
    ],
};

var common_aircraft_keys = {
    title: "Common Aircraft Keys",
    key: [
        { name: "Enter",     desc: "move rudder right" },
        { name: "0/Insert",  desc: "move rudder left" },
        { name: "1/End",     desc: "elevator trim up" },
        { name: "2/Down",    desc: "elevator up or increase AP altitude" },
        { name: "3/PgDn",    desc: "decr. throttle or AP autothrottle" },
        { name: "4/Left",    desc: "move aileron left or adj. AP hdg." },
        { name: "5/KP5",     desc: "center aileron, elev., and rudder" },
        { name: "6/Right",   desc: "move aileron right or adj. AP hdg." },
        { name: "7/Home",    desc: "elevator trim down" },
        { name: "8/Up",      desc: "elevator down or decrease AP altitude" },
        { name: "9/PgUp",    desc: "incr. throttle or AP autothrottle" },
        { name: "Space",     desc: "PTT - Push To Talk (via VoIP)" },
        { name: "!/@/#/$",   desc: "select engine 1/2/3/4" },
        { name: "b",         desc: "apply all brakes" },
        { name: "B",         desc: "toggle parking brake" },
       #{ name: "Ctrl-B",    desc: "toggle speed brake" },
        { name: "g/G",       desc: "gear up/down" },
        { name: "h",         desc: "cycle HUD (head up display)" },
        { name: "H",         desc: "cycle HUD brightness" },
       #{ name: "i/Shift-i", desc: "normal/alternative HUD" },
       #{ name: "j",         desc: "decrease spoilers" },
       #{ name: "k",         desc: "increase spoilers" },
        { name: "l",         desc: "toggle tail-wheel lock" },
        { name: "m/M",       desc: "mixture richer/leaner" },
        { name: "n/N",       desc: "propeller finer/coarser" },
        { name: "P",         desc: "toggle 2D panel" },
        { name: "S",         desc: "swap panels" },
        { name: "s",         desc: "fire starter on selected eng." },
        { name: ", .",       desc: "left/right brake (comma, period)" },
        { name: "~",         desc: "select all engines (tilde)" },
        { name: "[ ]",       desc: "flaps up/down" },
        { name: "{ }",       desc: "decr/incr magneto on sel. eng." },
        { name: "Ctrl-A",    desc: "AP: toggle altitude lock" },
        { name: "Ctrl-G",    desc: "AP: toggle glide slope lock" },
        { name: "Ctrl-H",    desc: "AP: toggle heading lock" },
        { name: "Ctrl-N",    desc: "AP: toggle NAV1 lock" },
        { name: "Ctrl-P",    desc: "AP: toggle pitch hold" },
        { name: "Ctrl-S",    desc: "AP: toggle auto-throttle" },
        { name: "Ctrl-T",    desc: "AP: toggle terrain lock" },
        { name: "Ctrl-W",    desc: "AP: toggle wing leveler" },
        { name: "F6",        desc: "AP: toggle heading mode" },
        { name: "F11",       desc: "open autopilot dialog" },
        { name: "F12",       desc: "open radio settings dialog" },
        { name: "Shift-F5",  desc: "scroll 2D panel down" },
        { name: "Shift-F6",  desc: "scroll 2D panel up" },
        { name: "Shift-F7",  desc: "scroll 2D panel left" },
        { name: "Shift-F8",  desc: "scroll 2D panel right" },
    ],
};

_setlistener("/sim/signals/screenshot", func {
     var path = getprop("/sim/paths/screenshot-last");
     var button = { button: { legend: "Ok", default: 1, binding: { command: "dialog-close" }}};
     var success= getprop("/sim/signals/screenshot");
     if (success) {
         popupTip("Screenshot written to '" ~ path ~ "'", 3);
     } else {
         popupTip("Error writing screenshot '" ~ path ~ "'", 600, button);
     }
});

var terrasync_stalled = 0;
_setlistener("/sim/terrasync/stalled", func {
     var stalled = getprop("/sim/terrasync/stalled");
     if (stalled and !terrasync_stalled)
     {
         var button = { button: { legend: "Ok", default: 1, binding: { command: "dialog-close" }}};
         popupTip("Scenery download stalled. Too many errors reported. See log output.", 600, button);
     }
     terrasync_stalled = stalled;
});

var do_welcome = 1;
_setlistener("/sim/signals/fdm-initialized", func {
    var haveTutorials = size(props.globals.getNode("/sim/tutorials", 1).getChildren("tutorial"));
    gui.menuEnable("tutorial-start", haveTutorials);
    if (do_welcome and haveTutorials)
        settimer(func { setprop("/sim/messages/copilot", "Welcome aboard! Need help? Use 'Help -> Tutorials'.");}, 5.0);
    do_welcome = 0;
});


##
# overwrite custom shader settings when quality-level is set on startup
var qualityLevel = getprop("/sim/rendering/shaders/quality-level");
var rembrandtOn = getprop("/sim/rendering/rembrandt/enabled");
if (qualityLevel == -1) {
    setprop("/sim/rendering/shaders/custom-settings",1);
}
elsif (qualityLevel != nil) {
    setprop("/sim/rendering/shaders/custom-settings",0);
    setprop("/sim/rendering/shaders/quality-level-internal",qualityLevel);
    if (qualityLevel == 0) {
        setprop("/sim/rendering/shaders/skydome",0);
    }
}
# overwrite custom shader settings when quality-level is set through the slider
# in the Rendering Options dialog
var update_shader_settings = func() {
    if (!getprop("/sim/rendering/shaders/custom-settings")){
        var qualityLvl = getprop("/sim/rendering/shaders/quality-level-internal");
		setprop("/sim/rendering/shaders/quality-level", qualityLvl);
        setprop("/sim/rendering/shaders/landmass",qualityLvl);
        setprop("/sim/rendering/shaders/urban",qualityLvl);
        setprop("/sim/rendering/shaders/water",qualityLvl);
        if (qualityLvl >= 1.0){
            qualityLvl = 1.0;
        }
        setprop("/sim/rendering/shaders/model",qualityLvl);
        setprop("/sim/rendering/shaders/contrails",qualityLvl);
        setprop("/sim/rendering/shaders/crop",qualityLvl);
        setprop("/sim/rendering/shaders/generic",qualityLvl);
        setprop("/sim/rendering/shaders/transition",qualityLvl);
    } else {
		setprop("/sim/rendering/shaders/quality-level",-1);
	}

    if (rembrandtOn) {
		setprop("/sim/rendering/shaders/skydome",0);
	}
};
_setlistener("/sim/rendering/shaders/custom-settings", func { update_shader_settings() } );
_setlistener("/sim/rendering/shaders/quality-level-internal",   func { update_shader_settings() } );
update_shader_settings();
