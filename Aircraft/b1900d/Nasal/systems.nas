####B1900d systems
#### Syd Adams


aircraft.livery.init("Aircraft/b1900d/Models/Liveries");
var FDM ="";
var tanks=[];
var N1=[0.0,0.0];
var fuel_cutoff=[0,0];


var Wiper = {
    new : func(prop,power,settings){
        m = { parents : [Wiper] };
        m.direction = 1;
        m.delay_count = 0;
        m.spd_factor = 0;
        m.speed_prop=[];
        m.delay_prop=[];
        m.node = props.globals.getNode(prop,1);
        m.power = props.globals.getNode(power,1);
        if(m.power.getValue()==nil)m.power.setDoubleValue(0);
        m.position = m.node.getNode("position-norm", 1);
        m.position.setDoubleValue(0);
        m.switch = m.node.getNode("switch", 1);
        m.switch.setIntValue(0);
        for(var i=0; i<settings; i+=1) {
            append(m.speed_prop,m.node.getNode("arc-sec["~i~"]",1));
            if(m.speed_prop[i].getValue()==nil)m.speed_prop[i].setDoubleValue(i);
            append(m.delay_prop,m.node.getNode("delay-sec["~i~"]",1));
            if(m.delay_prop[i].getValue()==nil)m.delay_prop[i].setDoubleValue(i * 0.5);
        }
        return m;
    },
    active: func{
    if(me.power.getValue()<=5)return;
    var sw=me.switch.getValue();
    var sec =getprop("/sim/time/delta-sec");
    var spd_factor = 1/me.speed_prop[sw].getValue();
    var pos = me.position.getValue();
    if(sw==0){
        spd_factor = 1/me.speed_prop[1].getValue();
        if(pos <=0){
        me.position.setValue(0);
        return;
        }
    } 

    if(pos >=1.000){
        me.direction=-1;
        }elsif(pos <=0){
            me.direction=1;
            var dly=me.delay_prop[sw].getValue();
            if(dly>0){
                me.direction=0;
                me.delay_count+=sec;
                if(me.delay_count >= dly){
                    me.delay_count=0;
                    me.direction=1;
                }
            }
        }
    var wiper_time = spd_factor*sec;
    pos =pos+(wiper_time * me.direction);
    me.position.setValue(pos);
    }
};

###### warning panel ########
var Alarm = {
    new : func(prop){
    m = { parents : [Alarm] };
    m.counter=0;
    m.gpwscounter=0;
    m.gpwstimer=0;
    m.dh_armed=0;
    m.warning_props=["L-fuel-psi","cbn-alt","cbn-diff","R-fuel-psi","L-oil-psi",
    "L-env-fail","cbn-door","R-env-fail","R-oil-psi","L-ac-bus","crg-door",
    "R-ac-bus","L-bleed-air","AP-trim","emer-lights","AP-fail","R-bleed-air"];
    m.caution_props=["LDCgen","LFQty","BATchg","RFQty","RDCgen",
    "FXfer","Taxi","Lignition","Rignition","LFuelCol","RFuelCol"];
    m.warning_index=[];
    m.caution_index=[];
    m.node = props.globals.initNode(prop);
    m.Warning= m.node.initNode("warning");
    m.Caution = m.node.initNode("caution");
        m.MCaution = m.Caution.initNode("Master",0,"BOOL");
        m.Ctest = m.Caution.initNode("test",0,"BOOL");
        m.MCflasher = m.Caution.initNode("flasher",0,"INT");
        m.Warning = m.node.initNode("warning");
        m.MWarning = m.Warning.initNode("Master",0,"BOOL");
        m.Wtest = m.Warning.initNode("test",0,"BOOL");
        m.MWflasher = m.Warning.initNode("flasher",0,"INT");
        m.GPWS = m.node.initNode("gpws");
        m.volume=m.GPWS.initNode("volume",0.5,"DOUBLE");
        m.altitude_active=m.GPWS.initNode("altitude-active",0,"BOOL");
        m.altitude_callout=m.GPWS.initNode("altitude-callout",0,"INT");
        m.terrain_active=m.GPWS.initNode("terrain-active",0,"BOOL");
        m.terrain_alert=m.GPWS.initNode("terrain-alert",0,"BOOL");
        m.bank=m.GPWS.initNode("bank-angle",0,"BOOL");
        m.pitch=m.GPWS.initNode("pitch",0,"BOOL");
        m.sink=m.GPWS.initNode("sink-rate",0,"BOOL");
        m.minimums=m.GPWS.initNode("minimums",0,"BOOL");
        for(var i=0; i<size(m.warning_props); i+=1) {
            append(m.warning_index,m.Warning.initNode(m.warning_props[i],0,"BOOL"));
        }
        for(var i=0; i<size(m.caution_props); i+=1) {
            append(m.caution_index,m.Caution.initNode(m.caution_props[i],0,"BOOL"));
        }
    return m;
    },

###############
    check_caution:func{
        var pwr=getprop("systems/electrical/volts") or 0;
        if(pwr==0)return;
        var smpl=0;
        var Ctest=me.MCaution.getValue();
        if(Ctest){
            var Cflash =me.MCflasher.getValue();
            Cflash=1-Cflash;
            me.MCflasher.setValue(Cflash);
        }else{
            me.MCflasher.setValue(Ctest);
        }
        if(getprop("consumables/fuel/tank[0]/level-lbs")<324){
        smpl=1;me.MCaution.setValue(1);}
        me.caution_index[1].setValue(smpl);
        smpl=0;
        if(getprop("consumables/fuel/tank[0]/level-lbs")<53){
        smpl=1;me.MCaution.setValue(1);}
        me.caution_index[9].setValue(smpl);
        smpl=0;
        if(getprop("consumables/fuel/tank[1]/level-lbs")<53){
        smpl=1;me.MCaution.setValue(1);}
        me.caution_index[10].setValue(smpl);
        smpl=0;
        if(getprop("consumables/fuel/tank[1]/level-lbs")<324){
        smpl=1;me.MCaution.setValue(1);}
        me.caution_index[3].setValue(smpl);
        smpl=0;
        if(!getprop("controls/electric/engine/generator")){
        smpl=1;me.MCaution.setValue(1);}
        me.caution_index[0].setValue(smpl);
        smpl=0;
        if(!getprop("controls/electric/engine[1]/generator")){
        smpl=1;me.MCaution.setValue(1);}
        me.caution_index[4].setValue(smpl);
        smpl=0;
        if(!getprop("controls/electric/engine[0]/generator") and !getprop("controls/electric/engine[1]/generator")){
        smpl=1;me.MCaution.setValue(1);}
        me.caution_index[2].setValue(smpl);
        smpl=0;
        if(getprop("controls/fuel/transfer")!="off")smpl=1;
        me.caution_index[5].setValue(smpl);
        smpl=0;
        if(!getprop("controls/gear/gear-down") and getprop("controls/lighting/taxi-lights"))smpl=1;
            me.caution_index[6].setValue(smpl);

        me.caution_index[7].setValue(getprop("controls/engines/engine[0]/ignition"));
        me.caution_index[8].setValue(getprop("controls/engines/engine[1]/ignition"));
    },
###############
    check_warning:func{
        var pwr=getprop("systems/electrical/volts") or 0;
        if(pwr==0)return;
        var testbutton=me.Wtest.getValue();
        var master=me.MWarning.getValue();
        var test1=0;
        var test2=0;
        var ac1=0;
        var ac2=0;
        var cbndoor=0;
        if(master){
                var Wflash =me.MWflasher.getValue();
                Wflash=1-Wflash;
                me.MWflasher.setValue(Wflash);
            }else{
                me.MWflasher.setValue(0);
            }

        if(pwr<5){
            master=0;
            test1=0;
            test2=0;
            ac1=0;
            ac2=0;
            cbndoor=0;
            testbutton=0;
        }elsif(testbutton){
            master=1;
            test1=1;
            test2=1;
            ac1=1;
            ac2=1;
            cbndoor=1;
        }else{
            if(getprop("engines/engine/n1")<50){
                test1=1;
                master=1;
            }
            if(getprop("engines/engine[1]/n1")<50){
                test2=1;
                master=1;
            }
            if(getprop("systems/electrical/LH-ac-bus")<100){
                ac1=1;
                master=1;
            }
            if(getprop("systems/electrical/RH-ac-bus")<100){
                ac2=1;
                master=1;
            }
            if(getprop("controls/cabin-door/position-norm")>0){
                cbndoor=1;
                master=1;
            }
        }
            me.MWarning.setValue(master);
            me.warning_index[0].setValue(test1);
            me.warning_index[4].setValue(test1);
            me.warning_index[5].setValue(test1);
            me.warning_index[12].setValue(test1);

            me.warning_index[3].setValue(test2);
            me.warning_index[7].setValue(test2);
            me.warning_index[8].setValue(test2);
            me.warning_index[16].setValue(test2);

            me.warning_index[9].setValue(ac1);
            me.warning_index[11].setValue(ac2);

            me.warning_index[1].setValue(testbutton);
            me.warning_index[2].setValue(testbutton);
            me.warning_index[10].setValue(testbutton);
            me.warning_index[13].setValue(testbutton);
            me.warning_index[14].setValue(testbutton);
            me.warning_index[15].setValue(testbutton);
            me.warning_index[6].setValue(cbndoor);


    }
};





var S_volume = props.globals.initNode("/sim/sound/E_volume",0.2);
var Engstep = 0;
var wiper = Wiper.new("controls/electric/wipers","systems/electrical/volts",3);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10);
FHmeter.stop();
var alert=Alarm.new("instrumentation/annunciators");

setlistener("/sim/signals/fdm-initialized", func {
    setprop("/instrumentation/clock/flight-meter-hour",0);
    print("systems loaded");
    FDM=getprop("sim/flight-model");
    setprop("consumables/fuel/tank[0]/selected",1);
    setprop("consumables/fuel/tank[1]/selected",1);
    setprop("consumables/fuel/tank[2]/selected",0);
    setprop("consumables/fuel/tank[3]/selected",0);
     settimer(update_systems, 2);
    settimer(update_alarms,0);
    });


setlistener("controls/fuel/Laux-switch", func(laux){
    if(laux.getValue()=="auto"){
        setprop("consumables/fuel/tank[2]/selected",1);
        setprop("consumables/fuel/tank[0]/selected",0);
    }else{
        setprop("consumables/fuel/tank[0]/selected",1);
        setprop("consumables/fuel/tank[2]/selected",0);
        }
},0,0);

setlistener("controls/fuel/Raux-switch", func(raux){
    if(raux.getValue()=="auto"){
        setprop("consumables/fuel/tank[3]/selected",1);
        setprop("consumables/fuel/tank[1]/selected",0);
    }else{
        setprop("consumables/fuel/tank[1]/selected",1);
        setprop("consumables/fuel/tank[3]/selected",0);
        }
},0,0);

var update_fuel = func{
    if(getprop("controls/fuel/gauge-switch")=="auxilary"){
        setprop("consumables/fuel/gauge[0]",getprop("consumables/fuel/tank[2]/level-lbs"));
        setprop("consumables/fuel/gauge[1]",getprop("consumables/fuel/tank[3]/level-lbs"));
    }else{
        setprop("consumables/fuel/gauge[0]",getprop("consumables/fuel/tank[0]/level-lbs"));
        setprop("consumables/fuel/gauge[1]",getprop("consumables/fuel/tank[1]/level-lbs"));
    }

    if(getprop("consumables/fuel/tank[2]/selected")){
        if(getprop("consumables/fuel/tank[2]/level-lbs")<=3.35){
            setprop("consumables/fuel/tank[2]/selected",0);
            setprop("consumables/fuel/tank[0]/selected",1);
            }
        }
    if(getprop("consumables/fuel/tank[3]/selected")){
        if(getprop("consumables/fuel/tank[3]/level-lbs")<=3.35){
            setprop("consumables/fuel/tank[3]/selected",0);
            setprop("consumables/fuel/tank[1]/selected",1);
        }
    }
}


setlistener("/sim/current-view/internal", func(vw){
    if(vw.getValue()){
        S_volume.setValue(0.2);
        }else{
            S_volume.setValue(1.0);
        }
},1,0);

setlistener("/sim/model/start-idling", func(idle){
    var run= idle.getBoolValue();
    if(run){
        Startup();
    }else{
        Shutdown();
    }
},0,0);

setlistener("/gear/gear[1]/wow", func(gr){
    if(gr.getBoolValue()){
    FHmeter.stop();setprop("gear/alarm-enabled",1);
    }else{FHmeter.start();setprop("controls/cabin-door/open",0);}
},0,0);

setlistener("controls/engines/engine[0]/condition", func(c1){
    if(c1.getValue() <= 0.01) fuel_cutoff[0]=1 else fuel_cutoff[0]=0;
    setprop("controls/engines/engine[0]/cutoff",fuel_cutoff[0]);
},1,0);

setlistener("controls/engines/engine[1]/condition", func(c2){
    if(c2.getValue() <= 0.01) fuel_cutoff[1]=1 else fuel_cutoff[1]=0;
    setprop("controls/engines/engine[1]/cutoff",fuel_cutoff[1]);
},1,0);


var Startup = func{
setprop("controls/engines/engine[0]/cutoff",0);
setprop("controls/engines/engine[1]/cutoff",0);
setprop("controls/electric/engine[0]/generator",1);
setprop("controls/electric/engine[1]/generator",1);
setprop("controls/electric/engine[0]/bus-tie",1);
setprop("controls/electric/engine[1]/bus-tie",1);
setprop("controls/electric/avionics-switch",1);
setprop("controls/electric/battery-switch",1);
setprop("controls/electric/inverter-switch",1);
setprop("controls/lighting/instrument-lights",1);
setprop("controls/lighting/landing-lights",1);
setprop("controls/lighting/landing-lights[1]",1);
setprop("controls/lighting/taxi-lights",1);
setprop("controls/lighting/beacon/switch",1);
setprop("controls/lighting/strobe/switch",1);
setprop("controls/lighting/logo-lights",1);
setprop("controls/engines/engine[0]/condition",1);
setprop("controls/engines/engine[1]/condition",1);
setprop("controls/engines/engine[0]/condition-input",1);
setprop("controls/engines/engine[1]/condition-input",1);
setprop("controls/engines/engine[0]/mixture",1);
setprop("controls/engines/engine[1]/mixture",1);
setprop("controls/engines/engine[0]/propeller-pitch",1);
setprop("controls/engines/engine[1]/propeller-pitch",1);
setprop("engines/engine[0]/running",1);
setprop("engines/engine[1]/running",1);
setprop("controls/electric/RH-AC-bus",1);
setprop("controls/electric/LH-AC-bus",1);
setprop("controls/electric/efis/bank[0]",1);
setprop("controls/electric/efis/bank[1]",1);
setprop("instrumentation/altimeter/setting-inhg",getprop("environment/pressure-sea-level-inhg"));
setprop("controls/fuel/Laux-switch","auto");
setprop("consumables/fuel/tank[0]/selected",0);
setprop("consumables/fuel/tank[1]/selected",0);
setprop("consumables/fuel/tank[2]/selected",1);
setprop("consumables/fuel/tank[3]/selected",1);
setprop("controls/fuel/Raux-switch","auto");
setprop("controls/fuel/gauge-switch","auxilary");
if(FDM=="jsb"){
    setprop("fdm/jsbsim/propulsion/engine/n1",60);
    setprop("fdm/jsbsim/propulsion/engine[1]/n1",60);
    }
}

var Shutdown = func{
setprop("controls/electric/engine[0]/generator",0);
setprop("controls/electric/engine[1]/generator",0);
setprop("controls/electric/engine[0]/bus-tie",0);
setprop("controls/electric/engine[1]/bus-tie",0);
setprop("controls/electric/avionics-switch",0);
setprop("controls/electric/battery-switch",0);
setprop("controls/electric/inverter-switch",0);
setprop("controls/lighting/instrument-lights",0);
setprop("controls/lighting/landing-lights",0);
setprop("controls/lighting/landing-lights[1]",0);
setprop("controls/lighting/taxi-lights",0);
setprop("controls/lighting/beacon/switch",0);
setprop("controls/lighting/strobe/switch",0);
setprop("controls/lighting/logo-lights",0);
setprop("controls/engines/engine[0]/cutoff",1);
setprop("controls/engines/engine[1]/cutoff",1);
setprop("controls/engines/engine[0]/condition",0);
setprop("controls/engines/engine[1]/condition",0);
setprop("controls/engines/engine[0]/condition-input",0);
setprop("controls/engines/engine[1]/condition-input",0);
setprop("controls/engines/engine[0]/mixture",0);
setprop("controls/engines/engine[1]/mixture",0);
setprop("controls/engines/engine[0]/propeller-pitch",0);
setprop("controls/engines/engine[1]/propeller-pitch",0);
setprop("engines/engine[0]/running",0);
setprop("engines/engine[1]/running",0);
setprop("controls/electric/RH-AC-bus",0);
setprop("controls/electric/LH-AC-bus",0);
setprop("controls/electric/efis/bank[0]",0);
setprop("controls/electric/efis/bank[1]",0);
}

var flight_meter = func{
var fmeter = getprop("/instrumentation/clock/flight-meter-sec");
var fminute = fmeter * 0.016666;
var fhour = fminute * 0.016666;
setprop("/instrumentation/clock/flight-meter-hour",fhour);
}

controls.gearDown = func(v) {
    if(getprop("controls/gear/gear-lock")) return;
    if (v < 0) {
        if(!getprop("gear/gear[1]/wow"))setprop("/controls/gear/gear-down", 0);
    } elsif (v > 0) {
      setprop("/controls/gear/gear-down", 1);
    }
}

controls.startEngine = func(v) {
    if(getprop("systems/electrical/volts")==0)return;
        if(getprop("controls/engines/engine[0]/selected"))setprop("/controls/engines/engine[0]/starter",v) 
        else setprop("/controls/engines/engine[0]/starter",0);
         if(getprop("controls/engines/engine[1]/selected"))setprop("/controls/engines/engine[1]/starter",v) 
        else setprop("/controls/engines/engine[1]/starter",0);
}

var update_alarms = func {
    if(alert.counter ==0){
        alert.check_caution();
    }elsif(alert.counter ==1){
        alert.check_warning();
    }
    alert.counter =1-alert.counter;
    settimer(update_alarms,0.25);
}

var check_gear = func {
    if(getprop("controls/gear/gear-down")){
        setprop("gear/alarm",0);
        return;
    }
    var gd=0;
    flp=getprop("controls/flight/flaps");
    if(flp==0.5){
        if(N1[0]<85 or N1[1]<85)
        gd=getprop("gear/alarm-enabled");
    }
    if(flp>0.5)gd=1;
    setprop("gear/alarm",gd);
}

var update_engine = func(eng){
    if(FDM=="jsb")return;
    N1[eng] = getprop("engines/engine["~eng~"]/n1");
    var rn=getprop("engines/engine["~eng~"]/running");
    var cnd =getprop("controls/engines/engine["~eng~"]/condition");
    var cutoff =getprop("controls/engines/engine["~eng~"]/cutoff");
    var tm=getprop("sim/time/delta-sec");
        if(rn){
                setprop("instrumentation/eng-gauge/fuel-pph["~eng~"]",getprop("engines/engine["~eng~"]/fuel-flow-gph")* 6.72);
                setprop("controls/engines/engine["~eng~"]/condition-input",cnd);
                setprop("engines/engine["~eng~"]/n1",getprop("engines/engine["~eng~"]/n2"));
        }else{
            var ign= getprop("controls/engines/engine["~eng~"]/ignition");
            var strtr=getprop("controls/engines/engine["~eng~"]/starter");
                setprop("controls/engines/engine["~eng~"]/condition-input",0);
                if(strtr){
                N1[eng] = N1[eng] + (tm * 3);
                if(N1[eng]>15){
                    if(N1[eng]>30)N1[eng]=30;
                    if(ign==1){
                        if(cnd>0.01){
                            setprop("controls/engines/engine["~eng~"]/condition-input",cnd);
                        }
                    }
                }
            }else{
                N1[eng] = N1[eng] - (tm * 2);
                if(N1[eng]<0)N1[eng]=0;
            }
            setprop("engines/engine["~eng~"]/n1",N1[eng]);
    }
}


var update_systems = func {
    
    flight_meter();
    wiper.active();
    update_fuel();
    if(getprop("controls/cabin-door/open")){
        if(getprop("engines/engine/running"))setprop("controls/cabin-door/open",0);
    }
    # manual start #
    update_engine(Engstep);
    Engstep=1-Engstep;
    check_gear();
    settimer(update_systems,0);
}