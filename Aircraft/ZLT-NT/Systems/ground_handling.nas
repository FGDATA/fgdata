###############################################################################
##
## Zeppelin NT-07 airship
##
##  Copyright (C) 2008 - 2014  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

###########################################################################
## Initialization and reset.

var LOCAL_MOORING_ALT_OFFSET = 11.8;
var MAX_WIRE_LENGTH = 100.0 * FT2M;

var init = func(reinit=0) {
    if (getprop("/sim/presets/onground")) {
        settimer(func {
            # Set up an initial mooring location.
            mooring.add_fixed_mooring(geo.aircraft_position(),
                                      LOCAL_MOORING_ALT_OFFSET);
        }, 0.4);
        # We need the FDM to run in between.
        settimer(func {
            mooring.attach_mooring_wire();
            mooring.set_winch_speed(-1.0);
        }, 0.5);
    }

    # Enable Alt+Click to place the mooring mast
    if (!reinit) {
        setlistener("/sim/signals/click", func {
            var click_pos = geo.click_position();
            if (__kbd.alt.getBoolValue()) {
                mooring.add_fixed_mooring(click_pos,
                                          LOCAL_MOORING_ALT_OFFSET);
            }
        });
    }

    # Set up ground crew models.
    setprop("/sim/model/crew-chief/right-elbow-joint-deg", 90.0);
}

var _ground_handling_initialized = 0;
setlistener("/sim/signals/fdm-initialized", func {
    init(_ground_handling_initialized);
    _ground_handling_initialized = 1;
});

###########################################################################
## Mooring location support.
var mooring = {
    ##################################################
    init : func(reinit) {
        if (!reinit) {
            me.UPDATE_INTERVAL = 0.0;
            me.MP_ANNOUNCE_INTERVAL = 60.0;
            # Catalog of possible MP mast carriers.
            # Format: <model path> : <alt_offset>
            me.MP_MAST_CARRIERS = {
                "Aircraft/ZLT-NT/Models/GroundCrew/scania-mast-truck.xml" :
                    "sim/model/mast-truck/mast-head-height-m",
            };
            me.loopid = 0;
            ## Hash containing all supported mooring locations.
            ## Format:
            ##   Fixed {position : <coord>, alt_offset : <m>}
            ##   AI    {base : <node>, alt_offset : <m>}
            me.moorings = {};
            me.model = {local : nil};
            me.mast_truck_base =
                props.globals.getNode("/sim/model/mast-truck", 1);
            # Attach listeners for new MP/AI models
            setlistener
                (props.globals.getNode("/ai/models/model-added", 1),
                 func (path) {
                     var node = props.globals.getNode(path.getValue());
                     if (nil == node.getNode("sim/model/path")) return;
                     var model =
                         node.getNode("sim/model/path").getValue();
                     if (contains(mooring.MP_MAST_CARRIERS, model)) {
                         settimer
                             (func {
                                 mooring.add_ai_mooring
                                     (node,
                                      mooring.MP_MAST_CARRIERS[model]);
                                 #print("Added: " ~ path.getValue());
                              }, 0.0);
                         
                     }
                 });
            setlistener
                (props.globals.getNode("/ai/models/model-removed"),
                 func (path) {
                     var node = props.globals.getNode(path.getValue());
                     mooring.remove_ai_mooring(node);
                     #print("Removed: " ~ path.getValue());
                 });
            me.model_path = "Aircraft/ZLT-NT/Models/mooring_truck.xml";
        }
        me.last_mp_announce = systime();
        me.active_mooring = props.globals.getNode("/fdm/jsbsim/mooring");
        me.selected = "";
        me.reset();
        print("ZLT-NT Mooring ... Standing by.");
    },
    ##################################################
    add_fixed_mooring : func(pos, alt_offset, name="local") {
        var geo_info = geodinfo(pos.lat(), pos.lon());
        if (geo_info == nil) return;
        pos.set_alt(geo_info[0]);
        me.moorings[name] = { position   : pos,
                              alt_offset : alt_offset };
        # Put a mooring mast model here. Note the model specific offset.
        if (me.model[name] != nil) me.model[name].remove();
        me.model[name] =
            geo.put_model(me.model_path, pos);
        me.mast_truck_base.getNode("mast-head-height-m", 1).
            setValue(alt_offset);
        if (name == "local") {
            announce_fixed_mooring(pos, alt_offset);
        }
        #print("ZLT-NT Mooring: New fixed mooring " ~ name ~ ".");
    },
    ##################################################
    remove_fixed_mooring : func(name) {
        if (me.model[name] != nil) me.model[name].remove();
        delete(me.moorings, name);
    },
    ##################################################
    add_ai_mooring : func(ai, alt_offset) {
        if (ai == nil) return;
        var name = ai.getNode("callsign").getValue();
        if (name == "") { name = ai.getNode("name").getValue(); }
        me.moorings[name] = { base       : ai,
                              alt_offset : alt_offset };
        #print("ZLT-NT Mooring: New MP/AI mooring " ~ name ~ ".");
    },
    ##################################################
    remove_ai_mooring : func(ai) {
        if (ai == nil) return;
        foreach (var name; keys(me.moorings)) {
            if (contains(me.moorings[name], "base") and
                me.moorings[name].base == ai) {
                delete(me.moorings, name);
                return;
            }
        }
    },
    ##################################################
    attach_mooring_wire : func {
        var dist = me.active_mooring.getNode("total-distance-ft").getValue();
        if ((dist < MAX_WIRE_LENGTH/FT2M) and
            (getprop("/position/altitude-agl-ft")*FT2M < MAX_WIRE_LENGTH)) {
            me.active_mooring.getNode("winch-speed-fps").setValue(0);
            me.active_mooring.getNode("initial-wire-length-ft").setValue(dist);
            me.active_mooring.getNode("wire-connected").setValue(1.0);
            me.announce("Ground reports: Mooring cable attached.");
        } else {
            me.announce("We are too far from the mooring mast.");
        }
    },
    ##################################################
    change_wire_length : func(d) {
        var len =
            me.active_mooring.getNode("initial-wire-length-ft").getValue();
        var sp  = me.active_mooring.getNode("max-winch-speed-fps").getValue();
        if ((len == 0) and (d < 0)) {
            var t = me.active_mooring.getNode("wire-connected").getValue();
            interpolate(me.active_mooring.getNode("wire-connected"), 2*t, 5.0);
        } else {
            interpolate(me.active_mooring.getNode("initial-wire-length-ft"),
                        (len + d) < 0 ? 0 : len + d, math.abs(d/sp));
        }
    },
    ##################################################
    set_winch_speed : func(sp) {
        if (me.active_mooring.getNode("wire-connected").getValue() == 0.0) {
            me.active_mooring.getNode("winch-speed-fps").setValue(0);
            return;
        }
        
        var max = me.active_mooring.getNode("max-winch-speed-fps").getValue();
        if (math.abs (sp) > max) {
            sp = sp/math.abs(sp) * max;
        }
        me.active_mooring.getNode("winch-speed-fps").setValue(sp);
        me.announce("Winch " ~
                    math.abs(int(0.3048*sp)) ~ "." ~
                    math.mod(math.abs(int(3.048*sp)), 10) ~
                    " meters-per-second " ~
                    ((sp < 0) ? "in" : "out") ~ ".");
    },
    ##################################################
    release_mooring : func {
        if (me.active_mooring.getNode("moored").getValue() >= 1.0) {
            me.active_mooring.getNode("wire-connected").setValue(0.0);
            me.announce("Mooring connection released.");
        } elsif (me.active_mooring.getNode("wire-connected").getValue() >=
                 1.0) {
            me.active_mooring.getNode("wire-connected").setValue(0.0);
            me.announce("Released mooring wire.");
        }
        me.active_mooring.getNode("winch-speed-fps").setValue(0);
    },
    announce : func(msg) {
        setprop("/sim/messages/copilot", msg);
    },
    ##################################################
    update : func {
#    if (me.mooring.getNode("wire-connected").getValue()) return;
# The mooring might have moved..
        var distance = FT2M *
            me.active_mooring.getNode("total-distance-ft").getValue();
        
        # Break wire connection if too far way.
        if (distance > MAX_WIRE_LENGTH and
            me.active_mooring.getNode("wire-connected").getBoolValue()) {
            me.release_mooring();
        }

        var ac_pos = geo.aircraft_position();
        var found = 0;
        foreach (var name; keys(me.moorings)) {
            # Find the mooring position.
            if (contains(me.moorings[name], "position")) {
                var pos = me.moorings[name].position;
            } else {
                var ai = me.moorings[name].base;
                var pos = geo.Coord.set_latlon
                    (ai.getNode("position/latitude-deg").getValue(),
                     ai.getNode("position/longitude-deg").getValue(),
                     FT2M * ai.getNode("position/altitude-ft").getValue());
            }
            if ((name == me.selected) or
                (pos.direct_distance_to(ac_pos) < distance)) {
                if (name != me.selected) {
                    print("ZLT-NT Mooring: Switched mooring to " ~ name ~ ".");
                    me.selected = name;
                }
                distance = pos.distance_to(ac_pos);
                me.active_mooring.getNode("latitude-deg").setValue(pos.lat());
                me.active_mooring.getNode("longitude-deg").setValue(pos.lon());
                # First check if the offset is fixed or a AI/MP property.
                var offset = 0;
                if (dual_control_tools.is_num(me.moorings[name].alt_offset)) {
                    offset = me.moorings[name].alt_offset;
                } else {
                    # Read the offset property but guard against it still being
                    # uninitialized.
                    offset =
                        me.moorings[name].base.
                            getNode(me.moorings[name].alt_offset, 1).getValue()
                        or 0;
                }
                me.active_mooring.getNode("altitude-ft").
                    setValue(M2FT * (pos.alt() + offset));

                found = 1;
            }
        }

        # Animate mooring mast head. Currently affects all mast trucks.
        if (me.active_mooring.getNode("wire-connected").getBoolValue()) {
            # Best effort approximation: Use aircraft heading and pitch.
            me.mast_truck_base.getNode("mast-head-heading-deg", 1).
                setValue(getprop("/orientation/heading-deg") + 180);
            me.mast_truck_base.getNode("mast-head-pitch-deg", 1).
                setValue(-getprop("/orientation/pitch-deg"));
        }

        # Announce local mooring mast.
        var now = systime();
        if (now > me.last_mp_announce + me.MP_ANNOUNCE_INTERVAL) {
            announce_fixed_mooring(me.moorings["local"].position,
                                   me.moorings["local"].alt_offset);
            me.last_mp_announce = now;
        }
    },
    ##################################################
    reset : func {
        me.loopid += 1;
        me._loop_(me.loopid);
    },
    ##################################################
    _loop_ : func(id) {
        id == me.loopid or return;
        me.update();
        settimer(func { me._loop_(id); }, me.UPDATE_INTERVAL);
    }
};

# Initialize the mooring singleton right away.
mooring.init(0);
