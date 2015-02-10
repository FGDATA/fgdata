# This is a small script that adjusts autopilot target values to track
# (fly in formation with) an AI or Multiplayer aircraft.

# Quick start instructions:
#
#
# 1. Copy this file into $FGROOT/data/Nasal (along with the other
#    system nasal scripts.)
#
# 2. Start up FlightGear selecting an airplane with a reasonably configured
#    autopilot that responds to and works with the standard autopilot 
#    dialog box (F11).  The MiG 15 is one that works, the 777-200 works,
#    the Citation Bravo does not work, the default c172 probably does not
#    work, etc.
#
# 3. Take off and establish stable flight.
#
# 4. Open the property browser (File->Browse Internal Properties) and navigate
#    to /ai/models/  Choose one of the available aircraft[] or multiplayer[]
#    entries.  You can look at all those subtrees to find the call sign you
#    want.  Also note that the subtree for each entity has a radar area that
#    will show range and offset from your current heading.
#
# 5. Open a second property browser window (upper left click box in the first
#    property browser window.)  Navigate to /autopilot/target-tracking/
#
# 6. Set "/autopilot/target-tracking/target-root" to point to the entity
#    path you discovered in step #4.  For instance, this should be set to
#    something like /ai/models/multiplayer[2] or /ai/models/aircraft[0]
#
# 7. Set "/autopilot/target-tracking/goal-range-nm" to the follow distance
#    you want.
#
# 8. Set "/autopilot/target-tracking/enable" = 1, this will turn on the radar
#    computation for each ai/multiplayer entity and will tell the tracking
#    script to start updating the autopilot settings.
#
# 9. Open up the autopilot configuration window (F11) and activate any of the
#    heading, pitch, and speed axes.  The script will begin updating the heading
#    bug angle, the "speed with throttle" value, and the "altitude hold" value.
#
# 10. You can choose to mix and match any of the autopilot modes you want, i.e.
#     you could turn off the heading control and turn manually while the system
#     holds speed and altitude for you.
#
# 11. It always helps to have a sensible target arcraft to chase.  You are
#     flying within the turn radius and climb rate limits of your autopilot.
#
#     Don't forget you are pilot in command and at all times responsible for
#     maintaining safe airspeed and altitude.
#
#     Enjoy the ride!


# print("Target Tracking script loading ...");

# script defaults (configurable if you like)
var default_update_period = 0.05;
var default_goal_range_nm = 0.05;
var default_target_root = "/ai/models/aircraft[0]";
var default_min_speed_kt = 120;

# master enable switch
var target_tracking_enable = 0;

# update period
var update_period = default_update_period;

# goal range to acheive when following target
var goal_range_nm = 0;

# minimum speed so we don't drop out of the sky
var min_speed_kt = 0;

# Target property tree root
var target_root = "";

# Loop identifier
var tracker_loop_id = 0;

# Initialize target tracking
var TrackInit = func {
    if (props.globals.getNode("autopilot") == nil)
        return;

    target_tracking_enable = getprop("/autopilot/target-tracking/enable");
    if ( target_tracking_enable == nil ) {
        target_tracking_enable = 0;
        setprop("/autopilot/target-tracking/enable", target_tracking_enable);
    }

    update_period = getprop("/autopilot/target-tracking/update-period");
    if ( update_period == nil ) {
        update_period = default_update_period;
        setprop("/autopilot/target-tracking/update-period", update_period);
    }

    goal_range_nm = getprop("/autopilot/target-tracking/goal-range-nm");
    if ( goal_range_nm == nil ) {
        goal_range_nm = default_goal_range_nm;
        setprop("/autopilot/target-tracking/goal-range-nm", goal_range_nm);
    }

    min_speed_kt = getprop("/autopilot/target-tracking/min-speed-kt");
    if ( min_speed_kt == nil ) {
        min_speed_kt = default_min_speed_kt;
        setprop("/autopilot/target-tracking/min-speed-kt", min_speed_kt);
    }

    target_root = getprop("/autopilot/target-tracking/target-root");
    if ( target_root == nil ) {
        target_root = default_target_root;
        setprop("/autopilot/target-tracking/target-root", target_root);
    }
   
    setlistener("/autopilot/target-tracking/enable", func { startTimer();} );
}

# If enabled, update our AP target values based on the target range,
# bearing, and speed
var TrackUpdate = func(loop_id) {
    # avoid running multiple concurrent timers
    if (tracker_loop_id != loop_id)
        return;

    if (props.globals.getNode("autopilot") == nil)
        return;

    target_tracking_enable = getprop("/autopilot/target-tracking/enable");

    if ( target_tracking_enable == 1 ) {
        update_period = getprop("/autopilot/target-tracking/update-period");

        # refresh user configurable values
        goal_range_nm = getprop("/autopilot/target-tracking/goal-range-nm");
        target_root = getprop("/autopilot/target-tracking/target-root");

        # force radar debug-mode on (forced radar calculations even if
        # no radar instrument and ai aircraft are out of range
        setprop("/instrumentation/radar/debug-mode", 1);

        my_hdg_prop = sprintf("/orientation/heading-magnetic-deg" );
        my_hdg = getprop(my_hdg_prop);

        my_hdg_true_prop = sprintf("/orientation/heading-deg" );
        my_hdg_true = getprop(my_hdg_true_prop);

        var alt_prop = sprintf("%s/position/altitude-ft", target_root );
        var alt = getprop(alt_prop);
        if ( alt == nil ) {
            print("bad property path: ", alt_prop);
            return;
        }
    
        var speed_prop = sprintf("%s/velocities/true-airspeed-kt", target_root );
        var speed = getprop(speed_prop);
        if ( speed == nil ) {
            print("bad property path: ", speed_prop);
            return;
        }
    
        var range_prop = sprintf("%s/radar/range-nm", target_root );
        var range = getprop(range_prop);
        if ( range == nil ) {
            print("bad property path: ", range_prop);
            return;
        }
    
        var h_offset_prop = sprintf("%s/radar/h-offset", target_root );
        var h_offset = getprop(h_offset_prop);
        if ( h_offset == nil ) {
            print("bad property path: ", h_offset_prop);
            return;
        }

        if ( h_offset > -90 and h_offset < 90 ) {
            # in front of us
            var range_error = range - goal_range_nm;
        } else {
            # behind us
            var range_error = goal_range_nm - range;
        }
        var target_speed = speed + range_error * 100.0;
        if ( target_speed < min_speed_kt ) {
            target_speed = min_speed_kt;
        }

        setprop( "/autopilot/settings/target-altitude-ft", alt );
        setprop( "/autopilot/settings/heading-bug-deg", my_hdg + h_offset );
        setprop( "/autopilot/settings/true-heading-deg",
                 my_hdg_true + h_offset );
        setprop( "/autopilot/settings/target-speed-kt", target_speed );

        # only keep the timer running when the feature is really enabled
        settimer(func() { TrackUpdate(loop_id); }, update_period );
    }
}

# create and start a new timer to cause our update function to be called periodially
startTimer = func {
    tracker_loop_id += 1;
    TrackUpdate(tracker_loop_id);
 }

settimer(TrackInit, 0);

