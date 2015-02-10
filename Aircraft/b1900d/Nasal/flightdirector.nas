# FCS-65#

var FGC_65=props.globals.getNode("instrumentation/fgc-65",1);
    var fgc_power = 0;
var APP_65A=FGC_65.getNode("app-65a",1);
    var AP=APP_65A.initNode("AP","","STRING");
    var yd_btn=APP_65A.initNode("YD",0,"BOOL");
    var sr_btn=APP_65A.initNode("SR",0,"BOOL");
    var half_btn=APP_65A.initNode("BANK",1.0,"DOUBLE");
var FCP_65=FGC_65.getNode("fcp-65",1);
    var hdg_btn=FCP_65.initNode("hdg-btn",0,"BOOL");
    var nav_btn=FCP_65.initNode("nav-btn",0,"BOOL");
    var appr_btn=FCP_65.initNode("appr-btn",0,"BOOL");
    var bc_btn=FCP_65.initNode("bc-btn",0,"BOOL");
    var climb_btn=FCP_65.initNode("climb-btn",0,"BOOL");
    var alt_btn=FCP_65.initNode("alt-btn",0,"BOOL");
    var altsel_btn=FCP_65.initNode("altsel-btn",0,"BOOL");
    var vs_btn=FCP_65.initNode("vs-btn",0,"BOOL");
    var ias_btn=FCP_65.initNode("ias-btn",0,"BOOL");
    var dsc_btn=FCP_65.initNode("dsc-btn",0,"BOOL");
var Internal=FGC_65.getNode("internal",1);
    var appr_armed=Internal.initNode("appr-armed",0,"BOOL");
    var appr_enabled=Internal.initNode("appr-active",0,"BOOL");
    var nav_armed=Internal.initNode("nav-armed",0,"BOOL");
    var nav_enabled=Internal.initNode("nav-active",0,"BOOL");
    var Lmode=Internal.initNode("lateral","ROLL","STRING");
    var Larmed=Internal.initNode("lateral-arm","","STRING");
    var Vmode=Internal.initNode("vertical","PITCH","STRING");
    var Varmed=Internal.initNode("vertical-arm","","STRING");
    var FD_enabled=Internal.initNode("fd/enabled",1,"BOOL");
    var FD_pitch=Internal.initNode("fd/pitch",0.0,"DOUBLE");
    var FD_roll=Internal.initNode("fd/roll",0.0,"DOUBLE");
    var crs1_offset=Internal.initNode("offsets/crs1-brg",0.0,"DOUBLE");
    var crs2_offset=Internal.initNode("offsets/crs2-brg",0.0,"DOUBLE");
    var hdg_bug=Internal.initNode("offsets/hdg-bug",0.0,"DOUBLE");
    var nav1_offset=Internal.initNode("offsets/nav1-brg",0.0,"DOUBLE");
    var nav2_offset=Internal.initNode("offsets/nav2-brg",0.0,"DOUBLE");
var Settings=FGC_65.getNode("settings",1);
    var alt_tgt=Settings.initNode("alt",0,"INT");
    var hdg_tgt=Settings.initNode("hdg",0,"INT");
    var ias_tgt=Settings.initNode("ias",0,"INT");
    var pitch_tgt=Settings.initNode("pitch",0,"DOUBLE");
    var roll_tgt=Settings.initNode("roll",0,"DOUBLE");
    var vs_tgt=Settings.initNode("vs",0,"INT");

var gps_enabled=props.globals.initNode("instrumentation/nav/slaved-to-gps");
var localizer=props.globals.initNode("instrumentation/nav/nav-loc");
var BC=props.globals.initNode("instrumentation/nav/back-course-btn");
var BNK=props.globals.initNode("instrumentation/fgc-65/settings/bank");
var NavSrc=props.globals.initNode("instrumentation/fgc-65/internal/nav-src");
var SG1=props.globals.initNode("instrumentation/nav/signal-quality-norm");
var lateral_cap=props.globals.initNode("instrumentation/nav/heading-needle-deflection-norm");
var gs_cap=props.globals.initNode("instrumentation/nav/gs-needle-deflection-norm");
var gs_rng=props.globals.initNode("instrumentation/nav/gs-in-range");
var fgc_bus=props.globals.initNode("systems/electrical/outputs/fgc-65",0.0,"DOUBLE");
var btn_timer=0;

var count=0;


setlistener("/sim/signals/fdm-initialized", func {
    settimer(update_fd, 5);
    print("FCS-65 loaded");
});

setlistener(fgc_bus, func(pwr){
    if(pwr.getValue()>5)fgc_power=1 else fgc_power=0;
},1,0);

setlistener("instrumentation/nav/slaved-to-gps", func(gps) {
    if(gps.getValue()){
        if(Larmed.getValue() !=""){
            Larmed.setValue("");
            Lmode.setValue("LNV1");
            nav_armed.setValue(0);
            nav_enabled.setValue(1);
        }
    }else{
        Larmed.setValue("");
        Lmode.setValue("ROLL");
        nav_armed.setValue(0);
        nav_enabled.setValue(0);
    }
});


var btn_pressed=func(btn,val,unit){
    if(fgc_power==0)return;
    if(val!=0){
        btn_timer += 1;
        if(btn_timer==5){
            if(unit==0){
                FCP65_input(btn);
            }elsif(unit==1){
                APP65_input(btn);
            }
        }
    }else btn_timer=0;
}

var FCP65_input = func(mode){
    var tmp = "";
    var nv ="";
    if(mode=="hdg"){
        tmp = Lmode.getValue();
        if(tmp != "HDG") tmp="HDG" else tmp = "ROLL";
        Lmode.setValue(tmp);
        Larmed.setValue("");
        appr_enabled.setValue(0);
        nav_enabled.setValue(0);
    }elsif(mode=="nav"){
        tmp = nav_armed.getValue();
        var tmp1 = "";
        tmp=1-tmp;
        nav_armed.setValue(tmp);
        if(tmp == 1){
            if(localizer.getValue()) tmp1 = "LOC1" else tmp1 = "VOR1";
            if(gps_enabled.getValue())tmp1="LNV1";
            Larmed.setValue(tmp1);
            Lmode.setValue("HDG");
        }else Larmed.setValue("ROLL");
    }elsif(mode=="appr"){
            tmp = appr_armed.getValue();
            tmp =1-tmp;
            if(!localizer.getValue())tmp=0;
            appr_armed.setValue(tmp);
            nav_enabled.setValue(0);
            nav_armed.setValue(0);
            appr_enabled.setValue(0);
            if(tmp==1) Larmed.setValue("LOC1") else Larmed.setValue("ROLL");
            Varmed.setValue("");
    }elsif(mode=="bc"){
        tmp = Lmode.getValue();
        if(!BC.getValue()){
            if(tmp == "LOC1")BC.setValue(1);
        }else BC.setValue(0);
    }elsif(mode=="alt"){
        tmp = Vmode.getValue();
        if(tmp != "ALT"){
            if(Lmode.getValue()!="ROLL" or AP.getValue()=="AP"){
                tmp = "ALT";
                set_alt();
                }
        }else tmp ="PITCH";
        Vmode.setValue(tmp);
    }elsif(mode=="vs"){
        tmp = Vmode.getValue();
        if(tmp != "VS"){
            if(Lmode.getValue()!="ROLL" or AP.getValue()=="AP"){
                tmp = "VS";
                set_vs();
            }
        }else tmp ="PITCH";
        Vmode.setValue(tmp);
    }elsif(mode=="ias"){
        tmp = Vmode.getValue();
        if(tmp != "IAS"){
            if(Lmode.getValue()!="ROLL" or AP.getValue()=="AP"){
                tmp = "IAS";
                set_ias();
            }
        }else tmp ="PITCH";
        Vmode.setValue(tmp);
    }
}

var APP65_input = func(mode){
    var tmp="";
    if(mode=="ap"){
        var ap = AP.getValue();
        if(ap!="AP"){
        AP.setValue("AP");
        if(!yd_btn.getValue())yd_btn.setValue(1);
        if(Vmode.getValue()=="PITCH") set_pitch();
        if(Lmode.getValue()=="ROLL") set_roll();
        } else AP.setValue("");
    }elsif(mode=="yd"){
        var yd = yd_btn.getValue();
        yd=1-yd;
         yd_btn.setValue(yd);
    }elsif(mode=="sr"){
        var sr = sr_btn.getValue();
        sr=1-sr;
        sr_btn.setValue(sr);
    }elsif(mode=="bnk"){
        tmp=half_btn.getValue();
        if(tmp==1)tmp=0.5 else tmp=1;
        half_btn.setValue(tmp);
    }
}

pitch_wheel = func(dir){
    if(fgc_power==0)return;
    var tmp = Vmode.getValue();
    if(tmp=="VS"){
        var tmp1 = getprop("instrumentation/fgc-65/settings/vs");
        tmp1+=(200 * dir);
        if(tmp1<-2000)tmp1=-2000;
        if(tmp1>3000)tmp1=3000;
        setprop("instrumentation/fgc-65/settings/vs",tmp1);
    }elsif(tmp=="IAS"){
        var tmp1 = getprop("instrumentation/fgc-65/settings/ias");
        tmp1+=(1 * dir);
        if(tmp1<100)tmp1=100;
        if(tmp1>240)tmp1=240;
        setprop("instrumentation/fgc-65/settings/ias",tmp1);
    }elsif(tmp=="ALT"){
        var tmp1 = getprop("instrumentation/fgc-65/settings/alt");
        tmp1+=(100 * dir);
        if(tmp1<1500)tmp1=1500;
        if(tmp1>25000)tmp1=25000;
        setprop("instrumentation/fgc-65/settings/alt",tmp1);
    }elsif(tmp=="PITCH"){
        var tmp1 = getprop("instrumentation/fgc-65/settings/pitch");
        tmp1+=(0.5 * dir);
        if(tmp1<-10.0)tmp1=-10.0;
        if(tmp1>15.0)tmp1=15.0;
        setprop("instrumentation/fgc-65/settings/pitch",tmp1);
    }
}


var set_pitch=func {
    setprop("instrumentation/fgc-65/settings/pitch",getprop("orientation/pitch-deg"));
}

var set_roll=func {
    setprop("instrumentation/fgc-65/settings/roll",getprop("orientation/roll-deg"));
}

var set_ias=func {
    setprop("instrumentation/fgc-65/settings/ias",int(getprop("instrumentation/airspeed-indicator/indicated-speed-kt")));
}

var set_vs=func {
    setprop("instrumentation/fgc-65/settings/vs",(int(getprop("autopilot/internal/vert-speed-fpm")*0.01) * 100));
}

var set_alt=func {
    setprop("instrumentation/fgc-65/settings/alt",int(getprop("instrumentation/altimeter/indicated-altitude-ft") * 0.01) *100);
}

var monitor_Larmed=func {
    var la = Larmed.getValue();
    var trkoffset = abs(getprop("instrumentation/fgc-65/internal/offsets/crs1-brg"));
    var capture=0;
    var sgnl=SG1.getValue();
    var dfl=abs(lateral_cap.getValue());
    if(la == "")return;
    if(la=="LNV1")capture=1;
    if(sgnl >0.95 and trkoffset<90){
        if(appr_armed.getValue()){
            if(dfl<0.7){
                appr_armed.setValue(0);
                appr_enabled.setValue(1);
                capture=1;
                Varmed.setValue("GS");
            }
        }else{
            if(dfl<0.9){
                capture=1;
            }
        }
    }
    if(capture==1){
        Lmode.setValue(Larmed.getValue());
        Larmed.setValue("");
        nav_armed.setValue(0);
        nav_enabled.setValue(1);
    }
}

var monitor_Varmed=func {
     var va = Varmed.getValue();
    if(va == "")return;
    if(va=="GS"){
        if(gs_rng.getValue()){
            if(abs(gs_cap.getValue())<0.15){
                Vmode.setValue(va);
                Varmed.setValue("");
            }
        }
    }else{
        Vmode.setValue(Varmed.getValue());
        Varmed.setValue("");
    }
}

var monitor_faults=func {
    if(AP.getValue()=="AP"){
        if(getprop("position/altitude-agl-ft")<200) AP.setValue("");
        var ptc = abs(getprop("orientation/pitch-deg"));
        var rll = abs(getprop("orientation/roll-deg"));
        if(rll>60) AP.setValue("AP FAIL");
        if(ptc>30) AP.setValue("AP FAIL");
    }
}

var test_alerter=func {
    var dflt = 0;
    var myalt=getprop("instrumentation/altimeter/indicated-altitude-ft");
    var asel=getprop("instrumentation/alt-alerter/fl") * 100;
    var dev = abs(myalt-asel);
    if(dev < 1000 and dev>300) dflt=1;
    if(dev <= 25) dflt=1;
    setprop("instrumentation/alt-alerter/alert",dflt * getprop("instrumentation/alt-alerter/enabled"));
}

var update_fd = func {
    
    if(count==0)monitor_Larmed();
    if(count==1)monitor_Varmed();
    if(count==2)monitor_faults();
    if(count==3)test_alerter();
    count+=1;
    if(count>3)count=0;
settimer(update_fd, 0); 
}
