var KX165 = {
  baseNode : "/instrumentation/",
  use : "selected-mhz",
  standby : "standby-mhz",

  swap : function(what, idx) {
    var base = this.makeNodeName(idx, what);
    fgCommand.propertySwap(base + this.use, base + this.standby);
  },

  set : function(what, which, idx, val) {
    fgCommand.propertyAssign(this.makeNodeName(idx, what, which), val);
  },

  bind : function(idx, div) {

    // click handler for swap buttons
    $(div).find("#com-swap").click(function() {
      KX165.swap("comm", idx);
    });
    $(div).find("#nav-swap").click(function() {
      KX165.swap("nav", idx);
    });

    // change handler for frequency input fields
    $(div).find("#com-use").change(function(evt) {
      KX165.set("comm", KX165.use, idx, evt.target.value);
    });

    $(div).find("#com-standby").change(function(evt) {
      KX165.set("comm", KX165.standby, idx, evt.target.value);
    });

    $(div).find("#nav-use").change(function(evt) {
      KX165.set("nav", KX165.use, idx, evt.target.value);
    });

    $(div).find("#nav-standby").change(function(evt) {
      KX165.set("nav", KX165.standby, idx, evt.target.value);
    });

    // listen for changed properties
    SetListener( KX165.makeNodeName( idx, "comm", KX165.use ) + "-fmt", function(n) {
      $(div).find("#com-use").val( n.value );
    });
    SetListener( KX165.makeNodeName( idx, "comm", KX165.standby ) + "-fmt", function(n) {
      $(div).find("#com-standby").val( n.value );
    });
    SetListener( KX165.makeNodeName( idx, "nav", KX165.use ) + "-fmt", function(n) {
      $(div).find("#nav-use").val( n.value );
    });
    SetListener( KX165.makeNodeName( idx, "nav", KX165.standby ) + "-fmt", function(n) {
      $(div).find("#nav-standby").val( n.value );
    });
  },

  makeNodeName : function(idx, section, leaf) {
    // build /instrumentation/comm[n]/frequencies/selected-mhz
    var reply = this.baseNode + section;
    if (idx > 0)
      reply += "[" + idx + "]";
    reply += "/frequencies/";
    if( typeof(leaf) != 'undefined' )
      reply += leaf;
    return reply;
  }
};
