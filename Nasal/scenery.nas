###############################################################################
##
##  Support tools for multiplayer enabled scenery objects.
##
##  Copyright (C) 2011 - 2013  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# The event channel for scenery objects.
# See mp_broadcast.EventChannel for documentation.
var events = nil;

###############################################################################
# An extended aircraft.door that transmits the door events over MP using the
# scenery.events channel.
# Use only for single instance objects (e.g. static scenery objects).
#
# Note: Currently toggle() is the only shared event.
var sharedDoor = {
    new: func(node, swingtime, pos = 0) {
        var obj = aircraft.door.new(node, swingtime, pos);
        obj.parents    = [sharedDoor] ~ obj.parents;
        obj.event_hash = mp_broadcast.Binary.stringHash
            (isa(node, props.Node) ? node.getPath() : node);
        obj.clock      = mp_broadcast.LamportClock.new();
        obj.loopid     = 0;
        events.register(obj.event_hash,
                        func (sender, msg) { obj._process(sender, msg) });
        return obj;
    },
    toggle: func {
        # Send current time, current position and target position.
        me.clock.advance();
        me.move(me.target);
        me._loop(me.loopid += 1);
    },
    destroy : func {
        me.loopid += 1;
        events.deregister(me.event_hash);
    },
    _process : func (sender, msg) {
        if (me.clock.merge(sender, msg)) {
            me.setpos(mp_broadcast.Binary.decodeDouble
                      (substr(msg, mp_broadcast.Binary.sizeOf["LamportTS"])));
            me.target = mp_broadcast.Binary.decodeByte
                (substr(msg,
                        mp_broadcast.Binary.sizeOf["LamportTS"] +
                        mp_broadcast.Binary.sizeOf["double"]));
            me.move(me.target);
        }
    },
    _loop : func (id) {
        id == me.loopid or return;
        # Send current time, current position and target position.
        events.send(me.event_hash,
                    me.clock.timestamp() ~
                    mp_broadcast.Binary.encodeDouble(me.positionN.getValue()) ~
                    mp_broadcast.Binary.encodeByte(!me.target));
        settimer(func { me._loop(id); }, 17, 1);
    }
};

###############################################################################
# Internals
var shared_pp = "scenery/share-events";

var _set_state = func {
    if (getprop("/sim/signals/reinit")) return; # Ignore resets.
    if (getprop(shared_pp)) {
        #print("scenery.nas: starting event sharing.");
        events.start();
    } else {
        #print("scenery.nas: stopping event sharing.");
        events.stop();
    }

}

_setlistener("sim/signals/nasal-dir-initialized", func {
    events = mp_broadcast.EventChannel.new("scenery/events");
    if (getprop(shared_pp)) {
        #print("scenery.nas: starting event sharing.");
        events.start();
    } else {
        #print("scenery.nas: stopping event sharing.");
        events.stop();
    }
    setlistener(shared_pp, _set_state);
});
