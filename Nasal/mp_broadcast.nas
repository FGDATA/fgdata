###############################################################################
##
##  A message based information broadcast for the multiplayer network.
##
##  Copyright (C) 2008 - 2013  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

###############################################################################
# Event broadcast channel using a MP enabled string property.
# Events from users in multiplayer.ignore are ignored.
#
# EventChannel.new(mpp_path)
#   Create a new event broadcast channel. Any MP user with the same
#   primitive will receive all messages sent to the channel from the point
#   she/he joined (barring severe MP packet loss).
#   NOTE: Message delivery is not guaranteed.
#     mpp_path - MP property path                        : string
#
# EventChannel.register(event_hash, handler)
#   Register a handler for the event identified by the hash event_hash.
#     event_hash - hash value for the event : a unique 4 character string
#     handler    - a handler function for the event : func (sender, msg)
#
# EventChannel.deregister(event_hash)
#   Deregister the handler for the event identified by the hash event_hash.
#     event_hash - hash value for the event : a unique 4 character string
#
# EventChannel.send(event_hash, msg)
#   Sends the event event_hash with the message msg to the channel.
#     event_hash - hash value for the event : a unique 4 character string
#     msg        - text string with Binary data encoded data : string
#
# EventChannel.die()
#   Destroy this EventChannel instance.
#
var EventChannel = {};
EventChannel.new = func (mpp_path) {
  var obj = BroadcastChannel.new(mpp_path,
                                 func (n, msg) { obj._process(n, msg) });
  # Save send from being overriden.
  obj.parent_send = obj.send;
  # Put EventChannel methods before BroadcastChannel methods.
  obj.parents = [EventChannel] ~ obj.parents;
  obj.events  = {};
  return obj;
}
EventChannel.register = func (event_hash,
                              handler) {
  me.events[event_hash] = handler;
}
EventChannel.deregister = func (event_hash) {
  delete(me.events, event_hash);
}
EventChannel.send = func (event_hash,
                          msg) {
  me.parent_send(event_hash ~ msg);
}
############################################################
# Internals.
EventChannel._process = func (n, msg) {
  var event_hash = Binary.readHash(msg);
  if (contains(me.events, event_hash)) {
    me.events[event_hash](n, substr(msg, Binary.sizeOf["Hash"]));
  }
}

###############################################################################
# Broadcast primitive using a MP enabled string property.
# Broadcasts from users in multiplayer.ignore are ignored.
#
# BroadcastChannel.new(mpp_path, process)
#   Create a new broadcast primitive. Any MP user with the same
#   primitive will receive all messages sent to the channel from the point
#   she/he joined (barring severe MP packet loss).
#   NOTE: Message delivery is not guaranteed.
#     mpp_path - MP property path                        : string
#     process  - handler called when receiving a message : func (n, msg)
#                n is the base node of the senders property tree
#                (i.e. /ai/models/multiplay[x])
#     send_to_self - if 1 locally sent messages are      : int {0,1}
#                    delivered just like remote messages.
#                    If 0 locally sent messages are not delivered
#                    to the local receiver.
#     accept_predicate - function to select which        : func (p)
#                        multiplayers to listen to.
#                        p is the multiplayer entry node.
#                        The default is to accept any multiplayer.
#     on_disconnect - function to be called when an      : func (p)
#                     accepted MP user leaves.
#     enable_send   - Set to 0 to disable sending.
#
# BroadcastChannel.send(msg)
#   Sends the message msg to the channel.
#     msg - text string with Binary data encoded data : string
#
# BroadcastChannel.die()
#   Destroy this BroadcastChannel instance.
#
var BroadcastChannel = {};
BroadcastChannel.new = func (mpp_path, process,
                             send_to_self = 0,
                             accept_predicate = nil,
                             on_disconnect = nil,
                             enable_send=1) {
  var obj = { parents      : [BroadcastChannel],
              mpp_path     : mpp_path,
              send_node    : enable_send ? props.globals.getNode(mpp_path, 1) 
                                         : nil,
              process_msg  : process,
              send_to_self : send_to_self,
              accept_predicate :
                (accept_predicate != nil) ? accept_predicate
                                          : func (p) { return 1; },
              on_disconnect : (on_disconnect != nil) ? on_disconnect
                                                     : func (p) { return; },
              # Internal state.
              started      : 0,    # External state: started/stopped.
              running      : 0,    # Internal state: running or not.
              send_buf     : [],
              peers        : {},
              loopid       : 0,
              last_time    : 0.0,  # For join handling.
              last_send    : 0.0   # For the send queue 
            };
  if (enable_send and (obj.send_node == nil)) {
    printlog("warn",
             "BroadcastChannel invalid send node.");
    return nil;
  }
  setlistener(obj.ONLINE_pp, func {
    obj.set_state();
  });
  obj.start();

  return obj;
}
BroadcastChannel.send = func (msg) {
  if (!me.running or me.send_node == nil)
    return;

  var t = getprop("/sim/time/elapsed-sec");
  if (((t - me.last_send) > me.SEND_TIME) and (size(me.send_buf) == 0)) {
    me.send_node.setValue(msg);
    me.last_send = t;
    if (me.send_to_self) me.process_msg(props.globals, msg);
  } else {
    append(me.send_buf, msg);
  }
}
BroadcastChannel.die = func {
  me.loopid += 1;
  me.started = 0;
  me.running = 0;
  #print("BroadcastChannel[" ~ me.mpp_path ~ "] ...  destroyed.");
}
BroadcastChannel.start = func {
  #print("mp_broadcast.nas: starting channel " ~ me.mpp_path ~ ".");
  me.started = 1;
  me.set_state();
}
BroadcastChannel.stop = func {
  #print("mp_broadcast.nas: stopping channel " ~ me.mpp_path ~ ".");
  me.started = 0;
  me.set_state();
}

############################################################
# Internals.
BroadcastChannel.ONLINE_pp = "/sim/multiplay/online";
BroadcastChannel.PERIOD    = 1.3; 
BroadcastChannel.SEND_TIME = 0.6;
BroadcastChannel.set_state = func {
  if (me.started and getprop(me.ONLINE_pp)) {
    if (me.running) return;
    #print("mp_broadcast.nas: activating channel " ~ me.mpp_path ~ ".");
    me.running = 1;
    me._loop_(me.loopid += 1);
  } else {
    #print("mp_broadcast.nas: deactivating channel " ~ me.mpp_path ~ ".");
    me.running = 0;
    me.loopid += 1;
  }
}
BroadcastChannel.update = func {
  var t = getprop("/sim/time/elapsed-sec");
  var process_msg = me.process_msg;

  # Handled join/leave. This is done more seldom.
  if ((t - me.last_time) > me.PERIOD) {
    var mpplayers =
      props.globals.getNode("/ai/models").getChildren("multiplayer");
    foreach (var pilot; mpplayers) {
      var valid = pilot.getChild("valid");
      if ((valid != nil) and valid.getValue() and
          !contains(multiplayer.ignore,
                    pilot.getChild("callsign").getValue())) {
        if ((me.peers[pilot.getIndex()] == nil) and
            me.accept_predicate(pilot)) {
          me.peers[pilot.getIndex()] =
            MessageChannel.
            new(pilot.getNode(me.mpp_path),
                MessageChannel.new_message_handler(process_msg, pilot));
        }
      } else {
        if (contains(me.peers, pilot.getIndex())) {
          delete(me.peers, pilot.getIndex());
          me.on_disconnect(pilot);
        }
      }
    }
    me.last_time = t;
  }
  # Process new messages.
  foreach (var w; keys(me.peers)) {
    if (me.peers[w] != nil) me.peers[w].update();
  }
  # Check send buffer.
  if (me.send_node == nil) return;

  if ((t - me.last_send) > me.SEND_TIME) {
    if (size(me.send_buf) > 0) {
      me.send_node.setValue(me.send_buf[0]);
      if (me.send_to_self) me.process_msg(props.globals, me.send_buf[0]);
      me.send_buf = subvec(me.send_buf, 1);
      me.last_send = t;
    } else {
      # Nothing new to send. Reset the send property to save bandwidth.
      me.send_node.setValue("");
    }
  }
}
BroadcastChannel._loop_ = func (id) {
  me.running or return;
  id == me.loopid or return;

  #print("mp_broadcast.nas: " ~ me.mpp_path ~ ":" ~ id ~ ".");
  me.update();
  settimer(func { me._loop_(id); }, 0, 1);
}
######################################################################

###############################################################################
# Lamport clock. Useful for creating a total order for events or messages.
# The users' callsigns are used to break ties.
#
# LamportClock.new()
#   Creates a new lamport clock for this user.
#
# LamportClock.merge(sender, sender_timestamp)
#   Merges the timestamp from the sender with the local clock.
#     sender           : base node of the senders property tree
#     sender_timestamp : the timestamp received from the sender.
#   Returns 1 if the local clock was advanced; 0 otherwise.
#
# LamportClock.advance()
#   Advances the local clock one tick.
#
# LamportClock.timestamp()
#   Returns an encoded 4 character long timestamp from the local clock.
#
var LamportClock = {
  # LamportClock.new()
  #   Creates a new lamport clock for this user.
  new : func {
    var obj = {
      parents  : [LamportClock],
      callsign : getprop("/sim/multiplay/callsign"),
      time     : 0
    };
    return obj;
  },
  merge : func (sender, sender_timestamp) {
    var sender_time = Binary.decodeInt28(sender_timestamp);
    if (sender_time > me.time) {
      me.time = sender_time;
      return 1;
    } elsif ((sender_time == me.time) and
             (cmp(sender.getNode("callsign").getValue(), me.callsign) > 0)) {
      return 1;
    } else {
      # The received timestamp is old and should be ignored.
      return 0;
    }
  },
  advance : func {
    me.time += 1;
  },
  timestamp : func {
    return Binary.encodeInt28(me.time);
  }
};


###############################################################################
# Some routines for encoding/decoding values into/from a string. 
# NOTE: MP is picky about what it sends in a string propery.
#       Encode 7 bits as a printable 8 bit character.
var Binary = {};
Binary.TWOTO27 =  134217728;
Binary.TWOTO28 =  268435456;
Binary.TWOTO31 = 2147483648;
Binary.TWOTO32 = 4294967296;
Binary.sizeOf = {};
############################################################
Binary.sizeOf["int"] = 5;
Binary.encodeInt = func (int) {
  var bf = bits.buf(5);
  if (int < 0) int += Binary.TWOTO32;
  var r = int;
  for (var i = 0; i < 5; i += 1) {
    var c = math.mod(r, 128);
    bf[4-i] = c + `A`;
    r = (r - c)/128;
  }
  return bf;
}
############################################################
Binary.decodeInt = func (str) {
  var v = 0;
  var b = 1;
  for (var i = 0; i < 5; i += 1) {
    v += (str[4-i] - `A`) * b;
    b *= 128;
  }
  if (v / Binary.TWOTO31 >= 1) v -= Binary.TWOTO32;
  return int(v);
}
############################################################
# NOTE: This encodes a 7 bit byte.
Binary.sizeOf["byte"] = 1;
Binary.encodeByte = func (int) {
  var bf = bits.buf(1);
  if (int < 0) int += 128;
  bf[0] = math.mod(int, 128) + `A`;
  return bf;
}
############################################################
Binary.decodeByte = func (str) {
  var v = str[0] - `A`;
  if (v / 64 >= 1) v -= 128;
  return int(v);
}
############################################################
# NOTE: This encodes a 28 bit integer.
Binary.sizeOf["int28"] = 4;
Binary.encodeInt28 = func (int) {
  var bf = bits.buf(4);
  if (int < 0) int += Binary.TWOTO32;
  var r = int;
  for (var i = 0; i < 4; i += 1) {
    var c = math.mod(r, 128);
    bf[3-i] = c + `A`;
    r = (r - c)/128;
  }
  return bf;
}
############################################################
Binary.decodeInt28 = func (str) {
  var v = 0;
  var b = 1;
  for (var i = 0; i < 4; i += 1) {
    v += (str[3-i] - `A`) * b;
    b *= 128;
  }
  if (v / Binary.TWOTO27 >= 1) v -= Binary.TWOTO28;
  return int(v);
}
############################################################
# NOTE: This can neither handle huge values nor really tiny.
Binary.sizeOf["double"] = 2*Binary.sizeOf["int"];
Binary.encodeDouble = func (d) {
  return Binary.encodeInt(int(d)) ~
         Binary.encodeInt((d - int(d)) * Binary.TWOTO31);
}
############################################################
Binary.decodeDouble = func (str) {
  return Binary.decodeInt(substr(str, 0)) +
         Binary.decodeInt(substr(str, 5)) / Binary.TWOTO31;
}
############################################################
# Encodes a geo.Coord object.
Binary.sizeOf["Coord"] = 3*Binary.sizeOf["double"];
Binary.encodeCoord = func (coord) {
  return Binary.encodeDouble(coord.lat()) ~
         Binary.encodeDouble(coord.lon()) ~
         Binary.encodeDouble(coord.alt());
}
############################################################
# Decodes an encoded geo.Coord object.
Binary.decodeCoord = func (str) {
  var coord = geo.aircraft_position();
  coord.set_latlon(Binary.decodeDouble(substr(str, 0)),
                   Binary.decodeDouble(substr(str, 10)),
                   Binary.decodeDouble(substr(str, 20)));
  return coord;
}
############################################################
# Encodes a string as a hash value.
Binary.sizeOf["Hash"] = 4;
Binary.stringHash = func (str) {
  var hash = 0;
  for(var i=0; i<size(str); i+=1) {
      hash += math.mod(32*hash + str[i], Binary.TWOTO28-3);
  }
  return substr(Binary.encodeInt(hash), 1, 4);
}
############################################################
# Decodes an encoded geo.Coord object.
Binary.readHash = func (str) {
  return substr(str, 0, Binary.sizeOf["Hash"]);
}
############################################################
Binary.sizeOf["LamportTS"] = 4;
######################################################################

###############################################################################
# Detects incomming messages encoded in a string property.
#   n       - MP source : property node
#   process - action    : func (v)
# NOTE: This is a low level component.
#       The same object is seldom used for both sending and receiving.
var MessageChannel = {};
MessageChannel.new = func (n = nil, process = nil) {
  var obj = { parents     : [MessageChannel],
              node        : n, 
              process_msg : process,
              old         : "" };
  return obj;
}
MessageChannel.update = func {
  if (me.node == nil) return;

  var msg = me.node.getValue();
  if (!streq(typeof(msg), "scalar")) return;

  if ((me.process_msg != nil) and
      !streq(msg, "") and
      !streq(msg, me.old)) {
    me.process_msg(msg);
    me.old = msg;
  }
}
MessageChannel.send = func (msg) {
  me.node.setValue(msg);
}
MessageChannel.new_message_handler = func (handler, arg1) {
  var local_arg1 = arg1; # Disconnect from future changes to arg1.
  return func (msg) { handler(local_arg1, msg) };
};
