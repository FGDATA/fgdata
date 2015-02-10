###############################################################################
##
##  Animated Jetway System. Spawns and manages interactive jetway models.
##
##  Copyright (C) 2011  Ryan Miller
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

###############################################################################
# (See http://wiki.flightgear.org/Howto:_Animated_jetways)
#
# Special jetway definition files located in $FG_ROOT/Airports/Jetways/XXXX.xml
# for each airport are loaded when the user's aircraft is within 50 nm of the
# airport. The script dynamically generates runtime model files, writes them to
# $FG_ROOT/Models/Airport/Jetway/runtimeX.xml, and places them into the
# simulator using the model manager.
#
# Different jetway models can be defined and are placed under
# $FG_ROOT/Models/Airport/Jetway/XXX.xml.
#
# Jetways can be extended/retracted independently either by user operation or
# by automatic extension for AI models and multiplayer aircraft.
#
# UTILITY FUNCTIONS
# -----------------
#
# print_debug(<message>)			- prints debug messages
#	<message>				- message to print
#
# print_error(<messsage>)			- prints error messages
#	<message>				- error to print
#
# alert(<message>)				- displays an alert message in-sim
#	<message>				- the message
#
# normdeg(<angle>)				- normalizes angle measures between -180° and 180°
#	<angle>					- angle to normalize
#
# remove(<vector>, <item>)			- removes an element from a vector
#	<vector>				- vector
#	<index>					- item
#
# isin(<vector>, <item>)			- checks if an item exists in a vector
#	<vector>				- vector
#	<item>					- item
#
# putmodel(<path>, <lat>, <lon>, <alt>, <hdg>)	- add a model to the scene graph (unlike geo.put_model(), models added with this function can be adjusted)
#	<path>					- model path
#	<lat>					- latitude
#	<lon>					- longitude
#	<alt>					- altitude in m
#	<hdg>					- heading
#
# interpolate_table(<table>, <value>)		- interpolates a value within a table
#	<table>					- interpolation table/vector, in the format of [[<ind>, <dep>], [<ind>, <dep>], ... ]
#	<value>					- value
#
# get_relative_filepath(<path>, <target>)	- gets a relative file path from a directory
#	<path>					- directory path should be relative to
#	<target>				- target directory
#
# find_airports(<max dist>)			- gets a list of nearest airports
#	<max dist>				- maximum search distance in nm (currently unused)
#
# JETWAY CLASS
# ------------
#
# Jetway.					- creates a new jetway object/model
#   new(<airport>, <model>, <gate>, <door>,
#       <airline>, <lat>, <lon>, <alt>,
#	<heading>, [, <init_extend>]
#	[, <init_heading>] [, <init_pitch>]
#	[, <init_ent_heading>])
#	<airport>				- ICAO of associated airport
#	<model>					- jetway model definition (i.e. Models/Airport/Jetway/generic.xml)
#	<gate>					- gate number (i.e. "A1")
#	<door>					- door number (i.e. 0)
#	<airline>				- airline code (i.e. "AAL")
#	<lat>					- latitude location of model
#	<lon>					- longitude location of model
#	<alt>					- elevation of model in m
#	<heading>				- (optional) heading of model
#	<init_extend>				- (optional) initial extension of tunnel in m
#	<init_heading>				- (optional) initial rotation of tunnel along the Z axis
#	<init_pitch>				- (optional) initial pitch of tunnel (rotation along Y axis)
#	<init_ent_heading>			- (optional) initial rotation of entrance along the Z axis
#
#   toggle(<user>, <heading>, <coord>		- extends/retracts a jetway
#          [, <hood>])
#	<user>					- whether or not jetway is toggled by user command (0/1)
#	<heading>				- heading of aircraft to connect to
#	<coord>					- a geo.Coord of the target aircraft's door
#	<hood>					- (optional) amount to rotate jetway hood (only required when <user> != 1)
#
#   extend(<user>, <heading>, <coord>		- extends a jetway (should be called by Jetway.toggle())
#          [, <hood>])
#	<user>					- whether or not jetway is toggled by user command (0/1)
#	<heading>				- heading of aircraft to connect to
#	<coord>					- a geo.Coord of the target aircraft's door
#	<hood>					- (optional) amount to rotate jetway hood (only required when <user> != 1)
#
#   retract(<user>)				- retracts a jetway (should be called by Jetway.toggle())
#	<user>					- whether or not a jetway is toggled by user command (0/1)
#
#   remove()					- removes a jetway object and its model
#
#   reload()					- reloads a jetway object and its model
#
#   setpos(<lat>, <lon>, <heading>, <alt>)	- moves a jetway to a new location
#	<lat>					- new latitude
#	<lon>					- new longitude
#	<heading>				- new heading
#	<alt>					- new altitude in m
#
#   setmodel(<model>, <airline>, <gate>)	- changes the jetway model
#	<model>					- new model
#	<airline>				- new airline sign code
#	<gate>					- new gate number
#
# INTERACTION FUNCTIONS
# ---------------------
#
# dialog()					- open settings dialog
#
# toggle_jetway(<id>)				- toggles a jetway by user command (should be called by a pick animation in a jetway model)
#	<id>					- id number of jetway to toggle
#
# toggle_jetway_from_coord(<door>, <hood>,	- toggles a jetway with the target door at the specified coordinates
#                          <heading>, [<lat>,
#                          <lon>] [<coord>])
#	<door>					- door number (i.e. 0)
#	<hood>					- amount to rotate jetway hood
#	<lat>					- (required or <coord>) latitude location of door
#	<lon>					- (required or <coord>) longitude location of door
#	<coord>					- (required or <lat>, <lon>) a geo.Coord of the door
#
# toggle_jetway_from_model(<model node>)	- toggles a jetway using an AI model instead of the user's aircraft
#	<model node>				- path of AI model (i.e. /ai/models/aircraft[0])- can be the path in a string or a props.Node
#
# INTERNAL FUNCTIONS
# ------------------
#
# load_airport_jetways(<airport>)		- loads jetways at an airport
#	<airport>				- ICAO of airport
#
# unload_airport_jetways(<airport>)		- unloads jetways at an airport
#	<airport>				- ICAO of airport
#
# update_jetways()				- interpolates model animation values
#
# load_jetways()				- loads new jetway models and unloads out-of-range models every 10 seconds; also connects AI and MP aircraft
#

## Utility functions
####################

# prints debug messages
var print_debug = func(msg)
 {
 if (debug_switch.getBoolValue())
  {
  print(msg);
  }
 };
# prints error messages
var print_error = func(msg)
 {
 print("\x1b[31m" ~ msg ~ "\x1b[m");
 };
# alerts the user
var alert = func(msg)
 {
 setprop("/sim/messages/ground", msg);
 };
# normalizes headings between -180 and 180
var normdeg = func(x)
 {
 while (x >= 180)
  {
  x -= 360;
  }
 while (x <= -180)
  {
  x += 360;
  }
 return x;
 };
# deletes an item in a vector
var remove = func(vector, item)
 {
 var s = size(vector);
 var found = 0;
 for (var i = 0; i < s; i += 1)
  {
  if (found)
   {
   vector[i - 1] = vector[i];
   }
  elsif (vector[i] == item)
   {
   found = 1;
   }
  }
 if (found) setsize(vector, s - 1);
 return vector;
 };
# checks if an item is in a vector
var isin = func(vector, v)
 {
 foreach (var item; vector)
  {
  if (item == v) return 1;
  }
 return 0;
 };
# adds a model
var putmodel = func(path, lat, lon, alt, hdg)
 {
 var models = props.globals.getNode("/models");
 var model = nil;
 for (var i = 0; 1; i += 1)
  {
  if (models.getChild("model", i, 0) == nil)
   {
   model = models.getChild("model", i, 1);
   break;
   }
  }
 var model_path = model.getPath();
 model.getNode("path", 1).setValue(path);
 model.getNode("latitude-deg", 1).setDoubleValue(lat);
 model.getNode("latitude-deg-prop", 1).setValue(model_path ~ "/latitude-deg");
 model.getNode("longitude-deg", 1).setDoubleValue(lon);
 model.getNode("longitude-deg-prop", 1).setValue(model_path ~ "/longitude-deg");
 model.getNode("elevation-ft", 1).setDoubleValue(alt * M2FT);
 model.getNode("elevation-ft-prop", 1).setValue(model_path ~ "/elevation-ft");
 model.getNode("heading-deg", 1).setDoubleValue(hdg);
 model.getNode("heading-deg-prop", 1).setValue(model_path ~ "/heading-deg");
 model.getNode("pitch-deg", 1).setDoubleValue(0);
 model.getNode("pitch-deg-prop", 1).setValue(model_path ~ "/pitch-deg");
 model.getNode("roll-deg", 1).setDoubleValue(0);
 model.getNode("roll-deg-prop", 1).setValue(model_path ~ "/roll-deg");
 model.getNode("load", 1).remove();
 return model;
 };

# interpolates a value
var interpolate_table = func(table, v)
 {
 var x = 0;
 forindex (i; table)
  {
  if (v >= table[i][0])
   {
   x = i + 1 < size(table) ? (v - table[i][0]) / (table[i + 1][0] - table[i][0]) * (table[i + 1][1] - table[i][1]) + table[i][1] : table[i][1];
   }
  }
 return x;
 };
# gets a relative file path
var get_relative_filepath = func(path, target)
 {
 var newpath = "";
 for (var i = size(path) - 1; i >= 0; i -= 1)
  {
  var char = substr(path, i, 1);
  if (char == "/") newpath ~= "../";
  }
 # we can just append the target path for UNIX systems, but we need to remove the drive letter prefix for DOS systems
 return newpath ~ (string.match(substr(target, 0, 3), "?:/") ? substr(target, 2, size(target) - 2) : target);
 };
# gets a list of nearest airports
# TODO: Don't use /sim/airport/nearest-airport-id, which restricts the list to 1 airport
var find_airports = func(max_distance)
 {
 var apt = getprop("/sim/airport/closest-airport-id");
 return apt == "" ? nil : [apt];
 };

## Global variables
###################

var root = nil;
var home = nil;
var scenery = [];

var UPDATE_PERIOD = 0;
var LOAD_PERIOD = 10;
var LOAD_DISTANCE = 50;				# in nautical miles
var LOAD_JETWAY_PERIOD = 0.05;
var NUMBER_OF_JETWAYS = 1000;			# approx max number of jetways loadable in FG
var runtime_files = NUMBER_OF_JETWAYS / LOAD_PERIOD * LOAD_JETWAY_PERIOD;
runtime_files = int(runtime_files) == runtime_files ? runtime_files : int(runtime_files) + 1;
var runtime_file = 0;
var update_loopid = -1;
var load_loopid = -1;
var load_listenerid = nil;
var loadids = {};
var dialog_object = nil;
var loaded_airports = [];
var jetways = [];

# properties
var on_switch = nil;
var debug_switch = nil;
var mp_switch = nil;
var jetway_id_prop = "/sim/jetways/last-loaded-jetway";

# interpolation tables
var extend_rate = 0.5;
var extend_table = [
  [0.0, 0.0],
  [0.2, 0.3],
  [0.6, 0.3],
  [0.8, 1.0],
  [1.0, 1.0]
 ];
var pitch_rate = 1;
var pitch_table = [
  [0.0, 0.0],
  [0.4, 0.7],
  [0.7, 1.0],
  [1.0, 1.0]
 ];
var heading_rate = 1;
var heading_table = [
  [0.0, 0.0],
  [0.2, 0.0],
  [0.6, 0.7],
  [0.9, 1.0],
  [1.0, 1.0]
 ];
var heading_entrance_rate = 5;
var heading_entrance_table = [
  [0.0, 0.0],
  [0.3, 0.0],
  [0.6, 0.7],
  [0.8, 1.0],
  [1.0, 1.0]
 ];
var hood_rate = 1;
var hood_table = [
  [0.0, 0.0],
  [0.9, 0.0],
  [1.0, 1.0]
 ];

## Classes
##########

# main jetway class
var Jetway =
 {
 new: func(airport, model, gate, door, airline, lat, lon, alt, heading, init_extend = 0, init_heading = 0, init_pitch = 0, init_ent_heading = 0)
  {
  var id = 0;
  for (var i = 0; 1; i += 1)
   {
   if (i == size(jetways))
    {
    setsize(jetways, i + 1);
    id = i;
    break;
    }
   elsif (jetways[i] == nil)
    {
    id = i;
    }
   }
  # locate the jetway model directory and load the model tree
  var model_tree = nil;
  var model_file = "";
  var model_dir = "";
  var airline_file = "";
  # search in scenery directories
  foreach (var scenery_path; scenery)
   {
   model_dir = scenery_path ~ "/Models/Airport/Jetway";
   model_file = model_dir ~ "/" ~ model ~ ".xml";
   airline_file = model_dir ~ "/" ~ model ~ ".airline." ~ airline ~ ".xml";
   print_debug("Trying to load a jetway model from " ~ model_file);
   if (io.stat(model_file) == nil) continue;
   model_tree = io.read_properties(model_file);
   if (io.stat(airline_file) != nil) props.copy(io.read_properties(airline_file), model_tree);
   break;
   }
  if (model_tree == nil)
   {
   model_dir = root ~ "/Models/Airport/Jetway";
   model_file = model_dir ~ "/" ~ model ~ ".xml";
   airline_file = model_dir ~ "/" ~ model ~ ".airline." ~ airline ~ ".xml";
   print_debug("Falling back to " ~ model_file);
   if (io.stat(model_file) == nil)
    {
    print_error("Failed to load jetway model: " ~ model);
    return;
    }
   model_tree = io.read_properties(model_file);
   if (io.stat(airline_file) != nil) props.copy(io.read_properties(airline_file), model_tree);
   }

  var m =
   {
   parents: [Jetway]
   };
  m._active = 1; # set this to 'true' on the first run so that the offsets can take effect
  m._edit = 0;
  m.airport = airport;
  m.gate = gate;
  m.airline = airline;
  m.id = id;
  m.model = model;
  m.extended = 0;
  m.door = door;
  m.lat = lat;
  m.lon = lon;
  m.alt = alt;
  m.heading = geo.normdeg(180 - heading);
  m.init_extend = init_extend;
  m.init_heading = init_heading;
  m.init_pitch = init_pitch;
  m.init_ent_heading = init_ent_heading;
  m.target_extend = 0;
  m.target_pitch = 0;
  m.target_heading = 0;
  m.target_ent_heading = 0;
  m.target_hood = 0;
  m.rotunda_x = model_tree.getNode("rotunda/x-m").getValue();
  m.rotunda_y = model_tree.getNode("rotunda/y-m").getValue();
  m.rotunda_z = model_tree.getNode("rotunda/z-m").getValue();
  m.offset_extend = model_tree.getNode("extend-offset-m").getValue();
  m.offset_entrance = model_tree.getNode("entrance-offset-m").getValue();
  m.min_extend = model_tree.getNode("min-extend-m").getValue();
  m.max_extend = model_tree.getNode("max-extend-m").getValue();

  # get the runtime file path
  if (runtime_file == runtime_files)
   {
   runtime_file = 0;
   }
  var runtime_file_path = home ~ "/runtime-jetways/" ~ runtime_file ~ ".xml";
  runtime_file += 1;

  # create the model node and the door object
  m.node = putmodel(runtime_file_path, lat, lon, alt, geo.normdeg(360 - heading));
  var node_path = m.node.getPath();
  m.door_object = aircraft.door.new(node_path ~ "/jetway-position", 0);

  # manipulate the model tree
  model_tree.getNode("path").setValue(model_dir ~ "/" ~ model_tree.getNode("path").getValue());
  model_tree.getNode("toggle-action-script").setValue("jetways.toggle_jetway(" ~ id ~ ");");
  model_tree.getNode("gate").setValue(m.gate);
  model_tree.getNode("extend-m").setValue(props.globals.initNode(node_path ~ "/jetway-position/extend-m", 0, "DOUBLE").getPath());
  model_tree.getNode("pitch-deg").setValue(props.globals.initNode(node_path ~ "/jetway-position/pitch-deg", 0, "DOUBLE").getPath());
  model_tree.getNode("heading-deg").setValue(props.globals.initNode(node_path ~ "/jetway-position/heading-deg", 0, "DOUBLE").getPath());
  model_tree.getNode("entrance-heading-deg").setValue(props.globals.initNode(node_path ~ "/jetway-position/entrance-heading-deg", 0, "DOUBLE").getPath());
  model_tree.getNode("hood-deg").setValue(props.globals.initNode(node_path ~ "/jetway-position/hood-deg", 0, "DOUBLE").getPath());
  # airline texture
  var airline_tex = model_tree.getNode("airline-texture-path", 1).getValue();
  var airline_node = model_tree.getNode(model_tree.getNode("airline-prop-path", 1).getValue());
  if (airline_tex != nil and airline_node != nil)
   {
   airline_node.setValue(get_relative_filepath(home ~ "/runtime-jetways", model_dir ~ "/" ~ airline_tex));
   }
  # write the model tree
  io.write_properties(runtime_file_path, model_tree);

  jetways[id] = m;
  print_debug("Loaded jetway #" ~ id);
  jetway_id_prop.setValue(id);
  return m;
  },
 toggle: func(user, heading, coord, hood = 0)
  {
  me._active = 1;
  if (me.extended)
   {
   me.retract(user, heading, coord);
   }
  else
   {
   me.extend(user, heading, coord, hood);
   }
  },
 extend: func(user, heading, door_coord, hood = 0)
  {
  me.extended = 1;

  # get the coordinates of the jetway and offset for the rotunda position
  var jetway_coord = geo.Coord.new();
  jetway_coord.set_latlon(me.lat, me.lon);
  jetway_coord.apply_course_distance(me.heading, me.rotunda_x);
  jetway_coord.apply_course_distance(me.heading - 90, me.rotunda_y);
  jetway_coord.set_alt(me.alt + me.rotunda_z);

  if (debug_switch.getBoolValue())
   {
   # place UFO cursors at the calculated door and jetway positions for debugging purposes
   geo.put_model("Aircraft/ufo/Models/cursor.ac", door_coord);
   geo.put_model("Aircraft/ufo/Models/cursor.ac", jetway_coord);
   }

  # offset the door for the length of the jetway entrance
  door_coord.apply_course_distance(heading - 90, me.offset_entrance);

  # calculate the bearing to the aircraft and the distance from the door
  me.target_heading = normdeg(jetway_coord.course_to(door_coord) - me.heading - me.init_heading);
  me.target_extend = jetway_coord.distance_to(door_coord) - me.offset_extend - me.init_extend;

  # check if distance exceeds maximum jetway extension length
  if (me.target_extend + me.init_extend > me.max_extend)
   {
   me.extended = 0;
   me.target_extend = 0;
   me.target_heading = 0;
   if (user) alert("Your aircraft is too far from this jetway.");
   print_debug("Jetway #" ~ me.id ~ " is too far from the door");
   return;
   }
  # check if distance fails to meet minimum jetway extension length
  if (me.target_extend + me.init_extend < me.min_extend)
   {
   me.extended = 0;
   me.target_extend = 0;
   me.target_heading = 0;
   if (user) alert("Your aircraft is too close to this jetway.");
   print_debug("Jetway #" ~ me.id ~ " is too close to the door");
   return;
   }

  # calculate the jetway pitch, entrance heading, and hood
  me.target_pitch = math.atan2((door_coord.alt() - jetway_coord.alt()) / (me.target_extend + me.offset_extend + me.init_extend), 1) * R2D - me.init_pitch;
  me.target_ent_heading = normdeg((heading + 90) - (me.heading + (me.target_heading + me.init_heading) + me.init_ent_heading));
  me.target_hood = user ? getprop("/sim/model/door[" ~ me.door ~ "]/jetway-hood-deg") : hood;

  # fire up the animation
  if (user) alert("Extending jetway.");
  var animation_time = math.abs(me.target_extend / extend_rate) + math.abs(me.target_pitch / pitch_rate) + math.abs(me.target_heading / heading_rate) + math.abs(me.target_ent_heading / heading_entrance_rate) + math.abs(me.target_hood / hood_rate);
  me.door_object.swingtime = animation_time;
  me.door_object.open();

  print_debug("************************************************");
  print_debug("Activated jetway #" ~ me.id);
  print_debug("Using door #" ~ me.door);
  print_debug("Jetway heading:		" ~ me.heading ~ " deg");
  print_debug("Extension:		" ~ me.target_extend ~ " m");
  print_debug("Pitch:			" ~ me.target_pitch ~ " deg");
  print_debug("Heading:		" ~ me.target_heading ~ " deg");
  print_debug("Entrance heading:	" ~ me.target_ent_heading ~ " deg");
  print_debug("Hood:			" ~ me.target_hood ~ " deg");
  print_debug("Total animation time:	" ~ animation_time ~ " sec");
  print_debug("Jetway extending");
  print_debug("************************************************");
  },
 retract: func(user)
  {
  if (user) alert("Retracting jetway.");
  me.door_object.close();
  me.extended = 0;

  print_debug("************************************************");
  print_debug("Activated jetway #" ~ me.id);
  print_debug("Total animation time:	" ~ me.door_object.swingtime ~ " sec");
  print_debug("Jetway retracting");
  print_debug("************************************************");
  },
 remove: func
  {
  me.node.remove();
  var id = me.id;
  jetways[me.id] = nil;
  print_debug("Unloaded jetway #" ~ id);
  },
 reload: func
  {
  var airport = me.airport;
  var model = me.model;
  var gate = me.gate;
  var door = me.door;
  var airline = me.airline;
  var lat = me.lat;
  var lon = me.lon;
  var alt = me.alt;
  var heading = geo.normdeg(180 - (me.heading - 360));
  var init_extend = me.init_extend;
  var init_heading = me.init_heading;
  var init_pitch = me.init_pitch;
  var init_ent_heading = me.init_ent_heading;
  me.remove();
  Jetway.new(airport, model, gate, door, airline, lat, lon, alt, heading, init_extend, init_heading, init_pitch, init_ent_heading);
  },
 setpos: func(lat, lon, hdg, alt)
  {
  me.node.getNode("latitude-deg").setValue(lat);
  me.lat = lat;
  me.node.getNode("longitude-deg").setValue(lon);
  me.lon = lon;
  me.node.getNode("heading-deg").setValue(geo.normdeg(hdg - 180));
  me.heading = hdg;
  me.node.getNode("elevation-ft").setValue(alt * M2FT);
  me.alt = alt;
  },
 setmodel: func(model, airline, gate)
  {
  me.airline = airline;
  me.gate = gate;
  me.model = model;
  me.extended = 0;
  me.target_extend = 0;
  me.target_pitch = 0;
  me.target_heading = 0;
  me.target_ent_heading = 0;
  me.target_hood = 0;
  me.door_object.setpos(0);
  me.reload();
  }
 };

## Interaction functions
########################

var dialog = func
 {
 if (dialog_object == nil) dialog_object = gui.Dialog.new("/sim/gui/dialogs/jetways/dialog", "gui/dialogs/jetways.xml");
 dialog_object.open();
 };

var toggle_jetway = func(n)
 {
 var jetway = jetways[n];
 if (jetway == nil) return;
 var door = props.globals.getNode("/sim/model/door[" ~ jetway.door ~ "]");
 if (door == nil)
  {
  alert("Your aircraft does not define the location of door " ~ (jetway.door + 1) ~ ", cannot extend this jetway.");
  return;
  }

 # get the coordinates of the user's aircraft and offset for the door position and aircraft pitch
 var coord = geo.aircraft_position();
 var heading = getprop("/orientation/heading-deg");
 var pitch = getprop("/orientation/pitch-deg");
 coord.apply_course_distance(heading, -door.getChild("position-x-m").getValue());
 coord.apply_course_distance(heading + 90, door.getChild("position-y-m").getValue());
 coord.set_alt(coord.alt() + door.getChild("position-z-m").getValue());
 coord.set_alt(coord.alt() + math.tan(pitch * D2R) * -door.getChild("position-x-m").getValue());

 jetway.toggle(1, heading, coord);
 };
var toggle_jetway_from_coord = func(door, hood, heading, lat, lon = nil)
 {
 if (isa(lat, geo.Coord))
  {
  var coord = lat;
  }
 else
  {
  var coord = geo.Coord.new();
  coord.set_latlon(lat, lon);
  }
 var closest_jetway = nil;
 var closest_jetway_dist = nil;
 var closest_jetway_coord = nil;
 foreach (var jetway; jetways)
  {
  if (jetway == nil) continue;
  var jetway_coord = geo.Coord.new();
  jetway_coord.set_latlon(jetway.lat, jetway.lon);

  var distance = jetway_coord.distance_to(coord);
  if ((closest_jetway_dist == nil or distance < closest_jetway_dist) and jetway.door == door)
   {
   closest_jetway = jetway;
   closest_jetway_dist = distance;
   closest_jetway_coord = jetway_coord;
   }
  }
 if (closest_jetway == nil)
  {
  print_debug("No jetways available");
  }
 elsif (!closest_jetway.extended)
  {
  closest_jetway.toggle(0, heading, coord, hood);
  }
 };
var toggle_jetway_from_model = func(model)
 {
 model = aircraft.makeNode(model);
 var doors = model.getChildren("door");
 if (doors == nil or size(doors) == 0) return;
 for (var i = 0; i < size(doors); i += 1)
  {
  var coord = geo.Coord.new();
  var hdg = model.getNode("orientation/true-heading-deg").getValue();
  var lat = model.getNode("position/latitude-deg").getValue();
  var lon = model.getNode("position/longitude-deg").getValue();
  var alt = model.getNode("position/altitude-ft").getValue() * FT2M + doors[i].getNode("position-z-m").getValue();
  coord.set_latlon(lat, lon, alt);
  coord.apply_course_distance(hdg, -doors[i].getNode("position-x-m").getValue());
  coord.apply_course_distance(hdg + 90, doors[i].getNode("position-y-m").getValue());
  print_debug("Connecting a jetway to door #" ~ i ~ " for model " ~ model.getPath());
  toggle_jetway_from_coord(i, doors[i].getNode("jetway-hood-deg").getValue(), hdg, coord);
  }
 };

## Internal functions
#####################

# loads jetways at an airport
var load_airport_jetways = func(airport)
 {
 if (isin(loaded_airports, airport)) return;
 var tree = io.read_airport_properties(airport, "jetways");
 if (tree == nil)
  {
  tree = io.read_properties(root ~ "/AI/Airports/" ~ airport ~ "/jetways.xml");
  if (tree == nil) return;
  }
 append(loaded_airports, airport);
 print_debug("Loading jetways for airport " ~ airport);
 var nodes = tree.getChildren("jetway");

 loadids[airport] = loadids[airport] == nil ? 0 : loadids[airport] + 1;
 var i = 0;
 var loop = func(id)
  {
  if (id != loadids[airport]) return;
  if (i >= size(nodes)) return;
  var jetway = nodes[i];
  var model = jetway.getNode("model", 1).getValue() or return;
  var gate = jetway.getNode("gate", 1).getValue() or "";
  var door = jetway.getNode("door", 1).getValue() or 0;
  var airline = jetway.getNode("airline", 1).getValue() or "None";
  var lat = jetway.getNode("latitude-deg", 1).getValue() or return;
  var lon = jetway.getNode("longitude-deg", 1).getValue() or return;
  var elev = jetway.getNode("elevation-m", 1).getValue() or 0;
  var alt = geo.elevation(lat, lon) + elev;
  var heading = jetway.getNode("heading-deg", 1).getValue() or 0;
  var init_extend = jetway.getNode("initial-position/jetway-extension-m", 1).getValue() or 0;
  var init_heading = jetway.getNode("initial-position/jetway-heading-deg", 1).getValue() or 0;
  var init_pitch = jetway.getNode("initial-position/jetway-pitch-deg", 1).getValue() or 0;
  var init_ent_heading = jetway.getNode("initial-position/entrance-heading-deg", 1).getValue() or 0;
  Jetway.new(airport, model, gate, door, airline, lat, lon, alt, heading, init_extend, init_heading, init_pitch, init_ent_heading);

  i += 1;
  settimer(func loop(id), LOAD_JETWAY_PERIOD);
  };
 settimer(func loop(loadids[airport]), 0);
 };
# unloads jetways at an airport
var unload_airport_jetways = func(airport)
 {
 print_debug("Unloading jetways for airport " ~ airport);
 foreach (var jetway; jetways)
  {
  if (jetway != nil and jetway.airport == airport) jetway.remove();
  }
 remove(loaded_airports, airport);
 };

# restarts the main update loop
var restart = func()
 {
 update_loopid += 1;
 update_jetways(update_loopid);
 settimer(func
  {
  load_loopid += 1;
  load_jetways(load_loopid);
  }, 2);
 print("Animated jetways ... initialized");
 };
# main update loop (runs when jetways are enable and actived)
var update_jetways = func(loopid)
 {
 # terminate if loopid does not match
 if (loopid != update_loopid) return;
 # if jetways disabled, unload jetways and terminate
 if (!on_switch.getBoolValue())
  {
 foreach (var jetway; jetways)
   {
   if (jetway != nil) jetway.remove();
   }
  setsize(jetways, 0);
  setsize(loaded_airports, 0);
  return;
  }
 # interpolate jetway values
 foreach (var jetway; jetways)
  {
  if (jetway == nil) continue;
  if (jetway._active or jetway._edit)
   {
   var position = jetway.door_object.getpos();
   if (position == 0 or position == 1) jetway._active = 0;
   jetway.node.getNode("jetway-position/extend-m").setValue(interpolate_table(extend_table, position) * jetway.target_extend + jetway.init_extend);
   jetway.node.getNode("jetway-position/pitch-deg").setValue(interpolate_table(pitch_table, position) * jetway.target_pitch + jetway.init_pitch);
   jetway.node.getNode("jetway-position/heading-deg").setValue(interpolate_table(heading_table, position) * jetway.target_heading + jetway.init_heading);
   jetway.node.getNode("jetway-position/entrance-heading-deg").setValue(interpolate_table(heading_entrance_table, position) * jetway.target_ent_heading + jetway.init_ent_heading);
   jetway.node.getNode("jetway-position/hood-deg").setValue(interpolate_table(hood_table, position) * jetway.target_hood);
   }
  }
 settimer(func update_jetways(loopid), UPDATE_PERIOD);
 };
# loading/unloading loop (runs continuously)
var load_jetways = func(loopid)
 {
 if (load_listenerid != nil) removelistener(load_listenerid);
 # terminate if loopid does not match
 # unloading jetways if jetways are disabled is handled by update loop
 if (loopid != load_loopid or !on_switch.getBoolValue()) return;
 var airports = find_airports(LOAD_DISTANCE);
 if (airports == nil) return;
 # search for any airports out of range and unload their jetways
 foreach (var airport; loaded_airports)
  {
  if (!isin(airports, airport))
   {
   unload_airport_jetways(airport);
   }
  }
 # load any airports in range
 foreach (var airport; airports)
  {
  load_airport_jetways(airport);
  }

 var nearest_airport = airportinfo();
 nearest_airport = nearest_airport == nil ? nil : nearest_airport.id;
 if (isin(loaded_airports, nearest_airport))
  {
  # loop through the AI aircraft and extend/retract jetways
  var ai_aircraft = props.globals.getNode("ai/models").getChildren("aircraft");
  foreach (var aircraft; ai_aircraft)
   {
   if (!aircraft.getNode("valid", 1).getBoolValue()) continue;
   var connected = aircraft.getNode("connected-to-jetways", 1);
   var velocity = aircraft.getNode("velocities/true-airspeed-kt", 1).getValue();
   # TODO: Find a better way to know when the aircraft is "parked"
   if (velocity != nil and velocity > -1 and velocity < 1)
    {
    if (!connected.getBoolValue()) toggle_jetway_from_model(aircraft);
    connected.setBoolValue(1);
    }
   else
    {
    if (connected.getBoolValue()) toggle_jetway_from_model(aircraft);
    connected.setBoolValue(0);
    }
   }
  # loop through the multiplayer aircraft and extend/retract jetways
  # TODO: In the future, broadcast jetway properties over MP, making this part obselete
  if (mp_switch.getBoolValue())
   {
   var multiplayers = props.globals.getNode("ai/models").getChildren("multiplayer");
   foreach (var aircraft; multiplayers)
    {
    if (!aircraft.getNode("valid", 1).getBoolValue()) continue;
    var connected = aircraft.getNode("connected-to-jetways", 1);
    var velocity = aircraft.getNode("velocities/true-airspeed-kt", 1).getValue();
    if (velocity != nil and velocity > -1 and velocity < 1)
     {
     if (!connected.getBoolValue()) toggle_jetway_from_model(aircraft);
     connected.setBoolValue(1);
     }
    else
     {
     if (connected.getBoolValue()) toggle_jetway_from_model(aircraft);
     connected.setBoolValue(0);
     }
    }
   }
  }
 settimer(func load_jetways(loopid), LOAD_PERIOD);
 };
## fire it up
_setlistener("/nasal/jetways/loaded", func
 {
 # global variables
 root = string.normpath(getprop("/sim/fg-root"));
 home = string.normpath(getprop("/sim/fg-home"));
 foreach (var scenery_path; props.globals.getNode("/sim").getChildren("fg-scenery"))
  {
  append(scenery, string.normpath(scenery_path.getValue()));
  }
 if (size(scenery) == 0) append(scenery, root ~ "/Scenery");

 # properties
 on_switch = props.globals.getNode("/nasal/jetways/enabled", 1);
 debug_switch = props.globals.getNode("/sim/jetways/debug", 1);
 mp_switch = props.globals.getNode("/sim/jetways/interact-with-multiplay", 1);

 jetway_id_prop = props.globals.getNode(jetway_id_prop, 1);
 restart();
 });
