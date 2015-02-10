# Joystick configuration library.
var DIALOGROOT  = "/sim/gui/dialogs/joystick-config";
var MAX_AXES = 8;
var MAX_NASALS = 8;
var MAX_BUTTONS = 24;

# Hash of the custom axis/buttons
var custom_bindings = {};

# Class for an individual joystick axis binding
var Axis = {
  new: func(name, prop, invertable) {
    var m = { parents: [Axis] };
    m.name = name;
    m.prop = prop;
    m.invertable = invertable;
    m.inverted = 0;
    return m;
  },
  
  clone: func() {
    var m = { parents: [Axis] };
    m.name = me.name;
    m.prop = me.prop;
    m.invertable = me.invertable;
    m.inverted = me.inverted;
    return m;
  },
  
  match: func(prop) {
    return 0;
  },
  
  parse: func(prop) { },

  readProps: func(props) {},
    
  getName: func() { return me.name; },
  getBinding: func(axis) { return props.Node.new(); },
  isInvertable: func() { return me.invertable; },
  isInverted: func() { return me.inverted; },
  
  setInverted: func(b) { 
    if (me.invertable) me.inverted = b;
  },  
};

var CustomAxis = {
  new: func() {
    var m = { parents: [CustomAxis, Axis.new("Custom", "", 0) ] };
    me.custom_binding = nil;
    return m;
  },

  clone: func() {
    var m = { parents: [CustomAxis, Axis.new("Custom", "", 0) ] };
    m.custom_binding = me.custom_binding;
    return m;
  },
  
  match: func(prop) {
    var p = props.Node.new();
    
    if (prop.getNode("binding") != nil) {
      props.copy(prop.getNode("binding"), p);
      me.custom_binding = p;
      return 1;
    } else  {
      return 0;
    }
  },
  
  getBinding: func(axis) {
    var p = props.Node.new().getNode("axis[" ~ axis ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    props.copy(me.custom_binding, p.getNode("binding", 1));    
    return p;
  },  
};

var UnboundAxis = {
  new: func() {
    var m = { parents: [UnboundAxis, Axis.new("None", "", 0) ] };
    return m;
  },

  clone: func() {
    var m = { parents: [UnboundAxis, Axis.new("None", "", 0) ] };
    return m;
  },
  
  match: func(prop) {
    return 1;
  },
  
  getBinding: func(axis) {
    return nil;
  },
};


var PropertyScaleAxis = {
  new: func(name, prop, deadband=0, factor=1, offset=0) {
    var m = { parents: [PropertyScaleAxis, Axis.new(name, prop, 1) ] };
    m.prop=prop;
    m.deadband = deadband;
    m.factor = factor;
    m.offset = offset;
    return m;
  },

  clone: func() {
    var m = { parents: [PropertyScaleAxis, Axis.new(me.name, me.prop, 1) ] };

    m.inverted = me.inverted;
    
    m.prop= me.prop;
    m.deadband = me.deadband;
    m.factor = me.factor;
    m.offset = me.offset;
    return m;
  },

  
  match: func(prop) {
    var cmd = prop.getNode("binding", 1).getNode("command", 1).getValue();
    var p = prop.getNode("binding", 1).getNode("property", 1).getValue();
    return ((cmd == "property-scale") and (p == me.prop));
  },
  
  parse: func(p) { 
    me.deadband = p.getNode("binding", 1).getNode("dead-band", 1).getValue();        
    if (p.getNode("binding", 1).getNode("factor", 1).getValue() != nil) {
      me.inverted = (p.getNode("binding", 1).getNode("factor", 1).getValue() < 0);
    }
    me.offset = p.getNode("binding", 1).getNode("offset", 1).getValue();
  },
  
  getBinding: func(axis) {
    var p = props.Node.new();
    p = p.getNode("axis[" ~ axis ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    p.getNode("binding", 1).getNode("command", 1).setValue("property-scale");
    p.getNode("binding", 1).getNode("property", 1).setValue(me.prop);
    p.getNode("binding", 1).getNode("dead-band", 1).setValue(me.deadband);
    if (me.inverted) {    
      p.getNode("binding", 1).getNode("factor", 1).setValue(0 - me.factor);
    } else {
      p.getNode("binding", 1).getNode("factor", 1).setValue(me.factor);
    }
    p.getNode("binding", 1).getNode("offset", 1).setValue(me.offset);
    return p;
  },
  
};

var NasalScaleAxis = {
  new: func(name, script, prop) {
    var m = { parents: [NasalScaleAxis, Axis.new(name, prop, 0) ] };
    m.script = script;
    m.prop = prop;
    return m;
  },
  
  clone: func() {
    var m = { parents: [NasalScaleAxis, Axis.new(me.name, me.prop, 0) ] };
    
    m.script = me.script;
    m.prop = me.prop;
    return m;
  },
  
  match: func(prop) {
    var cmd = prop.getNode("binding", 1).getNode("command", 1).getValue();
    var p = prop.getNode("binding", 1).getNode("script", 1).getValue();
    if ((p != nil) and (cmd == "nasal")) {
      p = string.trim(p);
      p = string.replace(p, ";", "");
      p = p ~ ";";
      return (p == me.script);
    } else {
      return 0;
    }
  },
  
  getBinding: func(axis) {
    var p = props.Node.new().getNode("axis[" ~ axis ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    p.getNode("binding", 1).getNode("command", 1).setValue("nasal");
    p.getNode("binding", 1).getNode("script", 1).setValue(me.script);
    return p;
  },
};

var NasalLowHighAxis = {
  new: func(name, lowscript, highscript, prop) {
    var m = { parents: [NasalLowHighAxis, Axis.new(name, prop, 1) ] };
    m.lowscript = lowscript;
    m.highscript = highscript;
    return m;
  },
  
  clone: func() {
    var m = { parents: [NasalLowHighAxis, Axis.new(me.name, me.prop, 1) ] };

    m.inverted = me.inverted;

    m.lowscript = me.lowscript;
    m.highscript = me.highscript;
    return m;
  },  
  
  match: func(prop) {
    var cmd = prop.getNode("low", 1).getNode("binding", 1).getNode("command", 1).getValue();
    var p = prop.getNode("low", 1).getNode("binding", 1).getNode("script", 1).getValue();

    if ((p == nil) or (cmd != "nasal")) return 0;
    p = string.trim(p);
    p = string.replace(p, ";", "");
    p = p ~ ";";
    
    if (p == me.lowscript) { 
      return 1;
    }
    
    if (p == me.highscript) {
      me.inverted = 1;
      return 1;    
    }
    
    return 0;
  },
  
  getBinding: func(axis) {
    var p = props.Node.new().getNode("axis[" ~ axis ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);

    p.getNode("low", 1).getNode("binding", 1).getNode("command", 1).setValue("nasal");
    p.getNode("high", 1).getNode("binding", 1).getNode("command", 1).setValue("nasal");
    
    if (me.inverted) {
      p.getNode("low", 1).getNode("binding", 1).getNode("script", 1).setValue(me.highscript);
      p.getNode("high", 1).getNode("binding", 1).getNode("script", 1).setValue(me.lowscript);
    } else {
      p.getNode("low", 1).getNode("binding", 1).getNode("script", 1).setValue(me.lowscript);
      p.getNode("high", 1).getNode("binding", 1).getNode("script", 1).setValue(me.highscript);
    }
    
    return p;
  },
};


var axisBindings = [
  PropertyScaleAxis.new("Aileron", "/controls/flight/aileron"),
  PropertyScaleAxis.new("Elevator", "/controls/flight/elevator"),
  PropertyScaleAxis.new("Rudder",   "/controls/flight/rudder"),
  NasalScaleAxis.new("Throttle",  "controls.throttleAxis();", "/controls/engines/engine[0]/throttle") ,
  NasalScaleAxis.new("Mixture",   "controls.mixtureAxis();", "/controls/engines/engine[0]/mixture") ,
  NasalScaleAxis.new("Propeller", "controls.propellerAxis();", "/controls/engines/engine[0]/propeller-pitch") , 
  NasalLowHighAxis.new("View (horizontal)",   
                      "setprop(\"/sim/current-view/goal-heading-offset-deg\", getprop(\"/sim/current-view/goal-heading-offset-deg\") + 30);", 
                      "setprop(\"/sim/current-view/goal-heading-offset-deg\", getprop(\"/sim/current-view/goal-heading-offset-deg\") - 30);", 
                      "/sim/current-view/goal-heading-offset-deg"), 
  NasalLowHighAxis.new("View (vertical)",
                       "setprop(\"/sim/current-view/goal-pitch-offset-deg\", getprop(\"/sim/current-view/goal-pitch-offset-deg\") - 20);", 
                       "setprop(\"/sim/current-view/goal-pitch-offset-deg\", getprop(\"/sim/current-view/goal-pitch-offset-deg\") + 20);", 
                       "/sim/current-view/goal-heading-offset-deg"), 
#  PropertyScaleAxis.new("Aileron Trim",  "/controls/flight/aileron-trim"),
#  PropertyScaleAxis.new("Elevator Trim", "/controls/flight/elevator-trim"),
#  PropertyScaleAxis.new("Rudder Trim",  "/controls/flight/rudder-trim"),
  PropertyScaleAxis.new("Brake Left", "/controls/gear/brake-left", 0, 0.5, 1.0),
  PropertyScaleAxis.new("Brake Right", "/controls/gear/brake-right", 0, 0.5, 1.0),
  NasalLowHighAxis.new("Aileron Trim",  "controls.aileronTrim(-1);", "controls.aileronTrim(1);", "/controls/flight/aileron-trim"),
  NasalLowHighAxis.new("Elevator Trim", "controls.elevatorTrim(-1);", "controls.elevatorTrim(1);", "/controls/flight/elevator-trim"),
  NasalLowHighAxis.new("Rudder Trim",   "controls.rudderTrim(-1);", "controls.rudderTrim(1);", "/controls/flight/rudder-trim"), 
  CustomAxis.new(),
  UnboundAxis.new(),
];

# Button bindings
var ButtonBinding = {
  new: func(name, binding, repeatable) {
    var m = { parents: [ButtonBinding] };
    m.name = name;
    m.binding = binding;
    m.repeatable = repeatable;
    return m;
  },
  
  clone: func() {
    var m = { parents: [ButtonBinding] };
    m.name = me.name;
    m.binding= me.binding;
    m.repeatable = me.repeatable;
    return m;
  },
  
  match: func(prop) {
    return 0;
  },

  getName: func() { return me.name; },
  getBinding: func(button) { return nil; },
  isRepeatable: func() { return me.repeatable; }
};

var CustomButton = {
  new: func() {
    var m = { parents: [CustomButton, ButtonBinding.new("Custom", "", 0) ] };
    m.custom_binding = nil;
    return m;
  },

  clone: func() {
    var m = { parents: [CustomButton, ButtonBinding.new("Custom", "", 0) ] };
    m.custom_binding = me.custom_binding;
    return m;
  },
    
  match: func(prop) {
    if (prop.getNode("binding") != nil) {
      var p = props.Node.new();
      props.copy(prop.getNode("binding"), p);
      me.custom_binding = p;
      return 1;
    } else  {
      return 0;
    }
  },
  
  getBinding: func(button) {
    var p = props.Node.new().getNode("button[" ~ button ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    props.copy(me.custom_binding, p.getNode("binding", 1));    
    return p;
  },  
};

var UnboundButton = {
  new: func() {
    var m = { parents: [UnboundButton, ButtonBinding.new("None", "", 0) ] };
    return m;
  },

  clone: func() {
    var m = { parents: [UnboundButton, ButtonBinding.new("None", "", 0) ] };
    return m;
  },
  
  match: func(prop) {
    return (prop.getNode("binding") != nil);
  },
  
  getBinding: func(button) {
    var p = props.Node.new().getNode("button[" ~ button ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    return p;
  },
};


var PropertyToggleButton = {
  new: func(name, prop) {
    var m = { parents: [PropertyToggleButton, ButtonBinding.new(name, prop, 0) ] };
    return m;
  },

  clone: func() {
    var m = { parents: [PropertyToggleButton, ButtonBinding.new(me.name, me.binding, 0) ] };
    return m;
  },

  match: func(prop) {
  
    var c = prop.getNode("binding", 1).getNode("command", 1).getValue();
    var p = prop.getNode("binding", 1).getNode("property", 1).getValue();
    return ((c == "property-toggle") and (p == me.prop));
  },
  
  getBinding: func(button) {
    var p = props.Node.new().getNode("button[" ~ button ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    p.getNode("binding", 1).getNode("command", 1).setValue("property-toggle");
    p.getNode("binding", 1).getNode("property", 1).setValue(me.binding);
    return p;
  },
};

var PropertyAdjustButton = {
  new: func(name, prop, step) {
    var m = { parents: [PropertyAdjustButton, ButtonBinding.new(name, prop, 0) ] };
    m.step = step;
    return m;
  },

  clone: func() {
    var m = { parents: [PropertyAdjustButton, ButtonBinding.new(me.name, me.binding, 0) ] };
    m.step = me.step;
    return m;
  },

  match: func(prop) {  
    var c = prop.getNode("binding", 1).getNode("command", 1).getValue();
    var p = prop.getNode("binding", 1).getNode("property", 1).getValue();
    var s = prop.getNode("binding", 1).getNode("step", 1).getValue();
    return ((c == "property-adjust") and (p == me.binding) and (s == me.step));
  },
  
  getBinding: func(button) {
    var p = props.Node.new().getNode("button[" ~ button ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    p.getNode("binding", 1).getNode("command", 1).setValue("property-adjust");
    p.getNode("binding", 1).getNode("property", 1).setValue(me.binding);
    p.getNode("binding", 1).getNode("step", 1).setValue(me.step);
    return p;
  },
};

var NasalButton = {
  new: func(name, script, repeatable) {
    var m = { parents: [NasalButton, ButtonBinding.new(name, script, repeatable) ] };
    return m;
  },

  clone: func() {
    var m = { parents: [NasalButton, ButtonBinding.new(me.name, me.binding, me.repeatable) ] };
    return m;
  },

  match: func(prop) {  
    var c = prop.getNode("binding", 1).getNode("command", 1).getValue();
    var p = prop.getNode("binding", 1).getNode("script", 1).getValue();
    
    if (p == nil) { return 0; }
    
    p = string.trim(p);
    p = string.replace(p, ";", "");
    p = p ~ ";";
    
    return ((c == "nasal") and (p == me.binding));
  },
  
  getBinding: func(button) {
    var p = props.Node.new().getNode("button[" ~ button ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    p.getNode("binding", 1).getNode("command", 1).setValue("nasal");
    p.getNode("binding", 1).getNode("script", 1).setValue(me.binding);
    p.getNode("repeatable", 1).setValue(me.repeatable);
    return p;
  },
};


var NasalHoldButton = {
  new: func(name, script, scriptUp) {
    var m = { parents: [NasalHoldButton, ButtonBinding.new(name, script, 0) ] };
    m.scriptUp = scriptUp;
    return m;
  },

  clone: func() {
    var m = { parents: [NasalHoldButton, ButtonBinding.new(me.name, me.binding, 0) ] };
    m.scriptUp = me.scriptUp;
    return m;
  },

  match: func(prop) {  
  
    var c = prop.getNode("mod-up", 1).getNode("binding", 1).getNode("command", 1).getValue();
    var p1 = prop.getNode("binding", 1).getNode("script", 1).getValue();
    var p2 = prop.getNode("mod-up", 1).getNode("binding", 1).getNode("script", 1).getValue();
    
    if (p2 == nil) { return 0; }
    
    p1 = string.trim(p1);
    p1 = string.replace(p1, ";", "");
    p1 = p1 ~ ";";
    
    return ((c == "nasal") and (p1 == me.binding));
  },
  
  getBinding: func(button) {
    var p = props.Node.new().getNode("button[" ~ button ~ "]", 1);
    p.getNode("desc", 1).setValue(me.name);
    p.getNode("repeatable", 1).setValue("false");
    p.getNode("binding", 1).getNode("command", 1).setValue("nasal");
    p.getNode("binding", 1).getNode("script", 1).setValue(me.binding);
    p.getNode("mod-up", 1).getNode("binding", 1).getNode("command", 1).setValue("nasal");
    p.getNode("mod-up", 1).getNode("binding", 1).getNode("script", 1).setValue(me.scriptUp);
    return p;
  },
};

var buttonBindings = [
  NasalButton.new("Elevator Trim Up", "controls.elevatorTrim(-1);", 1),
  NasalButton.new("Elevator Trim Down", "controls.elevatorTrim(1);", 1),
  NasalButton.new("Rudder Trim Left", "controls.rudderTrim(-1);", 1),
  NasalButton.new("Rudder Trim Right", "controls.rudderTrim(1);", 1),
  NasalButton.new("Aileron Trim Left", "controls.aileronTrim(-1);", 1),
  NasalButton.new("Aileron Trim Right", "controls.aileronTrim(1);", 1),
  NasalHoldButton.new("FGCom PTT", "controls.ptt(1);", "controls.ptt(0);"),
  NasalHoldButton.new("Trigger", "controls.trigger(1);", "controls.trigger(0);"),
  NasalHoldButton.new("Flaps Up", "controls.flapsDown(-1);", "controls.flapsDown(0);"),
  NasalHoldButton.new("Flaps Down", "controls.flapsDown(1);", "controls.flapsDown(0);"),
  NasalHoldButton.new("Gear Up", "controls.gearDown(-1);", "controls.gearDown(0);"),
  NasalHoldButton.new("Gear Down", "controls.gearDown(1);", "controls.gearDown(0);"),
  NasalHoldButton.new("Spoilers Retract", "controls.stepSpoilers(-1);", "controls.stepSpoilers(0);"),
  NasalHoldButton.new("Spoilers Deploy", "controls.stepSpoilers(1);", "controls.stepSpoilers(0);"),
  NasalHoldButton.new("Brakes", "controls.applyBrakes(1);", "controls.applyBrakes(0);"),

  NasalButton.new("View Decrease", "view.decrease(0.75);", 1),
  NasalButton.new("View Increase", "view.increase(0.75);", 1),
  NasalButton.new("View Cycle Forwards", "view.stepView(1);", 0),
  NasalButton.new("View Cycle Backwards", "view.stepView(-1);", 0),
  PropertyAdjustButton.new("View Left", "/sim/current-view/goal-heading-offset-deg", "30.0"),
  PropertyAdjustButton.new("View Right", "/sim/current-view/goal-heading-offset-deg", "-30.0"),
  PropertyAdjustButton.new("View Up", "/sim/current-view/goal-pitch-offset-deg", "20.0"),
  PropertyAdjustButton.new("View Down", "/sim/current-view/goal-pitch-offset-deg", "-20.0"),
  CustomButton.new(),
];

# Parse config from the /input tree and write it to the
# dialog_root.
var readConfig = func(dialog_root="/sim/gui/dialogs/joystick-config") {

  var js_name = getprop(dialog_root ~ "/selected-joystick");
  var joysticks = props.globals.getNode("/input/joysticks").getChildren("js");
  
  if (size(joysticks) == 0) { return 0; }
  
  if (js_name == nil) {
    js_name = joysticks[0].getNode("id").getValue();  
  }
  
  var js = nil;
  
  forindex (var i; joysticks) {
    if ((joysticks[i].getNode("id") != nil) and 
        (joysticks[i].getNode("id").getValue() == js_name)) 
    {
      js = joysticks[i];
      setprop(dialog_root ~ "/selected-joystick", js_name);
      setprop(dialog_root ~ "/selected-joystick-index", i);
      setprop(dialog_root ~ "/selected-joystick-config", joysticks[i].getNode("source").getValue());
    }
  }
  
  if (js == nil) {
    # We didn't find the joystick we expected - default to the first 
    setprop(dialog_root ~ "/selected-joystick", joysticks[0].getNode("id").getValue());
    setprop(dialog_root ~ "/selected-joystick-index", 0);
    setprop(dialog_root ~ "/selected-joystick-config", joysticks[0].getNode("source").getValue());
  }
  
  # Set up the axes assignments
  var axes = js.getChildren("axis");

  for (var axis = 0; axis < MAX_AXES; axis = axis +1) {

    var p = props.globals.getNode(dialog_root ~ "/axis[" ~ axis ~ "]", 1);
    p.remove();
    p = props.globals.getNode(dialog_root ~ "/axis[" ~ axis ~ "]", 1);
    
    # Note that we can't simply use an index into the axes array
    # as that doesn't work for a sparsley populated set of axes.
    # E.g. one with n="3"
    var a = js.getNode("axis[" ~ axis ~ "]");
  
    if (a != nil) {         
      # Read properties from bindings
      props.copy(a, p.getNode("original_binding", 1));

      var binding = nil;
      foreach (var b; joystick.axisBindings) {
        if ((binding == nil) and (a != nil) and b.match(a)) {
          binding = b.clone();
          binding.parse(a);
          p.getNode("binding", 1).setValue(binding.getName());
          p.getNode("invertable", 1).setValue(binding.isInvertable());
          p.getNode("inverted", 1).setValue(binding.isInverted());
        }
      }
      
      if (binding == nil) {
        # No binding for this axis
        p.getNode("binding", 1).setValue("None");
        p.getNode("invertable", 1).setValue(0);
        p.getNode("inverted", 1).setValue(0);
        p.removeChild("original_binding");
      }         
    } else {
      p.getNode("binding", 1).setValue("None");
      p.getNode("invertable", 1).setValue(0);
      p.getNode("inverted", 1).setValue(0);
      p.removeChild("original_binding");
    }
  }

  # Set up button assignment.
  var buttons = js.getChildren("button");

  for (var button = 0; button < MAX_BUTTONS; button = button + 1) {
    var btn = props.globals.getNode(dialog_root ~ "/button[" ~ button ~ "]", 1);
    btn.remove();
    btn = props.globals.getNode(dialog_root ~ "/button[" ~ button ~ "]", 1);
    
    # Note that we can't simply use an index into the buttons array
    # as that doesn't work for a sparsley populated set of buttons.
    # E.g. one with n="3"
    var a = js.getNode("button[" ~ button ~ "]");

    if (a != nil) {         
      # Read properties from bindings
      props.copy(a, btn.getNode("original_binding", 1));
      var binding = nil;
      foreach (var b; joystick.buttonBindings) {
        if ((binding == nil) and (a != nil) and b.match(a)) {
          binding = b.clone();
          btn.getNode("binding", 1).setValue(binding.getName());
          props.copy(b.getBinding(button), btn.getNode("original_binding", 1));
        }
      }
      
      if (b == nil) {
        btn.getNode("binding", 1).setValue("None");
        btn.removeChild("original_binding");
      }
    } else {
      btn.getNode("binding", 1).setValue("None");
      btn.removeChild("original_binding");
    }
  }  

  # Set up Nasal code.
  var nasals = js.getChildren("nasal");

  for (var nasal = 0; nasal < MAX_NASALS; nasal = nasal + 1) {
    var nas = props.globals.getNode(dialog_root ~ "/nasal[" ~ nasal ~ "]", 1);
    nas.remove();
    nas = props.globals.getNode(dialog_root ~ "/nasal[" ~ nasal ~ "]", 1);
    
    # Note that we can't simply use an index into the buttons array
    # as that doesn't work for a sparsley populated set of buttons.
    # E.g. one with n="3"
    var a = js.getNode("nasal[" ~ nasal ~ "]");
    if (a != nil) {
      props.copy(a, nas.getNode("original_script", 1));
    }
  }  
}

var writeConfig = func(dialog_root="/sim/gui/dialogs/joystick-config", reset=0) {  

  # Write out the joystick file.
  var config = props.Node.new();
  var id = getprop(dialog_root ~ "/selected-joystick");
  
  if (reset == 1) {
    # We've been asked to reset the joystick config to the default.  As we can't
    # delete the configuration file, we achieve this by setting an invalid name 
    # tag that won't match. 
    config.getNode("name", 1).setValue("UNUSED INVALID CONFIG");
  } else {
    config.getNode("name", 1).setValue(id);
  }
  
  var nasals = props.globals.getNode(dialog_root).getChildren("nasal");
  forindex (var nas; nasals) {
      var nasalscript = config.getNode("nasal[" ~ nas ~ "]", 1);
      props.copy(props.globals.getNode(dialog_root ~ "/nasal[" ~ nas ~ "]/original_script", 1), nasalscript);
  }  
  
  var axes = props.globals.getNode(dialog_root).getChildren("axis");
  forindex (var axis; axes) {
    var name = getprop(dialog_root ~ "/axis[" ~ axis ~ "]/binding");
    
    if (name != "None") {
      foreach (var binding; axisBindings) {
        if (binding.getName() == name) {
          var b = binding.clone();
          b.setInverted(getprop(dialog_root ~ "/axis[" ~ axis ~ "]/inverted"));
          
          # Generate the axis and binding
          var axisnode = config.getNode("axis[" ~ axis ~ "]", 1);
          if (name == "Custom") {          
            props.copy(props.globals.getNode(dialog_root ~ "/axis[" ~ axis ~ "]/original_binding", 1), axisnode);
          } else {
            props.copy(b.getBinding(axis), axisnode);
          }
        }
      }    
    }
  }

  var buttons = props.globals.getNode(dialog_root).getChildren("button");
  forindex (var btn; buttons) {
    var name = getprop(dialog_root ~ "/button[" ~ btn ~ "]/binding");

    if (name != "None") {
      foreach (var binding; buttonBindings) {
        if (binding.getName() == name) {
          var b = binding.clone();
          # Generate the axis and binding
          var buttonprop = config.getNode("button[" ~ btn ~ "]", 1);
          if (name == "Custom") {          
            props.copy(props.globals.getNode(dialog_root ~ "/button[" ~ btn ~ "]/original_binding", 1), buttonprop);
          } else {
            props.copy(b.getBinding(btn), buttonprop);
          }
        }
      }    
    }
  }
  
  var filename = id;
  filename = string.replace(filename, " ", "-");
  filename = string.replace(filename, ".", "");
  filename = string.replace(filename, "/", "");
  
  # Write out the file
  io.write_properties(getprop("/sim/fg-home") ~ "/Input/Joysticks/" ~ filename ~ ".xml", config);
}

var resetConfig = func(dialog_root="/sim/gui/dialogs/joystick-config") {
  writeConfig(dialog_root, 1);
}
