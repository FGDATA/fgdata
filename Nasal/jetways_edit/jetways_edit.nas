###############################################################################
##
##  Animated Jetway System. Allows the user to edit jetways during runtime.
##
##  Copyright (C) 2011  Ryan Miller
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

###############################################################################
# (See http://wiki.flightgear.org/Howto:_Animated_jetways)
#

### Static jetway model profiles ###
### This class specifies the offsets used when converting static jetways using the STG converter ###
var Static_jetway =
 [
  # Models/Airport/Jetway/jetway-movable.ac
  # Models/Airport/Jetway/jetway-movable.xml
  # Models/Airport/Jetway/jetway-movable-2.ac
  # Models/Airport/Jetway/jetway-movable-2.xml
  # Models/Airport/Jetway/jetway-movable-3.ac
  # Models/Airport/Jetway/jetway-movable-3.xml
  {
  models:
   [
   "Models/Airport/Jetway/jetway-movable.ac",
   "Models/Airport/Jetway/jetway-movable.xml",
   "Models/Airport/Jetway/jetway-movable-2.ac",
   "Models/Airport/Jetway/jetway-movable-2.xml",
   "Models/Airport/Jetway/jetway-movable-3.ac",
   "Models/Airport/Jetway/jetway-movable-3.xml"
   ],
  offsets:
   {
   x: -2.042,
   y: 0,
   z: 0,
   heading: 0
   },
  init_pos:
   {
   extend: 7.24,
   heading: 0,
   pitch: 0,
   ent_heading: -90
   },
  model: "generic",
  airline: "None"
  },
  # Models/Airport/Jetway/jetway.xml
  # Models/Airport/Jetway/jetway-ba.ac
  # Models/Airport/Jetway/jetway-ba.xml
  {
  models:
   [
   "Models/Airport/Jetway/jetway.xml",
   "Models/Airport/Jetway/jetway-ba.ac",
   "Models/Airport/Jetway/jetway-ba.xml"
   ],
  offsets:
   {
   x: 0,
   y: 0,
   z: -0.25,
   heading: 0
   },
  init_pos:
   {
   extend: 7.24,
   heading: -6.7,
   pitch: -3.6,
   ent_heading: -83.3
   },
  model: "generic",
  airline: "None"
  },
  # Models/Airport/Jetway/jetway-737-ba.ac
  # Models/Airport/Jetway/jetway-737-ba.xml
  {
  models:
   [
   "Models/Airport/Jetway/jetway-737-ba.ac",
   "Models/Airport/Jetway/jetway-737-ba.xml"
   ],
  offsets:
   {
   x: 0,
   y: 0,
   z: -0.25,
   heading: 0
   },
  init_pos:
   {
   extend: 7.24,
   heading: -6.7,
   pitch: -4,
   ent_heading: -83.3
   },
  model: "generic",
  airline: "None"
  },
  # Models/Airport/Jetway/jetway-747-ba.ac
  # Models/Airport/Jetway/jetway-747-ba.xml
  {
  models:
   [
   "Models/Airport/Jetway/jetway-747-ba.ac",
   "Models/Airport/Jetway/jetway-747-ba.xml"
   ],
  offsets:
   {
   x: 0,
   y: 0,
   z: -0.25,
   heading: 0
   },
  init_pos:
   {
   extend: 7.24,
   heading: -6.7,
   pitch: 2,
   ent_heading: -83.3
   },
  model: "generic",
  airline: "None"
  },
  # Models/Airport/Jetway/jetway-a320-ba.ac
  # Models/Airport/Jetway/jetway-a320-ba.xml
  {
  models:
   [
   "Models/Airport/Jetway/jetway-a320-ba.ac",
   "Models/Airport/Jetway/jetway-a320-ba.xml"
   ],
  offsets:
   {
   x: 0,
   y: 0,
   z: -0.25,
   heading: 0
   },
  init_pos:
   {
   extend: 7.24,
   heading: -6.7,
   pitch: -1.6,
   ent_heading: -83.3
   },
  model: "generic",
  airline: "None"
  },
  # Models/Airport/Jetway/AutoGate-ba.ac
  # Models/Airport/Jetway/AutoGate.xml
  {
  models:
   [
   "Models/Airport/Jetway/AutoGate-ba.ac",
   "Models/Airport/Jetway/AutoGate.xml"
   ],
  offsets:
   {
   x: -10,
   y: 25,
   z: 0,
   heading: -90
   },
  init_pos:
   {
   extend: 7.68,
   heading: 0,
   pitch: 0,
   ent_heading: -90
   },
  model: "generic",
  airline: "None"
  },
  # Models/Airport/Jetway/DockingGate-ba.ac
  # Models/Airport/Jetway/DockingGate.xml
  {
  models:
   [
   "Models/Airport/Jetway/DockingGate-ba.ac",
   "Models/Airport/Jetway/DockingGate.xml"
   ],
  offsets:
   {
   x: -10,
   y: 5,
   z: 0,
   heading: -90
   },
  init_pos:
   {
   extend: 7.68,
   heading: 0,
   pitch: 0,
   ent_heading: -90
   },
  model: "generic",
  airline: "None"
  }
 ];

### Rest of script follows below ###
### Watch your step! :) ###
var dialog_object = nil;
var selected_jetway = nil;
var mouse_mmb = 0;
var kbd_shift = nil;
var kbd_ctrl = nil;
var kbd_alt = nil;
var enabled = nil;
var FLASH_PERIOD = 0.3;
var FLASH_NUM = 3;
var filedialog_listener = 0;

var click = func(pos)
 {
 if (kbd_alt.getBoolValue())
  {
  if (selected_jetway == nil) return;
  selected_jetway.setpos(pos.lat(), pos.lon(), selected_jetway.heading, pos.alt());
  }
 elsif (kbd_shift.getBoolValue())
  {
  if (selected_jetway != nil) selected_jetway._edit = 0;
  selected_jetway = nil;
  }
 elsif (kbd_ctrl.getBoolValue())
  {
  var nearest_jetway = nil;
  var min_dist = geo.ERAD;
  for (var i = 0; i < size(jetways.jetways); i += 1)
   {
   var jetway = jetways.jetways[i];
   if (jetway == nil) continue;
   var dist = geo.Coord.new().set_latlon(jetway.lat, jetway.lon, jetway.alt).direct_distance_to(pos);
   if (dist < min_dist)
    {
    min_dist = dist;
    nearest_jetway = jetway;
    }
   }
  if (nearest_jetway != nil)
   {
   if (selected_jetway != nil) selected_jetway._edit = 0;
   selected_jetway = nearest_jetway;
   setprop("/sim/jetways/adjust/model", selected_jetway.model);
   setprop("/sim/jetways/adjust/door", selected_jetway.door);
   setprop("/sim/jetways/adjust/airline", selected_jetway.airline);
   setprop("/sim/jetways/adjust/gate", selected_jetway.gate);
   selected_jetway._edit = 1;
   flash(nearest_jetway);
   }
  }
 else
  {
  var airport = getprop("/sim/airport/closest-airport-id");
  if (airport == "") return;
  selected_jetway = jetways.Jetway.new(airport, "generic", "FG", 0, "FGFS", pos.lat(), pos.lon(), pos.alt(), 0);
  selected_jetway._edit = 1;
  if (!jetways.isin(jetways.loaded_airports, airport)) append(jetways.loaded_airports, airport);
  setprop("/sim/jetways/adjust/model", selected_jetway.model);
  setprop("/sim/jetways/adjust/door", selected_jetway.door);
  setprop("/sim/jetways/adjust/airline", selected_jetway.airline);
  setprop("/sim/jetways/adjust/gate", selected_jetway.gate);
  flash(selected_jetway);
  }
 };
var delete = func
 {
 if (selected_jetway == nil) return;
 selected_jetway.remove();
 selected_jetway = nil;
 };
var adjust = func(name, value)
 {
 if (selected_jetway == nil) return;
 if (name == "longitudinal")
  {
  var jetway_pos = geo.Coord.new();
  jetway_pos.set_latlon(selected_jetway.lat, selected_jetway.lon, selected_jetway.alt);
  var dir = geo.aircraft_position().course_to(jetway_pos);
  jetway_pos.apply_course_distance(dir, value);
  selected_jetway.setpos(jetway_pos.lat(), jetway_pos.lon(), selected_jetway.heading, selected_jetway.alt);
  }
 elsif (name == "transversal")
  {
  var jetway_pos = geo.Coord.new();
  jetway_pos.set_latlon(selected_jetway.lat, selected_jetway.lon, selected_jetway.alt);
  var dir = geo.aircraft_position().course_to(jetway_pos) + 90;
  jetway_pos.apply_course_distance(dir, value);
  selected_jetway.setpos(jetway_pos.lat(), jetway_pos.lon(), selected_jetway.heading, selected_jetway.alt);
  }
 elsif (name == "altitude")
  {
  var alt = selected_jetway.alt + value * 0.4;
  selected_jetway.setpos(selected_jetway.lat, selected_jetway.lon, selected_jetway.heading, alt);
  }
 elsif (name == "heading")
  {
  var hdg = geo.normdeg(selected_jetway.heading + value * 4);
  selected_jetway.setpos(selected_jetway.lat, selected_jetway.lon, hdg, selected_jetway.alt);
  }
 elsif (name == "initial-extension")
  {
  var newvalue = selected_jetway.init_extend + value;
  if (newvalue > selected_jetway.max_extend)
   {
   gui.popupTip("Value exceeds maximum jetway extension limit");
   }
  elsif (newvalue < selected_jetway.min_extend)
   {
   gui.popupTip("Value lower than minimum jetway extension limit");
   }
  else
   {
   selected_jetway.init_extend = newvalue;
   }
  }
 elsif (name == "initial-pitch")
  {
  selected_jetway.init_pitch += value;
  }
 elsif (name == "initial-heading")
  {
  selected_jetway.init_heading += value;
  }
 elsif (name == "initial-entrance-heading")
  {
  selected_jetway.init_ent_heading += value;
  }
 elsif (name == "model")
  {
  selected_jetway.setmodel(value, selected_jetway.airline, selected_jetway.gate);
  selected_jetway = jetways.jetways[getprop("/sim/jetways/last-loaded-jetway")];
  }
 elsif (name == "door")
  {
  selected_jetway.door = value;
  }
 elsif (name == "airline")
  {
  selected_jetway.setmodel(selected_jetway.model, value, selected_jetway.gate);
  selected_jetway = jetways.jetways[getprop("/sim/jetways/last-loaded-jetway")];
  }
 elsif (name == "gate")
  {
  selected_jetway.setmodel(selected_jetway.model, selected_jetway.airline, value);
  selected_jetway = jetways.jetways[getprop("/sim/jetways/last-loaded-jetway")];
  }
 };
var export = func
 {
 var path = getprop("/sim/fg-home") ~ "/Export/";
 var airports = {};
 var airportarray = [];
 foreach (var jetway; jetways.jetways)
  {
  if (jetway == nil) continue;
  if (airports[jetway.airport] == nil)
   {
   airports[jetway.airport] = [];
   append(airportarray, jetway.airport);
   }
  var node = props.Node.new();
  node.getNode("model", 1).setValue(jetway.model);
  node.getNode("gate", 1).setValue(jetway.gate);
  node.getNode("door", 1).setIntValue(jetway.door);
  node.getNode("airline", 1).setValue(jetway.airline);
  node.getNode("latitude-deg", 1).setDoubleValue(jetway.lat);
  node.getNode("longitude-deg", 1).setDoubleValue(jetway.lon);
  var alt = jetway.alt;
  jetway.setpos(jetway.lat, jetway.lon, jetway.heading, -geo.ERAD);
  node.getNode("elevation-m", 1).setDoubleValue(alt - geo.elevation(jetway.lat, jetway.lon));
  jetway.setpos(jetway.lat, jetway.lon, jetway.heading, alt);
  node.getNode("heading-deg", 1).setDoubleValue(geo.normdeg(180 - jetway.heading));
  node.getNode("initial-position/jetway-extension-m", 1).setDoubleValue(jetway.init_extend);
  node.getNode("initial-position/jetway-heading-deg", 1).setDoubleValue(jetway.init_heading);
  node.getNode("initial-position/jetway-pitch-deg", 1).setDoubleValue(jetway.init_pitch);
  node.getNode("initial-position/entrance-heading-deg", 1).setDoubleValue(jetway.init_ent_heading);
  append(airports[jetway.airport], node);
  }
 foreach (var airport; airportarray)
  {
  var file = path ~ airport ~ ".xml";
  var args = props.Node.new({ filename: file });
  var nodes = airports[airport];
  foreach (var node; nodes)
   {
   var data = args.getNode("data", 1);
   for (var i = 0; 1; i += 1)
    {
    if (data.getChild("jetway", i, 0) == nil)
     {
     props.copy(node, data.getChild("jetway", i, 1));
     break;
     }
    }
   }
  fgcommand("savexml", args);
  print("jetway definitions for airport " ~ airport ~ " exported to " ~ file);
  }
 };
var convert_stg = func
 {
 fgcommand("dialog-show", props.Node.new({ "dialog-name": "file-select" }));
 setprop("/sim/gui/dialogs/file-select/path", "");
 filedialog_listener = setlistener("/sim/gui/dialogs/file-select/path", func(n)
  {
  removelistener(filedialog_listener);
  var path = n.getValue();
  if (path == "") return;
  var stg = io.readfile(path);
  var stg_lines = [[]];
  var current_word = "";
  for (var i = 0; i < size(stg); i += 1)
   {
   var char = substr(stg, i, 1);
   if (char == " " or char == "\n")
    {
    append(stg_lines[size(stg_lines) - 1], current_word);
    current_word = "";
    if (char == "\n") append(stg_lines, []);
    }
   else
    {
    current_word ~= char;
    }
   }

  var jetway_array = [];
  foreach (var line; stg_lines)
   {
   if (size(line) < 6 or line[0] != "OBJECT_SHARED") continue;
   var foundmodel = 0;
   var jetway = nil;
   foreach (var profile; Static_jetway)
    {
    foreach (var model; profile.models)
     {
     if (model == line[1]) foundmodel = 1;
     }
    if (foundmodel)
     {
     jetway = profile;
     break;
     }
    }
   if (jetway == nil) continue;
   var heading = num(line[5]);
   var coord = geo.Coord.new();
   coord.set_latlon(line[3], line[2], line[4]);
   coord.apply_course_distance(360 - heading, -jetway.offsets.x);
   coord.apply_course_distance(360 - heading + 90, jetway.offsets.y);
   coord.set_alt(coord.alt() + jetway.offsets.z);
   var hash = {};
   hash.coord = coord;
   hash.heading = heading + jetway.offsets.heading;
   hash.init_extend = jetway.init_pos.extend;
   hash.init_heading = jetway.init_pos.heading;
   hash.init_pitch = jetway.init_pos.pitch;
   hash.init_ent_heading = jetway.init_pos.ent_heading;
   hash.model = jetway.model;
   hash.airline = jetway.airline;
   append(jetway_array, hash);
   }

  var airport = getprop("/sim/airport/closest-airport-id");
  if (airport == "") return;
  var i = 0;
  var loop = func
   {
   if (i >= size(jetway_array)) return;
   var jetway = jetway_array[i];
   jetways.Jetway.new(airport, jetway.model, "", 0, jetway.airline, jetway.coord.lat(), jetway.coord.lon(), jetway.coord.alt(), jetway.heading, jetway.init_extend, jetway.init_heading, jetway.init_pitch, jetway.init_ent_heading);
   if (!jetways.isin(jetways.loaded_airports, airport)) append(jetways.loaded_airports, airport);
   i += 1;
   settimer(loop, jetways.LOAD_JETWAY_PERIOD);
   };
  settimer(loop, 0);
  jetways.alert("Creating " ~ size(jetway_array) ~ " jetways for airport " ~ airport);
  }, 0, 1);
 };
var flash = func(jetway)
 {
 if (!contains(jetway, "_flashnum") or jetway._flashnum == -1)
  {
  jetway._alt = jetway.alt;
  jetway.setpos(jetway.lat, jetway.lon, jetway.heading, -geo.ERAD);
  jetway._flashnum = 0;
  settimer(func flash(jetway), FLASH_PERIOD);
  }
 elsif (!contains(jetway, "_alt"))
  {
  jetway._flashnum = -1;
  jetway.setpos(jetway.lat, jetway.lon, jetway.heading, geo.elevation(jetway.lat, jetway.lon));
  return;
  }
 elsif (jetway._flashnum == FLASH_NUM + 1)
  {
  jetway.setpos(jetway.lat, jetway.lon, jetway.heading, jetway._alt);
  jetway._alt = nil;
  jetway._flashnum = -1;
  }
 else
  {
  if (jetway.alt == -geo.ERAD)
   {
   jetway.setpos(jetway.lat, jetway.lon, jetway.heading, jetway._alt);
   }
  else
   {
   jetway.setpos(jetway.lat, jetway.lon, jetway.heading, -geo.ERAD);
   }
  jetway._flashnum += 1;
  settimer(func flash(jetway), FLASH_PERIOD);
  }
 };

var dialog = func
 {
 if (dialog_object == nil) dialog_object = gui.Dialog.new("/sim/gui/dialogs/jetways-adjust/dialog", "gui/dialogs/jetways-adjust.xml");
 dialog_object.open();
 };
var print_help = func
 {
 print("JETWAY EDITOR HELP");
 print("*******************************************************");
 print("See: http://wiki.flightgear.org/Howto:_Animated_jetways");
 print("");
 print("Adjust position, heading, and altitude with top sliders");
 print("Adjust initial jetway positions with bottom sliders");
 print("");
 print("<Model>			model of selected jetway");
 print("<Door>			aircraft door number of selected jetway");
 print("<Airline sign>		airline sign code of selected jetway");
 print("<Gate>			gate number of selected jetway");
 print("");
 print("[Center sliders]	apply slider offsets and return sliders to 0");
 print("[Export]		export jetway definition file(s)");
 print("[STG converter]		convert static jetways in STG files to animated jetways");
 print("[?]			show this help text");
 print("");
 print("Click			add jetway on click position");
 print("Alt-click		move selected jetway to click position");
 print("Ctrl-click		select a jetway near click position");
 print("Shift-click		deselect selected jetway");
 print("Backspace		delete selected jetway");
 print("*******************************************************");
 };

_setlistener("/nasal/jetways_edit/loaded", func
 {
 print("Animated jetway editor ... loaded");
 kbd_shift = props.globals.getNode("/devices/status/keyboard/shift");
 kbd_ctrl = props.globals.getNode("/devices/status/keyboard/ctrl");
 kbd_alt = props.globals.getNode("/devices/status/keyboard/alt");
 enabled = props.globals.getNode("/nasal/jetways_edit/enabled");

 setlistener("/sim/jetways/adjust/model", func(n)
  {
  var v = n.getValue();
  if (selected_jetway != nil and v != selected_jetway.model)
   {
   adjust("model", v);
   }
  }, 0, 0);
 setlistener("/sim/jetways/adjust/door", func(n)
  {
  var v = n.getValue();
  if (selected_jetway != nil and v != selected_jetway.door)
   {
   adjust("door", v);
   }
  }, 0, 0);
 setlistener("/sim/jetways/adjust/airline", func(n)
  {
  var v = n.getValue();
  if (selected_jetway != nil and v != selected_jetway.airline)
   {
   adjust("airline", v);
   }
  }, 0, 0);
 setlistener("/sim/jetways/adjust/gate", func(n)
  {
  var v = n.getValue();
  if (selected_jetway != nil and v != selected_jetway.gate)
   {
   adjust("gate", v);
   }
  }, 0, 0);
 setlistener("/devices/status/keyboard/event", func(event)
  {
  if (!event.getNode("pressed").getValue()) return;
  if (enabled.getBoolValue() and event.getNode("key").getValue() == 8) delete();
  });
 setlistener("/devices/status/mice/mouse/button[1]", func(n) mouse_mmb = n.getBoolValue(), 1, 0);
 setlistener("/sim/signals/click", func if (!mouse_mmb and enabled.getBoolValue()) click(geo.click_position()));
 });
