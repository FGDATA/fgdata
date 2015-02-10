/**
 * 
 */
var fgCommand = {
  oneArg : function(t1, p1) {
    return {
      name : '',
      children : [ {
        name : t1,
        index : 0,
        value : p1
      }  ]
    };
  },
  twoArgs : function(t1, p1, t2, p2) {
    return {
      name : '',
      children : [ {
        name : t1,
        index : 0,
        value : p1
      }, {
        name : t2,
        index : (t1 == t2 ? 1 : 0),
        value : p2
      } ]
    };
  },

  twoPropsArgs : function(p1, p2) {
    return this.twoArgs("property", p1, "property", p2);
  },

  propValueArgs : function(p, v) {
    return this.twoArgs("property", p, "value", v);
  },

  sendCommand : function(name, args) {
    if (typeof (args) == 'undefined ')
      $.post("/run.cgi?value=" + name);
    else
      $.post("/run.cgi?value=" + name, JSON.stringify(args));

  },

  propertySwap : function(p1, p2) {
    this.sendCommand("property-swap", this.twoPropsArgs(p1, p2));
  },

  propertyAssign : function(p1, value) {
    this.sendCommand("property-assign", this.propValueArgs(p1, value));
  },

  pause : function() {
    $.post("/run.cgi?value=pause");
  },

  dialogShow: function(dlg) {
    this.sendCommand("dialog-show", this.oneArg("dialog-name",dlg)); 
  },
  dialogClose: function(dlg) {
    this.sendCommand("dialog-close", this.oneArg("dialog-name",dlg)); 
  },
  reposition: function() {
    $.post("/run.cgi?value=reposition");
  },
  timeofday: function(type,offset) {
    this.sendCommand("timeofday", this.twoArgs("timeofday", type, "offset", null != offset ? offset : 0 ));
  }
};

