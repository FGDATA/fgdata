# route_manager.nas -  FlightPlan delegate(s) corresponding to the built-
# in route-manager dialog and GPS. Intended to provide a sensible default behaviour,
# but can be disabled by an aircraft-specific FMS / GPS system.

var RouteManagerDelegate = {
    new: func(fp) {
    # if this property is set, don't build a delegate at all
    if (getprop('/autopilot/route-manager/disable-route-manager'))
        return nil;

        var m = { parents: [RouteManagerDelegate] };
        m.flightplan = fp;
        return m;
    },

    departureChanged: func
    {
        printlog('info', 'saw departure changed');
        me.flightplan.clearWPType('sid');
        if (me.flightplan.departure == nil)
            return;

        if (me.flightplan.departure_runway == nil) {
        # no runway, only an airport, use that
            var wp = createWPFrom(me.flightplan.departure);
            wp.wp_role = 'sid';
            me.flightplan.insertWP(wp, 0);
            return;
        }
    # first, insert the runway itself
        var wp = createWPFrom(me.flightplan.departure_runway);
        wp.wp_role = 'sid';
        me.flightplan.insertWP(wp, 0);
        if (me.flightplan.sid == nil)
            return;

    # and we have a SID
        var sid = me.flightplan.sid;
        printlog('info', 'routing via SID ' ~ sid.id);
        me.flightplan.insertWaypoints(sid.route(me.flightplan.departure_runway), 1);
    },

    arrivalChanged: func
    {
        printlog('info', 'saw arrival changed');
        me.flightplan.clearWPType('star');
        me.flightplan.clearWPType('approach');
        if (me.flightplan.destination == nil)
            return;

        if (me.flightplan.destination_runway == nil) {
        # no runway, only an airport, use that
            var wp = createWPFrom(me.flightplan.destination);
            wp.wp_role = 'approach';
            me.flightplan.appendWP(wp);
            return;
        }

        var initialApproachFix = nil;
        if (me.flightplan.star != nil) {
            printlog('info', 'routing via STAR ' ~ me.flightplan.star.id);
            var wps = me.flightplan.star.route(me.flightplan.destination_runway);
            me.flightplan.insertWaypoints(wps, -1);

            initialApproachFix = wps[-1]; # final waypoint of STAR
        }

        if (me.flightplan.approach != nil) {
            var wps = me.flightplan.approach.route(initialApproachFix);

             if ((initialApproachFix != nil) and (wps == nil)) {
             # current GUI allows selected approach then STAR; but STAR
             # might not be possible for the approach (no transition).
             # since fixing the GUI flow is hard, let's route assuming no
             # IAF. This will likely cause an ugly direct leg, but that's
             # what the user asked for.

                 printlog('info', "couldn't route approach based on specified IAF "
                  ~ initialApproachFix.wp_name);
                 wps = me.flightplan.approach.route(nil);
             }

            if (wps == nil) {
                printlog('warn', 'routing via approach ' ~ me.flightplan.approach.id
                    ~ ' failed entirely.');
            } else {
                printlog('info', 'routing via approach ' ~ me.flightplan.approach.id);
                me.flightplan.insertWaypoints(wps, -1);
            }
        } else {
            printlog('info', 'routing direct to runway ' ~ me.flightplan.destination_runway.id);
            # no approach, just use the runway waypoint
            var wp = createWPFrom(me.flightplan.destination_runway);
            wp.wp_role = 'approach';
            me.flightplan.appendWP(wp);
        }
    },

    cleared: func
    {
        printlog('info', "saw active flightplan cleared, deactivating");
        # see http://https://code.google.com/p/flightgear-bugs/issues/detail?id=885
        fgcommand("activate-flightplan", props.Node.new({"activate": 0}));
    },

    endOfFlightPlan: func
    {
        printlog('info', "end of flight-plan, deactivating");
        fgcommand("activate-flightplan", props.Node.new({"activate": 0}));
    }
};


var FMSDelegate = {
    new: func(fp) {
    # if this property is set, don't build a delegate at all
    if (getprop('/autopilot/route-manager/disable-fms'))
        return nil;

        var m = { parents: [FMSDelegate], flightplan:fp, landingCheck:nil };

        # make FlightPlan behaviour match GPS config state
        fp.followLegTrackToFix = getprop('/instrumentation/gps/config/follow-leg-track-to-fix');

        # similarly, make FlightPlan follow the performance category settings
        fp.aircraftCategory = getprop('/autopilot/settings/icao-aircraft-category');

        return m;
    },

    _landingCheckTimeout: func
    {
        var wow = getprop('gear/gear[0]/wow');
        var gs = getprop('velocities/groundspeed-kt');
        if (wow and (gs < 25))  {
          printlog('info', 'touchdown on destination runway, end of route.');
          me.landingCheck.stop();
          # record touch-down time?
          me.flightplan.finish();
        }
    },

    waypointsChanged: func
    {
    },

    endOfFlightPlan: func
    {
      printlog('info', 'end of flight-plan');
    },

    currentWaypointChanged: func
    {
        if (me.landingCheck != nil) {
            me.landingCheck.stop();
            me.landingCheck = nil; # delete timer
        }

        #printlog('info', 'saw current WP changed, now ' ~ me.flightplan.current);
        var active = me.flightplan.currentWP();
        if (active == nil) return;

        if (active.alt_cstr_type == "at") {
            printlog('info', 'new WP has valid altitude restriction, setting on AP');
            setprop('/autopilot/settings/target-altitude-ft', active.alt_cstr);
        }

        var activeRunway = active.runway();
        # this check is needed to avoid problems with circular routes; when
        # activating the FP we end up here, and without this check, immediately
        # detect that we've 'landed' and finish the FP again.
        var wow = getprop('gear/gear[0]/wow');

        if (!wow and
            (activeRunway != nil) and
            (activeRunway.id == me.flightplan.destination_runway.id))
        {
            me.landingCheck = maketimer(2.0, me, FMSDelegate._landingCheckTimeout);
            me.landingCheck.start();
        }
    }
};

registerFlightPlanDelegate(FMSDelegate.new);
registerFlightPlanDelegate(RouteManagerDelegate.new);

