aircraft.livery.init("Aircraft/dhc2/Models/Liveries");
var volume=props.globals.initNode("/sim/sound/sim-volume",0.0);
var idle_volume=props.globals.initNode("/sim/sound/idle-volume",0.0);
var floats = 0;
var beacon_light = props.globals.initNode("/controls/lighting/beacon-light", 0.0);

var TireSpeed = {
    new : func(number){
        m = { parents : [TireSpeed] };
            m.num=number;
            m.circumference=[];
            m.tire=[];
            m.rpm=[];
            for(var i=0; i<m.num; i+=1) {
                var diam =arg[i];
                var circ=diam * math.pi;
                append(m.circumference,circ);
                append(m.tire,props.globals.initNode("gear/gear["~i~"]/tire-rpm",0,"DOUBLE"));
                append(m.rpm,0);
            }
        m.count = 0;
        return m;
    },
    #### calculate and write rpm ###########
    get_rotation: func (fdm1){
        var speed=0;
        if(fdm1=="yasim"){
            speed =getprop("gear/gear["~me.count~"]/rollspeed-ms") or 0;
            speed=speed*60;
            }elsif(fdm1=="jsb"){
                speed =getprop("fdm/jsbsim/gear/unit["~me.count~"]/wheel-speed-fps") or 0;
                speed=speed*18.288;
            }
        var wow = getprop("gear/gear["~me.count~"]/wow");
        if(wow){
            me.rpm[me.count] = speed / me.circumference[me.count];
        }else{
            if(me.rpm[me.count] > 0) me.rpm[me.count]=me.rpm[me.count]*0.95;
        }
        me.tire[me.count].setValue(me.rpm[me.count]);
        me.count+=1;
        if(me.count>=me.num)me.count=0;
    },
};

#Engine sensors class 
# ie: var Eng = Engine.new(engine number);
var Engine = {
    new : func(eng_num){
        m = { parents : [Engine]};
        m.air_temp = props.globals.initNode("environment/temperature-degc");
        m.oat = m.air_temp.getValue() or 0;
        m.ot_target=60;
        m.eng = props.globals.initNode("engines/engine["~eng_num~"]");
        m.running = 0;
        m.mp = m.eng.initNode("mp-inhg");
        m.cutoff = props.globals.initNode("controls/engines/engine["~eng_num~"]/cutoff");
        m.mixture = props.globals.initNode("engines/engine["~eng_num~"]/mixture");
        m.mixture_lever = props.globals.initNode("controls/engines/engine["~eng_num~"]/mixture",1,"DOUBLE");
        m.rpm = m.eng.initNode("rpm",1);
        m.oil_temp=m.eng.initNode("oil-temp-c",m.oat,"DOUBLE");
        m.carb_temp=m.eng.initNode("carb-temp-c",m.oat,"DOUBLE");
        m.oil_psi=m.eng.initNode("oil-pressure-psi",0.0,"DOUBLE");
        m.smoke=m.eng.initNode("smoke",0,"BOOL");
        m.firing=m.eng.initNode("firing",0.0,"DOUBLE");
        m.fuel_psi=m.eng.initNode("fuel-psi-norm",0,"DOUBLE");
        m.fuel_out=m.eng.initNode("out-of-fuel",0,"BOOL");
        m.fuel_switch=props.globals.initNode("controls/fuel/switch-position",-1,"INT");
        m.hpump=props.globals.initNode("systems/hydraulics/pump-psi["~eng_num~"]",0,"DOUBLE");

        m.smk0=0.0;
        m.smk1=0.0;

    m.Lrunning = setlistener("engines/engine["~eng_num~"]/running",func (rn){m.running=rn.getValue();},1,0);
    return m;
    },
#### update ####
    update : func{
        var mx =me.mixture_lever.getValue();
    me.mixture.setValue(mx);
        var hpsi =me.rpm.getValue();
        var fpsi =me.fuel_psi.getValue();
        var oilpsi=hpsi * 0.001;
        if(oilpsi>0.7)oilpsi =0.7;
        me.oil_psi.setValue(oilpsi);
        if(hpsi>60)hpsi = 60;
        me.hpump.setValue(hpsi);
        var rpm = me.rpm.getValue();
        var mp=me.mp.getValue();
    var OT= me.oil_temp.getValue();
    var cooling=(getprop("velocities/airspeed-kt") * 0.1) *2;
    cooling+=(mx * 5);
    var tgt=me.ot_target + mp;
    var tgt-=cooling;
    if(me.running){
        if(OT < tgt) OT+=rpm * 0.00001;
        if(OT > tgt) OT-=cooling * 0.001;
        }else{
        if(OT > me.air_temp.getValue()) OT-=0.001; 
    }
        me.oil_temp.setValue(OT);
        var fpVolts =getprop("systems/electrical/outputs/fuel-pump");
        if(fpVolts==nil)fpVolts=0;
    var ctemp=me.air_temp.getValue();
    ctemp -= (rpm * 0.007);
    me.carb_temp.setValue(ctemp);
        if(fpVolts>5){
            if(fpsi<0.5000)fpsi += 0.01;
        }else{
            if(fpsi>0.000) fpsi -= 0.01;
        }
        me.fuel_psi.setValue(fpsi);
        if(fpsi < 0.2){
            me.mixture.setValue(fpsi);
        }
        var idlesnd=(rpm-500)*0.001;
        if(idlesnd>1)idlesnd=1;
        idlesnd=1-idlesnd;
        idle_volume.setValue(idlesnd);

    me.smk1=me.firing.getValue();
    if((me.smk1 - me.smk0)>0.000000)me.smoke.setValue(1) else me.smoke.setValue(0);
    me.smk0=me.smk1;
    },

    fuel_select : func (sw){
        var position=me.fuel_switch.getValue();
        position +=sw;
        if(position > 2)position -=4;
        if(position < -1)position +=4;
        me.fuel_switch.setValue(position);
        setprop("/consumables/fuel/tank[0]/selected",0);
        setprop("/consumables/fuel/tank[1]/selected",0);
        setprop("/consumables/fuel/tank[2]/selected",0);
        if(position >= 0){
            setprop("/consumables/fuel/tank[" ~ position ~ "]/selected",1);
        };
        me.fuel_out.setValue(0);
    },

};
##################################

var WaspJr = Engine.new(0);
var tire=TireSpeed.new(3,0.76,0.76,0.33);

setlistener("/sim/signals/fdm-initialized", func {
    WaspJr.fuel_select(0);
    volume.setValue(0.5);
    if(getprop("sim/aero")=="dhc2F")floats=1;
    settimer(update,1);
});

setlistener("/sim/current-view/internal", func(vw){
    if(vw.getValue()){
        volume.setValue(0.4);
    }else{
        volume.setValue(1.0);
    }
},1,0);

setlistener("systems/electrical/outputs/beacon", func(bn){
    var beacon = bn.getValue()or 0;

    if( beacon > 5){
        setprop("/controls/lighting/beacon-light", 1);
    }else{
        setprop("/controls/lighting/beacon-light", 0);
    }
},1,0);

var secure = func{
    props.globals.getNode("/controls/winch/place").setBoolValue(1);
    settimer(set_winch,1);
}

var set_winch = func{
    props.globals.getNode("/controls/winch/place").setBoolValue(0);
}


controls.startEngine = func(v = 1) {
    var vlt = getprop("systems/electrical/volts") or 0;
    if(vlt < 15) v=0;
    setprop("controls/engines/engine/starter",v);
}


var update = func {
    WaspJr.update();
        if(floats ==0)tire.get_rotation("yasim");
        var ia=getprop("velocities/airspeed-kt");
        if(ia>40){
            if(getprop("controls/doors/open[0]"))setprop("controls/doors/open[0]",0);
            if(getprop("controls/doors/open[1]"))setprop("controls/doors/open[1]",0);
            if(getprop("controls/doors/open[2]"))setprop("controls/doors/open[2]",0);
            if(getprop("controls/doors/open[3]"))setprop("controls/doors/open[3]",0);
        }
    settimer(update,0);
}