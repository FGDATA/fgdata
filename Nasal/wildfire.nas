###############################################################################
##
##  A cellular automaton forest fire model with the ability to
##  spread over the multiplayer network.
##
##  Copyright (C) 2007 - 2012  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# The cellular automata model used here is loosely based on
#  A. Hernandez Encinas, L. Hernandez Encinas, S. Hoya White,
#  A. Martin del Rey, G. Rodriguez Sanchez,
#  "Simulation of forest fire fronts using cellular automata",
#  Advances in Engineering Software 38 (2007), pp. 372-378, Elsevier.

# Set this to print for debug.
var trace = func {}

# Where to save fire event logs.
var SAVEDIR = getprop("/sim/fg-home") ~ "/Wildfire/";

# Maximum number of ignite events a single user can send per second.
var MAX_IGNITE_RATE = 0.25;

###############################################################################
## External API

# Start a fire.
#   pos    - fire location    : geo.Coord
#   source - broadcast event? : bool
var ignite = func (pos, source=1) {
  if (!getprop(CA_enabled_pp)) return;
  if (getprop(MP_share_pp) and source) broadcast.send(ignition_msg(pos));
  CAFire.ignite(pos.lat(), pos.lon());
}

# Resolve a water drop impact.
#   pos    - drop location    : geo.Coord
#   radius - drop radius m    : double
#   volume - drop volume m3   : double
var resolve_water_drop = func (pos, radius, volume, source=1) {
  if (!getprop(CA_enabled_pp)) return;
  if (getprop(MP_share_pp) and source) {
    broadcast.send(water_drop_msg(pos, radius, volume));
  }
  var res = CAFire.resolve_water_drop(pos.lat(), pos.lon(), radius, volume);
  if (source) {
    score.extinguished += res.extinguished;
    score.protected    += res.protected;
    score.waste        += res.waste;
  }
}

# Resolve a retardant drop impact.
#   pos    - drop location : geo.Coord
#   radius - drop radius   : double
#   volume - drop volume   : double
var resolve_retardant_drop = func (pos, radius, volume, source=1) {
  if (!getprop(CA_enabled_pp)) return;
  if (getprop(MP_share_pp) and source) {
    broadcast.send(retardant_drop_msg(pos, radius, volume));
  }
  var res = CAFire.resolve_retardant_drop(pos.lat(), pos.lon(),
                                          radius, volume);
  if (source) {
    score.extinguished += res.extinguished;
    score.protected    += res.protected;
    score.waste        += res.waste;
  }
}

# Resolve a foam drop impact.
#   pos    - drop location : geo.Coord
#   radius - drop radius   : double
#   volume - drop volume   : double
var resolve_foam_drop = func (pos, radius, volume, source=1) {
  if (!getprop(CA_enabled_pp)) return;
  if (getprop(MP_share_pp) and source) {
    broadcast.send(foam_drop_msg(pos, radius, volume));
  }
  var res = CAFire.resolve_foam_drop(pos.lat(), pos.lon(),
                                     radius, volume);
  if (source) {
    score.extinguished += res.extinguished;
    score.protected    += res.protected;
    score.waste        += res.waste;
  }
}

# Load an event log.
#   skip_ahead_until - skip from last event to this time : double (epoch)
#                      fast forward from skip_ahead_until
#                      to current time.
#    x < last event    - fast forward all the way to current time (use 0).
#                        NOTE: Can be VERY time consuming.
#     -1               - skip to current time.
var load_event_log = func (filename, skip_ahead_until) {
  CAFire.load_event_log(filename, skip_ahead_until);
}

# Save an event log.
#
var save_event_log = func (filename) {
  CAFire.save_event_log(filename);
}

# Print current score summary.
var print_score = func {
  print("Wildfire drop summary: #extinguished cells: " ~ score.extinguished ~
        " #protected cells: " ~ score.protected ~
        " #wasted: " ~ score.waste);
  print("Wildfire fire summary: #created cells: " ~ CAFire.cells_created ~
        " #cells still burning: " ~ CAFire.cells_burning);
}

###############################################################################
# Internals.
###############################################################################

var msg_channel_mpp = "environment/wildfire/data";
var broadcast = nil;
var seq = 0;
# Configuration properties
var CA_enabled_pp         = "environment/wildfire/enabled";
var MP_share_pp           = "environment/wildfire/share-events";
var save_on_exit_pp       = "environment/wildfire/save-on-exit";
var restore_on_startup_pp = "environment/wildfire/restore-on-startup";
var crash_fire_pp         = "environment/wildfire/fire-on-crash";
var impact_fire_pp        = "environment/wildfire/fire-on-impact";
var report_score_pp       = "environment/wildfire/report-score";
var event_file_pp         = "environment/wildfire/events-file";
var time_hack_pp          = "environment/wildfire/time-hack-gmt";
#                           Format: "yyyy:mm:dd:hh:mm:ss"
# Internal properties to control the models
var models_enabled_pp     = "environment/wildfire/models/enabled";
var fire_LOD_pp           = "environment/wildfire/models/fire-lod";
var smoke_LOD_pp          = "environment/wildfire/models/smoke-lod";
var LOD_High = 20;
var LOD_Low  = 50;
var mp_last_limited_event = {}; # source : time

var score = { extinguished : 0, protected : 0, waste : 0 };
var old_score = { extinguished : 0, protected : 0, waste : 0 };

###############################################################################
# Utility functions.
var score_report_loop = func {
  if ((score.extinguished > old_score.extinguished) or
      (score.protected > old_score.protected)) {
    if (getprop(report_score_pp)) {
      setprop("/sim/messages/copilot",
              "Extinguished " ~ (score.extinguished - old_score.extinguished) ~
              " fire cells.");
    }
    old_score.extinguished = score.extinguished;
    old_score.protected    = score.protected;
    old_score.waste        = score.waste;
  } else {
    if (getprop(report_score_pp) and (score.waste > old_score.waste))
      setprop("/sim/messages/copilot",
              "Miss!");
    old_score.extinguished = score.extinguished;
    old_score.protected    = score.protected;
    old_score.waste        = score.waste;
  }
  settimer(score_report_loop, CAFire.GENERATION_DURATION);
}

###############################################################################
# MP messages

var ignition_msg = func (pos) {
  seq += 1;
  return Binary.encodeInt(seq) ~ Binary.encodeByte(1) ~
      Binary.encodeCoord(pos);
}

var water_drop_msg = func (pos, radius, volume) {
  seq += 1;
  return Binary.encodeInt(seq) ~ Binary.encodeByte(2) ~
      Binary.encodeCoord(pos) ~ Binary.encodeDouble(radius);
}

var retardant_drop_msg = func (pos, radius, volume) {
  seq += 1;
  return Binary.encodeInt(seq) ~ Binary.encodeByte(3) ~
      Binary.encodeCoord(pos) ~ Binary.encodeDouble(radius);
}

var foam_drop_msg = func (pos, radius, volume) {
  seq += 1;
  return Binary.encodeInt(seq) ~ Binary.encodeByte(4) ~
      Binary.encodeCoord(pos) ~ Binary.encodeDouble(radius);
}

var parse_msg = func (source, msg) {
  if (!getprop(MP_share_pp) or !getprop(CA_enabled_pp)) return;
  var cur_time = systime();
  var type = Binary.decodeByte(substr(msg, 5));
  if (type == 1) {
    var i = source.getIndex();
    if (!contains(mp_last_limited_event, i) or
        (cur_time - mp_last_limited_event[i]) > 1/MAX_IGNITE_RATE) {
      var pos = Binary.decodeCoord(substr(msg, 6));
      ignite(pos, 0);
    } else {
      printlog("alert", "wildfire.nas: Ignored ignite event flood from " ~
               source.getNode("callsign").getValue());
    }
    mp_last_limited_event[i] = cur_time;
  }
  if (type == 2) {
    var pos    = Binary.decodeCoord(substr(msg, 6));
    var radius = Binary.decodeDouble(substr(msg, 36));
    resolve_water_drop(pos, radius, 0, 0);
  }
  if (type == 3) {
    var pos    = Binary.decodeCoord(substr(msg, 6));
    var radius = Binary.decodeDouble(substr(msg, 36));
    resolve_retardant_drop(pos, radius, 0, 0);
  }
  if (type == 4) {
    var pos    = Binary.decodeCoord(substr(msg, 6));
    var radius = Binary.decodeDouble(substr(msg, 36));
    resolve_foam_drop(pos, radius, 0, 0);
  }
}

###############################################################################
# Simulation time management.
# NOTE: Time warp is ignored for the time being.

var SimTime = {
############################################################
  init : func {
    # Sim time is me.real_time_base + warp + sim-elapsed-sec
    me.real_time_base = systime();
    me.elapsed_time   = props.globals.getNode("/sim/time/elapsed-sec");
  },
  current_time : func {
    return me.real_time_base + me.elapsed_time.getValue();
  }
};


###############################################################################
#  Class that maintains the state of one fire cell.
var FireCell = {
############################################################
  new : func (x, y) {
    trace("Creating FireCell[" ~ x ~ "," ~ y ~ "]");
    var m = { parents: [FireCell] };
    m.lat = y * CAFire.CELL_SIZE/60.0 + 0.5 * CAFire.CELL_SIZE / 60.0;
    m.lon = x * CAFire.CELL_SIZE/60.0 + 0.5 * CAFire.CELL_SIZE / 60.0;
    m.x   = x;
    m.y   = y;
    m.state      = [0.0, 0.0];   # burned area / total area.
    m.burning    = [0, 0];       # {0,1} Not intensity but could become, maybe
    m.last       = 0;            # Last update generation.

    # Fetch ground type.
    var geo_info = geodinfo(m.lat, m.lon);
    if ((geo_info == nil) or (geo_info[1] == nil) or
        (geo_info[1].names == nil)) return nil;
    m.alt        = geo_info[0];
    m.burn_rate  = 0.0;
    foreach (var mat; geo_info[1].names) {
      trace("Material: " ~ mat);
      if (CAFire.BURN_RATE[mat] != nil) {
        if (CAFire.BURN_RATE[mat] > m.burn_rate)
          m.burn_rate = CAFire.BURN_RATE[mat];
      }
    }
    CAFireModels.add(x, y, m.alt);
    append(CAFire.active, m);
    CAFire.cells_created += 1;
    return m;
  },
############################################################
  ignite : func {
    if ((me.state[CAFire.old] < 1) and (me.burn_rate > 0)) {
      trace("FireCell[" ~ me.x ~ "," ~me.y ~ "] Ignited!");
      me.burning[CAFire.next] = 1;
      me.burning[CAFire.old]  = 1;
      CAFireModels.set_type(me.x, me.y, "fire");
      # Prevent update() on this cell in this generation.
      me.last = CAFire.generation;
    } else {
      trace("FireCell[" ~ me.lat ~ "," ~me.lon ~ "] Failed to ignite!");
    }
  },
############################################################
  extinguish : func (type="soot") {
    trace("FireCell[" ~ me.x ~ "," ~ me.y ~ "] extinguished.");
    var result = 0;
    if (me.burning[CAFire.old]) result = 1;
    if (me.burn_rate == 0) result = -1; # A waste to protect this cell.

    if (me.state[CAFire.next] > 1) me.state[CAFire.next] = 1;
    me.burning[CAFire.next] = 0;
    me.burn_rate            = 0; # This cell is nonflammable now.
    # Prevent update() on this cell in this generation.
    me.last = CAFire.generation;
    if ((me.state[CAFire.old] > 0.0) and (me.burning[CAFire.old] > 0)) {
      CAFireModels.set_type(me.x, me.y, "soot");
    } else {
      # Use a model representing contamination here.
      CAFireModels.set_type(me.x, me.y, type);
    }
    return result;
  },
############################################################
  update : func () {
    trace("FireCell[" ~ me.x ~ "," ~me.y ~ "] " ~ me.state[CAFire.old]);
    if ((me.state[CAFire.old] == 1) and (me.burning[CAFire.old] == 0))
      return 0;
    if ((me.burn_rate == 0) and (me.burning[CAFire.old] == 0))
      return 0;
    if (me.last >= CAFire.generation) return 1; # Some event has happened here.
    me.last = CAFire.generation;

    me.state[CAFire.next] = me.state[CAFire.old] +
      (me.burning[CAFire.old] * me.burn_rate +
       me.get_neighbour_burn((me.state[CAFire.old] > CAFire.IGNITE_THRESHOLD))
       ) * CAFire.GENERATION_DURATION;

    if ((me.burning[CAFire.old] == 0) and
        (0 < me.state[CAFire.next]) and (me.state[CAFire.old] < 1)) {
      me.ignite();
      return 1;
    }
    if (me.state[CAFire.next] >= 1) {
      me.extinguish("soot");
      return 0;
    }
    if (me.burn_rate == 0) {
      # Does this make sense?
      me.extinguish("protected");
      return 0;
    }
    me.burning[CAFire.next] = me.burning[CAFire.old];
    CAFireModels.set_type(me.x, me.y, me.burning[CAFire.old] ? "fire" : "soot");
    return 1;
  },
############################################################
# Get neightbour burn values.
  get_neighbour_burn : func (create) {
    var burn = 0.0;
    foreach (var d; CAFire.NEIGHBOURS[0]) {
      var c = CAFire.get_cell(me.x + d[0], me.y + d[1]);
      if (c != nil) {
        burn += c.burning[CAFire.old] * c.burn_rate *
                (5*me.alt / c.alt) *
                c.state[CAFire.old] * CAFire.GENERATION_DURATION;
      } else {
        if (create) {
          # Create the neighbour.
          CAFire.set_cell(me.x + d[0], me.y + d[1],
                          FireCell.new(me.x + d[0],
                                       me.y + d[1]));
        }
      }
    }
    foreach (var d; CAFire.NEIGHBOURS[1]) {
      var c = CAFire.get_cell(me.x + d[0], me.y + d[1]);
      if (c != nil) {
        burn += 0.785 * c.burning[CAFire.old] * c.burn_rate *
                (5*me.alt / c.alt) *
                c.state[CAFire.old] * CAFire.GENERATION_DURATION;
      } else {
        if (create) {
          # Create the neighbour.
          CAFire.set_cell(me.x + d[0], me.y + d[1],
                          FireCell.new(me.x + d[0],
                                       me.y + d[1]));
        }
      }
    }
    return burn;
  },
############################################################
};

###############################################################################
#  Class that maintains the 3d model(s) for one fire cell.
var CellModel = {
############################################################
    new : func (x, y, alt) {
        var m = { parents: [CellModel] };
        m.type  = "none";
        m.model = nil;
        m.lat = y * CAFire.CELL_SIZE/60.0 + 0.5 * CAFire.CELL_SIZE / 60.0;
        m.lon = x * CAFire.CELL_SIZE/60.0 + 0.5 * CAFire.CELL_SIZE / 60.0;
        m.x   = x;
        m.y   = y;
        m.alt = alt + 0.1;
        return m;
    },
############################################################
    set_type : func(type) {
        if (me.model != nil) {
            if (me.type == type) return;
            me.model.remove();
            me.model = nil;
        }
        me.type = type;
        if (CAFireModels.MODEL[type] == "") return;

        # Always put "cheap" models for now.
        if (CAFireModels.models_enabled or (type != "fire")) {
            me.model =
                geo.put_model(CAFireModels.MODEL[type], me.lat, me.lon, me.alt);
            trace("Created 3d model " ~ type ~ " " ~ CAFireModels.MODEL[type]);
        }
    },
############################################################
    remove : func() {
        if (me.model != nil) me.model.remove();
        me.model = nil;
    }
############################################################
};

###############################################################################
#  Singleton that maintains the CA models.
var CAFireModels = {};
# Constants
CAFireModels.MODEL = {         # Model paths
    "fire"                   : "Models/Effects/Wildfire/wildfire.xml",
    "soot"                   : "Models/Effects/Wildfire/soot.xml",
    "foam"                   : "Models/Effects/Wildfire/foam.xml",
    "water"                  : "",
    "retardant"              : "Models/Effects/Wildfire/retardant.xml",
    "protected"              : "",
    "none"                   : "",
};
# State
CAFireModels.grid = {};        # Sparse cell model grid storage.
CAFireModels.pending = [];     # List of pending model changes.
CAFireModels.models_enabled = 1;
CAFireModels.loopid = 0;
######################################################################
# Public operations
############################################################
CAFireModels.init = func {
  # Initialization.
  setlistener(models_enabled_pp, func (n) {
    me.set_models_enabled(n.getValue());
  }, 1);
  me.reset(1);
}
############################################################
# Reset the model grid to the empty state.
CAFireModels.reset = func (enabled) {
  # Clear the model grid.
  foreach (var x; keys(me.grid)) {
    foreach (var y; keys(me.grid[x])) {
      if (me.grid[x][y] != nil) me.grid[x][y].remove();
    }
  }
  # Reset state.
  me.grid = {};
  me.pending = [];

  if (enabled) {
    me.start();
  }
}
############################################################
# Start the CA model grid.
CAFireModels.start = func {
  me.loopid += 1;
  me._loop_(me.loopid);
}
############################################################
# Stop the CA model grid.
# Note that it will catch up lost time when started again.
CAFireModels.stop = func {
  me.loopid += 1;
}
############################################################
# Add a new cell model.
CAFireModels.add = func(x, y, alt) {
  append(me.pending, { x: x, y: y, alt: alt });
}
############################################################
# Update a cell model.
CAFireModels.set_type = func(x, y, type) {
  append(me.pending, { x: x, y: y, type: type });
}
############################################################
CAFireModels.set_models_enabled = func(on=1) {
  me.models_enabled = on;
  # We should do a pass over all cells here to add/remove models.
  # For now I don't so only active cells will actually remove the
  # models. All models will be hidden by their select animations, though.
}
######################################################################
# Private operations
############################################################
CAFireModels.update = func {
  var work =  size(me.pending)/10;
  while (size(me.pending) > 0 and work > 0) {
    var c = me.pending[0];
    me.pending = subvec(me.pending, 1);
    work -= 1;
    if (contains(c, "alt")) {
      if (me.grid[c.x] == nil) {
        me.grid[c.x] = {};
      }
      me.grid[c.x][c.y] = CellModel.new(c.x, c.y, c.alt);
    }
    if (contains(c, "type")) {
      me.grid[c.x][c.y].set_type(c.type);
    }
  }
}
############################################################
CAFireModels._loop_ = func(id) {
  id == me.loopid or return;
  me.update();
  settimer(func { me._loop_(id); }, 0);
}
###############################################################################

###############################################################################
#  Singleton that maintains the fire cell CA grid.
var CAFire = {};
# State
CAFire.CELL_SIZE = 0.03; # "nm" (or rather minutes)
CAFire.GENERATION_DURATION = 4.0; # seconds
CAFire.PASSES = 8.0;     # Passes per full update.
CAFire.IGNITE_THRESHOLD = 0.3; # Minimum cell state for igniting neighbours.
CAFire.grid = {};        # Sparse cell grid storage.
CAFire.generation = 0;   # CA generation. Defined from the epoch.
CAFire.enabled = 0;
CAFire.active = [];      # List of active cells. These will be updated.
CAFire.old  = 0;         # selects new/old cell state.
CAFire.next = 1;         # selects new/old cell state.
CAFire.cells_created = 0;
CAFire.cells_burning = 0;
CAFire.pass = 0;         # Update pass within the current full update.
CAFire.pass_work = 0;    # Cells to update in each pass.
CAFire.remaining_work = []; # Work remaining in this full update.
CAFire.loopid = 0;
CAFire.event_log = [];   # List of all events that has occured so far.
CAFire.load_count = 0;
CAFire.BURN_RATE = {     # Burn rate DB. grid widths per second
# Grass
    "Grass"                 : 0.0010,
    "grass_rwy"             : 0.0010,
    "ShrubGrassCover"       : 0.0010,
    "ScrubCover"            : 0.0010,
    "BareTundraCover"       : 0.0010,
    "MixedTundraCover"      : 0.0010,
    "HerbTundraCover"       : 0.0010,
    "MixedCropPastureCover" : 0.0010,
    "DryCropPastureCover"   : 0.0010,
    "CropGrassCover"        : 0.0010,
    "CropWoodCover"         : 0.0010,
# Forest
    "DeciduousBroadCover"   : 0.0005,
    "EvergreenBroadCover"   : 0.0005,
    "MixedForestCover"      : 0.0005,
    "EvergreenNeedleCover"  : 0.0005,
    "WoodedTundraCover"     : 0.0005,
    "DeciduousNeedleCover"  : 0.0005,
# City
    "BuiltUpCover"          : 0.0005,
# ?
    "Landmass"              : 0.0005
};
CAFire.NEIGHBOURS =      # Neighbour index offsets. First row and column
                         # and then diagonal.
    [[[-1, 0], [0, 1], [1, 0], [0, -1]],
     [[-1, 1], [1, 1], [1, -1], [-1, -1]]];
######################################################################
# Public operations
############################################################
CAFire.init = func {
  # Initialization.
  me.reset(1, SimTime.current_time());
}
############################################################
# Reset the CA to the empty state and set its current time to sim_time.
CAFire.reset = func (enabled, sim_time) {
  # Clear the model grid.
  CAFireModels.reset(enabled);
  # Reset state.
  me.grid = {};
  me.generation = int(sim_time/CAFire.GENERATION_DURATION);
  me.active = [];
  me.old  = 0;
  me.next = 1;
  me.cells_created = 0;
  me.cells_burning = 0;
  me.pass = 0;
  me.pass_work = 0;
  me.remaining_work = [];
  me.event_log = [];

  me.enabled = enabled;
  if (me.enabled) {
    me.start();
  } else {
    me.stop();
  }
}
############################################################
# Start the CA.
CAFire.start = func {
  CAFireModels.start();
  broadcast.start();
  me.loopid += 1;
  me._loop_(me.loopid);
}
############################################################
# Stop the CA. Note that it will catch up lost time when started again.
CAFire.stop = func {
  CAFireModels.stop();
  broadcast.stop();
  me.loopid += 1;
}
############################################################
# Start a fire in the cell at pos.
CAFire.ignite = func (lat, lon) {
  trace("CAFire.ignite: Fire at " ~ lat ~", " ~ lon ~ ".");
  var x = int(lon*60/me.CELL_SIZE);
  var y = int(lat*60/me.CELL_SIZE);
  var cell = me.get_cell(x, y);
  if (cell == nil) {
    cell = FireCell.new(x, y);
    me.set_cell(x, y,
                cell);
  }
  if (cell != nil) cell.ignite();
  append(me.event_log, [SimTime.current_time(), "ignite", lat, lon]);
}
############################################################
# Resolve a water drop.
# For now: Assume that water makes the affected cell nonflammable forever
#          and extinguishes it if burning.
#   radius - meter : double
# Note: volume is unused ATM.
CAFire.resolve_water_drop = func (lat, lon, radius, volume=0) {
  trace("CAFire.resolve_water_drop: Dumping water at " ~ lat ~", " ~ lon ~
        " radius " ~ radius ~".");
  var x = int(lon*60/me.CELL_SIZE);
  var y = int(lat*60/me.CELL_SIZE);
  var r = int(2*radius/(me.CELL_SIZE*1852.0));
  var result = { extinguished : 0, protected : 0, waste : 0 };
  for (var dx = -r; dx <= r; dx += 1) {
    for (var dy = -r; dy <= r; dy += 1) {
      var cell = me.get_cell(x + dx, y + dy);
      if (cell == nil) {
        cell = FireCell.new(x + dx, y + dy);
        me.set_cell(x + dx, y + dy,
                    cell);
      }
      if (cell != nil) {
        var res = cell.extinguish("water");
        if (res > 0) {
          result.extinguished += 1;
        } else {
          if (res == 0) result.protected += 1;
          else          result.waste += 1;
        }
      } else {
        result.waste += 1;
      }
    }
  }
  append(me.event_log,
         [SimTime.current_time(), "water_drop", lat, lon, radius]);
  return result;
}
############################################################
# Resolve a fire retardant drop.
# For now: Assume that the retardant makes the affected cell nonflammable
#          forever and extinguishes it if burning.
# Note: volume is unused ATM.
CAFire.resolve_retardant_drop = func (lat, lon, radius, volume=0) {
  trace("CAFire.resolve_retardant_drop: Dumping retardant at " ~
        lat ~", " ~ lon ~ " radius " ~ radius ~".");
  var x = int(lon*60/me.CELL_SIZE);
  var y = int(lat*60/me.CELL_SIZE);
  var r = int(2*radius/(me.CELL_SIZE*1852.0));
  var result = { extinguished : 0, protected : 0, waste : 0 };
  for (var dx = -r; dx <= r; dx += 1) {
    for (var dy = -r; dy <= r; dy += 1) {
      var cell = me.get_cell(x + dx, y + dy);
      if (cell == nil) {
        cell = FireCell.new(x + dx, y + dy);
        me.set_cell(x + dx, y + dy,
                    cell);
      }
      if (cell != nil) {
        var res = cell.extinguish("retardant");
        if (res > 0) {
          result.extinguished += 1;
        } else {
          if (res == 0) result.protected += 1;
          else          result.waste += 1;
        }
      } else {
        result.waste += 1;
      }
    }
  }
  append(me.event_log,
         [SimTime.current_time(), "retardant_drop", lat, lon, radius]);
  return result;
}
############################################################
# Resolve a foam drop.
# For now: Assume that water makes the affected cell nonflammable forever
#          and extinguishes it if burning.
#   radius - meter : double
# Note: volume is unused ATM.
CAFire.resolve_foam_drop = func (lat, lon, radius, volume=0) {
  trace("CAFire.resolve_foam_drop: Dumping foam at " ~ lat ~", " ~ lon ~
        " radius " ~ radius ~".");
  var x = int(lon*60/me.CELL_SIZE);
  var y = int(lat*60/me.CELL_SIZE);
  var r = int(2*radius/(me.CELL_SIZE*1852.0));
  var result = { extinguished : 0, protected : 0, waste : 0 };
  for (var dx = -r; dx <= r; dx += 1) {
    for (var dy = -r; dy <= r; dy += 1) {
      var cell = me.get_cell(x + dx, y + dy);
      if (cell == nil) {
        cell = FireCell.new(x + dx, y + dy);
        me.set_cell(x + dx, y + dy,
                    cell);
      }
      if (cell != nil) {
        var res = cell.extinguish("foam");
        if (res > 0) {
          result.extinguished += 1;
        } else {
          if (res == 0) result.protected += 1;
          else          result.waste += 1;
        }
      } else {
        result.waste += 1;
      }
    }
  }
  append(me.event_log,
         [SimTime.current_time(), "foam_drop", lat, lon, radius]);
  return result;
}
############################################################
# Save the current event log.
# This is modelled on Melchior FRANZ's ac_state.nas.
CAFire.save_event_log = func (filename) {
  var args = props.Node.new({ filename : filename });
  var data = args.getNode("data", 1);

  gui.popupTip("Wildfire: Saving state to " ~ filename);

  var i = 0;
  foreach (var e; me.event_log) {
    var event = data.getNode("event[" ~ i ~ "]", 1);
    event.getNode("time-sec", 1).setDoubleValue(e[0]);
    event.getNode("type", 1).setValue(e[1]);
    event.getNode("latitude", 1).setDoubleValue(e[2]);
    event.getNode("longitude", 1).setDoubleValue(e[3]);
    # Event type specific data.
    if (e[1] == "water_drop")
      event.getNode("radius", 1).setDoubleValue(e[4]);
    if (e[1] == "foam_drop")
      event.getNode("radius", 1).setDoubleValue(e[4]);
    if (e[1] == "retardant_drop")
      event.getNode("radius", 1).setDoubleValue(e[4]);

#    debug.dump(e);
    i += 1;
  }
  # Add save event to aid skip ahead restore.
  var event = data.getNode("event[" ~ i ~ "]", 1);
  event.getNode("time-sec", 1).setDoubleValue(SimTime.current_time());
  event.getNode("type", 1).setValue("save");

  fgcommand("savexml", args);
}
############################################################
# Load an event log.
#   skip_ahead_until - skip from last event to this time : double (epoch)
#                      fast forward from skip_ahead_until
#                      to current time.
#    x < last event    - fast forward all the way to current time (use 0).
#     -1               - skip to current time.
CAFire.load_event_log = func (filename, skip_ahead_until) {
  me.load_count += 1;
  var logbase = "/tmp/wildfire-load-log[" ~ me.load_count ~ "]";
  if (!fgcommand("loadxml",
                 props.Node.new({ filename   : filename,
                                  targetnode : logbase }))) {
    printlog("alert", "Wildfire ... failed loading '" ~ filename ~ "'");
    return;
  }

  # Fast forward the automaton from the first logged event to the current time.
  CAFireModels.set_models_enabled(0);
  var first = 1;
  var events = props.globals.getNode(logbase).getChildren("event");
  foreach (var event; events) {
    if (first) {
      first = 0;
      me.reset(1, event.getNode("time-sec").getValue());
    }
#    print("[" ~
#          event.getNode("time-sec").getValue() ~ "," ~
#          event.getNode("type").getValue() ~ "]");
    var e = [event.getNode("time-sec").getValue(),
             event.getNode("type").getValue()];

    # Fast forward state.
    while (me.generation * me.GENERATION_DURATION < e[0]) {
#      print("between event ff " ~ me.generation);
      me.update();
    }
    # Apply event. Note: The logged time is wrong ATM.
    if (event.getNode("type").getValue() == "ignite") {
      me.ignite(event.getNode("latitude").getValue(),
                event.getNode("longitude").getValue());
      me.event_log[size(me.event_log) - 1][0] = e[0];
    }
    if (event.getNode("type").getValue() == "water_drop") {
      me.resolve_water_drop(event.getNode("latitude").getValue(),
                            event.getNode("longitude").getValue(),
                            event.getNode("radius").getValue());
      me.event_log[size(me.event_log) - 1][0] = e[0];
    }
    if (event.getNode("type").getValue() == "foam_drop") {
      me.resolve_foam_drop(event.getNode("latitude").getValue(),
                           event.getNode("longitude").getValue(),
                           event.getNode("radius").getValue());
      me.event_log[size(me.event_log) - 1][0] = e[0];
    }
    if (event.getNode("type").getValue() == "retardant_drop") {
      me.resolve_retardant_drop(event.getNode("latitude").getValue(),
                                event.getNode("longitude").getValue(),
                                event.getNode("radius").getValue());
      me.event_log[size(me.event_log) - 1][0] = e[0];
    }
  }
  if (first) {
    me.reset(1, SimTime.current_time());
    return;
  }

  var now = SimTime.current_time();
  if (skip_ahead_until == -1) {
    me.generation = int(now/me.GENERATION_DURATION);
  } else {
    if (me.generation < int(skip_ahead_until/me.GENERATION_DURATION)) {
      me.generation = int(skip_ahead_until/me.GENERATION_DURATION);
    }
    # Catch up with current time. NOTE: This can be very time consuming!
    while (me.generation * me.GENERATION_DURATION < now)
      me.update();
  }
  CAFireModels.set_models_enabled(getprop(models_enabled_pp));
}
######################################################################
# Internal operations
CAFire.get_cell = func (x, y) {
  if (me.grid[x] == nil) me.grid[x] = {};
  return me.grid[x][y];
}
############################################################
CAFire.set_cell = func (x, y, cell) {
  if (me.grid[x] == nil) {
    me.grid[x] = {};
  }
  me.grid[x][y] = cell;
}
############################################################
CAFire.update = func {
  if (!me.enabled) return; # The CA is disabled.
  if (me.pass == me.PASSES) {
    # Setup a new main iteration.
    me.generation += 1;
    me.pass = 0;
    me.remaining_work = me.active;
    me.active = [];
    me.pass_work = size(me.remaining_work)/ me.PASSES + 1;
    if (me.old == 1) {
      me.old  = 0;
      me.next = 1;
    } else {
      me.old  = 1;
      me.next = 0;
    }
    if (me.cells_burning > 0) {
      printlog("info",
               "Wildfire: generation " ~ me.generation ~ " updating " ~
               size(me.remaining_work) ~" / " ~ me.cells_created ~
               " created cells. " ~ me.cells_burning ~ " burning cells.");
    }
    # Set LOD.
    if (LOD_Low <= me.cells_burning) {
      props.globals.getNode(fire_LOD_pp).setIntValue(1);
      props.globals.getNode(smoke_LOD_pp).setIntValue(1);
    }
    if ((LOD_High <= me.cells_burning) and (me.cells_burning < LOD_Low)) {
      props.globals.getNode(fire_LOD_pp).setIntValue(5);
      props.globals.getNode(smoke_LOD_pp).setIntValue(5);
    }
    if (me.cells_burning < LOD_High) {
      props.globals.getNode(fire_LOD_pp).setIntValue(10);
      props.globals.getNode(smoke_LOD_pp).setIntValue(10);
    }
    me.cells_burning = 0;
  }

  me.pass += 1;

  var work = me.pass_work;
  var c = pop(me.remaining_work);
  while (c != nil) {
    if (c.update() != 0) {
      append(me.active, c);
      me.cells_burning += c.burning[me.next];
    }
    work -= 1;
    if (work <= 0) return;
    c = pop(me.remaining_work);
  }
}
############################################################
CAFire._loop_ = func(id) {
  id == me.loopid or return;
  me.update();
  settimer(func { me._loop_(id); },
           me.GENERATION_DURATION * (me.generation + 1/me.PASSES) -
           SimTime.current_time());
}
###############################################################################

###############################################################################
# Main initialization.
var Binary = nil;

_setlistener("/sim/signals/nasal-dir-initialized", func {

  Binary = mp_broadcast.Binary;

  # Create configuration properties if they don't exist already.
  props.globals.initNode(CA_enabled_pp, 1, "BOOL");
  setlistener(CA_enabled_pp, func (n) {
    if (getprop("/sim/signals/reinit")) return; # Ignore resets.
    CAFire.reset(n.getValue(), SimTime.current_time());
  });
  props.globals.initNode(MP_share_pp, 1, "BOOL");
  props.globals.initNode(crash_fire_pp, 1, "BOOL");
  props.globals.initNode(impact_fire_pp, 1, "BOOL");
  props.globals.initNode(save_on_exit_pp, 0, "BOOL");
  props.globals.initNode(restore_on_startup_pp, 0, "BOOL");
  props.globals.initNode(models_enabled_pp, 1, "BOOL");
  props.globals.initNode(report_score_pp, 1, "BOOL");
  props.globals.initNode(event_file_pp, "", "STRING");
  props.globals.initNode(time_hack_pp, "", "STRING");

  props.globals.initNode(fire_LOD_pp, 10, "INT");
  props.globals.initNode(smoke_LOD_pp, 10, "INT");

  SimTime.init();
  broadcast =
    mp_broadcast.BroadcastChannel.new(msg_channel_mpp, parse_msg);
  CAFire.init();

  # Start the score reporting.
  settimer(score_report_loop, CAFire.GENERATION_DURATION);

  setlistener("/sim/signals/exit", func {
    if (getprop(report_score_pp) and (CAFire.cells_created > 0))
      print_score();
    if (getprop(save_on_exit_pp))
      CAFire.save_event_log(SAVEDIR ~ "fire_log.xml");
  });

  # Determine the skip-ahead-to time, if any.
  var time_hack = time_string_to_epoch(getprop(time_hack_pp));
  if (time_hack > SimTime.current_time()) {
    printlog("alert",
             "wildfire.nas: Ignored time hack " ~
             (SimTime.current_time() - time_hack) ~
             " seconds into the future.");
    # Skip ahead to current time instead.
    time_hack = -1;
  } elsif (time_hack > 0) {
    printlog("alert",
             "wildfire.nas: Time hack " ~
             (SimTime.current_time() - time_hack) ~
             " seconds ago.");
  } else {
    # Skip ahead to current time instead.
    time_hack = -1;
  }

  if (getprop(event_file_pp) != "") {
    settimer(func {
      # Delay loading the log until the terrain is there. Note: hack.
      CAFire.load_event_log(getprop(event_file_pp), time_hack);
    }, 3);      
  } elsif (getprop(restore_on_startup_pp)) {
    settimer(func {
      # Delay loading the log until the terrain is there. Note: hack.
      # Restore skips ahead to current time.
      CAFire.load_event_log(SAVEDIR ~ "fire_log.xml", -1);
    }, 3);
  }

  # Detect aircraft crash.
  setlistener("sim/crashed", func(n) {
    if (getprop(crash_fire_pp) and n.getBoolValue())
      wildfire.ignite(geo.aircraft_position());
  });

  # Detect impact.
  var impact_node = props.globals.getNode("sim/ai/aircraft/impact/bomb", 1);
  setlistener("sim/ai/aircraft/impact/bomb", func(n) {

    if (getprop(impact_fire_pp) and n.getBoolValue()){
       var node = props.globals.getNode(n.getValue(), 1);
       var impactpos = geo.Coord.new();
       impactpos.set_latlon
         (node.getNode("impact/latitude-deg").getValue(),
          node.getNode("impact/longitude-deg").getValue());
       wildfire.ignite(impactpos);
    }

  });

  printlog("info", "Wildfire ... initialized.");
});
###############################################################################

###############################################################################
# Utility functions

# Convert a time string in the format yyyy[:mm[:dd[:hh[:mm[:ss]]]]]
# to seconds since 1970:01:01:00:00:00.
#
# Note: This is an over simplified approximation.
var time_string_to_epoch = func (time) {
  var res = [];
  if      (string.scanf(time, "%d:%d:%d:%d:%d:%d", var res1 = []) != 0) {
    res = res1;
  } elsif (string.scanf(time, "%d:%d:%d:%d:%d", var res2 = []) != 0) {
    res = res2 ~ [0];
  } elsif (string.scanf(time, "%d:%d:%d:%d", var res3 = []) != 0) {
    res = res3 ~ [0, 0];
  } elsif (string.scanf(time, "%d:%d:%d", var res4 = []) != 0) {
    res = res4 ~ [0, 0, 0];
  } elsif (string.scanf(time, "%d:%d", var res5 = []) != 0) {
    res = res5 ~ [0, 0, 0, 0];
  } elsif (string.scanf(time, "%d", var res6 = []) != 0) {
    res = res6 ~ [0, 0, 0, 0, 0];
  } else {
    return -1;
  }
  return
    (res[0] - 1970) * 3.15569e7 +
    (res[1] - 1) * 2.63e+6 +
    (res[2] - 1) * 86400 +
    res[3] * 3600 +
    res[4] * 60 +
    res[5];
}


###############################################################################
## WildFire configuration dialog.
## Partly based on Till Bush's multiplayer dialog

var CONFIG_DLG = 0;

var dialog = {
#################################################################
    init : func (x = nil, y = nil) {
        me.x = x;
        me.y = y;
        me.bg = [0, 0, 0, 0.3];    # background color
        me.fg = [[1.0, 1.0, 1.0, 1.0]];
        #
        # "private"
        me.title = "Wildfire";
        me.basenode = props.globals.getNode("/environment/wildfire");
        me.dialog = nil;
        me.namenode = props.Node.new({"dialog-name" : me.title });
        me.listeners = [];
    },
#################################################################
    create : func {
        if (me.dialog != nil)
            me.close();

        me.dialog = gui.Widget.new();
        me.dialog.set("name", me.title);
        if (me.x != nil)
            me.dialog.set("x", me.x);
        if (me.y != nil)
            me.dialog.set("y", me.y);

        me.dialog.set("layout", "vbox");
        me.dialog.set("default-padding", 0);
        var titlebar = me.dialog.addChild("group");
        titlebar.set("layout", "hbox");
        titlebar.addChild("empty").set("stretch", 1);
        titlebar.addChild("text").set("label", "Wildfire settings");
        titlebar.addChild("empty").set("stretch", 1);
        var w = titlebar.addChild("button");
        w.set("pref-width", 16);
        w.set("pref-height", 16);
        w.set("legend", "");
        w.set("default", 0);
        w.setBinding("nasal", "wildfire.dialog.destroy(); ");
        w.setBinding("dialog-close");
        me.dialog.addChild("hrule");

        var content = me.dialog.addChild("group");
        content.set("layout", "vbox");
        content.set("halign", "center");
        content.set("default-padding", 5);

        foreach (var b; [["Enabled", CA_enabled_pp],
                         ["Share over MP", MP_share_pp],
                         ["Show 3d models", models_enabled_pp],
                         ["Crash starts fire", crash_fire_pp],
                         ["Impact starts fire", impact_fire_pp],
                         ["Report score", report_score_pp],
                         ["Save on exit", save_on_exit_pp]]) {
            var w = content.addChild("checkbox");
            w.node.setValues({"label"    : b[0],
                              "halign"   : "left",
                              "property" : b[1]});
            w.setBinding("nasal",
                         "setprop(\"" ~ b[1] ~ "\"," ~
                         "!getprop(\"" ~ b[1] ~ "\"))");
        }
        me.dialog.addChild("hrule");

        # Buttons
        var buttons = me.dialog.addChild("group");
        buttons.node.setValues({"layout"  : "hbox"});

        # Load button.
        var load = buttons.addChild("button");
        load.node.setValues({"legend"    : "Load Wildfire log",
                              "halign"   : "center"});
        load.setBinding("nasal",
                        "wildfire.dialog.select_and_load()");

        # Close button
        var close = buttons.addChild("button");
        close.node.setValues({"legend"    : "Close",
                             "default"   : "true",
                             "key"       : "Esc"});
        close.setBinding("nasal", "wildfire.dialog.destroy();");
        close.setBinding("dialog-close");

        fgcommand("dialog-new", me.dialog.prop());
        fgcommand("dialog-show", me.namenode);
    },
#################################################################
    close : func {
        fgcommand("dialog-close", me.namenode);
    },
#################################################################
    destroy : func {
        CONFIG_DLG = 0;
        me.close();
        foreach(var l; me.listeners)
            removelistener(l);
        delete(gui.dialog, "\"" ~ me.title ~ "\"");
    },
#################################################################
    show : func {
        if (!CONFIG_DLG) {
            CONFIG_DLG = 1;
            me.init();
            me.create();
        }
    },
#################################################################
    select_and_load : func {
        var selector = gui.FileSelector.new
            (func (n) { load_event_log(n.getValue(), -1); },
             "Load Wildfire log",                    # dialog title
             "Load",                                 # button text
             ["*.xml"],                              # pattern for files
             SAVEDIR,                                # start dir
             "fire_log.xml");                        # default file name
        selector.open();
    }
}
###############################################################################
