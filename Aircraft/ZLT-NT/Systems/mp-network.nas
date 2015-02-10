###############################################################################
##
## Zeppelin NT-07 airship
##
##  Copyright (C) 2007 - 2014  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

var Binary = nil;
var broadcast = nil;
var message_id = nil;
var MOORING_OWNERS = {
    "Aircraft/ZLT-NT/Models/ZLT-NT.xml":         1,
    "Aircraft/ZNP-K/Models/ZNP-K.xml":           1,
    "Aircraft/Nordstern/Models/Nordstern.xml":   1
};

###############################################################################
# Send message wrappers.
var announce_fixed_mooring = func (pos, alt_offset) {
    if (typeof(broadcast) != "hash") return;
    broadcast.send(message_id["place_mooring_mast"] ~
                   Binary.encodeCoord(pos) ~
                   Binary.encodeDouble(alt_offset));
}

###############################################################################
# MP broadcast message handler.
var handle_message = func (sender, msg) {
#    print("Message from "~ sender.getNode("callsign").getValue() ~
#          " size: " ~ size(msg));
#    debug.dump(msg);
    var type = msg[0];
    if (type == message_id["place_mooring_mast"][0]) {
#        print("Airships: Placing mooring mast");
        var pos        =
            Binary.decodeCoord(substr(msg, 1));
        var alt_offset =
            Binary.decodeDouble(substr(msg, 1 + Binary.sizeOf["Coord"]));
#        debug.dump(pos);
        mooring.add_fixed_mooring(pos,
                                  alt_offset,
                                  sender.getPath());
    }
}

###############################################################################
# MP Accept and disconnect handlers.
var listen_to = func (pilot) {
    if (pilot.getNode("sim/model/path") != nil and
        contains(MOORING_OWNERS, pilot.getNode("sim/model/path").getValue())) {
#        print("mp-network.nas: Accepted " ~ pilot.getPath());
        return 1;
    } else {
#        print("mp-network.nas: Rejected " ~ pilot.getPath());
        return 0;
    }
}

var when_disconnecting = func (pilot) {
    mooring.remove_fixed_mooring(pilot.getPath());
}

###############################################################################
# Minimal Airships.mooring replacement.
var remote_mooring = {
    ##################################################
    init : func {
        me.model = {};
        me.model_path = "Aircraft/ZLT-NT/Models/mooring_truck.xml";
    },
    ##################################################
    add_fixed_mooring : func(pos, alt_offset, key) {
        if (me.model[key] != nil) me.model[key].remove();
        me.mast_truck_base = props.globals.getNode("/sim/model/mast-truck", 1);
        me.model[key] =
            geo.put_model(me.model_path, pos);
        # Set up ground crew models.
        setprop("/sim/model/crew-chief/right-elbow-joint-deg", 90.0);
        me.mast_truck_base.getNode("mast-head-height-m", 1).
            setValue(11.80);
    },
    ##################################################
    remove_fixed_mooring : func(key) {
        if (!contains(me.model, key)) return;
        if (me.model[key] != nil) me.model[key].remove();
    }
};

remote_mooring.init();

###############################################################################
# Initialization.
var mp_network_init = func (active_participant=0) {
    if (broadcast != nil) return; # Already initialized.
    Binary = mp_broadcast.Binary;
    broadcast =
        mp_broadcast.BroadcastChannel.new
            ("sim/multiplay/generic/string[0]",
             handle_message,
             0,
             listen_to,
             when_disconnecting,
             active_participant);
    # Set up the recognized message types.
    message_id = { place_mooring_mast : Binary.encodeByte(1),
                 };
}
