####    Bendix-King KFC-200 Flight Director    ####

#Buttons
# HDG ...heading hold
# FD ..... flightdirector on/off
# ALT  ....altitude arm 
# NAV ...VOR / LOC arm
# BC  ....LOC back course 
# APPR ... LOC / GS arm

####  lnav  ####
# 0 = wingleveler
# 1 = heading hold 
# 2 = NAV arm
# 3 = NAV cap
# 4 = APPR arm
# 5 = APPR cap

####  vnav  ####
# 0 = pitch hold
# 1 = ALT arm 
# 2 = ALT cap
# 3 = GS arm
# 4 = GS cap

var L_list=["wing-leveler","dg-heading-hold","dg-heading-hold","nav1-hold","dg-heading-hold","nav1-hold","dg-heading-hold","nav1-hold"];

var V_list=["pitch-hold","pitch-hold","altitude-hold","pitch-hold","gs1-hold"];

var fdprop = props.globals.getNode("/instrumentation/kfc200",1);
var lnav = 0;
var vnav = 0;
var current_alt=0.0;
var alt_select = 0.0;
var DH = 0;

var HASGS = "/instrumentation/nav/has-gs";
var NAVLOC = "/instrumentation/nav/nav-loc";
var NAVDST = "/instrumentation/nav/nav-dist";
var NAVRNG = "/instrumentation/nav/in-range";
var HDEFL = "/instrumentation/nav/heading-needle-deflection";
var GSDEFL = "/instrumentation/nav/gs-needle-deflection-norm";
var BC = "/instrumentation/nav/back-course-btn";

var HDG = props.globals.getNode("/autopilot/locks/heading",1);
var ALT = props.globals.getNode("/autopilot/locks/altitude",1);
var SPD = props.globals.getNode("/autopilot/locks/speed",1);
var SRVC = 0;

setlistener("/sim/signals/fdm-initialized", func {
    fdprop.getNode("serviceable",1).setBoolValue(1);
    fdprop.getNode("armed",1).setBoolValue(0);
    fdprop.getNode("cpld",1).setBoolValue(0);
    fdprop.getNode("pitch-trim",1).setIntValue(0);
    fdprop.getNode("alt-trim",1).setIntValue(0);
    fdprop.getNode("fd-on",1).setBoolValue(0);
    fdprop.getNode("gs-arm",1).setBoolValue(0);
    fdprop.getNode("lnav",1).setValue(0);
    fdprop.getNode("vnav",1).setValue(0);
    fdprop.getNode("alt-preset",1).setDoubleValue(0.0);
    fdprop.getNode("alt-alert",1).setBoolValue(0);
    fdprop.getNode("dh-alert",1).setBoolValue(0);
    DH = getprop("/autopilot/route-manager/min-lock-altitude-agl-ft");
    alt_select = 0;
    ALT.setValue(V_list[vnav]);
    HDG.setValue(L_list[lnav]);
    settimer(update,5);
    print("KFC-200 ... Check");
    });

setlistener("/instrumentation/kfc200/fd-on", func(fd){
    var fdON = fd.getBoolValue();
    clear_ap();
    },0,0);

setlistener("/autopilot/locks/passive-mode", func(ap){
    if(!ap.getBoolValue()){
        setprop("autopilot/settings/target-pitch-deg",getprop("/orientation/pitch-deg"));
        }
    },0,0);

setlistener("/instrumentation/kfc200/serviceable", func(srv){
    if(srv.getBoolValue()){SRVC=1;
        }else{
        SRVC=0;
        }
    },0,0);

setlistener("/autopilot/settings/target-altitude-ft",func(at){
    alt_select = at.getValue();
    },0,0);

setlistener("/autopilot/route-manager/min-lock-altitude-agl-ft",func(dh){
    DH = dh.getValue();
    },0,0);

setlistener("/instrumentation/kfc200/lnav",func(ln){
    if(SRVC == 0)return;
    lnav = ln.getValue();

    if(lnav == 4){
        if(!getprop(NAVLOC)){
            lnav=2;
            setprop("/instrumentation/kfc200/lnav",lnav);
        }else{
        if(getprop(HASGS)){
            if(!getprop(BC)){
                setprop("/instrumentation/kfc200/gs-arm",1);
                }
            }
        }
    }
HDG.setValue(L_list[lnav]);
},0,0);

setlistener("/instrumentation/kfc200/vnav", func(vn){
    if(SRVC == 0)return;
    vnav = vn.getValue();
    ALT.setValue(V_list[vnav]);
},0,0);

var clear_ap = func {
    setprop("/autopilot/settings/target-pitch-deg",getprop("/orientation/pitch-deg"));
    vnav = 0;
    lnav=0;
    setprop("/instrumentation/kfc200/lnav",lnav);
    setprop("/instrumentation/kfc200/vnav",vnav);
    HDG.setValue(L_list[lnav]);
    ALT.setValue(V_list[vnav]);
}

#### PITCH TRIM = 1 degree per second ####
var pitch_trim = func {
    var temp_pitch = getprop("autopilot/settings/target-pitch-deg");
    var FR =getprop("sim/frame-rate");
    if(FR > 0){
    var trim = (1/FR) * arg[0];
    setprop("autopilot/settings/target-pitch-deg",temp_pitch + trim);
    }
}

#### ALTITUDE TRIM = 600 fpm ####
var alt_trim = func {
    var temp_alt = getprop("autopilot/settings/target-altitude-ft");
    var FR =getprop("sim/frame-rate");
    if(FR > 0){
    var trim = (10/FR) * arg[0];
    setprop("autopilot/settings/target-altitude-ft",temp_alt + trim);
    }
}




var update_nav = func {
    if(SRVC == 1){
    var inrange= getprop(NAVRNG);

    if(inrange){

        if(lnav == 2 or lnav == 4){
            setprop("instrumentation/kfc200/armed",1);
            setprop("instrumentation/kfc200/cpld",0);
            var DF = getprop(HDEFL);
            if(DF > -9 and DF < 9){
            setprop("/instrumentation/kfc200/lnav",lnav + 1);
            setprop("instrumentation/kfc200/armed",0);
            setprop("instrumentation/kfc200/cpld",1);
            }
        }

        if(lnav ==5){
            if(getprop("instrumentation/kfc200/gs-arm")){
                if(getprop("instrumentation/nav/gs-distance") < 25000){
                    var GS1 = getprop(GSDEFL); 
                    if( GS1< 0.5 and GS1 > -0.5){vnav = 4;
                    setprop("/instrumentation/kfc200/vnav",vnav);
                    }
                }
            }
        }
    }

    if(vnav == 1){
        var offset = get_altoffset();
        if(offset > -990 and offset < 990){
            setprop("/instrumentation/kfc200/vnav",vnav + 1);
            }
        }

    }
}

var get_altoffset = func(){
    current_alt = getprop("/instrumentation/altimeter/pressure-alt-ft");
    var offset = (current_alt - alt_select);
    var alert =0;
    if(offset > -1000 and offset < -1000){
        if(offset < -300 and offset > 300)alert = 1;
    }
    fdprop.getNode("alt-alert").setBoolValue(alert);
    return(offset);
    }

var update = func {
    var PT = getprop("instrumentation/kfc200/pitch-trim");
    var AT = getprop("instrumentation/kfc200/alt-trim");
    if(PT !=0)pitch_trim(PT);
    if(AT!=0)alt_trim(AT);
    if(getprop("/position/altitude-agl-ft") < DH){
        props.globals.getNode("/autopilot/locks/passive-mode").setBoolValue(1);
        setprop("instrumentation/kfc200/dh-alert",1);
        }else{
        setprop("instrumentation/kfc200/dh-alert",0);
        }
    update_nav();
    settimer(update, 0);
    }

