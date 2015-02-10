#############################################################################
# Flight Director/Autopilot controller.
# Syd Adams
#
###  Initialization #######

var Lateral = "autopilot/locks/heading";
var Lateral_arm = "autopilot/locks/heading-arm";
var Vertical = "autopilot/locks/altitude";
var Vertical_arm = "autopilot/locks/altitude-arm";
var AP = "autopilot/locks/AP-status";
var NAVprop="autopilot/settings/nav-source";
var AutoCoord="controls/flight/auto-coordination";
var NAVSRC= getprop(NAVprop);
var count=0;
var Coord = 0;
var minimums=getprop("autopilot/settings/minimums");
var wx_range=[10,25,50,100,200,300];
var wx_index=3;


#####################################

setlistener("/sim/signals/fdm-initialized", func {
    setprop("instrumentation/nd/range",wx_range[wx_index]);
    print("Flight Director ...Check");
    settimer(update_fd, 30);
});

### AP /FD BUTTONS ####

var FD_set_mode = func(btn){
    var Lmode=getprop(Lateral);
    var LAmode=getprop(Lateral_arm);
    var Vmode=getprop(Vertical);
    var VAmode=getprop(Vertical_arm);


    if(btn=="ap"){
        Coord = getprop(AutoCoord);
        if(getprop(AP)!="AP1"){
            setprop(Lateral_arm,"");setprop(Vertical_arm,"");
            if(Vmode=="PTCH")set_pitch();
            if(Lmode=="ROLL")set_roll();
            if(getprop("position/altitude-agl-ft") > minimums) {
                setprop(AP,"AP1");setprop(AutoCoord,0);}
        } else kill_Ap("");
    }elsif(btn=="hdg"){
        if(Lmode!="HDG") setprop(Lateral,"HDG") else set_roll();
        setprop(Lateral_arm,"");setprop(Vertical_arm,"");
    }elsif(btn=="alt"){
        setprop(Lateral_arm,"");setprop(Vertical_arm,"");
        if(Vmode!="ALT"){
            setprop(Vertical,"ALT");setprop("autopilot/settings/asel",(getprop("instrumentation/altimeter/mode-c-alt-ft") * 0.01));
        } else set_pitch();
    }elsif(btn=="flc"){
        var flcmode = "FLC";
        var asel = "ASEL";
        if(NAVSRC=="FMS"){flcmode="VFLC";asel = "VASEL";}
        if(Vmode!=flcmode){
            var mc =getprop("instrumentation/airspeed-indicator/indicated-mach");
            var kt=int(getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));
            if(!getprop("autopilot/settings/changeover")){
                if(kt > 80 and kt <340){
                    setprop(Vertical,flcmode);
                    setprop(Vertical_arm,asel);
                    setprop("autopilot/settings/target-speed-kt",kt);
                    setprop("autopilot/settings/target-speed-mach",mc);
                }
            }else{
                if(mc > 0.40 and mc <0.85){
                    setprop(Vertical,flcmode);
                    setprop(Vertical_arm,asel);
                    setprop("autopilot/settings/target-speed-kt",kt);
                    setprop("autopilot/settings/target-speed-mach",mc);
                }
            }
        } else set_pitch();
    }elsif(btn=="nav"){
        set_nav_mode();
        setprop("autopilot/settings/low-bank",0);
    }elsif(btn=="vnav"){
        if(Vmode!="VALT"){
            if(NAVSRC=="FMS"){
                setprop(Vertical,"VALT");
                setprop(Lateral,"LNAV");
            }
            }else set_pitch();
    }elsif(btn=="app"){
        setprop(Lateral_arm,"");setprop(Vertical_arm,"");
        set_apr();
        setprop("autopilot/settings/low-bank",0);
    }elsif(btn=="vs"){
        setprop(Lateral_arm,"");setprop(Vertical_arm,"");
         if(Vmode!="VS"){
            var tgt_vs = (int(getprop("autopilot/internal/vert-speed-fpm") * 0.01)) * 100;
            setprop(Vertical,"VS");setprop("autopilot/settings/vertical-speed-fpm",tgt_vs);
        } else set_pitch();
    }elsif(btn=="stby"){
        setprop(Lateral_arm,"");setprop(Vertical_arm,"");
        set_pitch();
        set_roll();
        setprop("autopilot/settings/low-bank",0);
    }elsif(btn=="bank"){
        var Bnk="autopilot/settings/low-bank";
        if(Lmode=="HDG")setprop(Bnk,1-getprop(Bnk));
    }elsif(btn=="co"){
        var Co= 1- getprop("autopilot/settings/changeover");
         if(Vmode!="FLC") Co=0;
         setprop("autopilot/settings/changeover",Co);
    }
}

########  FMS/NAV BUTTONS  ############
var nav_src_set=func(src){
    setprop(Lateral_arm,"");setprop(Vertical_arm,"");
    set_pitch();set_roll();
    if(src=="fms"){
        if(getprop("autopilot/route-manager/route/num")>0)setprop(NAVprop,"FMS");
    }else{
        if (NAVSRC!="NAV1")setprop(NAVprop,"NAV1") else setprop(NAVprop,"NAV2");
    }
}

########### ARM VALID NAV MODE ################

var set_nav_mode=func{
    setprop(Lateral_arm,"");setprop(Vertical_arm,"");
    if(NAVSRC=="NAV1"){
        if(getprop("instrumentation/nav/data-is-valid")){
            if(getprop("instrumentation/nav/nav-loc"))setprop(Lateral_arm,"LOC") else setprop(Lateral_arm,"VOR");
            setprop(Lateral,"HDG");
        }
    }elsif(NAVSRC=="NAV2"){
        if(getprop("instrumentation/nav[1]/data-is-valid")){
            if(getprop("instrumentation/nav[1]/nav-loc"))setprop(Lateral_arm,"LOC") else setprop(Lateral_arm,"VOR");
            setprop(Lateral,"HDG");
        }
    }elsif(NAVSRC=="FMS"){
        if(getprop("autopilot/route-manager/active"))setprop(Lateral,"LNAV");
    }
}

#######  PITCH WHEEL ACTIONS #############

var pitch_wheel=func(dir){
    var Vmode=getprop(Vertical);
    var CO = getprop("autopilot/settings/changeover");
    var amt=0;
    if(Vmode=="VS"){
        amt = int(getprop("autopilot/settings/vertical-speed-fpm")) + (dir* 100);
        amt = (amt < -8000 ? -8000 : amt > 6000 ? 6000 : amt);
        setprop("autopilot/settings/vertical-speed-fpm",amt);
    }elsif(Vmode=="FLC" or Vmode=="VFLC"){
        if(!CO){
            amt=getprop("autopilot/settings/target-speed-kt") + dir;
            amt = (amt < 80 ? 80 : amt > 340 ? 340 : amt);
            setprop("autopilot/settings/target-speed-kt",amt);
        }else{
            amt=getprop("autopilot/settings/target-speed-mach") + (dir*0.01);
            amt = (amt < 0.40 ? 0.40 : amt > 0.85 ? 0.85 : amt);
            setprop("autopilot/settings/target-speed-mach",amt);
        }
    }elsif(Vmode=="PTCH"){
        amt=getprop("autopilot/settings/target-pitch-deg") + (dir*0.1);
        amt = (amt < -20 ? -20 : amt > 20 ? 20 : amt);
        setprop("autopilot/settings/target-pitch-deg",amt)
    }
}

########    FD INTERNAL ACTIONS  #############

var set_pitch=func{
    setprop(Vertical,"PTCH");setprop("autopilot/settings/target-pitch-deg",getprop("orientation/pitch-deg"));
}

var set_roll=func{
    setprop(Lateral,"ROLL");setprop("autopilot/settings/target-roll-deg",0.0);
}

var set_apr=func{
    if(NAVSRC == "NAV1"){
        if(getprop("instrumentation/nav/nav-loc") and getprop("instrumentation/nav/has-gs")){
            setprop(Lateral_arm,"LOC");
            setprop(Vertical_arm,"GS");
            setprop(Lateral,"HDG");
        }
    }elsif(NAVSRC == "NAV2"){
    if(getprop("instrumentation/nav[1]/nav-loc") and getprop("instrumentation/nav[1]/has-gs")){
            setprop(Lateral_arm,"LOC");
            setprop(Vertical_arm,"GS");
            setprop(Lateral,"HDG");
        }
    }
}

setlistener("autopilot/settings/minimums", func(mn) {
    minimums=mn.getValue();
},1,0);


setlistener(NAVprop, func(Nv) {
    NAVSRC=Nv.getValue();
},1,0);

var update_nav=func{
    var sgnl = "- - -";
    var gs =0;
    if(NAVSRC == "NAV1"){
        if(getprop("instrumentation/nav/data-is-valid"))sgnl="VOR1";
        setprop("autopilot/internal/in-range",getprop("instrumentation/nav/in-range"));
        setprop("autopilot/internal/gs-in-range",getprop("instrumentation/nav/gs-in-range"));
        var dst=getprop("instrumentation/nav/nav-distance") or 0;
        dst*=0.000539;
        setprop("autopilot/internal/nav-distance",dst);
        setprop("autopilot/internal/nav-id",getprop("instrumentation/nav/nav-id"));
        if(getprop("instrumentation/nav/nav-loc"))sgnl="LOC1";
        if(getprop("instrumentation/nav/has-gs"))sgnl="ILS1";
        if(sgnl=="ILS1")gs = 1;
        setprop("autopilot/internal/gs-valid",gs);
        setprop("autopilot/internal/nav-type",sgnl);
        course_offset("instrumentation/nav[0]/radials/selected-deg");
        setprop("autopilot/internal/to-flag",getprop("instrumentation/nav/to-flag"));
        setprop("autopilot/internal/from-flag",getprop("instrumentation/nav/from-flag"));
    }elsif(NAVSRC == "NAV2"){
        if(getprop("instrumentation/nav[1]/data-is-valid"))sgnl="VOR2";
        setprop("autopilot/internal/in-range",getprop("instrumentation/nav[1]/in-range"));
        setprop("autopilot/internal/gs-in-range",getprop("instrumentation/nav[1]/gs-in-range"));
        var dst=getprop("instrumentation/nav[1]/nav-distance") or 0;
        dst*=0.000539;
        setprop("autopilot/internal/nav-distance",dst);
        setprop("autopilot/internal/nav-id",getprop("instrumentation/nav[1]/nav-id"));
        if(getprop("instrumentation/nav[1]/nav-loc"))sgnl="LOC2";
        if(getprop("instrumentation/nav[1]/has-gs"))sgnl="ILS2";
        if(sgnl=="ILS2")gs = 1;
        setprop("autopilot/internal/gs-valid",gs);
        setprop("autopilot/internal/nav-type",sgnl);
        course_offset("instrumentation/nav[1]/radials/selected-deg");
        setprop("autopilot/internal/to-flag",getprop("instrumentation/nav[1]/to-flag"));
        setprop("autopilot/internal/from-flag",getprop("instrumentation/nav[1]/from-flag"));
    }elsif(NAVSRC == "FMS"){
        setprop("autopilot/internal/nav-type","FMS1");
        setprop("autopilot/internal/in-range",1);
        setprop("autopilot/internal/gs-in-range",0);
        setprop("autopilot/internal/nav-distance",getprop("instrumentation/gps/wp/wp[1]/distance-nm"));
        setprop("autopilot/internal/nav-id",getprop("instrumentation/gps/wp/wp[1]/ID"));
        course_offset("instrumentation/gps/wp/wp[1]/bearing-mag-deg");
        setprop("autopilot/internal/to-flag",getprop("instrumentation/gps/wp/wp[1]/to-flag"));
        setprop("autopilot/internal/from-flag",getprop("instrumentation/gps/wp/wp[1]/from-flag"));
    }
}

var set_range = func(dir){
    wx_index+=dir;
    if(wx_index>5)wx_index=5;
    if(wx_index<0)wx_index=0;
    setprop("instrumentation/nd/range",wx_range[wx_index]);
}

var course_offset = func(src){
    var crs_set=getprop(src);
    var crs_offset= crs_set - getprop("orientation/heading-magnetic-deg");
    if(crs_offset>180)crs_offset-=360;
    if(crs_offset<-180)crs_offset+=360;
    setprop("autopilot/internal/course-offset",crs_offset);
    crs_offset+=getprop("autopilot/internal/cdi");
    if(crs_offset>180)crs_offset-=360;
    if(crs_offset<-180)crs_offset+=360;
    setprop("autopilot/internal/ap_crs",crs_offset);
    setprop("autopilot/internal/selected-crs",crs_set);
}

var monitor_L_armed = func{
    if(getprop(Lateral_arm)!=""){
        if(getprop("autopilot/internal/in-range")){
            var cdi=getprop("autopilot/internal/cdi");
            if(cdi < 40 and cdi > -40){
                setprop(Lateral,getprop(Lateral_arm));
                setprop(Lateral_arm,"");
            }
        }
    }
}

var monitor_V_armed = func{
    var Varm=getprop(Vertical_arm);
    var myalt=getprop("instrumentation/altimeter/indicated-altitude-ft");
    var asel=getprop("autopilot/settings/asel") * 100;
    var alterr=myalt-asel;
    if(Varm=="ASEL"){
        if(alterr >-250 and alterr <250){
            setprop(Vertical,"ALT");
            setprop(Vertical_arm,"");
        }
    }elsif(Varm=="VASEL"){
        if(alterr >-250 and alterr <250){
            setprop(Vertical,"VALT");
            setprop("instrumentation/gps/wp/wp[1]/altitude-ft",asel);
            setprop(Vertical_arm,"");
        }
    }elsif(Varm=="GS"){
        if(getprop(Lateral)=="LOC"){
            if(getprop("autopilot/internal/gs-in-range")){
                var gs_err=getprop("autopilot/internal/gs-deflection");
                var gs_dst=getprop("autopilot/internal/nav-distance");
                if(gs_dst <= 7.0){
                    if(gs_err >-0.25 and gs_err < 0.25){
                        setprop(Vertical,"GS");
                        setprop(Vertical_arm,"");
                    }
                }
            }
        }
    }
}

var monitor_AP_errors= func{
    var ralt=getprop("position/altitude-agl-ft");
    if(ralt<minimums)kill_Ap("");
    var rlimit=getprop("orientation/roll-deg");
    if(rlimit > 45 or rlimit< -45)kill_Ap("AP-FAIL");
    var plimit=getprop("orientation/pitch-deg");
    if(plimit > 30 or plimit< -30)kill_Ap("AP-FAIL");
}

var kill_Ap = func(msg){
    setprop(AP,msg);
    setprop(AutoCoord,Coord);
}

var get_ETE= func{
    var ttw = "--:--";
    var min =0;
    var hr=0;
    if(NAVSRC == "NAV1"){
        setprop("instrumentation/dme/frequencies/source","instrumentation/nav/frequencies/selected-mhz");
        min = int(getprop("instrumentation/dme/indicated-time-min"));
        if(min>60){
            var tmphr=(min*0.016666);
            hr=int(tmphr);
            var tmpmin=(tmphr-hr)*100;
            min=int(tmpmin);
        }
        ttw=sprintf("ETE %i:%02i",hr,min);
    }elsif(NAVSRC == "NAV2"){
        setprop("instrumentation/dme/frequencies/source","instrumentation/nav[1]/frequencies/selected-mhz");
        min = int(getprop("instrumentation/dme/indicated-time-min"));
        if(min>60){
            var tmphr=(min*0.016666);
            hr=int(tmphr);
            var tmpmin=(tmphr-hr)*100;
            min=int(tmpmin);
        }
        ttw=sprintf("ETE %s:%02i",hr,min);
    }elsif(NAVSRC == "FMS"){
        min = getprop("autopilot/route-manager/ete");
        min=int(min * 0.016666);
        if(min>60){
            var tmphr=(min*0.016666);
            hr=int(tmphr);
            var tmpmin=(tmphr-hr)*100;
            min=int(tmpmin);
        }
         ttw=sprintf("ETE %s:%02i",hr,min);
    }
    setprop("autopilot/internal/nav-ttw",ttw);
}


###  Main loop ###

var update_fd = func {
    update_nav();
    if(count==0)monitor_AP_errors();
    if(count==1)monitor_L_armed();
    if(count==2)monitor_V_armed();
     if(count==3)get_ETE();
    count+=1;
    if(count>3)count=0;
    settimer(update_fd, 0);
}
