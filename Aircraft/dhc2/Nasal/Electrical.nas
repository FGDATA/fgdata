####  piston engine electrical system    #### 
####    Syd Adams    ####

var ammeter_ave = 0.0;
var outPut = "systems/electrical/outputs/";
var BattVolts = props.globals.getNode("systems/electrical/batt-volts",1);
var Volts = props.globals.getNode("/systems/electrical/volts",1);
var Amps = props.globals.getNode("/systems/electrical/amps",1);
var EXT  = props.globals.getNode("/controls/electric/external-power",1); 
var switch_list=[];
var output_list=[];
var watt_list=[];

strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("controls/lighting/strobe-state", [0.05, 1.30], strobe_switch);
beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
aircraft.light.new("controls/lighting/beacon-state", [1.0, 1.0], beacon_switch);

#var battery = Battery.new(switch-prop,volts,amps,amp_hours,charge_percent,charge_amps);
Battery = {
    new : func(swtch,vlt,amp,hr,chp,cha){
    m = { parents : [Battery] };
            m.switch = props.globals.getNode(swtch,1);
            m.switch.setBoolValue(0);
            m.ideal_volts = vlt;
            m.ideal_amps = amp;
            m.amp_hours = hr;
            m.charge_percent = chp; 
            m.charge_amps = cha;
    return m;
    },
    apply_load : func(load,dt) {
        if(me.switch.getValue()){
        var amphrs_used = load * dt / 3600.0;
        var percent_used = amphrs_used / me.amp_hours;
        me.charge_percent -= percent_used;
        if ( me.charge_percent < 0.0 ) {
            me.charge_percent = 0.0;
        } elsif ( me.charge_percent > 1.0 ) {
        me.charge_percent = 1.0;
        }
        var output =me.amp_hours * me.charge_percent;
        return output;
        }else return 0;
    },

    get_output_volts : func {
        if(me.switch.getValue()){
            var x = 1.0 - me.charge_percent;
            var tmp = -(3.0 * x - 1.0);
            var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
            var output =me.ideal_volts * factor;
            return output;
        }else return 0;
    },

    get_output_amps : func {
        if(me.switch.getValue()){
            var x = 1.0 - me.charge_percent;
            var tmp = -(3.0 * x - 1.0);
            var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
            var output =me.ideal_amps * factor;
            return output;
        }else return 0;
    }
};

# var alternator = Alternator.new(num,switch,rpm_source,rpm_threshold,volts,amps);
Alternator = {
    new : func (num,switch,src,thr,vlt,amp){
        m = { parents : [Alternator] };
        m.switch =  props.globals.getNode(switch,1);
        m.switch.setBoolValue(0);
        m.meter =  props.globals.getNode("systems/electrical/gen-load["~num~"]",1);
        m.meter.setDoubleValue(0);
        m.gen_output =  props.globals.getNode("engines/engine["~num~"]/amp-v",1);
        m.gen_output.setDoubleValue(0);
        m.meter.setDoubleValue(0);
        m.rpm_source =  props.globals.getNode(src,1);
        m.rpm_threshold = thr;
        m.ideal_volts = vlt;
        m.ideal_amps = amp;
        return m;
    },

    apply_load : func(load) {
        var cur_volt=me.gen_output.getValue();
        var cur_amp=me.meter.getValue();
        if(cur_volt >1){
            var factor=1/cur_volt;
            gout = (load * factor);
            if(gout>1)gout=1;
        }else{
            gout=0;
        }
        if(cur_amp > gout)me.meter.setValue(cur_amp - 0.01);
        if(cur_amp < gout)me.meter.setValue(cur_amp + 0.01);
    },

    get_output_volts : func {
        var out = 0;
        if(me.switch.getBoolValue()){
            var factor = me.rpm_source.getValue() / me.rpm_threshold;
            if ( factor > 1.0 )factor = 1.0;
            var out = (me.ideal_volts * factor);
        }
        me.gen_output.setValue(out);
        return out;
    },

    get_output_amps : func {
        var ampout =0;
        if(me.switch.getBoolValue()){
            var factor = me.rpm_source.getValue() / me.rpm_threshold;
            if ( factor > 1.0 ) {
                factor = 1.0;
            }
            ampout = me.ideal_amps * factor;
        }
        return ampout;
    }
};

var battery = Battery.new("/controls/electric/battery-switch",24,30,34,1.0,7.0);
var alternator1 = Alternator.new(0,"controls/electric/engine[0]/generator","/engines/engine[0]/rpm",100.0,28.0,60.0);

#####################################
setlistener("/sim/signals/fdm-initialized", func {
    BattVolts.setDoubleValue(0);
    init_switches();
    settimer(update_electrical,5);
    print("Electrical System ... ok");

});

init_switches = func() {
    var tprop=props.globals.getNode("controls/electric/ammeter-switch",1);
    tprop.setBoolValue(1);
    tprop=props.globals.getNode("controls/lighting/instrument-lights",1);
    tprop.setBoolValue(0);

    setprop("controls/lighting/instrument-lights-norm",0.8);

    append(switch_list,"controls/engines/engine/starter");
    append(output_list,"starter");
    append(watt_list,10.0);

    append(switch_list,"controls/anti-ice/pitot-heat");
    append(output_list,"pitot-heat");
    append(watt_list,0.5);

    append(switch_list,"controls/lighting/landing-lights");
    append(output_list,"landing-lights");
    append(watt_list,1.0);

#    append(switch_list,"controls/lighting/instrument-lights");
#    append(output_list,"instrument-lights");
#    append(watt_list,0.2);

    append(switch_list,"controls/lighting/beacon-state/state");
    append(output_list,"beacon");
    append(watt_list,0.5);

    append(switch_list,"controls/lighting/nav-lights");
    append(output_list,"nav-lights");
    append(watt_list,0.5);

    append(switch_list,"controls/lighting/strobe-state/state");
    append(output_list,"strobe");
    append(watt_list,0.5);

    append(switch_list,"controls/engines/engine/fuel-pump");
    append(output_list,"fuel-pump");
    append(watt_list,0.5);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"adf");
    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"dme");
    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"adf");
    append(watt_list,0.2);

#    append(switch_list,"controls/electric/avionics-switch");
#    append(output_list,"gps");
#    append(watt_list,0.5);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"adf");
    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"DG");
    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"transponder");
    append(watt_list,0.2);

#    append(switch_list,"controls/electric/avionics-switch");
#    append(output_list,"mk-viii");
#    append(watt_list,0.2);

#    append(switch_list,"controls/electric/avionics-switch");
#    append(output_list,"tacan");
#    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"turn-coordinator");
    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"comm");
    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"comm[1]");
    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"nav");
    append(watt_list,0.2);

    append(switch_list,"controls/electric/avionics-switch");
    append(output_list,"nav[1]");
    append(watt_list,0.2);

    for(var i=0; i<size(switch_list); i+=1) {
        var tmp = props.globals.getNode(switch_list[i],1);
        tmp.setBoolValue(0);
    }
setprop("controls/electric/avionics-switch",1);
}

update_virtual_bus = func( dt ) {
    var PWR = getprop("systems/electrical/serviceable");
    var battery_volts = battery.get_output_volts();
    BattVolts.setValue(battery_volts);
    var alternator1_volts = alternator1.get_output_volts();
    var external_volts = 24.0;

    load = 0.0;
    bus_volts = 0.0;
    power_source = nil;
        
        bus_volts = battery_volts;
        power_source = "battery";

    if (alternator1_volts > bus_volts) {
        bus_volts = alternator1_volts;
        power_source = "alternator1";
        }

    if ( EXT.getBoolValue() and ( external_volts > bus_volts) ) {
        bus_volts = external_volts;
        }

    bus_volts *=PWR;

    load += electrical_bus(bus_volts);

    ammeter = 0.0;

    if ( power_source == "battery" ) {
        ammeter = -load;
        } else {
        ammeter = battery.charge_amps;
    }

    if ( power_source == "battery" ) {
        battery.apply_load( load, dt );
        } elsif ( bus_volts > battery_volts ) {
        battery.apply_load( -battery.charge_amps, dt );
        }

    ammeter_ave = 0.8 * ammeter_ave + 0.2 * ammeter;

   Amps.setValue(ammeter_ave);
   Volts.setValue(bus_volts);
    alternator1.apply_load(load);

return load;
}

electrical_bus = func(bv) {
    var bus_volts = bv;
    var load = 0.0;
    var srvc = 0.0;


    for(var i=0; i<size(switch_list); i+=1) {
        var srvc = getprop(switch_list[i]);
        load = load + srvc * watt_list[i];
        setprop(outPut~output_list[i],bus_volts * srvc);
    }

    var DIMMER = bus_volts * getprop("controls/lighting/instrument-lights-norm");
    var INSTR_SWTCH = getprop("controls/lighting/instrument-lights");
    DIMMER=DIMMER*INSTR_SWTCH;

    setprop(outPut~"instrument-lights",DIMMER);
    setprop(outPut~"instrument-lights-norm",DIMMER * 0.0357);

    return load;
}

update_electrical = func {
    var scnd = getprop("sim/time/delta-sec");
    update_virtual_bus( scnd );
settimer(update_electrical, 0);
}
