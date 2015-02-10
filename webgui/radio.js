$(document).ready(
    function() {

      var rp = new Array();
      rp["#com1u"] = "/instrumentation/comm/frequencies/selected-mhz";
      rp["#com1s"] = "/instrumentation/comm/frequencies/standby-mhz";
      rp["#nav1u"] = "/instrumentation/nav/frequencies/selected-mhz";
      rp["#nav1s"] = "/instrumentation/nav/frequencies/standby-mhz";
      rp["#com2u"] = "/instrumentation/comm[1]/frequencies/selected-mhz";
      rp["#com2s"] = "/instrumentation/comm[1]/frequencies/standby-mhz";
      rp["#nav2u"] = "/instrumentation/nav[1]/frequencies/selected-mhz";
      rp["#nav2s"] = "/instrumentation/nav[1]/frequencies/standby-mhz";
      rp["#adf1u"] = "/instrumentation/adf/frequencies/selected-khz";
      rp["#adf1s"] = "/instrumentation/adf/frequencies/standby-khz";
      rp["#dme1u"] = "/instrumentation/dme/frequencies/selected-mhz";

      $("#com1u").change(function(o) {
        fgCommand.propertyAssign(rp["#com1u"], $("#com1u").val());
      });
      $("#com1s").change(function(o) {
        fgCommand.propertyAssign(rp["#com1s"], $("#com1s").val());
      });
      $("#nav1u").change(function(o) {
        fgCommand.propertyAssign(rp["#nav1u"], $("#nav1u").val());
      });
      $("#nav1s").change(function(o) {
        fgCommand.propertyAssign(rp["#nav1s"], $("#nav1s").val());
      });
      $("#com2u").change(function(o) {
        fgCommand.propertyAssign(rp["#com2u"], $("#com2u").val());
      });
      $("#com2s").change(function(o) {
        fgCommand.propertyAssign(rp["#com2s"], $("#com2s").val());
      });
      $("#nav2u").change(function(o) {
        fgCommand.propertyAssign(rp["#nav2u"], $("#nav2u").val());
      });
      $("#nav2s").change(function(o) {
        fgCommand.propertyAssign(rp["#nav2s"], $("#nav2s").val());
      });
      $("#adf1u").change(function(o) {
        fgCommand.propertyAssign(rp["#adf1u"], $("#adf1u").val());
      });
      $("#adf1s").change(function(o) {
        fgCommand.propertyAssign(rp["#adf1s"], $("#adf1s").val());
      });
      $("#dme1u").change(function(o) {
        fgCommand.propertyAssign(rp["#dme1u"], $("#dme1u").val());
      });

      $("#com1swap").click(function() {
        fgCommand.propertySwap(rp["#com1u"], rp["#com1s"]);
      });
      $("#nav1swap").click(function() {
        fgCommand.propertySwap(rp["#nav1u"], rp["#nav1s"]);
      });
      $("#com2swap").click(function() {
        fgCommand.propertySwap(rp["#com2u"], rp["#com2s"]);
      });
      $("#nav2swap").click(function() {
        fgCommand.propertySwap(rp["#nav2u"], rp["#nav2s"]);
      });
      $("#adf1swap").click(function() {
        fgCommand.propertySwap(rp["#adf1u"], rp["#adf1s"]);
      });

      PropertyChangeListener(function() {
        SetListener( rp["#com1u"], function(n) {
          $("#com1u").val( n.value );
        });
        SetListener( rp["#com1s"], function(n) {
          $("#com1s").val( n.value );
        });
        SetListener( rp["#nav1u"], function(n) {
          $("#nav1u").val( n.value );
        });
        SetListener( rp["#nav1s"], function(n) {
          $("#nav1s").val( n.value );
        });
        SetListener( rp["#com2u"], function(n) {
          $("#com2u").val( n.value );
        });
        SetListener( rp["#com2s"], function(n) {
          $("#com2s").val( n.value );
        });
        SetListener( rp["#nav2u"], function(n) {
          $("#nav2u").val( n.value );
        });
        SetListener( rp["#nav2s"], function(n) {
          $("#nav2s").val( n.value );
        });
        SetListener( rp["#adf1u"], function(n) {
          $("#adf1u").val( n.value );
        });
        SetListener( rp["#adf1s"], function(n) {
          $("#adf1s").val( n.value );
        });
        SetListener( rp["#dme1u"], function(n) {
          $("#dme1u").val( n.value );
        });
      });
});
