#777 systems
#Syd Adams
#
var SndOut = props.globals.getNode("sim/sound/Ovolume",1);
var chronometer = aircraft.timer.new("instrumentation/clock/ET-sec",1);
var vmodel = substr(getprop("sim/aero"), 3);
aircraft.livery.init("Aircraft/777/Models/Liveries"~substr(vmodel,0,4));

#EFIS specific class
# ie: var efis = EFIS.new("instrumentation/efis");
var EFIS = {
    new : func(prop1){
        var m = { parents : [EFIS]};
        m.mfd_mode_list=["APP","VOR","MAP","PLAN"];

        m.efis = props.globals.initNode(prop1);
        m.mfd = m.efis.initNode("mfd");
        m.pfd = m.efis.initNode("pfd");
        m.eicas = m.efis.initNode("eicas");
        m.mfd_mode_num = m.mfd.initNode("mode-num",2,"INT");
        m.mfd_display_mode = m.mfd.initNode("display-mode",m.mfd_mode_list[2]);
        m.std_mode = m.efis.initNode("inputs/setting-std",0,"BOOL");
        m.previous_set = m.efis.initNode("inhg-previous",29.92);
        m.kpa_mode = m.efis.initNode("inputs/kpa-mode",0,"BOOL");
        m.kpa_output = m.efis.initNode("inhg-kpa",29.92);
        m.kpa_prevoutput = m.efis.initNode("inhg-kpa-previous",29.92);
        m.temp = m.efis.initNode("fixed-temp",0);
        m.alt_meters = m.efis.initNode("inputs/alt-meters",0,"BOOL");
        m.fpv = m.efis.initNode("inputs/fpv",0,"BOOL");
        m.nd_centered = m.efis.initNode("inputs/nd-centered",0,"BOOL");

        m.mins_mode = m.efis.initNode("inputs/minimums-mode",0,"BOOL");
        m.mins_mode_txt = m.efis.initNode("minimums-mode-text","RADIO","STRING");
        m.minimums = m.efis.initNode("minimums",250,"INT");
        m.minimums_baro= m.efis.initNode("minimums-baro",250,"INT");
        m.minimums_radio= m.efis.initNode("minimums-radio",250,"INT");
        m.mk_minimums = props.globals.getNode("instrumentation/mk-viii/inputs/arinc429/decision-height");
        m.tfc = m.efis.initNode("inputs/tfc",0,"BOOL");
        m.wxr = m.efis.initNode("inputs/wxr",0,"BOOL");
        m.range = m.efis.initNode("inputs/range-nm",0);
        m.sta = m.efis.initNode("inputs/sta",0,"BOOL");
        m.wpt = m.efis.initNode("inputs/wpt",0,"BOOL");
        m.arpt = m.efis.initNode("inputs/arpt",0,"BOOL");
        m.data = m.efis.initNode("inputs/data",0,"BOOL");
        m.pos = m.efis.initNode("inputs/pos",0,"BOOL");
        m.terr = m.efis.initNode("inputs/terr",0,"BOOL");
        m.rh_vor_adf = m.efis.initNode("inputs/rh-vor-adf",0,"INT");
        m.lh_vor_adf = m.efis.initNode("inputs/lh-vor-adf",0,"INT");
        m.nd_plan_wpt = m.efis.initNode("inputs/plan-wpt-index", 0, "INT");

        m.wptIndexL = setlistener("instrumentation/efis/inputs/plan-wpt-index", func m.update_nd_plan_center());

        m.kpaL = setlistener("instrumentation/altimeter/setting-inhg", func m.calc_kpa());

        m.eicas_msg_alert   = m.eicas.initNode("msg/alert"," ","STRING");
        m.eicas_msg_caution = m.eicas.initNode("msg/caution"," ","STRING");
        m.eicas_msg_info    = m.eicas.initNode("msg/info"," ","STRING");
        m.update_radar_font();
        m.update_nd_center();
        setprop("instrumentation/transponder/mode-switch",0);
        setprop("controls/lighting/overhead-intencity",0.5);
        setprop("controls/lighting/CB-intencity",0.5);
        setprop("controls/lighting/panel-flood-intencity",0.5);
        setprop("controls/lighting/dome-intencity",0.5);
        return m;
    },
#### convert inhg to kpa ####
    calc_kpa : func{
        var kp = getprop("instrumentation/altimeter/setting-inhg");
        kp = kp * 33.8637526;
        me.kpa_output.setValue(kp);
        kp = getprop("instrumentation/efis/inhg-previous");
        kp = kp * 33.8637526;
        me.kpa_prevoutput.setValue(kp);
        },
#### update temperature display ####
    update_temp : func{
        var tmp = getprop("environment/temperature-degc");
        if(tmp < 0.00){
            tmp = -1 * tmp;
        }
        me.temp.setValue(tmp);
    },
######### Controller buttons ##########
    ctl_func : func(md,val){
        controls.click(3);
        if(md=="range")
        {
            var rng = me.range.getValue();
            if(val ==1){
                rng =rng * 2;
                if(rng > 640) rng = 640;
            }elsif(val =-1){
                rng =rng / 2;
                if(rng < 10) rng = 10;
            }
            me.range.setValue(rng);
        }
        elsif(md=="dh")
        {
            if(me.mins_mode.getValue())
            {
                if(val==0)
                {
                    num=250;
                }
                else
                {
                    num = me.minimums_baro.getValue();
                    num+=val;
                    if(num<0)num=0;
                    if(num>12000)num=12000;
                }
                me.minimums_baro.setValue(num);
            }
            else
            {
                if(val==0)
                {
                    num=250;
                }
                else
                {
                    num =me.minimums_radio.getValue();
                    num+=val;
                    if(num<0)num=0;
                    if(num>2500)num=2500;
                }
                me.minimums_radio.setValue(num);
            }
            me.minimums.setValue(num);
            me.mk_minimums.setValue(num);
        }
        elsif(md=="mins")
        {
            me.mins_mode.setValue(val);
            if (val)
            {
                me.mins_mode_txt.setValue("BARO");
                me.minimums.setValue(me.minimums_baro.getValue());
            }
            else
            {
                me.mins_mode_txt.setValue("RADIO");
                me.minimums.setValue(me.minimums_radio.getValue());
            }
        }
        elsif(md=="display")
        {
            var num =me.mfd_mode_num.getValue();
            num+=val;
            if(num<0)num=0;
            if(num>3)num=3;
            me.mfd_mode_num.setValue(num);
            me.mfd_display_mode.setValue(me.mfd_mode_list[num]);

            # for all modes except plan, acft is up. For PLAN,
            # north is up.
            var isPLAN = (num == 3);
            setprop("instrumentation/nd/aircraft-heading-up", !isPLAN);
            setprop("instrumentation/nd/user-position", isPLAN);
            me.nd_plan_wpt.setValue(getprop("autopilot/route-manager/current-wp"));

            me.update_nd_center();
            me.update_nd_plan_center();
        }
        elsif(md=="rhvor")
        {
            var num =me.rh_vor_adf.getValue();
            num+=val;
            if(num>1)num=1;
            if(num<-1)num=-1;
            me.rh_vor_adf.setValue(num);
        }
        elsif(md=="lhvor")
        {
            var num =me.lh_vor_adf.getValue();
            num+=val;
            if(num>1)num=1;
            if(num<-1)num=-1;
            me.lh_vor_adf.setValue(num);
        }
        elsif(md=="center")
        {
            if(me.mfd_mode_num.getValue() == 3)
            {
                var index = me.nd_plan_wpt.getValue() + 1;
                if(index >= getprop("autopilot/route-manager/route/num")) index = getprop("autopilot/route-manager/current-wp");
                me.nd_plan_wpt.setValue(index);
            }
            else
            {
                var num =me.nd_centered.getValue();
                num = 1 - num;
                me.nd_centered.setValue(num);
                me.update_radar_font();
                me.update_nd_center();
            }
        }
        else
        {
            print("Unsupported mode: ",md);
        }
    },
    update_radar_font : func {
        var fnt=[12,13];
        var linespacing = 0.01;
        var num = me.nd_centered.getValue();
        setprop("instrumentation/radar/font/size",fnt[num]);
        setprop("instrumentation/radar/font/line-spacing",linespacing);
    },
    update_nd_center : func {
        # PLAN mode is always centered
        var isPLAN = (me.mfd_mode_num.getValue() == 3);
        if (isPLAN or me.nd_centered.getValue())
        {
            setprop("instrumentation/nd/y-center", 0.5);
        } else {
            setprop("instrumentation/nd/y-center", 0.15);
        }
    },

    update_nd_plan_center : func {
        # find wpt lat, lon
        var index = me.nd_plan_wpt.getValue();
        if(index >= 0)
        {
            var lat = getprop("autopilot/route-manager/route/wp[" ~ index ~ "]/latitude-deg");
            var lon = getprop("autopilot/route-manager/route/wp[" ~ index ~ "]/longitude-deg");
            if(lon!=nil) setprop("instrumentation/nd/user-longitude-deg", lon);
            if(lat!=nil) setprop("instrumentation/nd/user-latitude-deg", lat);
        }
    },
#### update EICAS messages ####
    update_eicas : func(alertmsgs,cautionmsgs,infomsgs) {
        var msg="";
        for(var i=0; i<size(alertmsgs); i+=1)
        {
            msg = msg ~ alertmsgs[i] ~ "\n";
        }
        me.eicas_msg_alert.setValue(msg);
        for(var i=0; i<size(cautionmsgs); i+=1)
        {
            msg = msg ~ cautionmsgs[i] ~ "\n";
        }
        me.eicas_msg_caution.setValue(msg);
        for(var i=0; i<size(infomsgs); i+=1)
        {
            msg = msg ~ infomsgs[i] ~ "\n";
        }
        me.eicas_msg_info.setValue(msg);
    },
};
##############################################
##############################################

##########################

var Wiper = {
    new : func {
        var m = { parents : [Wiper] };
        m.direction = 0;
        m.delay_count = 0;
        m.spd_factor = 0;
        m.node = props.globals.getNode(arg[0],1);
        m.power = props.globals.getNode(arg[1],1);
        if(m.power.getValue()==nil)
            m.power.setDoubleValue(0);
        m.spd = m.node.getNode("arc-sec",1);
        if(m.spd.getValue()==nil)
            m.spd.setDoubleValue(1);
        m.delay = m.node.getNode("delay-sec",1);
        if(m.delay.getValue()==nil)
            m.delay.setDoubleValue(0);
        m.position = m.node.getNode("position-norm", 1);
        m.position.setDoubleValue(0);
        m.switch = m.node.getNode("switch", 1);
        if (m.switch.getValue() == nil)
            m.switch.setBoolValue(0);
        return m;
    },
    active: func{
        if(me.power.getValue()<=5)return;
        var spd_factor = 1/me.spd.getValue();
        var pos = me.position.getValue();
        if(!me.switch.getValue()){
            if(pos <= 0.000)return;
        }
        if(pos >=1.000){
            me.direction=-1;
        }elsif(pos <=0.000){
            me.direction=0;
            me.delay_count+=getprop("sim/time/delta-sec");
            if(me.delay_count >= me.delay.getValue()){
                me.delay_count=0;
                me.direction=1;
            }
        }
        var wiper_time = spd_factor*getprop("sim/time/delta-sec");
        pos +=(wiper_time * me.direction);
        me.position.setValue(pos);
    }
};
#####################

var Efis = EFIS.new("instrumentation/efis");
var Efis2 = EFIS.new("instrumentation/efis[1]");
var LHeng=Engine.new(0);
var RHeng=Engine.new(1);
var wiper = Wiper.new("controls/electric/wipers","systems/electrical/bus-volts");

setlistener("sim/signals/fdm-initialized", func {
    SndOut.setDoubleValue(0.15);
    chronometer.stop();
    props.globals.initNode("instrumentation/clock/ET-display",0,"INT");
    props.globals.initNode("instrumentation/clock/time-display",0,"INT");
    props.globals.initNode("instrumentation/clock/time-knob",0,"INT");
    props.globals.initNode("instrumentation/clock/et-knob",0,"INT");
    props.globals.initNode("instrumentation/clock/set-knob",0,"INT");
    balance_fuel();
    setprop("instrumentation/comm/power-btn",0);
    setprop("instrumentation/comm[1]/power-btn",0);
    setprop("instrumentation/comm[2]/power-btn",0);
    setprop("instrumentation/comm/power-good",0);
    setprop("instrumentation/comm[1]/power-good",0);
    setprop("instrumentation/comm[2]/power-gppd",0);
    setprop("instrumentation/comm/volume",0.5);
    setprop("instrumentation/comm[1]/volume",0.5);
    setprop("instrumentation/comm[2]/volume",0.5);
    setprop("controls/fuel/tank[0]/boost-pump-switch[0]",1);
    setprop("controls/fuel/tank[0]/boost-pump-switch[1]",1);
    setprop("controls/fuel/tank[2]/boost-pump-switch[0]",1);
    setprop("controls/fuel/tank[2]/boost-pump-switch[1]",1);
    setprop("autopilot/route-manager/cruise/speed-kts",320);
    setprop("autopilot/route-manager/cruise/speed-mach",0.840);
    setprop("controls/engines/autostart",1);
    setprop("controls/engines/engine/eec-switch",1);
    setprop("controls/engines/engine[1]/eec-switch",1);
#Fuel Jittson Arm
    setprop("controls/fuel/b-jtsnarm", 1);
    setprop("controls/fuel/tank[0]/b-nozzle", 1);
    setprop("controls/fuel/tank[2]/b-nozzle", 1);
#XFD valve
    setprop("controls/fuel/b-xfdfwd-vlv", 1);
    setprop("controls/fuel/b-xfdaft-vlv", 1);
    setprop("controls/fuel/b-xfdaft-vlv", 1);
    setprop("controls/anti-ice/window-heat-ls-switch", 1);
    setprop("controls/anti-ice/window-heat-lf-switch", 1);
    setprop("controls/anti-ice/window-heat-rf-switch", 1);
    setprop("controls/anti-ice/window-heat-rs-switch", 1);

    setprop("controls/flight/adiru-switch", 1);
    setprop("controls/flight/thrust-asym-switch", 1);
    setprop("controls/switches/fire/cargo-fwd-switch", 0);
    setprop("controls/switches/fire/cargo-aft-switch", 0);
    setprop("controls/switches/fire/apu-discharged", 1);
    settimer(start_updates,1);
});

var systems_running = 0;
var start_updates = func {
    if (getprop("position/gear-agl-ft")>30)
    {
        # airborne startup
        Startup();
        setprop("controls/gear/brake-parking",0);
        setprop("controls/lighting/taxi-lights",0);
        setprop("instrumentation/afds/ap-modes/pitch-mode", "TO/GA");
        setprop("instrumentation/afds/ap-modes/roll-mode", "TO/GA");
        setprop("instrumentation/afds/inputs/vertical-index", 10);
        setprop("instrumentation/afds/inputs/lateral-index", 9);
        setprop("instrumentation/afds/inputs/at-armed", 1);
        setprop("instrumentation/afds/inputs/at-armed[1]", 1);
        setprop("instrumentation/afds/inputs/AP", 1);
        setprop("autopilot/internal/airport-height", 0);
        setprop("engines/engine[0]/run",1);
        setprop("engines/engine[1]/run",1);
        setprop("autopilot/settings/target-speed-kt", getprop("sim/presets/airspeed-kt"));
        b777.afds.input(1,1);
        setprop("autopilot/settings/counter-set-altitude-ft", getprop("sim/presets/altitude-ft"));
        setprop("autopilot/settings/actual-target-altitude-ft", getprop("sim/presets/altitude-ft"));
        b777.afds.input(0,2);
        setprop("controls/flight/rudder-trim", 0);
        setprop("controls/flight/elevator-trim", 0);
        setprop("controls/flight/aileron-trim", 0);
        setprop("instrumentation/weu/state/takeoff-mode",0);
        if(var vbaro = getprop("environment/metar/pressure-inhg"))
        {
            setprop("instrumentation/altimeter/setting-inhg", vbaro);
        }
        # set ILS frequency
        var cur_runway = getprop("sim/presets/runway");
        var runways = airportinfo(getprop("sim/presets/airport-id")).runways;
        var r =runways[cur_runway];
        if (r != nil and r.ils != nil)
        {
            setprop("instrumentation/nav/frequencies/selected-mhz", (r.ils.frequency / 100));
        }
    }

    # start update_systems loop - but start it once only
    if (!systems_running)
    {
        systems_running = 1;
        update_systems();
    }
}

setlistener("sim/signals/reinit", func {
    SndOut.setDoubleValue(0.15);
    Shutdown();
});

#setlistener("autopilot/route-manager/route/num", func(wp){
#    var wpt= wp.getValue() -1;
#
#    if(wpt>-1){
#    setprop("instrumentation/groundradar/id",getprop("autopilot/route-manager/route/wp["~wpt~"]/id"));
#    }else{
#    setprop("instrumentation/groundradar/id",getprop("sim/tower/airport-id"));
#    }
#},1,0);

setlistener("sim/current-view/internal", func(vw){
    if(vw.getValue()){
        SndOut.setDoubleValue(0.3);
    }else{
        SndOut.setDoubleValue(1.0);
    }
},1,0);

controls.autostart = func() {
    var run = !(getprop("engines/engine[0]/run") or getprop("engines/engine[1]/run"));
    if(run){
        Startup();
    }else{
        Shutdown();
    }
}

setlistener("instrumentation/clock/et-knob", func(et){
    var tmp = et.getValue();
    if(tmp == -1){
        chronometer.reset();
    }elsif(tmp==0){
        chronometer.stop();
    }elsif(tmp==1){
        chronometer.start();
    }
},0,0);

setlistener("instrumentation/transponder/mode-switch", func(transponder_switch){
    var mode = transponder_switch.getValue();
    var tcas_mode = 1;
    if (mode == 3) tcas_mode = 2;
    if (mode == 4) tcas_mode = 3;
    setprop("instrumentation/tcas/inputs/mode",tcas_mode);
},0,0);

setlistener("instrumentation/tcas/outputs/traffic-alert", func(traffic_alert){
    var alert = traffic_alert.getValue();
    # any TCAS alert enables the traffic display
    if (alert) setprop("instrumentation/efis/inputs/tfc",1);
},0,0);

setlistener("controls/flight/speedbrake", func(spd_brake){
    var brake = spd_brake.getValue();
    # do not update lever when in AUTO position
    if ((brake==0) and (getprop("controls/flight/speedbrake-lever")==2))
    {
        setprop("controls/flight/speedbrake-lever",0);
    }
    elsif ((brake==1)
           and ((getprop("controls/flight/speedbrake-lever")==0)
           or (getprop("controls/flight/speedbrake-lever")==1)))
    {
        setprop("controls/flight/speedbrake-lever",2);
    }
},0,0);

setlistener("controls/flight/speedbrake-lever", func(spd_lever){
    var lever = spd_lever.getValue();
    controls.click(7);
    # do not set speedbrake property unless changed (avoid revursive updates)
    if ((lever==0)and(getprop("controls/flight/speedbrake")!=0))
    {
        setprop("controls/flight/speedbrake",0);
    }
    elsif ((lever==2)and(getprop("controls/flight/speedbrake")!=1))
    {
        setprop("controls/flight/speedbrake",1);
    }
},0,0);

controls.toggleAutoSpoilers = func() {
    # 0=spoilers retracted, 1=auto, 2=extended
    if (getprop("controls/flight/speedbrake-lever")!=1)
        setprop("controls/flight/speedbrake-lever",1);
    else
        setprop("controls/flight/speedbrake-lever",2*getprop("controls/flight/speedbrake"));
}

setlistener("controls/flight/flaps", func { controls.click(6) } );
setlistener("controls/gear/gear-down", func { controls.click(8) } );
controls.gearDown = func(v) {
    if (v < 0) {
        if(!getprop("gear/gear[1]/wow"))setprop("controls/gear/gear-down", 0);
    } elsif (v > 0) {
      setprop("controls/gear/gear-down", 1);
    }
}

controls.toggleLandingLights = func()
{
    var state = getprop("controls/lighting/landing-light[1]");
    setprop("controls/lighting/landing-light[0]",!state);
    setprop("controls/lighting/landing-light[1]",!state);
    setprop("controls/lighting/landing-light[2]",!state);
}

var balance_fuel = func{
    var capwing = getprop("consumables/fuel/tank[0]/capacity-gal_us");
# make the fuel quantity balancing
    var total_fuel = 0;
    var capcenter = 0;
    var j = 3;
    if(vmodel == "-200LR")
    {
        j = 6;
        capcenter = getprop("consumables/fuel/tank[1]/capacity-gal_us");
    }
    for(var i = 0; i < j; i += 1)
    {
        total_fuel += getprop("consumables/fuel/tank["~i~"]/level-gal_us");
    }
    if(j == 6)
    {
        if(total_fuel > ((capwing * 2) + capcenter))
        {
            var capaux = ((total_fuel -  ((capwing * 2) + capcenter)) / 3);
            setprop("consumables/fuel/tank[3]/level-gal_us", capaux);
            setprop("consumables/fuel/tank[4]/level-gal_us", capaux);
            setprop("consumables/fuel/tank[5]/level-gal_us", capaux);
            total_fuel -= (capaux * 3);
        }
        else
        {
            setprop("consumables/fuel/tank[3]/level-gal_us", 0);
            setprop("consumables/fuel/tank[4]/level-gal_us", 0);
            setprop("consumables/fuel/tank[5]/level-gal_us", 0);
        }
    }
    if(total_fuel > (capwing * 2))
    {
        setprop("consumables/fuel/tank[0]/level-gal_us", capwing);
        setprop("consumables/fuel/tank[1]/level-gal_us", (total_fuel - (capwing * 2)));
        setprop("consumables/fuel/tank[2]/level-gal_us", capwing);
    }
    else
    {
        setprop("consumables/fuel/tank[0]/level-gal_us", (total_fuel / 2));
        setprop("consumables/fuel/tank[1]/level-gal_us", 0);
        setprop("consumables/fuel/tank[2]/level-gal_us", (total_fuel / 2));
    }
}

var Startup = func{
    setprop("sim/model/armrest",1);
    setprop("controls/electric/engine[0]/generator",1);
    setprop("controls/electric/engine[1]/generator",1);
    setprop("controls/electric/engine[0]/bus-tie",1);
    setprop("controls/electric/engine[1]/bus-tie",1);
    setprop("systems/electrical/outputs/avionics",1);
    setprop("controls/electric/inverter-switch",1);
    setprop("controls/lighting/instrument-norm",0.8);
    setprop("controls/lighting/nav-lights",1);
    setprop("controls/lighting/beacon",1);
    setprop("controls/lighting/wing-lights",1);
    setprop("controls/lighting/taxi-lights",0);
    setprop("controls/lighting/logo-lights",1);
    setprop("controls/lighting/cabin-lights",1);
    setprop("controls/lighting/strobe",1);
    setprop("controls/lighting/landing-light[0]",1);
    setprop("controls/lighting/landing-light[1]",1);
    setprop("controls/lighting/landing-light[2]",1);
    setprop("controls/engines/engine[0]/cutoff",0);
    setprop("controls/engines/engine[1]/cutoff",0);
    setprop("engines/engine[0]/out-of-fuel",0);
    setprop("engines/engine[1]/out-of-fuel",0);
    setprop("controls/flight/elevator-trim",0);
    setprop("controls/flight/aileron-trim",0);
    setprop("controls/flight/rudder-trim",0);
    setprop("instrumentation/transponder/mode-switch",4); # transponder mode: TA/RA
    setprop("engines/engine[0]/run",1);
    setprop("engines/engine[1]/run",1);
    setprop("controls/hydraulics/system[1]/C1ELEC-switch", 1);
    setprop("controls/hydraulics/system[1]/C2ELEC-switch", 1);
    setprop("controls/hydraulics/system/LACMP-switch", 1);
    setprop("controls/hydraulics/system[1]/C1ADP-switch", 1);
    setprop("controls/hydraulics/system[1]/C2ADP-switch", 1);
    setprop("controls/hydraulics/system[2]/RACMP-switch", 1);
}

var Shutdown = func{
    setprop("controls/gear/brake-parking",1);
    setprop("controls/electric/APU-generator",0);
    setprop("systems/electrical/outputs/avionics",0);
    setprop("controls/electric/battery-switch",0);
    setprop("controls/electric/inverter-switch",0);
    setprop("controls/lighting/instruments-norm",0);
    setprop("controls/lighting/nav-lights",0);
    setprop("controls/lighting/beacon",0);
    setprop("controls/lighting/strobe",0);
    setprop("controls/lighting/wing-lights",0);
    setprop("controls/lighting/taxi-lights",0);
    setprop("controls/lighting/logo-lights",0);
    setprop("controls/lighting/cabin-lights",0);
    setprop("controls/lighting/landing-light[0]",0);
    setprop("controls/lighting/landing-light[1]",0);
    setprop("controls/lighting/landing-light[2]",0);
    setprop("controls/engines/engine[0]/cutoff",1);
    setprop("controls/engines/engine[1]/cutoff",1);
    setprop("controls/flight/elevator-trim",0);
    setprop("controls/flight/aileron-trim",0);
    setprop("controls/flight/rudder-trim",0);
    setprop("controls/flight/speedbrake-lever",0);
    setprop("sim/model/armrest",0);
    setprop("instrumentation/transponder/mode-switch",0); # transponder mode: off
    setprop("controls/engines/StartIgnition-knob[0]",0);
    setprop("controls/engines/StartIgnition-knob[1]",0);
    setprop("engines/engine[0]/run",0);
    setprop("engines/engine[1]/run",0);
    setprop("engines/engine[0]/rpm",0);
    setprop("engines/engine[1]/rpm",0);
    setprop("engines/engine[0]/n2rpm",0);
    setprop("engines/engine[1]/n2rpm",0);
    setprop("engines/engine[0]/fuel-flow_pph",0);
    setprop("engines/engine[1]/fuel-flow_pph",0);
    setprop("instrumentation/weu/state/takeoff-mode",1);
    setprop("controls/hydraulics/system[1]/C1ELEC-switch", 0);
    setprop("controls/hydraulics/system[1]/C2ELEC-switch", 0);
    setprop("controls/hydraulics/system/LACMP-switch", 0);
    setprop("controls/hydraulics/system[1]/C1ADP-switch", 0);
    setprop("controls/hydraulics/system[1]/C2ADP-switch", 0);
    setprop("controls/hydraulics/system[2]/RACMP-switch", 0);
}

var click_reset = func(propName) {
    setprop(propName,0);
}

controls.click = func(button) {
    if (getprop("sim/freeze/replay-state"))
        return;
    var propName="sim/sound/click"~button;
    setprop(propName,1);
    settimer(func { click_reset(propName) },0.4);
}

switch_ind = func() {
# Battery switch
    if(getprop("controls/electric/battery-switch") == 0)
    {
        if(bat.getValue() > 24)
        {
            setprop("controls/electric/b_batt", 0);
        }
        else
        {
            setprop("controls/electric/b_batt", 1);
        }
    }
    else
    {
        setprop("controls/electric/b_batt", 1);
        }
# Primary external power switch
    if(primary_external.getValue() == 1)
    {
        if(pri_epc.getValue() == 1)
        {
            setprop("controls/electric/b_ext_power_p", 2);
        }
        else
        {
            setprop("controls/electric/b_ext_power_p", 1);
        }
    }
    else
    {
        pri_epc.setValue(0);
        setprop("controls/electric/b_ext_power_p", 0);
    }
# Secondary external power switch
    if(secondary_external.getValue() == 1)
    {
        if(sec_epc.getValue() == 0)
        {
            setprop("controls/electric/b_ext_power_s", 1);
        }
        else
        {
            setprop("controls/electric/b_ext_power_s", 2);
        }
    }
    else
    {
        sec_epc.setValue(0);
        setprop("controls/electric/b_ext_power_s", 0);
    }
# Left generator switch
    if(cpt_flt_inst.getValue() < 24)
    {
        setprop("controls/electric/b-lidg", 1);
    }
    elsif(getprop("controls/electric/engine/gen-switch") == 0)
    {
        setprop("controls/electric/b-lidg", 0);
    }
    else
    {
        if(lidg.get_output_volts() > 80)
        {
            setprop("controls/electric/b-lidg", 1);
        }
        else
        {
            setprop("controls/electric/b-lidg", 0);
        }
    }
# Right generator switch
    if(cpt_flt_inst.getValue() < 24)
    {
        setprop("controls/electric/b-ridg", 1);
    }
    elsif(getprop("controls/electric/engine[1]/gen-switch") == 0)
    {
        setprop("controls/electric/b-ridg", 0);
    }
    else
    {
        if(ridg.get_output_volts() > 80)
        {
            setprop("controls/electric/b-ridg", 1);
        }
        else
        {
            setprop("controls/electric/b-ridg", 0);
        }
    }
# Left backup generator switch
    if(cpt_flt_inst.getValue() < 24)
    {
        setprop("controls/electric/b-lbugen", 1);
    }
    elsif(getprop("controls/electric/engine/gen-bu-switch") == 0)
    {
        setprop("controls/electric/b-lbugen", 0);
    }
    else
    {
        setprop("controls/electric/b-lbugen", 1);
    }
# Right backup generator switch
    if(cpt_flt_inst.getValue() < 24)
    {
        setprop("controls/electric/b-rbugen", 1);
    }
    elsif(getprop("controls/electric/engine[1]/gen-bu-switch") == 0)
    {
        setprop("controls/electric/b-rbugen", 0);
    }
    else
    {
        setprop("controls/electric/b-rbugen", 1);
    }
# Left BTR switch
    if(bat.getValue() < 24)
    {
        setprop("controls/electric/b-lbus-tie", 1);
    }
    else
    {
        if(getprop("controls/electric/engine/bus-tie") == 0)
        {
            setprop("controls/electric/b-lbus-tie", 0);
        }
        else
        {
            setprop("controls/electric/b-lbus-tie", 1);
        }
    }
# Right BTR switch
    if(bat.getValue() < 24)
    {
        setprop("controls/electric/b-rbus-tie", 1);
    }
    else
    {
        if(getprop("controls/electric/engine[1]/bus-tie") == 0)
        {
            setprop("controls/electric/b-rbus-tie", 0);
        }
        else
        {
            setprop("controls/electric/b-rbus-tie", 1);
        }
    }
# APU generator switch
    if(bat.getValue() < 24)
    {
        setprop("controls/electric/b-apugen", 1);
    }
    else
    {
        if(ac_tie_bus.getValue() > 80)
        {
            if(getprop("controls/APU/apu-gen-switch") == 0)
            {
                setprop("controls/electric/b-apugen", 0);
            }
            else
            {
                setprop("controls/electric/b-apugen", 1);
            }
        }
        else
        {
            if(getprop("controls/APU/run") == 1)
            {
                setprop("controls/electric/b-apugen", 0);
            }
            else
            {
                setprop("controls/electric/b-apugen", 1);
            }
        }
    }
# Fuel control panel indication
# LH boost #1
    if(!getprop("consumables/fuel/tank[0]/empty")
        and ((getprop("controls/fuel/tank/boost-pump-switch")
                and (l_xfr.getValue() > 80))
            or ((hot_bat.getValue() > 24)
                and (getprop("controls/APU/off-start-run") != 0))))
    {
        setprop("controls/fuel/tank[0]/boost-pump[0]", 1);
    }
    else
    {
        setprop("controls/fuel/tank[0]/boost-pump[0]", 0);
    }
    if((getprop("controls/fuel/tank[0]/boost-pump[0]") == 0)
        and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/fuel/tank[0]/b-boost-pump[0]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[0]/b-boost-pump[0]", 1);
    }
# LH boost #2
    if(!getprop("consumables/fuel/tank[0]/empty")
            and getprop("controls/fuel/tank/boost-pump-switch[1]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[0]/boost-pump[1]", 1);
    }
    else
    {
        setprop("controls/fuel/tank[0]/boost-pump[1]", 0);
    }
    if((getprop("controls/fuel/tank[0]/boost-pump[1]") == 0)
        and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/fuel/tank[0]/b-boost-pump[1]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[0]/b-boost-pump[1]", 1);
    }
# RH boost #1
    if(!getprop("consumables/fuel/tank[2]/empty")
            and getprop("controls/fuel/tank[2]/boost-pump-switch[0]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[2]/boost-pump[0]", 1);
    }
    else
    {
        setprop("controls/fuel/tank[2]/boost-pump[0]", 0);
    }
    if((getprop("controls/fuel/tank[2]/boost-pump[0]") == 0)
        and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/fuel/tank[2]/b-boost-pump[0]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[2]/b-boost-pump[0]", 1);
    }
#RH boost #2
    if(!getprop("consumables/fuel/tank[2]/empty")
            and getprop("controls/fuel/tank[2]/boost-pump-switch[1]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[2]/boost-pump[1]", 1);
    }
    else
    {
        setprop("controls/fuel/tank[2]/boost-pump[1]", 0);
    }
    if((getprop("controls/fuel/tank[2]/boost-pump[1]") == 0)
        and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/fuel/tank[2]/b-boost-pump[1]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[2]/b-boost-pump[1]", 1);
    }
#CTR boost #1
    if((!getprop("consumables/fuel/tank[1]/empty")
            or ((vmodel == "-200LR")
            and (!getprop("consumables/fuel/tank[3]/empty")
                or !getprop("consumables/fuel/tank[4]/empty")
                or !getprop("consumables/fuel/tank[5]/empty"))))
            and getprop("controls/fuel/tank[1]/boost-pump-switch[0]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[1]/boost-pump[0]", 1);
    }
    else
    {
        setprop("controls/fuel/tank[1]/boost-pump[0]", 0);
    }
    if((getprop("controls/fuel/tank[1]/boost-pump[0]") == 0)
        and (cpt_flt_inst.getValue() > 24)
        and (!getprop("consumables/fuel/tank[1]/empty")
            or ((vmodel == "-200LR")
            and (!getprop("consumables/fuel/tank[3]/empty")
                or !getprop("consumables/fuel/tank[4]/empty")
                or !getprop("consumables/fuel/tank[5]/empty")))))
    {
        setprop("controls/fuel/tank[1]/b-boost-pump[0]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[1]/b-boost-pump[0]", 1);
    }
#CTR boost #2
    if((!getprop("consumables/fuel/tank[1]/empty")
            or ((vmodel == "-200LR")
            and (!getprop("consumables/fuel/tank[3]/empty")
                or !getprop("consumables/fuel/tank[4]/empty")
                or !getprop("consumables/fuel/tank[5]/empty"))))
            and getprop("controls/fuel/tank[1]/boost-pump-switch[1]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[1]/boost-pump[1]", 1);
    }
    else
    {
        setprop("controls/fuel/tank[1]/boost-pump[1]", 0);
    }
    if((getprop("controls/fuel/tank[1]/boost-pump[1]") == 0)
        and (cpt_flt_inst.getValue() > 24)
        and (!getprop("consumables/fuel/tank[1]/empty")
            or ((vmodel == "-200LR")
            and (!getprop("consumables/fuel/tank[3]/empty")
                or !getprop("consumables/fuel/tank[4]/empty")
                or !getprop("consumables/fuel/tank[5]/empty")))))
    {
        setprop("controls/fuel/tank[1]/b-boost-pump[1]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[1]/b-boost-pump[1]", 1);
    }
#EEC Autostart
    if((getprop("controls/engines/autostart") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/engines/b-autostart", 0);
    }
    else
    {
        setprop("controls/engines/b-autostart", 1);
    }
#EEC Left
    if((getprop("controls/engines/engine/eec-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/engines/engine/b-eec-switch", 0);
    }
    else
    {
        setprop("controls/engines/engine/b-eec-switch", 1);
    }
#EEC Right
    if((getprop("controls/engines/engine[1]/eec-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/engines/engine[1]/b-eec-switch", 0);
    }
    else
    {
        setprop("controls/engines/engine[1]/b-eec-switch", 1);
    }
#WINDOWS HEAT
    if((getprop("controls/anti-ice/window-heat-ls-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/anti-ice/window-heat-ls", 0);
    }
    else
    {
        setprop("controls/anti-ice/window-heat-ls", 1);
    }
    if((getprop("controls/anti-ice/window-heat-lf-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/anti-ice/window-heat-lf", 0);
    }
    else
    {
        setprop("controls/anti-ice/window-heat-lf", 1);
    }
    if((getprop("controls/anti-ice/window-heat-rf-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/anti-ice/window-heat-rf", 0);
    }
    else
    {
        setprop("controls/anti-ice/window-heat-rf", 1);
    }
    if((getprop("controls/anti-ice/window-heat-rs-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/anti-ice/window-heat-rs", 0);
    }
    else
    {
        setprop("controls/anti-ice/window-heat-rs", 1);
    }
    if((getprop("controls/flight/adiru-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/flight/adiru", 0);
    }
    else
    {
        setprop("controls/flight/adiru", 1);
    }
    if((getprop("controls/flight/thrust-asym-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/flight/thrust-asym", 0);
    }
    else
    {
        setprop("controls/flight/thrust-asym", 1);
    }
    if((cpt_flt_inst.getValue() < 24)
            or (getprop("controls/switches/fire/cargo-fwd-switch") == 0))
    {
        setprop("controls/switches/fire/cargo-fwd", 1);
    }
    else
    {
        setprop("controls/switches/fire/cargo-fwd", 0);
    }
    if((cpt_flt_inst.getValue() < 24)
            or (getprop("controls/switches/fire/cargo-aft-switch") == 0))
    {
        setprop("controls/switches/fire/cargo-aft", 1);
    }
    else
    {
        setprop("controls/switches/fire/cargo-aft", 0);
    }
}

var update_systems = func {
    Efis.calc_kpa();
    Efis.update_temp();
    LHeng.update();
    RHeng.update();
    #wiper.active(); # not implemented yet!
    if(getprop("controls/gear/gear-down")){
        setprop("sim/multiplay/generic/float[0]",getprop("gear/gear[0]/compression-m"));
        setprop("sim/multiplay/generic/float[1]",getprop("gear/gear[1]/compression-m"));
        setprop("sim/multiplay/generic/float[2]",getprop("gear/gear[2]/compression-m"));
    }
    setprop("instrumentation/efis/mfd/rangearc", (Efis.mfd_display_mode.getValue() == "MAP")
        and (Efis.wxr.getValue() or Efis.terr.getValue() or Efis.tfc.getValue()));
    setprop("instrumentation/efis[1]/mfd/rangearc", (Efis2.mfd_display_mode.getValue() == "MAP")
        and (Efis2.wxr.getValue() or Efis2.terr.getValue() or Efis2.tfc.getValue()));
    var et_tmp = getprop("instrumentation/clock/ET-sec");
    var et_min = int(et_tmp * 0.0166666666667);
    var et_hr  = int(et_min * 0.0166666666667) * 100;
    et_tmp = et_hr+et_min;
    setprop("instrumentation/clock/ET-display",et_tmp);
    switch_ind();
    if(getprop("sim/rendering/shaders/skydome")
        and (getprop("position/gear-agl-ft") < 200))
    {
        if(getprop("systems/electrical/outputs/landing-light[1]"))
        {
            setprop("sim/rendering/als-secondary-lights/use-landing-light", 1);
            setprop("sim/rendering/als-secondary-lights/use-alt-landing-light", 1);
            setprop("sim/rendering/als-secondary-lights/landing-light1-offset-deg", -5);
            setprop("sim/rendering/als-secondary-lights/landing-light2-offset-deg", 5);
        }
        else
        {
            if(getprop("systems/electrical/outputs/taxi-lights"))
            {
                setprop("sim/rendering/als-secondary-lights/use-landing-light", 1);
                setprop("sim/rendering/als-secondary-lights/use-alt-landing-light", 0);
                setprop("sim/rendering/als-secondary-lights/landing-light1-offset-deg", 0);
            }
            else
            {
                setprop("sim/rendering/als-secondary-lights/use-landing-light", 0);
                setprop("sim/rendering/als-secondary-lights/use-alt-landing-light", 0);
            }
        }
    }
    setprop("instrumentation/rmu/unit/offside_tuned",
        (((getprop("instrumentation/rmu/unit/vhf-l") == 0) and (getprop("instrumentation/rmu/unit/hf-l") == 0))
            or getprop("instrumentation/rmu/unit[1]/vhf-l")
            or getprop("instrumentation/rmu/unit[1]/hf-l")
            or getprop("instrumentation/rmu/unit[2]/vhf-l")
            or getprop("instrumentation/rmu/unit[2]/hf-l")));
    setprop("instrumentation/rmu/unit[1]/offside_tuned",
        (((getprop("instrumentation/rmu/unit[1]/vhf-r") == 0) and (getprop("instrumentation/rmu/unit[1]/hf-r") == 0))
            or getprop("instrumentation/rmu/unit/vhf-r")
            or getprop("instrumentation/rmu/unit/hf-r")
            or getprop("instrumentation/rmu/unit[2]/vhf-r")
            or getprop("instrumentation/rmu/unit[2]/hf-r")));
    setprop("instrumentation/rmu/unit[2]/offside_tuned",
        ((getprop("instrumentation/rmu/unit[2]/vhf-c") == 0)
            or getprop("instrumentation/rmu/unit/vhf-c")
            or getprop("instrumentation/rmu/unit[1]/vhf-c")));

    settimer(update_systems,0);
}
