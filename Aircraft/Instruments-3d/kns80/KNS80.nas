####    King KNS-80 Integrated Navigation System   ####
####    Syd Adams    ####
####    Ron Jensen   ####
####
####	Must be included in the Set file to run the KNS80 radio 
####
#### Nav Modes  0 = VOR ; 1 = VOR/PAR ; 2 = RNAV/ENR ; 3 = RNAV/APR ;
####

var KNS80 = {
    new : func(prop){
        var m = { parents : [KNS80]};
		m.wpt_freq=[];
		m.wpt_radial=[];
		m.wpt_distance=[];
        m.volume_adjust =0;
		m.nav_selected = "instrumentation/nav/frequencies/selected-mhz";
		m.dme_selected = "instrumentation/dme/frequencies/selected-mhz";
		m.display_num = 0;
		m.use_num = 0;
		m.flasher = 0;
		
		m.kns80 = props.globals.initNode(prop);
		m.serviceable = m.kns80.initNode("serviceable",1,"BOOL");
		m.data_mode = m.kns80.initNode("data-mode",0,"DOUBLE");
        m.nav_mode = m.kns80.initNode("nav-mode",0,"DOUBLE");
        m.dme_hold = m.kns80.initNode("dme-hold",0,"BOOL");
		m.dsp_flash = m.kns80.initNode("flash",0,"BOOL");
		m.display = m.kns80.initNode("display",0,"DOUBLE");
		m.use = m.kns80.initNode("use",0,"DOUBLE");

		append(m.wpt_freq,m.kns80.initNode("wpt[0]/frequency",115.80,"DOUBLE"));
		append(m.wpt_freq,m.kns80.initNode("wpt[1]/frequency",111.70,"DOUBLE"));
		append(m.wpt_freq,m.kns80.initNode("wpt[2]/frequency",116.80,"DOUBLE"));
		append(m.wpt_freq,m.kns80.initNode("wpt[3]/frequency",113.90,"DOUBLE"));

		append(m.wpt_radial,m.kns80.initNode("wpt[0]/radial",280.0,"DOUBLE"));
		append(m.wpt_radial,m.kns80.initNode("wpt[1]/radial",280.0,"DOUBLE"));
		append(m.wpt_radial,m.kns80.initNode("wpt[2]/radial",029.0,"DOUBLE"));
		append(m.wpt_radial,m.kns80.initNode("wpt[3]/radial",029.0,"DOUBLE"));

		append(m.wpt_distance,m.kns80.initNode("wpt[0]/distance",0,"DOUBLE"));
		append(m.wpt_distance,m.kns80.initNode("wpt[1]/distance",0,"DOUBLE"));
		append(m.wpt_distance,m.kns80.initNode("wpt[2]/distance",0,"DOUBLE"));
		append(m.wpt_distance,m.kns80.initNode("wpt[3]/distance",0,"DOUBLE"));

        m.displayed_distance = m.kns80.initNode("displayed-distance",m.wpt_distance[0].getValue(),"DOUBLE");
        m.displayed_frequency = m.kns80.initNode("displayed-frequency",m.wpt_freq[0].getValue(),"DOUBLE");
        m.displayed_radial = m.kns80.initNode("displayed-radial",m.wpt_radial[0].getValue(),"DOUBLE");

		m.NAV=props.globals.initNode("instrumentation/nav");
		m.NAV1 = m.NAV.initNode("frequencies/selected-mhz");
		m.NAV1_RADIAL = m.NAV.initNode("radials/selected-deg");
		m.NAV1_ACTUAL = m.NAV.initNode("radials/actual-deg");
		m.NAV1_TO_FLAG = m.NAV.initNode("to-flag");
		m.NAV1_FROM_FLAG = m.NAV.initNode("from-flag");
		m.NAV1_HEADING_NEEDLE_DEFLECTION = m.NAV.initNode("heading-needle-deflection");
		m.NAV1_IN_RANGE = m.NAV.initNode("in-range");
		m.NAV1_distance = m.NAV.initNode("distance");
		
        m.NAV_volume = m.NAV.initNode("volume",0.2,"DOUBLE");

		m.CDI_NEEDLE = props.globals.initNode("/instrumentation/gps/cdi-deflection");
		m.TO_FLAG    = props.globals.initNode("/instrumentation/gps/to-flag");
		m.FROM_FLAG  = props.globals.initNode("/instrumentation/gps/from-flag");

		m.RNAV = m.kns80.initNode("rnav");
		m.RNAV_deflection = m.RNAV.initNode("heading-needle-deflection",0,"DOUBLE");
		m.RNAV_distance = m.RNAV.initNode("indicated-distance-nm",0,"DOUBLE");
		m.RNAV_reciprocal = m.RNAV.initNode("reciprocal-radial-deg",0,"DOUBLE");
		m.RNAV_actual_deg = m.RNAV.initNode("actual-deg",0,"DOUBLE");
		
		m.DME_mhz = props.globals.initNode("instrumentation/dme/frequencies/selected-mhz",0,"DOUBLE");
		m.DME_src = props.globals.initNode("instrumentation/dme/frequencies/source",m.nav_selected,"STRING");
		m.DME_dist = props.globals.initNode("instrumentation/dme/indicated-distance-nm",0,"DOUBLE");
		return m;
    },

#### volume adjust ####

volume : func(vlm){
		var vol = me.NAV_volume.getValue();
		vol += vlm;
		if(vol > 1.0)vol = 1.0;
		if(vol < 0.0){
			vol = 0.0;
			me.serviceable.setBoolValue(0);
			setprop("/instrumentation/nav/serviceable",0);
			setprop("/instrumentation/dme/serviceable",0);
		}
		if(vol > 0.0){
			me.serviceable.setBoolValue(1);
			setprop("/instrumentation/nav/serviceable",1);
			setprop("/instrumentation/dme/serviceable",1);
		}
		me.NAV_volume.setValue(vol);
    },

#### dme hold ####

DME_hold : func{
	var hold = me.dme_hold.getValue();
    hold= 1- hold;
	me.dme_hold.setValue(hold);
	if(hold==1){
        me.DME_mhz.setValue(me.NAV1.getValue());
        me.DME_src.setValue(me.dme_selected);
    }else{
        me.DME_mhz.setValue(0);
        me.DME_src.setValue(me.nav_selected);
        }
    },

#### display button ####

display_btn : func{
	me.display_num +=1;
	if(me.display_num>3)me.display_num=0;
	me.displayed_frequency.setValue(me.wpt_freq[me.display_num].getValue());
    me.displayed_distance.setValue(me.wpt_distance[me.display_num].getValue());
    me.displayed_radial.setValue(me.wpt_radial[me.display_num].getValue());
    me.data_mode.setValue(0);
    if(me.use_num == me.display_num){
        me.flasher=0;
		}else{
		me.flasher=1;
        }
	me.display.setValue(me.display_num);
    },

#### use button ####

use_btn : func{
	me.use_num = me.display_num;
    me.flasher=0;
    me.data_mode.setValue(0);
    me.use.setValue(me.use_num);
	me.NAV1.setValue(me.wpt_freq[me.display_num].getValue());
    },

#### data button ####

data_btn : func{
	var data = me.data_mode.getValue();
    data +=1;
	if(data > 2) data = 0;
    me.data_mode.setValue(data);
    },

#### data adjust ####

	data_adjust : func(dtadj){
    var dmode = me.data_mode.getValue();
    var num = dtadj;
    dtadj=0;
    if(dmode == 0){
        if(num == -1 or num ==1){num = num *0.05;}else{num = num *0.10;}
        var newfreq = me.displayed_frequency.getValue();
        newfreq += num;
        if(newfreq > 118.95){newfreq -= 11.00;}
        if(newfreq < 108.00){newfreq += 11.00;}
        me.displayed_frequency.setValue(newfreq);
		me.wpt_freq[me.display_num].setValue(newfreq);
		 if(me.use_num == me.display_num)me.NAV1.setValue(newfreq);
    }elsif(dmode == 1){
        var newrad = me.displayed_radial.getValue();
        newrad += num;
        if(newrad > 359){newrad -= 360;}
        if(newrad < 0){newrad += 360;}
        me.displayed_radial.setValue(newrad);
		me.wpt_radial[me.display_num].setValue(newrad);
    }elsif(dmode == 2){
        var newdist = me.displayed_distance.getValue();
        if(num == -1 or num ==1 ){num = num *0.1;}
        newdist += num;
        if(newdist > 99){newdist -= 100;}
        if(newdist < 0){newdist += 100;}
        me.displayed_distance.setValue(newdist);
		me.wpt_distance[me.display_num].setValue(newdist);
    }
},

#### update RNAV ####

# Properties
# outputs
# distance, radial from VOR Station
# rho, theta: distance and radial for phantom station
# range, bearing: distance and radial from phantom station
#### Nav Modes  0 = VOR ; 1 = VOR/PAR ; 2 = RNAV/ENR ; 3 = RNAV/APR ;

updateRNAV : func{

	if(!me.NAV1_IN_RANGE.getValue()) {
        return;
    }
	var mode = me.nav_mode.getValue() or 0;
    var distance=me.DME_dist.getValue() or 0;
    var selected_radial = me.NAV1_RADIAL.getValue() or 0;
    var radial = me.NAV1_ACTUAL.getValue() or 0;
    var rho = me.wpt_distance[me.use_num].getValue();
    var theta = me.wpt_radial[me.use_num].getValue();
    var fangle = 0;
    var needle_deflection = 0;
    var from_flag=1;
    var to_flag  =0;
    
    var x1 = distance * math.cos( radial*D2R );
    var y1 = distance * math.sin( radial*D2R );
    var x2 = rho * math.cos( theta*D2R );
    var y2 = rho * math.sin( theta*D2R );

    var range = math.sqrt( (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) );
    var bearing = math.atan2 (( y1-y2), (x1-x2))*R2D;

    if(bearing < 0) bearing += 360;
    var abearing = bearing > 180 ? bearing - 180 : bearing + 180;

    if( mode == 0){
        needle_deflection = (me.NAV1_HEADING_NEEDLE_DEFLECTION.getValue());
        range = distance;
    }
    if ( mode == 1){
        fangle = math.abs(selected_radial - radial);
        needle_deflection = math.sin((selected_radial - radial) * D2R) * distance * 2;
    }
    if ( mode == 2){
       fangle = math.abs(selected_radial - bearing);
        needle_deflection = math.sin((selected_radial - bearing) * D2R) * range * 2;
    } 
    if ( mode == 3){
        fangle = math.abs(selected_radial - bearing);
        needle_deflection = math.sin((selected_radial - bearing) * D2R) * range * 8;
    }

    if ( needle_deflection >  10) needle_deflection = 10;
    if ( needle_deflection < -10) needle_deflection =-10;
    if (fangle < 90 or fangle >270){
        from_flag=1;
        to_flag  =0;
    } else {
        from_flag=0;
        to_flag  =1;
    }

    me.RNAV_deflection.setValue(needle_deflection);
    me.CDI_NEEDLE.setDoubleValue(needle_deflection);
    me.TO_FLAG.setDoubleValue(to_flag);
    me.FROM_FLAG.setDoubleValue(from_flag);
    me.RNAV_distance.setValue(range);
    me.RNAV_reciprocal.setValue(abearing);
    me.RNAV_actual_deg.setValue(bearing);
	}
};

###########################################

var kns80 = KNS80.new("instrumentation/kns-80");

setlistener("/sim/signals/fdm-initialized", func {
		update();
	});

var update = func {
	kns80.updateRNAV();
	var fl = kns80.dsp_flash.getValue();
	
	if(kns80.flasher){
		kns80.dsp_flash.setValue(1-fl);
	}else{
		kns80.dsp_flash.setValue(1);
	};
	
	settimer(update,0.5);
};
