###############################################################################
##
##  RAF mk9 bubble sextant.
##
##  Copyright (C) 2007 - 2013  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

## NOTE: This module MUST be loaded as RAFmk9sextant;

## You can override these parameters when loading this file.
#   Field of view when looking through the sextant
var FOV = 25;
#   Distance from the eye to the sextant when looking through the sextant.
var VIEW_DISTANCE = 0.15;
#   The view in which the sextant will be used.
var VIEW_NAME = "Cockpit View";
#   The storage location and orientation.
#   The location is relative to the default center for the view.
var STOWED = { position    : {x:-0.3, y: 0.0, z: -0.2},
               orientation : {heading : 320.0,
                              pitch   : -45.0,
                              roll    : 0.0}
             };

## Interface functions.
var pick_up = func {
    if (handling.lookthrough) return;
    if (view.current != handling.source_view) return;

    handling.toggle();
    if (handling.enabled) {
        handling.view_angle.setValue(-90.0);
        handling.view_distance.setValue(2.0*VIEW_DISTANCE);
    }
}

var toggle_look_through = func {
    handling.toggle_look_through();
}

###############################################################################
# Bindings for mouse X and Y movements. Install these to the appropriate
# mouse mode and axes, e.g. in the -set file.
var mouseXmove = func {
    if (!_initialized or !handling.enabled) return;

    var delta = 3*cmdarg().getNode("offset").getValue();
    var view = "/sim/current-view/heading-offset-deg";
    var val = getprop(view) - delta;
    if(val < 0)   val = 0;
    if(val > 360) val = 360;
    setprop(view, val);
}
var mouseXtilt = func {
    if (!_initialized or !handling.enabled) return;

    var delta = 3*cmdarg().getNode("offset").getValue();
    # Roll adjustment
    var orient = sextant.get_orientation();
    var roll = orient[2] - delta;
    if(roll < -180) roll = -180;
    if(roll > 180)  roll = 180;
    sextant.set_orientation(orient[0], orient[1], roll);
}

var mouseYmove = func {
    if (!_initialized or !handling.enabled) return;

    var delta = 3*cmdarg().getNode("offset").getValue();
    var view = "/sim/current-view/pitch-offset-deg";
    var val = getprop(view) - delta;
    if(val < -90) val = -90;
    if(val > 90)  val = 90;
    setprop(view, val);
}
var mouseYaltitude = func {
    if (!_initialized or !handling.enabled) return;

    var delta = 3*cmdarg().getNode("offset").getValue();
    # Altitude adjustment   
    sextant.adjust_altitude_fine(delta);
}

var RAD = math.pi/180;
var DEG = 180/math.pi;

###############################################################################
# Class for managing one RAF mk9 bubble sextant instrument.
var sextant = {
    ##################################################
    init : func (n=0) {
        me.UPDATE_INTERVAL = 0.0;
        me.loopid = 0;
        me.base =
            props.globals.getNode("instrumentation/sextant["~ n ~"]/", 1);

        ## Instrument properties
        me.pitch_err = me.base.getNode("pitch-error-deg", 1);
        me.pitch_err.setDoubleValue(0);
        me.roll_err = me.base.getNode("roll-error-deg", 1);
        me.roll_err.setDoubleValue(0);
        me.setting_min = me.base.getNode("setting/min", 1);
        me.setting_min.setDoubleValue(0);
        me.setting_deg1 = me.base.getNode("setting/deg1", 1);
        me.setting_deg1.setDoubleValue(0); # 0 - 10 deg fractional.
        me.setting_deg10 = me.base.getNode("setting/deg10", 1);
        me.setting_deg10.setDoubleValue(0);
        me.bubble = me.base.getNode("bubble-norm", 1);
        me.bubble.setDoubleValue(0);
        me.serviceable = me.base.getNode("serviceable", 1);
        me.serviceable.setBoolValue(1);

        ## The instrument's orientation in the aircraft frame
        ## and position offset relative its initial position.
        me.position = [me.base.getNode("offsets/x-m", 1),
                       me.base.getNode("offsets/y-m", 1),
                       me.base.getNode("offsets/z-m", 1)];
        me.heading  = me.base.getNode("offsets/heading-deg", 1);
        me.pitch    = me.base.getNode("offsets/pitch-deg", 1);
        me.roll     = me.base.getNode("offsets/roll-deg", 1);

        me.position[0].setValue(0);
        me.position[1].setValue(0);
        me.position[2].setValue(0);
        me.heading.setValue(0);
        me.pitch.setValue(0);
        me.roll.setValue(0);

        me.reset();

        print("RAF Mk9 bubble sextant ... initialized");
    },
    ##################################################
    set_position : func (x, y ,z) {
        me.position[0].setValue(x);
        me.position[1].setValue(y);
        me.position[2].setValue(z);
    },
    ##################################################
    get_position : func (x, y ,z) {
        return [me.position[0].getValue(),
                me.position[1].getValue(),
                me.position[2].getValue()];
    },
    ##################################################
    set_orientation : func (heading, pitch, roll) {
        me.heading.setValue(heading);
        me.pitch.setValue(pitch);
        me.roll.setValue(roll);
    },
    ##################################################
    get_orientation : func () {
        return [me.heading.getValue(),
                me.pitch.getValue(),
                me.roll.getValue()];
    },
    ##################################################
    step_10deg_knob : func (d) {
        var val = me.setting_deg10.getValue() + (d < 0 ? -1 : 1);
        if(val < 0)  val = 0;
        if(val > 8)  val = 8;
        me.setting_deg10.setValue(val);
    },
    ##################################################
    step_5deg_knob : func (d) {
        var val = me.setting_deg1.getValue();
        var new = val;
        if (d <= 0 and val >= 5.0) new -= 5.0;
        if (d >= 0 and val <  5.0) new += 5.0;
        if(new < 0.0)  new = 0;
        if(new > 10.0) new = 10;
        me.setting_deg1.setValue(new);
    },
    ##################################################
    step_bubble_knob : func (d) {
        var val = me.bubble.getValue() + d;
        if(val < 0)  val = 0;
        if(val > 1)  val = 1;
        me.bubble.setValue(val);
    },
    ##################################################
    adjust_altitude_fine : func (d) {
        var val = me.setting_deg1.getValue() - d;
        if(val < 0) val = 0;
        if(val > 10) val = 10;

        me.setting_deg1.setValue(val);
        me.setting_min.setValue(60.0*val - 60*int(val));
    },
    ##################################################
    get_altitude : func {
        return 10.0 * me.setting_deg10.getValue() + me.setting_deg1.getValue();
    },
    ##################################################
    reset : func {
        me.loopid += 1;
        me._loop_(me.loopid);
    },
    ##################################################
    update : func {
        ## State data we need.
        var heading_ac = getprop("/orientation/heading-deg") * RAD;
        var pitch_ac   = getprop("/orientation/pitch-deg") * RAD;
        var roll_ac    = getprop("/orientation/roll-deg") * RAD;
        
        var yaw_v      = me.heading.getValue() * RAD;
        var pitch_v    = me.pitch.getValue() * RAD;
        var roll_v     = me.roll.getValue() * RAD;

        ##  Compute local aircraft axes vectors in the local frame
        ##    Account for aircraft orientation. (x/y/z = front/left/up)
        var T_ac = mulMM(mulMM(rotateZ(heading_ac), rotateY(pitch_ac)),
                         rotateX(roll_ac));
        ##  Account for view orientation and sextant settings.
        ##    The sextant frame is assumed to coincide with the view frame
        ##    except that it is pitched down altitude deg around its local
        ##    Y axis.
        var T_bs =  mulMM(mulMM(mulMM(mulMM(
                      T_ac,
                      rotateZ(yaw_v)),
                      rotateY(pitch_v)),
                      rotateX(roll_v)),
                      rotateY(-me.get_altitude() * RAD));

        var X_bs = mulMv(T_bs, X);
        var Y_bs = mulMv(T_bs, Y);
        var Z_bs = mulMv(T_bs, Z);

        ## Transform up in the local frame to the sextant frame.
        var Up = mulMv([X_bs, Y_bs, Z_bs], Z);
        var Up_xz = [Up[0], 0, Up[2]];
        var Up_yz = [0, Up[1], Up[2]];

        ## Compute interesting angles in the sextant frame.
        var p_err = angleV(Z, Up_xz);
        if (scalar(Up_xz, X) < 0.0) {
             p_err *= -1;
        }
        me.pitch_err.setValue(p_err*DEG);

        var r_err = angleV(Z, Up_yz);
        if (scalar(Up_yz, Y) < 0.0) {
             r_err *= -1;
        }
        me.roll_err.setValue(r_err*DEG);
    },
    ##################################################
    _loop_ : func(id) {
        id == me.loopid or return;
        me.update();
        settimer(func { me._loop_(id); }, me.UPDATE_INTERVAL, 1);
    }
};

###############################################################################
## Singleton class for handling (i.e. moving / rotating) a sextant.
var handling = {
    enabled : 0,
    ##################################################
    init : func (n=0) {
        # Initialize the instrument.
        sextant.init(n);
        sextant.set_position
            (STOWED.position.x,
             STOWED.position.y,
             STOWED.position.z);
        sextant.set_orientation
            (STOWED.orientation.heading,
             STOWED.orientation.pitch,
             STOWED.orientation.roll);

        me.UPDATE_INTERVAL = 0.0;
        me.loopid = 0;
        me.lookthrough = 0;

        me.base =
            props.globals.getNode("instrumentation/sextant["~ n ~"]/", 1);

        ## Instrument properties
        me.altitude_deg = me.base.getNode("altitude-deg", 1);
        me.altitude_deg.setDoubleValue(0);

        ## 3d model position properties
        me.source_view = view.views[view.indexof(VIEW_NAME)];
        var src = me.source_view.getNode("config");
        me.offset = {x: src.getNode("z-offset-m").getValue(),
                     y: src.getNode("x-offset-m").getValue(),
                     z: src.getNode("y-offset-m").getValue()};

        me.view_distance = me.base.getNode("view-distance-m", 1);
        me.view_distance.setDoubleValue(2.0*VIEW_DISTANCE);
        me.view_angle = me.base.getNode("view-angle-deg", 1);
        me.view_angle.setDoubleValue(0.0);

        ## Instrument "display"
        me.display = screen.display.new(20, 10);
        me.display.format = "%2.4f";
        me.display.add(me.altitude_deg,
                       props.globals.getNode("/sim/time/gmt"));

        settimer(func { me.disable(); }, 0.0);

        print("RAF Mk9 bubble sextant handling ... initialized");
    },
    ##################################################
    toggle : func {
        if (me.enabled) {
            me.disable();
        } else {
            me.enable();
        }
    },
    ##################################################
    enable : func {
        me.enabled = 1;
        me.display.redraw();

        me.loopid += 1;
        me._loop_(me.loopid);
    },
    ##################################################
    toggle_look_through : func {
        if (!me.enabled) return;
        if (!me.lookthrough) {
            me.lookthrough = 1;
            
            me.view_distance.setDoubleValue(VIEW_DISTANCE);
            me.view_angle.setValue(0.0);

            me.old_view = view.point.save();
            setprop("/sim/current-view/field-of-view", FOV);
        } else {
            me.lookthrough = 0;
            setprop("/sim/current-view/field-of-view",
                    me.old_view.getChild("field-of-view").getValue());
#            view.point.restore();            
            me.view_angle.setValue(-90.0);
            me.view_distance.setValue(2.0*VIEW_DISTANCE);
        }
    },
    ##################################################
    disable : func {
        me.enabled = 0;
        me.lookthrough = 0;
        me.display.close();

        sextant.set_position
            (STOWED.position.x,
             STOWED.position.y,
             STOWED.position.z);
        sextant.set_orientation
            (STOWED.orientation.heading,
             STOWED.orientation.pitch,
             STOWED.orientation.roll);
        me.view_distance.setDoubleValue(0.0);
        me.view_angle.setValue(0.0);
    },
    ##################################################
    update : func {
        ## Move the 3d model.
        if (view.current == me.source_view) {
            var src = props.globals.getNode("/sim/current-view");
            sextant.set_position
                (src.getNode("z-offset-m").getValue() - me.offset.x,
                 src.getNode("x-offset-m").getValue() - me.offset.y,
                 src.getNode("y-offset-m").getValue() - me.offset.z);
            var old = sextant.get_orientation();
            sextant.set_orientation
                (getprop("/sim/current-view/heading-offset-deg"),
                 getprop("/sim/current-view/pitch-offset-deg"),
                 old[2]);
            me.altitude_deg.setValue(sextant.get_altitude());
        }
    },
    ##################################################
    _loop_ : func(id) {
        id == me.loopid and me.enabled or return;
        me.update();
        settimer(func { me._loop_(id); }, me.UPDATE_INTERVAL, 1);
    }
};

###############################################################################
var _initialized = 0;
setlistener("/sim/signals/fdm-initialized", func {
    if (!_initialized) {
        handling.init();
        _initialized = 1;
    } else {
        handling.disable();
    }
});

###############################################################################
## Ugly matrix math as needed.
## Probably horribly inefficient matrix representation:
##   M[row][col] = [[row1], [row2], [row3]]
##   v[row] = [x, y, z]

var X = [1, 0, 0];
var Y = [0, 1, 0];
var Z = [0, 0, 1];
var id = [X, Y, Z];

var mulMv = func(M, v) {
    return [M[0][0]*v[0] + M[0][1]*v[1] + M[0][2]*v[2],
            M[1][0]*v[0] + M[1][1]*v[1] + M[1][2]*v[2],
            M[2][0]*v[0] + M[2][1]*v[1] + M[2][2]*v[2]];
}

var mulMM = func(A, B) {
    return [[A[0][0]*B[0][0] + A[0][1]*B[1][0] + A[0][2]*B[2][0],
             A[0][0]*B[0][1] + A[0][1]*B[1][1] + A[0][2]*B[2][1],
             A[0][0]*B[0][2] + A[0][1]*B[1][2] + A[0][2]*B[2][2]],
            [A[1][0]*B[0][0] + A[1][1]*B[1][0] + A[1][2]*B[2][0],
             A[1][0]*B[0][1] + A[1][1]*B[1][1] + A[1][2]*B[2][1],
             A[1][0]*B[0][2] + A[1][1]*B[1][2] + A[1][2]*B[2][2]],
            [A[2][0]*B[0][0] + A[2][1]*B[1][0] + A[2][2]*B[2][0],
             A[2][0]*B[0][1] + A[2][1]*B[1][1] + A[2][2]*B[2][1],
             A[2][0]*B[0][2] + A[2][1]*B[1][2] + A[2][2]*B[2][2]]];
}

var scalar = func(a, b) {
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
}

var absV = func(a) {
    return math.sqrt(scalar(a, a));
}

var crossV = func(a, b) {
    return [a[1]*b[2] - a[2]*b[1],
            a[2]*b[0] - a[0]*b[2],
            a[0]*b[1] - a[1]*b[0]];
}

var rotateX = func (r) {
    return [[1, 0, 0],
            [0, math.cos(-r), -math.sin(-r)],
            [0, math.sin(-r), math.cos(-r)]];
}

var rotateY = func (r) {
    return [[math.cos(-r), 0, math.sin(-r)],
            [0, 1, 0],
            [-math.sin(-r), 0, math.cos(-r)]];
}

var rotateZ = func (r) {
    return [[math.cos(r), -math.sin(r), 0],
            [math.sin(r), math.cos(r), 0],
            [0, 0, 1]];
}

var printMat = func (m) {
    foreach (var e; m) {
        if (typeof(e) == "scalar") {
            print(" " ~ e);
        } else {
            var line = ""; 
            foreach (var ee; e) {
                line = line ~ " " ~ ee;
            }
            print(line);
        }
    }
}

var angleV = func (a, b) {
    return math.acos(math.abs(scalar(a,b)) / (absV(a) * absV(b)));
}

#print("id*id=");
#printMat(mulMM(id,id));

#print("X=");
#printMat(X);

#print("RotY(45)*X=");
#printMat(mulMv(rotateY(45*math.pi/180),X));

#print("Y*X= " ~scalar(Y,X));
