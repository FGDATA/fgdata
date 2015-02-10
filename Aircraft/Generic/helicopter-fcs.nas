#
# Flight Control System for Helicopters by Tatsuhiro Nishioka 
# $Id$
#

var enableDebug = func() {
  setprop("/controls/flight/fcs/switches/debug", 1);
}

var debugEnabled = func() {
  var debugStatus = getprop("/controls/flight/fcs/switches/debug");
  if (debugStatus == 1) { 
    return 1;
  } else {
    return 0;
  }
}

var dumpParameters = func() {
  debug.dump(props.globals.getNode("/controls/flight/fcs/gains").getValues());
}

#
# FCSFilter - base class for FCS components like CAS and SAS
#
var FCSFilter = {
  #
  # new - constructor
  # input_path: a property path for a filter input
  #             nil is equivalent to "/controls/flight/"
  # output_path: a property path for a filter output
  # 
  new : func(input_path, output_path) {
    var obj = { parents : [FCSFilter], 
                input_path : input_path,
                output_path : output_path };
    obj.axis_conv = {'roll' : 'aileron', 'pitch' : 'elevator', 'yaw' : 'rudder' };
    obj.body_conv = {'roll' : 'v', 'pitch' : 'u' };
    obj.last_body_fps = {'roll' : 0.0, 'pitch' : 0.0 };
    obj.last_pos = {'roll' : 0.0, 'pitch' : 0.0, 'yaw' : 0.0};
    return obj;
  },

  #
  # updateSensitivities: read sensitivitiy values for all axis from the property
  #
  updateSensitivities : func() {
    me.sensitivities = props.globals.getNode("/controls/flight/fcs/gains/sensitivities").getValues();
  },

  #
  # read - gets input command for a given axis from input_path
  # 
  read : func(axis) {
    if (me.input_path == nil or me.input_path == "") {
      return getprop("/controls/flight/" ~ me.axis_conv[axis]);
    } else { 
      var value = getprop(me.input_path ~ "/" ~ axis);
      value = int(value * 1000) / 1000.0;
    }
  },

  # 
  # write - outputs command for a given axis into output_path
  # this will be the output of an next command filter (like SAS)
  #
  write : func(axis, value) {
    if (me.output_path == nil or me.output_path == '') {
      setprop("/controls/flight/fcs/" ~ axis, me.limit(value, 1.0));
    } else {
      setprop(me.output_path ~ "/" ~ axis, me.limit(value, 1.0));
    }
  },

  #
  # toggleFilterStatus - toggles engage/disengage FCS function
  # name: FCS filter name; one of /controls/flight/fcs/switches/*
  # 
  toggleFilterStatus : func(name) {
    var messages = ["disengaged", "engaged"];
    var path = "/controls/flight/fcs/switches/" ~ name;
    var status = getprop(path);
    setprop(path, 1 - status);
    screen.log.write(name ~ " " ~ messages[1 - status]);
  },

  #
  # getStatus - returns 1 if a given function is engaged
  # name: FCS filter name; one of /controls/flight/fcs/switches/*
  #
  getStatus : func(name) {
    var path = "/controls/flight/fcs/switches/" ~ name;
    return getprop(path);
  },

  #
  # limit - cut out a given value between +range to -range
  # value: number to be adjusted
  # range: absolute number for specifying the range
  limit : func(value, range) {
    if (value > range) {
      return range;
    } elsif (value < -range) {
      return - range;
    }
    return value;
  },

  max : func(val1, val2) {
    return (val1 > val2) ? val1 : val2;
  },

  min : func(val1, val2) {
    return (val1 > val2) ? val2 : val1;
  },

  #
  # calcCounterBodyFPS - calculates counter-force command to kill movement in each axis
  # axis: one of 'roll', 'pitch', or 'yaw'
  # input: input (0.0 - 1.0) for a given axis
  # offset_deg: 
  # 
  calcCounterBodyFPS : func(axis, input, offset_deg) {
    var position = getprop("/orientation/" ~ axis ~ "-deg");
    var body_fps = 0;
    var last_body_fps = me.last_body_fps[axis];
    var reaction_gain = 0;
    var heading = getprop("/orientation/heading-deg");
    var wind_speed_fps = getprop("/environment/wind-speed-kt") * 1.6878099;
    var wind_direction = getprop("/environment/wind-from-heading-deg");
    var wind_direction -= heading;
    var rate = getprop("/orientation/" ~ axis ~ "-rate-degps");
    var gear_pos = getprop("/gear/gear[0]/compression-norm") + getprop("/gear/gear[1]/compression-norm");
    var counter_fps = 0;
    var fps_axis = me.body_conv[axis]; # convert from {roll, pitch} to {u, v}
    var target_pos = offset_deg;
    var brake_deg = 0;

    body_fps = getprop("/velocities/" ~ fps_axis ~ "Body-fps");
    if (axis == 'roll') {
      var wind_fps = math.sin(wind_direction / 180 * math.pi) * wind_speed_fps; 
    } else {
      var wind_fps = math.cos(wind_direction / 180 * math.pi) * wind_speed_fps; 
    }
    var brake_freq = getprop("/controls/flight/fcs/gains/afcs/fps-" ~ axis ~ "-brake-freq");
    var brake_gain = getprop("/controls/flight/fcs/gains/afcs/fps-brake-gain-" ~ axis);
    body_fps -= wind_fps;
    var dfps = body_fps - me.last_body_fps[axis];
    var fps_coeff = getprop("/controls/flight/fcs/gains/afcs/fps-" ~ axis ~ "-coeff");
    target_pos -= int(body_fps * 100) / 100 * fps_coeff;
    if (axis == 'roll' and gear_pos > 0.0 and position > 0) {
      target_pos -= position * gear_pos / 5;
    }
    reaction_gain = getprop("/controls/flight/fcs/gains/afcs/fps-reaction-gain-" ~ axis);
    var brake_sensitivity = (axis == 'roll') ? 1 : 1;
    if (math.abs(position + rate / brake_freq * brake_sensitivity) > math.abs(target_pos)) {
      if (math.abs(dfps) > 1) {
        dfps = 1;
      }
      var error_deg = target_pos - position;
      brake_deg = (error_deg - rate / brake_freq) * math.abs(dfps * 10) * brake_gain;
      if (target_pos > 0) {
        brake_deg = me.min(brake_deg, 0);
      } else {
        brake_deg = me.max(brake_deg, 0);
      }
    }
    counter_fps = me.limit((target_pos + brake_deg) * reaction_gain, 1.0);
    if (debugEnabled() == 1) {
      setprop("/controls/flight/fcs/afcs/status/ah-" ~ fps_axis ~ "body-fps", body_fps);
      setprop("/controls/flight/fcs/afcs/status/ah-" ~ fps_axis ~ "body-wind-fps", wind_fps);
      setprop("/controls/flight/fcs/afcs/status/ah-" ~ axis ~ "-target-deg", target_pos);
      setprop("/controls/flight/fcs/afcs/status/ah-" ~ axis ~ "-rate", rate);
      setprop("/controls/flight/fcs/afcs/status/ah-delta-" ~ fps_axis ~ "body-fps", dfps);
      setprop("/controls/flight/fcs/afcs/status/ah-" ~ axis ~ "-brake-deg", brake_deg);
      setprop("/controls/flight/fcs/afcs/status/counter-fps-" ~ axis, counter_fps);
    }

    me.last_pos[axis] = position;
    me.last_body_fps[axis] = body_fps;
    return me.limit(counter_fps + input * 0.2, 1.0);
  },

};

#
# AFCS - Automatic Flight Control System
#
var AFCS = {
  new : func(input_path, output_path) {
    var obj = FCSFilter.new(input_path, output_path);
    obj.parents = [FCSFilter, AFCS];
    return obj;
  },

  #
  # toggle* - I/F methods for Instruments
  #
  toggleAutoHover : func() {
    me.toggleFilterStatus("auto-hover");
  },

  toggleAirSpeedLock : func() {
    me.toggleFilterStatus("air-speed-lock");
  },

  toggleHeadingLock : func() {
    me.toggleFilterStatus("heading-lock");
  },

  toggleAltitudeLock : func() {
    me.toggleFilterStatus("altitude-lock");
  },

  # 
  # auto hover - locks vBody_fps and uBody_fps regardless of wind speed/direction
  # 
  autoHover : func(axis, input) {
    if (axis == 'yaw') {
      return input;
    } else {
      var offset_deg = getprop("/controls/flight/fcs/gains/afcs/fps-" ~ axis ~ "-offset-deg");
      return me.calcCounterBodyFPS(axis, input, offset_deg);
    }
  },

  altitudeLock : func(axis, input) {
    # not implemented yet
    return input;
  },

  headingLock : func(axis, input) {
    # not implementet yet
    return input;
  },

  #
  # applying all AFCS functions
  # only auto hover is available at this moment
  #
  apply : func(axis) {
    var input = me.read(axis);
    var hover_status = me.getStatus("auto-hover");
    if (hover_status == 0) {
      me.write(axis, input);
      return;
    }
    me.write(axis, me.autoHover(axis, input));
  }
};

# 
# SAS : Stability Augmentation System - a rate damper
# 
var SAS = {
  # 
  # new
  #   input_path: is a base path to input axis; nil for using raw input from KB/JS
  #   output_path: is a base path to output axis; nis for using /controls/flight/fcs
  #   with input_path / output_path, you can connect SAS, CAS, and more control filters
  #
  new : func(input_path, output_path) {
    var obj = FCSFilter.new(input_path, output_path);
    obj.parents = [FCSFilter, SAS];
    return obj;
  },

  toggleEnable : func() {
    me.toggleFilterStatus("sas");
  },

  # 
  # calcGain - get gain for each axis based on air speed and dynamic pressure
  #   axis: one of 'roll', 'pitch', or 'yaw'
  # 
  calcGain : func(axis) {
    var mach = getprop("/velocities/mach");
    var initial_gain = getprop("/controls/flight/fcs/gains/sas/" ~ axis);
    var gain = initial_gain - 0.1 * mach * mach;
    if (math.abs(gain) < math.abs(initial_gain) * 0.01 or gain * initial_gain < 0) {
      gain = initial_gain * 0.01;
    }
    return gain;
  }, 

  #
  # calcAuthorityLimit - returns SAS authority limit using a given limit and mach number
  #
  calcAuthorityLimit : func() {
    var mach = getprop("/velocities/mach");
    var min_mach = 0.038;
    me.authority_limit = getprop("/controls/flight/fcs/gains/sas/authority-limit");
    var limit = me.authority_limit;
    if (math.abs(mach < min_mach)) {
      limit += (min_mach - math.abs(mach))  / min_mach * (1 - me.authority_limit) * 0.95;
    }
    if (debugEnabled() == 1) {
      setprop("/controls/flight/fcs/sas/status/authority-limit", limit);
    }
    return limit;
  },

  # 
  # apply - apply SAS damper to a given input axis
  #   axis: one of 'roll', 'pitch', or 'yaw'
  # 
  apply : func(axis) {
    me.updateSensitivities();
    var status = me.getStatus("sas");
    var input = me.read(axis);
    if (status == 0) {
      me.write(axis, input);
      return;
    }
    var mach = getprop("/velocities/mach");
    var value = 0;
    var rate = getprop("/orientation/" ~ axis ~ "-rate-degps");
    var gain = me.calcGain(axis);
    var limit = me.calcAuthorityLimit();
    if (math.abs(rate) >= me.sensitivities[axis]) {
      value = - gain * rate;
      if (value > limit) {
        value = limit;
      } elsif (value < - limit) {
        value = - limit;
      } 
    }
    me.write(axis, value + input);
  }
};

# 
# CAS : Control Augmentation System - makes your aircraft more meneuverable
# 
var CAS = {
  new : func(input_path, output_path) {
    var obj = FCSFilter.new(input_path, output_path);
    obj.parents = [FCSFilter, CAS];
    setprop("/autopilot/locks/altitude", '');
    setprop("/autopilot/locks/heading", '');
    obj.setCASControlThresholds(); 
    
    return obj;
  },

  calcRollRateAdjustment : func {
    var position = getprop("/orientation/roll-deg");
    return math.abs(math.sin(position / 180 * math.pi)) / 6;
  },

  #
  # calcHeadingAdjustment - returns roll axis output for stabilizing heading
  #
  calcHeadingAdjustment : func {
    if (getprop("/controls/flight/fcs/switches/heading-adjuster") == 1) {
      var gain = getprop("/controls/flight/fcs/gains/cas/output/heading-adjuster-gain");
      var yaw_rate = getprop("/orientation/yaw-rate-degps");
      var limit = getprop("/controls/flight/fcs/gains/cas/output/heading-adjuster-limit");
      var adjuster = yaw_rate * gain;
      return me.limit(adjuster, limit);
    } else {
      return 0;
    }
  },

  #
  # calcSideSlipAdjustment - returns yaw axis output for preventing side slip
  #
  calcSideSlipAdjustment : func {
    if (getprop("/controls/flight/fcs/switches/sideslip-adjuster") == 0) {
      return 0;
    }
    var mach = getprop("/velocities/mach");
    var slip = -getprop("/orientation/side-slip-deg"); # inverted after a change in side-slip sign (bug #901)
    var min_speed_threshold = getprop("/controls/flight/fcs/gains/cas/input/anti-side-slip-min-speed");
    if (mach < min_speed_threshold) { # works only if air speed > min_speed_threshold
      slip = 0;
    }
    var anti_slip_gain = getprop("/controls/flight/fcs/gains/cas/output/anti-side-slip-gain");
    var roll_deg = getprop("/orientation/roll-deg");
    var gain_adjuster = me.min(math.abs(mach) / 0.060, 1) * me.limit(0.2 + math.sqrt(math.abs(roll_deg)/10), 3);
    anti_slip_gain *= gain_adjuster;
    if (debugEnabled() == 1) {
      setprop("/controls/flight/fcs/cas/status/anti-side-slip", slip * anti_slip_gain);
    }
    return slip * anti_slip_gain;
  },
  
  #
  # isInverted - returns 1 if aircraft is inverted (roll > 90 or roll < -90)
  #
  isInverted : func() {
    var roll_deg = getprop("/orientation/roll-deg");
    if (roll_deg > 90 or roll_deg < -90)
      return 1;
    else
      return 0;
  },

  # FIXME: command for CAS is just a temporal one
  #
  # calcCommand - returns CAS output for each axis
  #
  calcCommand: func (axis, input) {
    var output = 0;
    var mach = getprop("/velocities/mach");
    var input_gain = me.calcGain(axis);
    var output_gain = getprop("/controls/flight/fcs/gains/cas/output/" ~ axis);
    var target_rate = input * input_gain;
    var rate = getprop("/orientation/" ~ axis ~ "-rate-degps");
    var drate = target_rate - rate;
    if (axis == 'pitch' and me.isInverted() == 1) {
      drate = - drate;
    }
    var attitudeControlThreshold = getprop("/controls/flight/fcs/gains/cas/input/attitude-control-threshold");
    var rateControlThreshold = getprop("/controls/flight/fcs/gains/cas/input/rate-control-threshold");
    var locks = {'pitch' : getprop("/autopilot/locks/altitude"),
                 'roll' : getprop("/autopilot/locks/heading")};
    setprop("/controls/flight/fcs/cas/target_" ~ axis ~ "rate", target_rate);
    setprop("/controls/flight/fcs/cas/delta_" ~ axis, drate);
    
    if (axis == 'roll' or axis == 'pitch') {
       if (math.abs(input) > rateControlThreshold) {
         return input;
       } elsif (math.abs(input) > attitudeControlThreshold or locks[axis] != '') {
         output = drate * output_gain;
       } else {
         output = me.calcAttitudeCommand(axis);
      }
      if (axis == 'roll' and math.abs(mach) < 0.035) {
        # FIXME: I don't know if OH-1 has this one
        output += me.calcCounterBodyFPS(axis, input, -0.8);
      }
    } elsif (axis == 'yaw') {
      if (getprop("/controls/flight/fcs/switches/tail-rotor-adjuster") == 0) {
        output = input;
      } else {
        output = drate * output_gain + me.calcSideSlipAdjustment();
      }
    } else {
      output = drate * output_gain;
    }
    return output;
  },

  toggleEnable : func() {
    me.toggleFilterStatus("cas");
  },

  #
  # toggle enable / disable attitude control 
  # you can make similar function that changes parameters
  # in attitude-control-limit and rate-control-limit
  # at controls/flight/fcs/gains/cas/input
  # CAS changes its behavior when roll/pitch axis inputs reaches each limit.
  # e.g. when attitude-control-limit is 0.7 and rate-control-limit is 0.9,
  # giving 0.6 for roll holds bank angle, 0.8 keeps roll rate, 
  # and 1.0 makes roll at maximum roll rate. 
  # Sets of initial values for these limits are stored at 
  # controls/fcs/gains/cas/{attitude,rate}
  #
  toggleAttitudeControl : func() {
    me.toggleFilterStatus("attitude-control");
    me.setCASControlThresholds();
  },

  setCASControlThresholds : func()
  {
    if (me.getStatus("attitude-control") == 1) {
      var params = props.globals.getNode("controls/flight/fcs/gains/cas/control/attitude").getValues();
      props.globals.getNode("controls/flight/fcs/gains/cas/input").setValues(params);
    } else {
      var params = props.globals.getNode("controls/flight/fcs/gains/cas/control/rate").getValues();
      props.globals.getNode("controls/flight/fcs/gains/cas/input").setValues(params);
    }
  },

  #
  # calcAttitudeCommand - Attitude base Augmentation output for roll and pitch axis
  # axis: either 'roll' or 'pitch'
  #
  calcAttitudeCommand : func(axis) {
    var input_gain = getprop("/controls/flight/fcs/gains/cas/input/attitude-" ~ axis);
    var output_gain = getprop("/controls/flight/fcs/gains/cas/output/" ~ axis);
    var brake_freq = getprop("/controls/flight/fcs/gains/cas/output/" ~ axis ~ "-brake-freq");
    var brake_gain = getprop("/controls/flight/fcs/gains/cas/output/" ~ axis ~ "-brake");
    var trim = getprop("/controls/flight/" ~ me.axis_conv[axis] ~ "-trim");

    var current_deg = getprop("/orientation/" ~ axis ~ "-deg");
    var rate = getprop("/orientation/" ~ axis ~ "-rate-degps");
    var target_deg = (me.read(axis) + trim) * input_gain;
    if (axis == 'roll' and math.abs(target_deg) < 0.1) { 
      # rolls a bit to counteract the heading changes only if target roll rate = 0
      target_deg += me.calcHeadingAdjustment();
    }
    var command_deg = 0;
    if (target_deg != 0) {
      command_deg = (0.094 * math.ln(math.abs(target_deg)) + 0.53) * target_deg;
    }

    var error_deg = command_deg - current_deg;
    if (axis == 'pitch' and me.isInverted() == 1) {
      error_deg = - error_deg;
    }
    var brake_deg = (error_deg - rate / brake_freq) * math.abs(error_deg) * brake_gain;

    if (command_deg > 0) {
      brake_deg = me.min(brake_deg, 0);
    } else {
      brake_deg = me.max(brake_deg, 0);
    }

    if (debugEnabled() == 1) {
      var monitor_prefix = me.output_path ~ "/status/" ~ axis;
      setprop(monitor_prefix ~ "-target_deg", target_deg);
      setprop(monitor_prefix ~ "-error_deg", error_deg);
      setprop(monitor_prefix ~ "-brake_deg", brake_deg);
      setprop(monitor_prefix ~ "-deg", current_deg);
      setprop(monitor_prefix ~ "-rate", -rate);
    }

    return (error_deg + brake_deg) * output_gain;
  },

  #
  # calcGain - returns gain for a given axis using a given gain and speed
  # FixMe: gain should be calculated using both speed and dynamic pressure
  #
  calcGain : func(axis) {
    var mach = getprop("/velocities/mach");
    var input_gain = getprop("/controls/flight/fcs/gains/cas/input/" ~ axis);
    var gain = input_gain;
    if (axis == 'pitch') {
      gain += 0.1 * mach * mach;
    } elsif (axis== 'yaw') {
      gain *= ((1 - mach) * (1 - mach));
    }
    if (gain * input_gain < 0.0 ) {
      gain = 0;
    }
    if (debugEnabled() == 1) {
      setprop("/controls/flight/fcs/cas/gain-" ~ axis, gain);
    }
    return gain;
  }, 

  #
  # apply - public method that outputs CAS command for a given axis to output_path
  #         input is read from input_path
  # axis: one of 'roll', 'pitch', or 'yaw'
  #
  apply : func(axis) {
    me.updateSensitivities();
    var input = me.read(axis);
    var status = me.getStatus("cas");
    var cas_command = 0;
    # FIXME : hmm, a bit nasty. CAS should be enabled even with auto-hover....
    if (status == 0 or (me.getStatus("auto-hover") == 1 and axis != 'yaw')) {
      me.write(axis, input);
      return;
    }
    cas_command = me.calcCommand(axis, input);
    me.write(axis, cas_command);
  }
};

#
# Tail hstab, "stabilator," for stabilize the nose 
#
var Stabilator = {
  new : func() {
    var obj = { parents : [Stabilator] };
    me.gainTable = props.globals.getNode("/controls/flight/fcs/gains/stabilator").getChildren('gain-table');
    return obj;
  },

  toggleEnable : func {
    var status = getprop("/controls/flight/fcs/switches/auto-stabilator");
    getprop("/controls/flight/fcs/switches/auto-stabilator", 1 - status);
  },
  
  #
  # calcPosition - returns stabilator position (output) depending on
  #                predefined gain table and mach number
  #
  calcPosition : func() {
    var speed = getprop("/velocities/mach") / 0.001497219; # in knot
    var index = int(math.abs(speed) / 10);
    if (index >= size(me.gainTable) - 1) {
      index = size(me.gainTable) - 2;
    }
    var gain = me.gainTable[index].getValue();
    var gainAmb = me.gainTable[index-1].getValue();
    var mod = math.mod(int(math.abs(speed)), 10);
    var position = gain * ((10 - mod) / 10) + gainAmb * mod / 10;
    if (speed < -20) {
      position = - position;
    }
    return position;
  },

  #
  # apply - public method for Stabilator control
  # no axis is required since it is only for hstab
  # 
  apply : func() {
    var status = getprop("/controls/flight/fcs/switches/auto-stabilator");
    if (status == 0) {
      return;
    }
    var gain = getprop("/controls/flight/fcs/gains/stabilator/stabilator-gain");
    var mach = getprop("/velocities/mach");
    var throttle = getprop("/controls/flight/throttle");
    var stabilator_norm = 0;

    stabilator_norm = me.calcPosition();   
    setprop("/controls/flight/fcs/stabilator", stabilator_norm);
  }
};

#
# Automatic tail rotor adjuster depending on collective/throttle status
#
var TailRotorCollective = {
  new : func() {
    var obj = FCSFilter.new("/controls/engines/engine[1]", "/controls/flight/fcs/tail-rotor");
    obj.parents = [FCSFilter, TailRotorCollective];
    obj.adjuster = 0.0;
    return obj;
  },

  #
  # apply - public method for tail rotor adjuster
  # no axis is required
  #
  apply : func() {
    var throttle = me.read("throttle");
    var pedal_pos_deg = getprop("/controls/flight/fcs/yaw");
    var cas_input = cas.read('yaw');
    var cas_input_gain = cas.calcGain('yaw');
    var target_rate = cas_input * cas_input_gain;
    var rate = getprop("/orientation/yaw-rate-degps");
    var error_rate = getprop("/controls/flight/fcs/cas/delta_yaw");
    var error_adjuster_gain = getprop("/controls/flight/fcs/gains/tail-rotor/error-adjuster-gain");

    var minimum = getprop("/controls/flight/fcs/gains/tail-rotor/src-minimum");
    var maximum = getprop("/controls/flight/fcs/gains/tail-rotor/src-maximum");
    var low_limit = getprop("/controls/flight/fcs/gains/tail-rotor/low-limit");
    var high_limit = getprop("/controls/flight/fcs/gains/tail-rotor/high-limit");
    var authority_limit = getprop("/controls/flight/fcs/gains/tail-rotor/authority-limit");
    var output = 0;
    var range = maximum - minimum;
    
    if (throttle < minimum) {
      output = low_limit;
    } elsif (throttle > maximum) {
      output = high_limit;
    } else {
      output = low_limit  + (throttle - minimum) / range * (high_limit - low_limit);
    } 

    # CAS driven tail rotor thrust adjuster
    me.adjuster = error_rate * error_adjuster_gain;
    me.adjuster = me.limit(me.adjuster, authority_limit);
    output += me.adjuster;

    setprop("/controls/flight/fcs/tail-rotor/error-rate", error_rate);
    setprop("/controls/flight/fcs/tail-rotor/adjuster", me.adjuster);

    me.write("throttle", output);
  }
};

# Back-up FCS
# It automatically disable CAS and shifts to 
# the backup mode (e.g. SAS only or direct link mode)
# 
var BackupFCS = {
  new : func() {
    var obj = { parents : [BackupFCS] };
    obj.switches = {'cas' : 0, 'sas' : 1, 'attitude-control' : 0 }; # default backup switches
    obj.normalSwitches = props.globals.getNode("/controls/flight/fcs/switches").getValues();
    setprop("/controls/flight/fcs/failures/manual-backup-mode", 0);
    setprop("/controls/flight/fcs/switches/backup-mode", 0);
    return obj;
  },

  # checkFCSFailures - detects FCS failures
  # returns 1 if failure (or manual backup mode) is detected, 0 otherwise
  #
  checkFCSFailures : func()
  {
    # not fully implemented yet
    if (getprop("/controls/flight/fcs/failures/manual-backup-mode") == 1) {
      return 1;
    } else {
      return 0;
    }
  },

  #
  # shiftToBackupMode - overwrites switches for force entering backup mode
  # 
  shiftToBackupMode : func() {
    if (me.switches != nil) {
      var switchNode = props.globals.getNode("/controls/flight/fcs/switches");
      switchNode.setValues(me.switches);
      setprop("/controls/flight/fcs/switches/backup-mode", 1);
    }
  },

  #
  # shiftToNormalMode - bring switches back to normal mode
  # switches for normalMode are captured at BackupFCS.new
  shiftToNormalMode : func() {
    if (me.normalSwitches != nil) {
      props.globals.getNode("/controls/flight/fcs/switches").setValues(me.normalSwitches);
      setprop("/controls/flight/fcs/switches/backup-mode", 0);
    }
  },

  #
  # setBackupMode - specifies set of values on FCS switches 
  # switches: hash of FCS switch values that will be set to
  #           controls/flight/fcs/switches on backup mode
  #           only values to be overwritten must be specified
  #           e.g. {'cas' : 0, 'sas' : 1}
  #
  setBackupMode : func(switches) {
    me.switches = switches
  },
  
  #
  # update - main I/F for BackupFCS
  #
  update : func() {
    if (me.checkFCSFailures() == 1) {
      me.shiftToBackupMode();
    } elsif (getprop("/controls/flight/fcs/switches/backup-mode") == 1) {
      me.shiftToNormalMode();
    }
  },

  #
  # toggleBackupMode - I/F for Cockpit Panel
  #
  toggleBackupMode : func() {
    var mode = getprop("/controls/flight/fcs/failures/manual-backup-mode");
    setprop("/controls/flight/fcs/failures/manual-backup-mode", 1 - mode);
  }
};

var sas = nil;
var cas = nil;
var afcs = nil;
var stabilator = nil;
var tail = nil;
var backup = nil;
var count = 0;

#
# AFCS main loop
# This runs at 60Hz (on every other update of /rotors/main/cone-deg)
#
var update = func {
  count += 1;
  # AFCS, CAS, and SAS run at 60Hz
  rpm = getprop("/rotors/main/rpm");
  # AFCS, CAS, and SAS run at 60Hz only when engine rpm >= 10
  # this rpm filter prevents CAS/SAS work when engine is not running,
  # which may cause Nasal runtime error
  if (math.mod(count, 2) == 0 or rpm < 10) {
    return;
  }

  cas.apply('roll');
  cas.apply('pitch');
  cas.apply('yaw');

  afcs.apply('roll');
  afcs.apply('pitch');
  afcs.apply('yaw');

  sas.apply('roll');
  sas.apply('pitch');
  sas.apply('yaw');
  stabilator.apply();
  tail.apply();
  backup.update();
}

# Factory default configuration values
# DO NOT CHANGE THESE VALUES.!
# You can change some of these values in per-aircraft nasal file.
# See Aircraft/OH-1/Nasal/OH1.nas for more detail
# 
var default_fcs_params = {
  'gains' : {
    'afcs' : { 
      # Auto Hover parameters
      'fps-brake-gain-pitch'    : 1.8,
      'fps-brake-gain-roll'     : 0.8,
      'fps-pitch-brake-freq'    : 3,
      'fps-pitch-coeff'         : -0.95,
      'fps-pitch-offset-deg'    : 0.9,
      'fps-reaction-gain-pitch' : -0.8,
      'fps-reaction-gain-roll'  : 0.3436,
      'fps-roll-brake-freq'     : 8,
      'fps-roll-coeff'          : 0.8,
      'fps-roll-offset-deg'     : -0.8
    },
    'cas' : {
      'input' : { # Input gains for CAS
        'roll' : 30, 
        'pitch' : -60, 
        'yaw' : 30, 
        'attitude-roll' : 80, 
        'attitude-pitch' : -80, 
        'attitude-control-threshold' : 0.0, # input threshold that CAS changes attitude-base control to rate-base control
        'rate-control-threshold' : 0.95,    # input threshold that CAS changes rate-base control to doing nothing
        'anti-side-slip-min-speed' : 0.015
      },
      'output' : { # Output gains for CAS
        'roll' : 0.06,
        'pitch' : -0.1, 
        'yaw' : 0.5, 
        'roll-brake-freq' : 10, 
        'pitch-brake-freq' : 3, 
        'roll-brake' : 0.4, 
        'pitch-brake' : 6, 
        'anti-side-slip-gain' : -4.5,
        'heading-adjuster-gain' : -5,
        'heading-adjuster-limit' : 5,
      },
      'control' : { # configuration for CAS augumentation modes
        'attitude' : { # Attitude control augmentation mode (e.g. ATTDAGMT button on OH-1)
          # Note: attitude-control-threshold must be smaller than rate-control-threshold in any mode
          'attitude-control-threshold' : 0.95, # Roll / Pitch attitude(angle) hold mode when 0 < input <= 0.95
          'rate-control-threshold' : 1.0 # Rate hold mode when 0.95 < input <= 1.0
        },
        'rate' : { # Rate control augmentation mode
          'attitude-control-threshold' : 0.0,
          'rate-control-threshold' : 0.95 
        },
      }
    },
    'sas' : { # gains for SAS
      'roll' : 0.02, 
      'pitch' : -0.10, 
      'yaw' : 0.04, 
      'authority-limit' : 0.15 # How much SAS will take over pilot's control. 0.15 means 15%
    },
    'sensitivities' : {
      'roll' : 1.0,
      'pitch' : 1.0,
      'yaw' : 3.0
    },
    'tail-rotor' : { # parameters for tail rotor control based on throttle / collective
      'src-minimum' : 0.10,  # throttle value that outputs low-limit
      'src-maximum' : 1.00,  # throttle value that outputs high-limit
      'low-limit' : 0.00011, 
      'high-limit' : 0.0035, 
      'error-adjuster-gain' : -0.5, # gain that how much CAS adjust yaw rate
      'authority-limit' : 0.3
    },
    'stabilator' : { # gain tables for adjusting either incidence or flap angle of hstab
                     # index is the speed (Kt) devided by 10
                     #   0    10   20    30   40   50   60   70   80   90  100  110  120  130  140  150  160, 170, 180, .....
      'gain-table' : [-0.9, -0.8, 0.1, -0.5, 0.0, 0.7, 0.8, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.9, 0.8, 0.6, 0.4, 0.2, -1.0]
    }
  },
  'switches' : { # master switches for AFCS, can be controlled by cockpit panel or keys
    'auto-hover' : 0, 
    'cas' : 1, 
    'sas' : 1, 
    'attitude-control' : 0,
    'auto-stabilator' : 1, 
    'sideslip-adjuster' : 1, 
    'tail-rotor-adjuster' : 1, 
    'heading-adjuster' : 0,
    'air-speed-lock' : 0,
    'heading-lock' : 0,
    'altitude-lock' : 0, 
  }
};
 
#
# initialize - creates AFCS components and invokes AFCS main loop
#
var initialize = func {
  cas = CAS.new(nil, "/controls/flight/fcs/cas");
  afcs = AFCS.new("/controls/flight/fcs/cas", "/controls/flight/fcs/afcs");
  sas = SAS.new("/controls/flight/fcs/afcs", "/controls/flight/fcs");
  stabilator = Stabilator.new();
  tail = TailRotorCollective.new();
  backup = BackupFCS.new(); 
  setlistener("/rotors/main/cone-deg", update);
}

#
# Stores default AFCS parameters at startup
#
var confNode = props.globals.getNode("/controls/flight/fcs", 1);
confNode.setValues(default_fcs_params);

#
# fcs-initialized signal must be set by per-aircraft nasal script
# to show that FCS configuration parameters are set
#
setlistener("/sim/signals/fcs-initialized", initialize);

