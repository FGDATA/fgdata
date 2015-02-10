###### Primus 1000 system ########
var FDMODE = props.globals.getNode("/instrumentation/primus1000/fdmode",1);
var NavPtr1=props.globals.getNode("/instrumentation/primus1000/dc550/nav1ptr",1);
var NavPtr2=props.globals.getNode("/instrumentation/primus1000/dc550/nav2ptr",1);
var NavPtr1_offset=props.globals.getNode("/instrumentation/primus1000/dc550/nav1ptr-hdg-offset",1);
var NavPtr2_offset=props.globals.getNode("/instrumentation/primus1000/dc550/nav2ptr-hdg-offset",1);
var RAmode=props.globals.getNode("/instrumentation/primus1000/ra-mode",1);
var DC550 = props.globals.getNode("/instrumentation/primus1000/dc550",1);
var fms_enabled =0;

#Primus 1000 class 
# ie: var primus = P1000.new();
var P1000 = {
    new : func(){
        m = { parents : [P1000]};
        m.primus = props.globals.getNode("instrumentation/primus1000",1);
        m.fd_mode=m.primus.getNode("fdmode",1);
        m.fd_mode.setIntValue(0);
        m.ra_mode=m.primus.getNode("ra-mode",1);
        m.ra_mode.setIntValue(0);
        m.fms_mode=m.primus.getNode("fms-mode",1);
        m.fms_mode.setBoolValue(0);

        m.dc550 = m.primus.getNode("dc550",1);
        m.baro_mode.setBoolValue(1);
        m.baro_kpa = m.efis.getNode("baro-kpa",1);
        m.baro_kpa.setDoubleValue(0);
        m.temp = m.efis.getNode("fixed-temp",1);
        m.temp.setDoubleValue(0);
    return m;
    },
#### convert inhg to kpa ####
    calc_kpa : func{
        var kp = getprop("instrumentation/altimeter/setting-inhg");
        me.baro_kpa.setValue(kp * 33.8637526);
        },
#### update temperature display ####
    update_temp : func{
        var tmp = getprop("/environment/temperature-degc");
        if(tmp < 0.00){
            tmp = -1 * tmp;
        }
        me.temp.setValue(tmp);
    },

};


var NavDist=props.globals.getNode("/instrumentation/primus1000/nav-dist-nm",1);
var NavType=props.globals.getNode("/instrumentation/primus1000/nav-type",1);
var NavString=props.globals.getNode("/instrumentation/primus1000/nav-string",1);
var NavID=props.globals.getNode("/instrumentation/primus1000/nav-id",1);
var FMSMode=props.globals.getNode("/instrumentation/primus1000/fms-mode",1);
var APoff=props.globals.getNode("/autopilot/locks/passive-mode",1);
var FMS_VNAV =["VNV","FMS"];
var NAV_SRC = ["VOR1","VOR2","ILS1","ILS2","FMS"];
var ET = aircraft.timer.new("/instrumentation/primus1000/pfd/ET-sec", 5,0);
var ETmin = props.globals.getNode("/instrumentation/primus1000/pfd/ET-min",1);
var EThour = props.globals.getNode("/instrumentation/primus1000/pfd/ET-hour",1);

var get_pointer_offset = func{
    var test=arg[0];
    var src =arg[1];
    var offset = 0;
    var hdg = getprop("/orientation/heading-magnetic-deg");
    if(test==0 or test == nil){return 0.0;}

    if(test == 1){
        if(src == 1){
        offset=getprop("/instrumentation/nav[1]/heading-deg");
        }else{
        offset=getprop("/instrumentation/nav/heading-deg");
        }
        if(offset == nil){offset=0.0;}
        offset -= hdg;
        if(offset < -180){offset += 360;}
        elsif(offset > 180){offset -= 360;}
        }elsif(test == 2){
            offset = props.globals.getNode("/instrumentation/adf/indicated-bearing-deg").getValue();
            }elsif(test == 3){
                offset = props.globals.getNode("/autopilot/internal/true-heading-error-deg").getValue();
                }
        return offset;
    }

var update_pfd = func{

    NavPtr1_offset.setValue(get_pointer_offset(NavPtr1.getValue(),0));
    NavPtr2_offset.setValue(get_pointer_offset(NavPtr2.getValue(),1));
    var id = "   ";
    var GSPDstring = "";
    var nm_calc=0.0;
    if(fms_enabled ==0){
        if(props.globals.getNode("/instrumentation/nav/data-is-valid").getBoolValue()){
            nm_calc = getprop("/instrumentation/nav/nav-distance");
            if(nm_calc == nil){nm_calc = 0.0;}
            nm_calc = 0.000539 * nm_calc;
            if(getprop("/instrumentation/nav/has-gs")){NavType.setValue(2);}
            id = getprop("instrumentation/nav/nav-id");
            if(id ==nil){id= "   ";}
        }
    }else{
        nm_calc = getprop("/autopilot/route-manager/wp/dist");
        if(nm_calc == nil){nm_calc = 0.0;}
        id = getprop("autopilot/route-manager/wp/id");
        if(id ==nil){id= "   ";}
     }
    NavDist.setValue(nm_calc);
    var ns= NavType.getValue();
    setprop("/instrumentation/primus1000/nav-string",NAV_SRC[ns]);
    setprop("/instrumentation/primus1000/nav-id",id);
    if(getprop("systems/electrical/ac-volts") < 5){
        setprop("instrumentation/primus1000/pfd/serviceable",0);
        setprop("instrumentation/primus1000/mfd/serviceable",0);
    }else{
        setprop("instrumentation/primus1000/pfd/serviceable",1);
        setprop("instrumentation/primus1000/mfd/serviceable",1);
    }

    var et = getprop("/instrumentation/primus1000/pfd/ET-sec");
    var ethour = et * 0.000277;
    EThour.setIntValue(ethour);
    var etmin = (ethour-EThour.getValue()) * 60;
    ETmin.setIntValue(etmin);
}



var update_mfd = func{
}

var update_fuel = func{
    var total_fuel = 0;
    if(getprop("/sim/flight-model")=="yasim"){
        FuelDensity=props.globals.getNode("consumables/fuel/tank[0]/density-ppg",1).getValue();
        var pph=getprop("/engines/engine[0]/fuel-flow-gph");
        if(pph == nil){pph = 0.0};
        FuelPph1.setValue(pph* FuelDensity);
        pph=getprop("/engines/engine[1]/fuel-flow-gph");
        if(pph == nil){pph = 0.0};
        FuelPph2.setValue(pph* FuelDensity);
        }else{
        total_fuel=props.globals.getNode("/fdm/jsbsim/propulsion/total-fuel-lbs").getValue();
        setprop("consumables/fuel/total-fuel-lbs",total_fuel);
    }
}

var update_eicas = func{
    update_fuel();
    }

setlistener("/instrumentation/primus1000/dc550/fms", func(md){
    var mode = md.getValue();
    FMSMode.setValue(FMS_VNAV[mode]);
    if(mode){NavType.setValue(4);
        fms_enabled=1;
        }else{
        NavType.setValue(0);
        fms_enabled=0;
    }
},0,0);



var update_p1000 = func {
    update_pfd();
    update_mfd();
    update_eicas();
    settimer(update_p1000,0);
    }

setlistener("/sim/signals/fdm-initialized", func {
    FDMODE.setBoolValue(1);
    NavPtr1.setDoubleValue(0.0);
    NavPtr2.setDoubleValue(0.0);
    NavPtr1_offset.setDoubleValue(0.0);
    NavPtr2_offset.setDoubleValue(0.0);
    DC550.getNode("hsi",1).setBoolValue(0);
    DC550.getNode("cp",1).setBoolValue(0);
    DC550.getNode("hpa",1).setBoolValue(0);
    DC550.getNode("ttg",1).setBoolValue(0);
    DC550.getNode("et",1).setBoolValue(0);
    DC550.getNode("fms",1).setBoolValue(0);
    FMSMode.setValue("VNV");
    NavType.setIntValue(0);
    NavString.setValue("VOR1");
    RAmode.setValue(0.0);
    NavDist.setValue(0.0);
    Hyd1.setValue(0.0);
    Hyd2.setValue(0.0);
    FuelPph1.setValue(0.0);
    FuelPph2.setValue(0.0);
    APoff.setBoolValue(1);
    props.globals.getNode("instrumentation/primus1000/pfd/serviceable",1).setBoolValue(1);
    props.globals.getNode("instrumentation/primus1000/mfd/serviceable",1).setBoolValue(1);
    props.globals.getNode("instrumentation/primus1000/mfd/mode",1).setValue("normal");
    ET.reset();
    ETmin.setIntValue(0);
    EThour.setIntValue(0);
    print("Primus 1000 systems ... check");
    settimer(update_p1000,1);
    });

