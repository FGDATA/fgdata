####    simple electrical system    ####
var main_bus=0;
var count=0;

var strobe_switch = props.globals.initNode("controls/lighting/strobe/switch",0,"BOOL");
aircraft.light.new("controls/lighting/strobe", [0.05, 1.30], strobe_switch);
var beacon_switch = props.globals.initNode("controls/lighting/beacon/switch",0,"BOOL");
aircraft.light.new("controls/lighting/beacon", [1.0, 1.0], beacon_switch);

#####################################
setlistener("/sim/signals/fdm-initialized", func {
    settimer(update_electrical,5);
    print("Electrical System ... ok");
});


update_bus1 = func(pwr){
    setprop("systems/electrical/outputs/lights/landing-lights[0]",pwr * getprop("controls/lighting/landing-lights"));
    setprop("systems/electrical/outputs/lights/landing-lights[1]",pwr * getprop("controls/lighting/landing-lights[1]"));
    setprop("systems/electrical/outputs/lights/taxi-lights",pwr * getprop("controls/lighting/taxi-lights"));
    setprop("systems/electrical/outputs/lights/logo-lights",pwr * getprop("controls/lighting/logo-lights"));
    setprop("systems/electrical/outputs/lights/nav-lights",pwr * getprop("controls/lighting/nav-lights"));
    setprop("systems/electrical/outputs/lights/recog-lights",pwr * getprop("controls/lighting/recog-lights"));
    setprop("systems/electrical/outputs/lights/instrument-lights",pwr * getprop("controls/lighting/instruments-norm"));
}

update_bus2 = func(pwr){
    var avn = pwr * getprop("controls/electric/avionics-switch");
    setprop("systems/electrical/outputs/mk-viii",avn);
    setprop("systems/electrical/outputs/turn-coordinator",avn);
    setprop("systems/electrical/outputs/transponder",avn);
    setprop("systems/electrical/outputs/gps",avn);
    setprop("systems/electrical/outputs/dme",avn);
    setprop("systems/electrical/outputs/adf",avn);
}

update_bus3 = func(pwr){
    setprop("systems/electrical/LH-ac-bus",pwr * 110);
    setprop("systems/electrical/RH-ac-bus",pwr * 110);
    setprop("systems/electrical/outputs/efis[0]",pwr * getprop("controls/electric/efis/bank[0]"));
    setprop("systems/electrical/outputs/efis[1]",pwr * getprop("controls/electric/efis/bank[1]"));
    setprop("systems/electrical/outputs/lights/eng-lights",pwr * getprop("controls/lighting/eng-norm"));
    setprop("systems/electrical/outputs/starter[0]",pwr * getprop("controls/engines/engine/starter"));
    setprop("systems/electrical/outputs/starter[1]",pwr * getprop("controls/engines/engine[1]/starter"));
}

update_bus4 = func(pwr){
    var avn = pwr * getprop("controls/electric/avionics-switch");
    setprop("systems/electrical/outputs/nav",avn);
    setprop("systems/electrical/outputs/nav[1]",avn);
    setprop("systems/electrical/outputs/comm",avn);
    setprop("systems/electrical/outputs/comm[1]",avn);
    setprop("systems/electrical/outputs/fgc-65",avn);
}

update_strobes = func(pwr){
    var bcn =getprop("controls/lighting/beacon/state");
    setprop("systems/electrical/outputs/lights/strobe",pwr * getprop("controls/lighting/strobe/state"));
    setprop("systems/electrical/outputs/lights/beacon",pwr * bcn);
    setprop("systems/electrical/outputs/lights/beacon[1]",pwr * (1-bcn));
}

update_electrical = func {
    var power=0;
    var load1=0.0;
    var load2=0.0;
    var volts=0;
    var AC=0;
    var invrtr=getprop("controls/electric/inverter-switch") or 0;
    var gen1=getprop("engines/engine[0]/running") * getprop("controls/electric/engine/bus-tie");
    var gen2=getprop("engines/engine[1]/running") * getprop("controls/electric/engine[1]/bus-tie");
    if(getprop("controls/electric/battery-switch")){power=1;volts=24;}
    if(gen1){power=1;volts=28;load1=1.0;if(gen2)load1-=0.5;}
    if(gen2){power=1;volts=28;load2=1.0;if(gen1)load2-=0.5;}
    setprop("systems/electrical/gen-load[0]",load1);
    setprop("systems/electrical/gen-load[1]",load2);
    setprop("systems/electrical/volts",volts);
    AC = 115 * (invrtr*power);
    setprop("systems/electrical/AC",AC);
    update_strobes(power);
    if(count==0)update_bus1(power);
    if(count==1)update_bus2(volts);
    if(count==2)update_bus3(power);
    if(count==3)update_bus4(volts);
    count +=1;
    if(count>3)count=0;
settimer(update_electrical, 0);
}