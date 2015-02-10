# A6M2 Zero-Flighter

#
# Zero Flight's Gear class
# This class simulates the Zero's landing gears that
# one gear moves at a time.
#
ZeroGear = {
  new : func {
    var obj = { parents : [ZeroGear],
            gear_direction : 1,
	    gear_changing : 0,
	    delay : 6,
            first_gear : "/gear/gear[0]/position-norm",
	    second_gear : "/gear/gear[1]/position-norm" };
    setlistener("/controls/gear/gear-down", func { obj.transform(); });
    setprop(obj.first_gear, 1);
    setprop(obj.second_gear, 1);
    return obj;
  },

  #
  # transform the gears
  #
  transform : func {
    var last_direction = me.gear_direction;
    me.gear_direction = getprop("/controls/gear/gear-down");
    if (last_direction != me.gear_direction) {
      interpolate(me.first_gear, me.gear_direction, me.delay);
      settimer(func { me.transformSecondGear(); }, me.delay);
      me.gear_changing = 1;
    }
  },

  #
  # Starts changing the position of the second gear
  #
  transformSecondGear : func {
    interpolate(me.second_gear, me.gear_direction, me.delay);
    me.gear_changing = 0;
  }
};

DynamicVolumetricEfficiency = {
  new : func ( default_val = 0.82 ) {
   var obj = { parents : [DynamicVolumetricEfficiency],
               default : default_val };
   setprop("/fdm/jsbsim/propulsion/engine/ve_coeff1", 0.019); # positive map
   setprop("/fdm/jsbsim/propulsion/engine/ve_coeff2", 0.035); # negative map
   setprop("/fdm/jsbsim/propulsion/engine/ve_coeff3", 0.009); # over +150mmHg
   setprop("/fdm/jsbsim/propulsion/engine/ve_highlimit", 1.2);
   setprop("/fdm/jsbsim/propulsion/engine/ve_lowlimit",  0.5);
   return obj;
  },
  
  update : func {
    #
    # volumetric efficiency is dynamically adjusted
    # to meet MAP/RPM/Velocity combination of typical flight configurations.
    # This is very tricky and could be unrealistic,but I believe similar dynamism 
    # should be considered in JSBSim.
    #
    var map = getprop("/fdm/jsbsim/propulsion/engine/map-inhg");
    var lowlimit = getprop("/fdm/jsbsim/propulsion/engine/ve_lowlimit");
    var highlimit = getprop("/fdm/jsbsim/propulsion/engine/ve_highlimit");
    var coeff = getprop("/fdm/jsbsim/propulsion/engine/ve_coeff1");
    if (map < 29.527555) {    # less than 1 bar
      coeff = getprop("/fdm/jsbsim/propulsion/engine/ve_coeff2");
    } elsif (map > 36) { # more than 1.2 bar, i.e. take-off power
      coeff = getprop("/fdm/jsbsim/propulsion/engine/ve_coeff3");
    }


    var efficiency = 0.82 + (map - 29.35) * coeff;
#    setprop("/fdm/jsbsim/propulsion/engine/volumetric-efficiency-raw", efficiency);

    if (efficiency > highlimit) { efficiency = highlimit; }
    if (efficiency < lowlimit) { efficiency = lowlimit; }
    setprop("/fdm/jsbsim/propulsion/engine/volumetric-efficiency", efficiency);
  }

};
  

#
# livery initialization
#
aircraft.livery.init("Aircraft/A6M2/Models/liveries", "sim/model/A6M2/livery/variant");

var a6m2 = JapaneseWarbird.new();
var observers = [Altimeter.new(), BoostGauge.new(), CylinderTemperature.new(), 
                 ExhaustGasTemperature.new(27.9), AutoMixtureControl.new(800), DynamicVolumetricEfficiency.new(0.82)];
foreach (observer; observers) {
    a6m2.addObserver(observer);
}

#var zero_gear = ZeroGear.new();
