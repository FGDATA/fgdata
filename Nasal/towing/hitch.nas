#
# Version: 30. December 2014
#
# Purpose of this routine:
# ------------------------
#
# - Create visible winch- and towropes for gliders and towplanes
# - Support of aerotowing and winch for JSBSim-aircraft (glider and towplanes)
#
# This routine is very similar to /FDM/YASim/Hitch.cpp
# Aerotowing is fully compatible to the YASim functionality.
# This means that YASim-gliders could be towed by JSBSim-aircraft and vice versa.
# Setup-instructions with copy and paste examples are given below:
#
#
# Setup of visible winch/towropes for Yasim-aircraft:
# ----------------------------------------------------
#
# YASim-aircraft with winch/aerotowing functionality should work out of the box.
# Optional you can customize the rope-diameter by adding the following to "your_aircraft-set.xml":
# </sim>
#  <hitches>
#   <aerotow>
#    <rope>
#     <rope-diameter-mm type ="float">10</rope-diameter-mm>
#    </rope>
#   </aerotow>
#   <winch>
#    <rope>
#     <rope-diameter-mm type ="float">20</rope-diameter-mm>
#    </rope>
#   </winch>
#  </hitches>
# </sim>
#
# That's all!
#
#
#
# Support of aerotowing and winch for JSBSim-aircraft (glider and towplanes):
# ----------------------------------------------------------------------------
#
# 1. Define a hitch in the JSBSim-File. Coordinates according to JSBSims structural frame of reference
# (x points to the tail, y points to the right wing, z points upwards).
# Unit must be "LBS", frame must be "BODY". The force name is arbitrary.
#
# <external_reactions>
#  <force name="hitch" frame="BODY" unit="LBS" >
#   <location unit="M">
#    <x>3.65</x>
#    <y> 0.0</y>
#    <z>-0.12</z>
#   </location>
#   <direction>
#    <x>0.0</x>
#    <y>0.0</y>
#    <z>0.0</z>
#   </direction>
#  </force>
# </external_reactions>


# 2. Define controls for aerotowing and winch.
# Add the following key bindings in "yourAircraft-set.xml":
# <input>
#  <keyboard>
#
#   <key n="15">
#     <name>Ctrl-o</name>
#     <desc>Find aircraft for aerotow</desc>
#     <binding>
#	<command>nasal</command>
#	<script>towing.findBestAIObject()</script>
#     </binding>
#   </key>
#
#   <key n="111">
#     <name>o</name>
#     <desc>Lock aerotow-hook</desc>
#     <binding>
#	<command>nasal</command>
#	<script>towing.closeHitch()</script>
#     </binding>
#   </key>
#
#   <key n="79">
#     <name>O</name>
#     <desc>Open aerotow-hook</desc>
#     <binding>
#	<command>nasal</command>
#	<script>towing.releaseHitch("aerotow")</script>
#     </binding>
#   </key>
#
#   <key n="23">
#     <name>Ctrl-w</name>
#     <desc>Place Winch and hook in</desc>
#     <binding>
#	<command>nasal</command>
#	<script>towing.setWinchPositionAuto()</script>
#     </binding>
#   </key>
#
#   <key n="119">
#     <name>w</name>
#     <desc>Start winch</desc>
#     <binding>
#	<command>nasal</command>
#	<script>towing.runWinch()</script>
#     </binding>
#   </key>
#
#   <key n="87">
#     <name>W</name>
#     <desc>Open winch-hook</desc>
#     <binding>
#	<command>nasal</command>
#	<script>towing.releaseHitch("winch")</script>
#     </binding>
#   </key>
#
#  </keyboard>
# </input>
#
# For towplanes only "key n=79" (Open aerotow-hook) is required!


# 3. Set mandatory properties:
#<sim>
# <hitches>
#  <aerotow>
#   <force_name_jsbsim type="string">hitch</force_name_jsbsim>
#   <force-is-calculated-by-other type="bool">false</force-is-calculated-by-other>
#   <mp-auto-connect-period type="float">0.0</mp-auto-connect-period>
#   <!-- OPTIONAL
#     <decoupled-force-and-rope-locations type="bool">true</decoupled-force-and-rope-locations>
#     <local-pos-x type="float">1.5</local-pos-x>
#     <local-pos-y type="float"> 0.00</local-pos-y>
#     <local-pos-z type="float">-0.3</local-pos-z>
#   -->
#  </aerotow>
#  <winch>
#   <force_name_jsbsim type="string">hitch</force_name_jsbsim>
#   <!-- OPTIONAL
#     <decoupled-force-and-rope-locations type="bool">true</decoupled-force-and-rope-locations>
#     <local-pos-x type="float">0.0</local-pos-x>
#     <local-pos-y type="float">0.0</local-pos-y>
#     <local-pos-z type="float">0.0</local-pos-z>
#   -->
#  </winch>
# </hitches>
#</sim>
#
# "force_name_jsbsim" must be the external force name in JSBSim.
# "force-is-calculated-by-other" should be "false" for gliders and "true" for tow planes.
# "mp-auto-connect-period" is only needed for tow planes and should be "1".
#
# IMPORTANT:
# The hitch location is stored twice in the property tree (for tow force and for rope animation).
# This is necessary to keep the towrope animation compatible to YASim-aircraft.
# The hitch location for the tow force is stored in "fdm/jsbsim/external_reactions/hitch/location-x(yz)-in" and for the
# animated towrope in "sim/hitches/aerotow(winch)/local-pos-x(yz)".
# By default only values for the tow force location have to be defined. The values for the towrope location are set
# automatically (decoupled-force-and-rope-locations is "false" by default).
# It is feasible to use different locations for the force and rope. In order to do this, you have to set
# "decoupled-force-and-rope-locations" to "true" and provide values for "sim/hitches/aerotow(winch)/local-pos-x(yz)".
# Note that the frame of reference is different. Here the coordinates for the "YASim-System" are needed
# (x points to the nose, y points to the left wing, z points upwards).


# 4. Set optional properties:
#<sim>
# <hitches>
#  <aerotow>
#   <tow>
#    <brake-force type="float">6000</brake-force>
#    <elastic-constant type="float">9000</elastic-constant>
#   </tow>
#   <rope>
#    <rope-diameter-mm type="float">20</rope-diameter-mm>
#   </rope>
#  </aerotow>
#  <winch>
#   <automatic-release-angle-deg type="float">70.</automatic-release-angle-deg>
#   <winch>
#    <initial-tow-length-m type="float">1000.</initial-tow-length-m>
#    <max-tow-length-m type="float">1500.</max-tow-length-m>
#    <max-force type="float">800.</max-force>
#    <max-power-kW type="float">100.</max-power-kW>
#    <max-spool-speed-m-s type="float">15.</max-spool-speed-m-s>
#    <max-unspool-speed-m-s type="float">20.</max-unspool-speed-m-s>
#    <spool-acceleration-m-s-s type="float">8.</spool-acceleration-m-s-s>
#    <rel-speed alias="/sim/hitches/winch/winch/actual-spool-speed-m-s"/>
#   </winch>
#   <tow>
#    <break-force type="float">10000</break-force>
#    <elastic-constant type="float">40000</elastic-constant>
#    <weight-per-m-kg-m type="float">0.01</weight-per-m-kg-m>
#   </tow>
#   <rope>
#    <rope-diameter-mm type="float">40</rope-diameter-mm>
#   </rope>
#  </winch>
# </hitches>
#<sim>


# That's it!


##################################################  general info  ############################################
#
# 3 different types of towplanes could exist: AI-plane, MP-plane without interaction, MP-plane with interaction.
# AI-planes are identified by the node "ai/models/aircraft/".
# MP-planes (interactice/non-interactive) are identified by the existence of node "ai/models/multiplayer".
# Interactive MP-plane: variables in node "ai/models/multiplayer/sim/hitches/" are updated.
# Non-interactive MP-plane: variables are not updated (values are either not defined or have "wrong" values
# from a former owner of this node.
#
# The following properties are transmitted in multiplayer:
# "sim/hitches/aerotow/tow/elastic-constant"
# "sim/hitches/aerotow/tow/weight-per-m-kg-m"
# "sim/hitches/aerotow/tow/dist"
# "sim/hitches/aerotow/tow/connected-to-property-node"
# "sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign"
# "sim/hitches/aerotow/tow/brake-force"
# "sim/hitches/aerotow/tow/end-force-x"
# "sim/hitches/aerotow/tow/end-force-y"
# "sim/hitches/aerotow/tow/end-force-z"
# "sim/hitches/aerotow/is-slave"
# "sim/hitches/aerotow/speed-in-tow-direction"
# "sim/hitches/aerotow/open", open);
# "sim/hitches/aerotow/local-pos-x"
# "sim/hitches/aerotow/local-pos-y"
# "sim/hitches/aerotow/local-pos-z"
#
##############################################################################################################




# ######################################################################################################################
#                                            check, if towing support makes sense
# ######################################################################################################################

# Check if node "sim/hitches" is defined. If not, return!
  if (props.globals.getNode("sim/hitches") == nil ) return;
  print("towing is active!");


# ######################################################################################################################
#                                           set defaults / initialize at startup
# ######################################################################################################################

# set defaults for properties that are NOT already defined

 # yasim properties for aerotow (should be already defined for yasim aircraft but not for JSBSim aircraft
  if (props.globals.getNode("sim/hitches/aerotow/broken") == nil )
      props.globals.getNode("sim/hitches/aerotow/broken", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/aerotow/force") == nil )
      props.globals.getNode("sim/hitches/aerotow/force", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/force-is-calculated-by-other") == nil )
      props.globals.getNode("sim/hitches/aerotow/force-is-calculated-by-other", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/aerotow/is-slave") == nil )
      props.globals.getNode("sim/hitches/aerotow/is-slave", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/aerotow/local-pos-x") == nil )
      props.globals.getNode("sim/hitches/aerotow/local-pos-x", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/local-pos-y") == nil )
      props.globals.getNode("sim/hitches/aerotow/local-pos-y", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/local-pos-z") == nil )
      props.globals.getNode("sim/hitches/aerotow/local-pos-z", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/mp-auto-connect-period") == nil )
      props.globals.getNode("sim/hitches/aerotow/mp-auto-connect-period", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/mp-time-lag") == nil )
      props.globals.getNode("sim/hitches/aerotow/mp-time-lag", 1).setValue(0.);
  #if (props.globals.getNode("sim/hitches/aerotow/open") == nil )
      props.globals.getNode("sim/hitches/aerotow/open", 1).setBoolValue(1);
  if (props.globals.getNode("sim/hitches/aerotow/speed-in-tow-direction") == nil )
      props.globals.getNode("sim/hitches/aerotow/speed-in-tow-direction", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/tow/brake-force") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/brake-force", 1).setValue(12345.);
  if (props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-node") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-node", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign", 1).setValue("");
  if (props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-or-mp-id") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-or-mp-id", 1).setIntValue(0);
  if (props.globals.getNode("sim/hitches/aerotow/tow/connected-to-mp-node") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-mp-node", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/aerotow/tow/connected-to-property-node") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-property-node", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/aerotow/tow/dist") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/dist", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/tow/elastic-constant") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/elastic-constant", 1).setValue(9111.);
  if (props.globals.getNode("sim/hitches/aerotow/tow/end-force-x") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/end-force-x", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/tow/end-force-y") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/end-force-y", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/tow/end-force-z") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/end-force-z", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/aerotow/tow/length") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/length", 1).setValue(60.);
  if (props.globals.getNode("sim/hitches/aerotow/tow/node") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/node", 1).setValue("");
  if (props.globals.getNode("sim/hitches/aerotow/tow/weight-per-m-kg-m") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/weight-per-m-kg-m", 1).setValue(0.35);

 # additional properties
  if (props.globals.getNode("sim/hitches/aerotow/oldOpen") == nil )
      props.globals.getNode("sim/hitches/aerotow/oldOpen", 1).setBoolValue(1);

 # new properties for towrope
  if (props.globals.getNode("sim/hitches/aerotow/rope/exist") == nil )
      props.globals.getNode("sim/hitches/aerotow/rope/exist", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/aerotow/rope/model_id") == nil )
      props.globals.getNode("sim/hitches/aerotow/rope/model_id", 1).setIntValue(-1);
  if (props.globals.getNode("sim/hitches/aerotow/rope/path_to_model") == nil )
      props.globals.getNode("sim/hitches/aerotow/rope/path_to_model", 1).setValue("Models/Aircraft/towropes.xml");
  if (props.globals.getNode("sim/hitches/aerotow/rope/rope-diameter-mm") == nil )
      props.globals.getNode("sim/hitches/aerotow/rope/rope-diameter-mm", 1).setIntValue(20.);

 # new properties for JSBSim aerotow
 if ( getprop("sim/flight-model") == "jsb" ) {
  if (props.globals.getNode("sim/hitches/aerotow/force_name_jsbsim") == nil )
      props.globals.getNode("sim/hitches/aerotow/force_name_jsbsim", 1).setValue("hitch");
  if (props.globals.getNode("sim/hitches/aerotow/mp_oldOpen") == nil )
      props.globals.getNode("sim/hitches/aerotow/mp_oldOpen", 1).setBoolValue(1);
  if (props.globals.getNode("sim/hitches/aerotow/tow/mp_last_reporded_dist") == nil )
      props.globals.getNode("sim/hitches/aerotow/tow/mp_last_reported_dist", 1).setValue(0.);
 }

 # yasim properties for winch (should already be defined for yasim aircraft but not for JSBSim aircraft
  #if (props.globals.getNode("sim/hitches/winch/open") == nil )
      props.globals.getNode("sim/hitches/winch/open", 1).setBoolValue(1);
  if (props.globals.getNode("sim/hitches/winch/broken") == nil )
      props.globals.getNode("sim/hitches/winch/broken", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/winch/winch/global-pos-x") == nil )
      props.globals.getNode("sim/hitches/winch/winch/global-pos-x", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/winch/winch/global-pos-y") == nil )
      props.globals.getNode("sim/hitches/winch/winch/global-pos-y", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/winch/winch/global-pos-z") == nil )
      props.globals.getNode("sim/hitches/winch/winch/global-pos-z", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/winch/winch/initial-tow-length-m") == nil )
      props.globals.getNode("sim/hitches/winch/winch/initial-tow-length-m", 1).setValue(1000.);
  if (props.globals.getNode("sim/hitches/winch/winch/max-tow-length-m") == nil )
      props.globals.getNode("sim/hitches/winch/winch/max-tow-length-m", 1).setValue(1500.);
  if (props.globals.getNode("sim/hitches/winch/winch/min-tow-length-m") == nil )
      props.globals.getNode("sim/hitches/winch/winch/min-tow-length-m", 1).setValue(1.);

  if (props.globals.getNode("sim/hitches/winch/tow/length") == nil )
      props.globals.getNode("sim/hitches/winch/tow/length", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/winch/tow/dist") == nil )
      props.globals.getNode("sim/hitches/winch/tow/dist", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/winch/tow/elastic-constant") == nil )
      props.globals.getNode("sim/hitches/winch/tow/elastic-constant", 1).setValue(40001.);
  if (props.globals.getNode("sim/hitches/winch/tow/weight-per-m-kg-m") == nil )
      props.globals.getNode("sim/hitches/winch/tow/weight-per-m-kg-m", 1).setValue(0.1);

 # additional properties
  if (props.globals.getNode("sim/hitches/winch/oldOpen") == nil )
      props.globals.getNode("sim/hitches/winch/oldOpen", 1).setBoolValue(1);
  if (props.globals.getNode("sim/hitches/winch/winch/max-spool-speed-m-s") == nil )
      props.globals.getNode("sim/hitches/winch/winch/max-spool-speed-m-s", 1).setValue(40.);

 # new properties for winch-rope
  if (props.globals.getNode("sim/hitches/winch/rope/exist") == nil )
      props.globals.getNode("sim/hitches/winch/rope/exist", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/winch/rope/model_id") == nil )
      props.globals.getNode("sim/hitches/winch/rope/model_id", 1).setIntValue(-1);
  if (props.globals.getNode("sim/hitches/winch/rope/path_to_model") == nil )
      props.globals.getNode("sim/hitches/winch/rope/path_to_model", 1).setValue("Models/Aircraft/towropes.xml");
  if (props.globals.getNode("sim/hitches/winch/rope/rope-diameter-mm") == nil )
      props.globals.getNode("sim/hitches/winch/rope/rope-diameter-mm", 1).setIntValue(20.);

 # new properties for JSBSim winch
 if ( getprop("sim/flight-model") == "jsb" ) {
  if (props.globals.getNode("sim/hitches/winch/force_name_jsbsim") == nil )
      props.globals.getNode("sim/hitches/winch/force_name_jsbsim", 1).setValue("hitch");
  if (props.globals.getNode("sim/hitches/winch/automatic-release-angle-deg") == nil )
      props.globals.getNode("sim/hitches/winch/automatic-release-angle-deg", 1).setValue(361.);
  if (props.globals.getNode("sim/hitches/winch/winch/clutched") == nil )
      props.globals.getNode("sim/hitches/winch/winch/clutched", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/winch/winch/actual-spool-speed-m-s") == nil )
      props.globals.getNode("sim/hitches/winch/winch/actual-spool-speed-m-s", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/winch/winch/spool-acceleration-m-s-s") == nil )
      props.globals.getNode("sim/hitches/winch/winch/spool-acceleration-m-s-s", 1).setValue(8.);
  if (props.globals.getNode("sim/hitches/winch/winch/max-unspool-speed-m-s") == nil )
      props.globals.getNode("sim/hitches/winch/winch/max-unspool-speed-m-s", 1).setValue(40.);
  if (props.globals.getNode("sim/hitches/winch/winch/actual-force-N") == nil )
      props.globals.getNode("sim/hitches/winch/winch/actual-force-N", 1).setValue(0.);
  if (props.globals.getNode("sim/hitches/winch/winch/max-force-N") == nil )
      props.globals.getNode("sim/hitches/winch/winch/max-force-N", 1).setValue(1000.);
  if (props.globals.getNode("sim/hitches/winch/winch/max-power-kW") == nil )
      props.globals.getNode("sim/hitches/winch/winch/max-power-kW", 1).setValue(123.);
  if (props.globals.getNode("sim/hitches/winch/tow/break-force-N") == nil )
      props.globals.getNode("sim/hitches/winch/tow/break-force-N", 1).setValue(12345.);
  if (props.globals.getNode("sim/hitches/winch/winch/magic-constant") == nil )
      props.globals.getNode("sim/hitches/winch/winch/magic-constant", 1).setValue(500.);
 }

 # new properties for JSBSim aerotow and winch
 if ( getprop("sim/flight-model") == "jsb" ) {
  if (props.globals.getNode("sim/hitches/aerotow/decoupled-force-and-rope-locations") == nil )
      props.globals.getNode("sim/hitches/aerotow/decoupled-force-and-rope-locations", 1).setBoolValue(0);
  if (props.globals.getNode("sim/hitches/winch/decoupled-force-and-rope-locations") == nil )
      props.globals.getNode("sim/hitches/winch/decoupled-force-and-rope-locations", 1).setBoolValue(0);
  # consider older JSBSim-versions which do NOT provide the locations of external_reactions in the property tree
   var hitchname_aerotow = getprop("sim/hitches/aerotow/force_name_jsbsim");
   var hitchname_winch   = getprop("sim/hitches/winch/force_name_jsbsim");
   if (props.globals.getNode("fdm/jsbsim/external_reactions/" ~ hitchname_aerotow ~ "/location-x-in") == nil )
     props.globals.getNode("sim/hitches/aerotow/decoupled-force-and-rope-locations").setBoolValue(1);
   if (props.globals.getNode("fdm/jsbsim/external_reactions/" ~ hitchname_winch ~ "/location-x-in") == nil )
     props.globals.getNode("sim/hitches/winch/decoupled-force-and-rope-locations").setBoolValue(1);
 }

# ######################################################################################################################
#                                                         main function
# ######################################################################################################################

var towing = func {

  #print("function towing is running");

  var FT2M = 0.30480;
  var M2FT = 1 / FT2M;
  var dt = 0;

  # -------------------------------  aerotow part -------------------------------

  var open = getprop("sim/hitches/aerotow/open");
  var oldOpen = getprop("sim/hitches/aerotow/oldOpen");

  if ( open != oldOpen ) {   # check if my hitch state has changed, if yes: message
    #print("state has changed: open=",open,"  oldOpen=",oldOpen);

    if ( !open ) {      # my hitch was open and is closed now
      if ( getprop("sim/flight-model") == "jsb" ) {
        var distance = getprop("sim/hitches/aerotow/tow/dist");
        var towlength_m = getprop("sim/hitches/aerotow/tow/length");
        if ( distance > towlength_m * 1.0001 ) {
          setprop("sim/messages/pilot", sprintf("Could not lock hitch (tow length is insufficient) on hitch %i!",
                                               getprop("sim/hitches/aerotow/tow/connected-to-mp-node")));
          props.globals.getNode("sim/hitches/aerotow/open").setBoolValue(1);  # open my hitch again
        }  # mp aircraft to far away
        else {  # my hitch is closed
          setprop("sim/messages/pilot", sprintf("Locked hitch aerotow %i!",
                                                 getprop("sim/hitches/aerotow/tow/connected-to-mp-node")));
        }
        props.globals.getNode("sim/hitches/aerotow/broken").setBoolValue(0);
      }  # end: JSBSim
      if ( !getprop("sim/hitches/aerotow/open") ) {
        # setup ai-towrope
        createTowrope("aerotow");

        # set default hitch coordinates (needed for Ai- and non-interactive MP aircraft)
        setAIObjectDefaults() ;
      }
    }  # end hitch is closed

    if ( open ) {   # my hitch is now open
      if ( getprop("sim/flight-model") == "jsb" ) {
        if ( getprop("sim/hitches/aerotow/broken") ) {
          setprop("sim/messages/pilot", sprintf("Oh no, the tow is broken"));
        }
        else {
          setprop("sim/messages/pilot", sprintf("Opened hitch aerotow %i!",
                                                getprop("sim/hitches/aerotow/tow/connected-to-mp-node")));
        }
      releaseHitch("aerotow"); # open=1 / forces=0
      }  # end: JSBSim
      removeTowrope("aerotow");   # remove towrope model
    }  # end hitch is open

    setprop("sim/hitches/aerotow/oldOpen",open);
  }  # end hitch state has changed

  if (!open ) {
    aerotow(open);
  }  # end hitch is closed (open == 0)
  else {   # my hitch is open
    var mp_auto_connect_period = props.globals.getNode("sim/hitches/aerotow/mp-auto-connect-period").getValue();
    if ( mp_auto_connect_period != 0 ) {   # if auto-connect
      if ( getprop("sim/flight-model") == "jsb" ) {  # only for JSBSim aircraft
        findBestAIObject();
      }   # end JSBSim	aircraft
      dt = mp_auto_connect_period;
      #print("towing: running as auto connect with period=",dt);
    }   # end if auto-connect
    else {  # my hitch is open and not auto-connect
      dt = 0;
    }
  }


  # -------------------------------  winch part -------------------------------

  var winchopen = getprop("sim/hitches/winch/open");
  var wincholdOpen = getprop("sim/hitches/winch/oldOpen");

  if ( winchopen != wincholdOpen ) {   # check if my hitch state has changed, if yes: message
    #print("winch state has changed: open=",winchopen,"  oldOpen=",wincholdOpen);
    if ( !winchopen ) {      # my hitch was open and is closed now
      if ( getprop("sim/flight-model") == "jsb" ) {
        var distance = getprop("sim/hitches/winch/tow/dist");
        var towlength_m = getprop("sim/hitches/winch/tow/length");
        if ( distance > towlength_m ) {
          setprop("sim/messages/pilot", sprintf("Could not lock hitch (tow length is insufficient) on hitch %i!",
                                               getprop("sim/hitches/aerotow/tow/connected-to-mp-node")));
          props.globals.getNode("sim/hitches/aerotow/open").setBoolValue(1);  # open my hitch again
        }  # mp aircraft to far away
        else {  # my hitch is closed
          setprop("sim/messages/pilot", sprintf("Locked hitch winch %i!",
                                                 getprop("sim/hitches/aerotow/tow/connected-to-mp-node")));
          setprop("sim/hitches/winch/winch/clutched","false");
        }
        props.globals.getNode("sim/hitches/winch/broken").setBoolValue(0);
        props.globals.getNode("sim/hitches/winch/winch/actual-spool-speed-m-s").setValue(0.);
      }  # end: JSBSim
      if ( !getprop("sim/hitches/winch/open") ) {
        # setup ai-towrope
        createTowrope("winch");

        # set default hitch coordinates (needed for Ai- and non-interactive MP aircraft)
        setAIObjectDefaults() ;
      }
    }  # end hitch is closed

    if ( winchopen ) {   # my hitch is now open
      if ( getprop("sim/flight-model") == "jsb" ) {
        if ( getprop("sim/hitches/winch/broken") ) {
          setprop("sim/messages/pilot", sprintf("Oh no, the tow is broken"));
        }
      releaseHitch("winch");
      }  # end: JSBSim
      pull_in_rope();
    }  # end hitch is open

    setprop("sim/hitches/winch/oldOpen",winchopen);
  } # end hitch state has changed

  if (!winchopen ) {
    winch(winchopen);
  }

  settimer( towing, dt );

}   # end towing


# ######################################################################################################################
#                                                   find best AI object
# ######################################################################################################################

var findBestAIObject = func (){

  # the nearest found plane, that is close enough will be used
  # set some default variables, needed later to identify if the found object is
  # an AI-Object, a "non-interactiv MP-Object or an interactive MP-Object

  # local variables
  var aiobjects = [];                    # keeps the ai-planes from the property tree
  var aiPosition = geo.Coord.new();      # current processed ai-plane
  var myPosition = geo.Coord.new();      # coordinates of glider
  var distance_m = 0;                    # distance to ai-plane

  var FT2M = 0.30480;

  var nodeIsAiAircraft = 0;
  var nodeIsMpAircraft = 0;
  var running_as_autoconnect = 0;
  var mp_open_last_state = 0;
  var isSlave = 0;

  if ( getprop("sim/flight-model") == "yasim" ) return;	# bypass this routine for Yasim-aircraft

  #print("findBestAIObject");

  if (props.globals.getNode("sim/hitches/aerotow/mp-auto-connect-period").getValue() != 0 ) {
    var running_as_autoconnect = 1;
    #print("findBestAIObject: running as auto connect");
  }

  var towlength_m = props.globals.getNode("sim/hitches/aerotow/tow/length").getValue();

  var bestdist_m = towlength_m; # initial value

  myPosition = geo.aircraft_position();
  # todo: calculate exact hitch position

  if( running_as_autoconnect ) {
    var mycallsign = props.globals.getNode("sim/multiplay/callsign").getValue();
    #print('mycallsign=',mycallsign);
  }

  var found = 0;
  aiobjects = props.globals.getNode("ai/models").getChildren();
  foreach (var aimember; aiobjects) {
    if ( (var node = aimember.getName() ) != nil ) {
      nodeIsAiAircraft = 0;
      nodeIsMpAircraft = 0;
      if ( sprintf("%8s",node)  == "aircraft" )	nodeIsAiAircraft = 1;
      if ( sprintf("%11s",node) == "multiplayer" ) nodeIsMpAircraft = 1;
      #print("found NodeName=",node,"  nodeIsAiAircraft=",nodeIsAiAircraft,"  nodeIsMpAircraft=",nodeIsMpAircraft  );
      if ( !nodeIsAiAircraft and !nodeIsMpAircraft ) continue;
      if ( !aimember.getNode("valid").getValue() )   continue;   # node is invalid

      if( running_as_autoconnect ) {
        if ( !nodeIsMpAircraft ) continue;
        #if ( aimember.getValue("sim/hitches/aerotow/open") == nil ) continue; # this node MUST exist for mp-aircraft which want to be towed
        #if ( aimember.getValue("sim/hitches/aerotow/open") == 1 ) continue;   # if mp hook open, auto-connect is NOT possible
	if ( aimember.getValue("sim/hitches/aerotow/open") != 0 ) continue;
	if (mycallsign != aimember.getValue("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign") ) continue ;  # I am the wrong one
        if ( !getprop("sim/hitches/aerotow/mp_oldOpen") ) continue;  # this prevents an unwanted immediate auto-connect after the dragger
	                                                             # released its hitch. Firstly wait for a reported "open" hitch from glider
      }

      var lat_deg = aimember.getNode("position/latitude-deg").getValue();
      var lon_deg = aimember.getNode("position/longitude-deg").getValue();
      var alt_m = aimember.getNode("position/altitude-ft").getValue() * FT2M;

      var aiPosition = geo.Coord.set_latlon( lat_deg, lon_deg, alt_m );
      distance_m = (myPosition.distance_to(aiPosition));
      #print('distance_m=',distance_m,'  bestdist_m=',bestdist_m);
      if ( distance_m < bestdist_m ) {
	bestdist_m = distance_m;

	var towEndNode = node;
        var nodeID = aimember.getNode("id").getValue();
        var aicallsign = aimember.getNode("callsign").getValue();
        #print('nodeId=',nodeID,'   AiCallsign=',aicallsign);

        #set properties
        props.globals.getNode("sim/hitches/aerotow/open").setBoolValue(0);
	props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-node").setBoolValue(nodeIsAiAircraft);
	props.globals.getNode("sim/hitches/aerotow/tow/connected-to-mp-node").setBoolValue(nodeIsMpAircraft);
	props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign").setValue(aicallsign);
	props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-or-mp-id").setIntValue(nodeID);
	props.globals.getNode("sim/hitches/aerotow/tow/connected-to-property-node").setBoolValue(1);
	props.globals.getNode("sim/hitches/aerotow/tow/node").setValue(towEndNode);
	props.globals.getNode("sim/hitches/aerotow/tow/dist").setValue(bestdist_m);
        props.globals.getNode("sim/hitches/aerotow/tow/mp_last_reported_dist", 1).setValue(0.);

	# Set some dummy values. In case of an "interactive"-MP plane
	# the correct values will be transmitted in the following loop
        aimember.getNode("sim/hitches/aerotow/local-pos-x",1).setValue(-5.);
        aimember.getNode("sim/hitches/aerotow/local-pos-y",1).setValue(0.);
        aimember.getNode("sim/hitches/aerotow/local-pos-z",1).setValue(0.);
	aimember.getNode("sim/hitches/aerotow/tow/dist",1).setValue(-1.);

        found = 1;
      }   # end distance_m < bestdist_m
    }   # end node != nil
  }   # end loop aiobjects
  if (found) {
    if ( !running_as_autoconnect) {
      setprop("sim/messages/pilot", sprintf("%s, I am on your hook, distance %4.3f meter.",aicallsign,bestdist_m));
    }
    else {
      setprop("sim/messages/ai-plane", sprintf("%s: I am on your hook, distance %4.3f meter.",aicallsign,bestdist_m ));
    }
    if ( running_as_autoconnect ) {
      isSlave = 1;
      props.globals.getNode("sim/hitches/aerotow/is-slave").setBoolValue(isSlave);
    }

    props.globals.getNode("sim/hitches/aerotow/mp_oldOpen").setBoolValue(1);

  }   # end: if found
  else {
    if (!running_as_autoconnect) {
      setprop("sim/messages/atc", sprintf("Sorry, no aircraft for aerotow!"));
    }
    else{
      #print("auto-connect: found=0");
      props.globals.getNode("sim/hitches/aerotow/mp_oldOpen").setBoolValue(1);
    }
  }

} # End function findBestAIObject


# ######################################################################################################################


# Start the towing animation ASAP
towing();



# ######################################################################################################################
#                                                         aerotow function
# ######################################################################################################################

var aerotow = func (open){

   #print("function aerotow is running");

#  if (!open ) {

  ###########################################  my hitch position  ############################################

  myPosition = geo.aircraft_position();
  var my_head_deg  = getprop("orientation/heading-deg");
  var my_roll_deg  = getprop("orientation/roll-deg");
  var my_pitch_deg = getprop("orientation/pitch-deg");

  # hook coordinates in Yasim-system (x-> nose / y -> left wing / z -> up)
  assignHitchLocations("aerotow");
  var x = getprop("sim/hitches/aerotow/local-pos-x");
  var y = getprop("sim/hitches/aerotow/local-pos-y");
  var z = getprop("sim/hitches/aerotow/local-pos-z");

  var alpha_deg = my_roll_deg * (1.);   # roll clockwise (looking in x-direction) := +
  var beta_deg  = my_pitch_deg * (-1.); # pitch clockwise (looking in y-direction) := -

  # transform hook coordinates
  var Xn = PointRotate3D(x:x,y:y,z:z,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:0.);

  var install_distance_m = Xn[0]; # in front of ref-point of glider
  var install_side_m     = Xn[1];
  var install_alt_m      = Xn[2];

  var myHitch_pos    = myPosition.apply_course_distance( my_head_deg , install_distance_m );
  var myHitch_pos    = myPosition.apply_course_distance( my_head_deg - 90. , install_side_m );
  myHitch_pos.set_alt(myPosition.alt() + install_alt_m);

  ###########################################  ai hitch position  ############################################

  #var aiNodeID = getprop("sim/hitches/aerotow/tow/connected-to-ai-or-mp-id");   # id of former found ai/mp aircraft
  #print("aiNodeID=",aiNodeID);
  var aiCallsign = getprop("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign");   # callsign of former found ai/mp aircraft

  var found = 0;

  aiobjects = props.globals.getNode("ai/models").getChildren();
  foreach (var aimember; aiobjects) {
    if ( (var c = aimember.getNode("id") ) != nil ) {
      if ( !aimember.getNode("valid").getValue() ) continue;  # node is invalid

      # Identifying the MP-aircraft by its node-id works fine with JSBSim-aircraft but NOT with YASim.
      # In YASim the node-id is not updated which could lead to complications (e.g. node-id changes after "Pause" or "Exit").
      #var testprop = c.getValue();
      #if ( testprop ==  aiNodeID) {

      # Identifying the MP-aircraft by its callsign works fine with JSBSim AND YASim-aircraft
      var testprop = aimember.getNode("callsign").getValue();
      if ( testprop == aiCallsign ) {

        found = found + 1;

        ######################  check status of ai hitch  ######################
        if ( getprop("sim/flight-model") == "jsb" ) {
	  # check if the multiplayer hitch state has changed
	  # this trick avoids immediate opening after locking because MP-aircraft has not yet reported a locked hitch
	  if ( (var d = aimember.getNode("sim/hitches/aerotow/open") ) != nil ) {
	    var mpOpen = aimember.getNode("sim/hitches/aerotow/open").getValue();
	    var mp_oldOpen = getprop("sim/hitches/aerotow/mp_oldOpen");
	    #print('mpOpen=',mpOpen,'  mp_oldOpen=',mp_oldOpen);
	    if ( mpOpen != mp_oldOpen ) { # state has changed: was open and is now locked OR was locked and is now open
	      if ( mpOpen ) {
                setprop("sim/messages/ai-plane", sprintf("%s: I have released the tow!",getprop("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign")) );
                releaseHitch("aerotow"); # my open=1 / forces=0 / remove towrope
	      }  # end: open
	      props.globals.getNode("sim/hitches/aerotow/mp_oldOpen").setBoolValue(mpOpen);
	    }  # end: state has changed
	  }  # end: node is available
        }  #end : JSBSim
        ########################################################################

        # get coordinates
        var ai_lat = aimember.getNode("position/latitude-deg").getValue();
        var ai_lon = aimember.getNode("position/longitude-deg").getValue();
        var ai_alt = (aimember.getNode("position/altitude-ft").getValue()) * FT2M;
        #print("ai_lat,lon,alt",ai_lat,ai_lon,ai_alt);

        var ai_pitch_deg = aimember.getNode("orientation/pitch-deg").getValue();
        var ai_roll_deg = aimember.getNode("orientation/roll-deg").getValue();
        var ai_head_deg = aimember.getNode("orientation/true-heading-deg").getValue();

        var aiHitchX = aimember.getNode("sim/hitches/aerotow/local-pos-x").getValue();
        var aiHitchY = aimember.getNode("sim/hitches/aerotow/local-pos-y").getValue();
        var aiHitchZ = aimember.getNode("sim/hitches/aerotow/local-pos-z").getValue();

        var aiPosition = geo.Coord.set_latlon( ai_lat, ai_lon, ai_alt );

        var alpha_deg = ai_roll_deg * (1.);
        var beta_deg  = ai_pitch_deg * (-1.);

        # transform hook coordinates
        var Xn = PointRotate3D(x:aiHitchX,y:aiHitchY,z:aiHitchZ,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:0.);

        var install_distance_m =  Xn[0]; # in front of ref-point of glider
        var install_side_m     =  Xn[1];
        var install_alt_m      =  Xn[2];

        var aiHitch_pos    = aiPosition.apply_course_distance( ai_head_deg , install_distance_m );
        var aiHitch_pos    = aiPosition.apply_course_distance( ai_head_deg - 90. , install_side_m );
        aiHitch_pos.set_alt(aiPosition.alt() + install_alt_m);

        ###########################################  distance between hitches  #####################################

        var distance = (myHitch_pos.direct_distance_to(aiHitch_pos));      # distance to plane in meter
        var aiHitchheadto = (myHitch_pos.course_to(aiHitch_pos));
        var height = myHitch_pos.alt() - aiHitch_pos.alt();

        var aiHitchpitchto = -math.asin((myHitch_pos.alt()-aiHitch_pos.alt())/distance) / 0.01745;
        #print("  pitch: ", aiHitchpitchto);

        # update position of rope
        setprop("ai/models/aerotowrope/position/latitude-deg", myHitch_pos.lat());
        setprop("ai/models/aerotowrope/position/longitude-deg", myHitch_pos.lon());
        setprop("ai/models/aerotowrope/position/altitude-ft", myHitch_pos.alt() * M2FT);
        #print("ai_lat,lon,alt",myHitch_pos.lat(),"   ",myHitch_pos.lon(),"   ",myHitch_pos.alt() );

        # update pitch and heading of rope
        setprop("ai/models/aerotowrope/orientation/true-heading-deg", aiHitchheadto);
        setprop("ai/models/aerotowrope/orientation/pitch-deg", aiHitchpitchto);

        # update length of rope
        setprop("sim/hitches/aerotow/tow/dist", distance);
        #print("distance=",distance);


        #############################################  calc forces  ##################################################

        # calc forces only for JSBSim-aircraft

        # tow-end-forces must be reported in N to be consiststent to Yasim-aircraft
        # hitch-forces must be LBS to be consistent to the JSBSim "external_forces/.../magnitude" definition

        if ( getprop("sim/flight-model") == "jsb" ) {
          #print("Force-Routine");

          # check if the MP-aircraft properties have been updated. If not (maybe due to time-lag) bypass force calculation (use previous forces instead)
          var mp_reported_dist = aimember.getNode("sim/hitches/aerotow/tow/dist").getValue();
          var mp_last_reported_dist = getprop("sim/hitches/aerotow/tow/mp_last_reported_dist");
          var mp_delta_reported_dist = mp_reported_dist - mp_last_reported_dist ;
          setprop("sim/hitches/aerotow/tow/mp_last_reported_dist",mp_reported_dist);
          var mp_delta_reported_dist2 = mp_delta_reported_dist  * mp_delta_reported_dist ;   # we need the absolute value
          if ( (mp_delta_reported_dist2 > 0.0000001) or (mp_reported_dist < 0. )){     # we have the updated MP coordinates (no time lag)
                                                                                       # or the MP-aircraft is a non-interactive mp plane (mp_reported_dist = -1)
                                                                                       # => update forces else use the old forces!

          var breakforce_N = getprop("sim/hitches/aerotow/tow/brake-force");  # could be different in both aircraft

          var isSlave = getprop("sim/hitches/aerotow/is-slave");
          if ( !isSlave ){  # if we are master, we have to calculate the forces
            #print("master: calc forces");
            var elastic_constant = getprop("sim/hitches/aerotow/tow/elastic-constant");
            var towlength_m = getprop("sim/hitches/aerotow/tow/length");

            var delta_towlength_m = distance - towlength_m;
            #print("towlength_m= ", towlength_m , "  elastic_constant= ", elastic_constant,"  delta_towlength_m= ", delta_towlength_m);

            if ( delta_towlength_m < 0. ) {
              var forcetow_N = 0.;
            }
            else{
              var forcetow_N = elastic_constant * delta_towlength_m / towlength_m;
            }
          }  # end !isSlave
          else {   # we are slave and get the forces from master
            #print("slave: get forces","    aimember=",aimember.getName());
            # get forces
            var forcetowX_N = aimember.getNode("sim/hitches/aerotow/tow/end-force-x").getValue() * 1;
            var forcetowY_N = aimember.getNode("sim/hitches/aerotow/tow/end-force-y").getValue() * 1;
            var forcetowZ_N = aimember.getNode("sim/hitches/aerotow/tow/end-force-z").getValue() * 1;
            var forcetow_N = math.sqrt( forcetowX_N * forcetowX_N + forcetowY_N * forcetowY_N + forcetowZ_N * forcetowZ_N );
          }  # end isSlave

          var forcetow_LBS = forcetow_N * 0.224809;   # N -> LBF
          #print(" forcetow_N ", forcetow_N , "  distance ", distance,"  ", breakforce_N);

          if ( forcetow_N < breakforce_N ) {

            var distancepr = (myHitch_pos.distance_to(aiHitch_pos));

            # correct a failure, if the projected length is larger than direct length
            if (distancepr > distance) { distancepr = distance;}

            var alpha = math.acos( (distancepr / distance) );
            if ( aiHitch_pos.alt() > myHitch_pos.alt()) alpha = - alpha;

            var beta = ( aiHitchheadto - my_head_deg ) * 0.01745;
            var gamma = my_pitch_deg * 0.01745;
            var delta = my_roll_deg * 0.01745;

            var sina = math.sin(alpha);
            var cosa = math.cos(alpha);
            var sinb = math.sin(beta);
            var cosb = math.cos(beta);
            var sing = math.sin(gamma);
            var cosg = math.cos(gamma);
            var sind = math.sin(delta);
            var cosd = math.cos(delta);

            #var forcetow = forcetow_N;   # we deliver N to JSBSim
            var forcetow = forcetow_LBS;   # we deliver LBS to JSBSim

            # calculate unit vector of force direction in JSBSim-system
            var force = 1;

            # global forces: alpha beta
            var fglobalx = force * cosa * cosb;
            var fglobaly = force * cosa * sinb;
            var fglobalz = force * sina;

            # local forces by pitch: gamma
            var flpitchx = fglobalx * cosg - fglobalz * sing;
            var flpitchy = fglobaly;
            var flpitchz = fglobalx * sing + fglobalz * cosg;

            # local forces by roll: delta
            var flrollx  =   flpitchx;
            var flrolly  =   flpitchy * cosd + flpitchz * sind;
            var flrollz  = - flpitchy * sind + flpitchz * cosd;

            # asigning to LOCAL coord of plane
            var forcex = flrollx;
            var forcey = flrolly;
            var forcez = flrollz;
            #print("fx=",forcex,"  fy=",forcey,"  fz=",forcez);

            # JSBSim-body-frame:  x-> nose / y -> right wing / z -> down
            # apply forces to hook (forces are in LBS or N see above)
            var hitchname = getprop("sim/hitches/aerotow/force_name_jsbsim");
            setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/magnitude", forcetow);
            setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/x", forcex);
            setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/y", forcey);
            setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/z", forcez);

          }  # end force < break force
          else {  # rope is broken
            props.globals.getNode("sim/hitches/aerotow/broken").setBoolValue(1);
            #setprop("sim/messages/atc", sprintf("Oh no, the tow is broken"));
            releaseHitch("aerotow"); # open=1 / forces=0 / remove towrope
          }

          #############################################  report forces  ##############################################

          # if we are connected to a MP-aircraft and master
          var nodeIsMpAircraft = getprop("sim/hitches/aerotow/tow/connected-to-mp-node");
          if ( nodeIsMpAircraft and !isSlave ){
            #print("report Forces");

            # transform my hitch coordinates to cartesian earth coordinates
            var myHitchCartEarth = geodtocart(myHitch_pos.lat(),myHitch_pos.lon(),myHitch_pos.alt() );
            var myHitchXearth_m = myHitchCartEarth[0];
            var myHitchYearth_m = myHitchCartEarth[1];
            var myHitchZearth_m = myHitchCartEarth[2];

            # transform MP hitch coordinates to cartesian earth coordinates
            var aiHitchCartEarth = geodtocart(aiHitch_pos.lat(),aiHitch_pos.lon(),aiHitch_pos.alt() );
            var aiHitchXearth_m = aiHitchCartEarth[0];
            var aiHitchYearth_m = aiHitchCartEarth[1];
            var aiHitchZearth_m = aiHitchCartEarth[2];

            # calculate normal vector in tow direction in cartesian earth coordinates
            var dx = aiHitchXearth_m - myHitchXearth_m;
            var dy = aiHitchYearth_m - myHitchYearth_m;
            var dz = aiHitchZearth_m - myHitchZearth_m;
            var dl = math.sqrt( dx * dx + dy * dy + dz * dz );

            var forcetowX_N = forcetow_N * dx / dl;
            var forcetowY_N = forcetow_N * dy / dl;
            var forcetowZ_N = forcetow_N * dz / dl;

            setprop("sim/hitches/aerotow/tow/dist", distance);
            setprop("sim/hitches/aerotow/tow/end-force-x", -forcetowX_N); # force acts in
            setprop("sim/hitches/aerotow/tow/end-force-y", -forcetowY_N); # opposite direction
            setprop("sim/hitches/aerotow/tow/end-force-z", -forcetowZ_N); # at tow end

          } # end report forces

          }  # end: timelag
          else{
            #print("forces NOT updated!");
          }
        }  # end forces/JSBSim


      }  # end: aiNodeID
    }  # end: check id != nil
  }  # end: loop over aiobjects

  if ( found == 0 ) {
    if ( getprop("sim/flight-model") == "jsb" ) {
      setprop("sim/messages/atc", sprintf("MP-aircraft disappeared!" ));
      props.globals.getNode("sim/hitches/aerotow/open").setBoolValue(1);  # open my hitch
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-or-mp-id").setIntValue(0);
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign").setValue("");
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-ai-node").setBoolValue(0);
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-mp-node").setBoolValue(0);
      props.globals.getNode("sim/hitches/aerotow/tow/connected-to-property-node").setBoolValue(0);
    }
    #if ( getprop("sim/flight-model") == "yasim" ) removeTowrope("aerotow");   # remove towrope model
  } # end found=0

}   # end function aerotow



# ######################################################################################################################
#                                                         winch function
# ######################################################################################################################

var winch = func (open){

  var FT2M = 0.30480;
  var M2FT = 1. / FT2M;
  var RAD2DEG = 57.29578;
  var DEG2RAD = 1. / RAD2DEG;

  if (!open ) {

  ###########################################  my hitch position  ############################################

  myPosition = geo.aircraft_position();
  var my_head_deg  = getprop("orientation/heading-deg");
  var my_roll_deg  = getprop("orientation/roll-deg");
  var my_pitch_deg = getprop("orientation/pitch-deg");

  # hitch coordinates in YASim-system (x-> nose / y -> left wing / z -> up)
  assignHitchLocations("winch");
  var x = getprop("sim/hitches/winch/local-pos-x");
  var y = getprop("sim/hitches/winch/local-pos-y");
  var z = getprop("sim/hitches/winch/local-pos-z");

  var alpha_deg = my_roll_deg * (1.);   # roll clockwise (looking in x-direction) := +
  var beta_deg  = my_pitch_deg * (-1.); # pitch clockwise (looking in y-direction) := -

  # transform hook coordinates
  var Xn = PointRotate3D(x:x,y:y,z:z,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:0.);

  var install_distance_m = Xn[0]; # in front of ref-point of glider
  var install_side_m     = Xn[1];
  var install_alt_m      = Xn[2];

  var myHitch_pos    = myPosition.apply_course_distance( my_head_deg , install_distance_m );
  var myHitch_pos    = myPosition.apply_course_distance( my_head_deg - 90. , install_side_m );
  myHitch_pos.set_alt(myPosition.alt() + install_alt_m);

  ###########################################  winch hitch position  ############################################

  # get coordinates
  var winch_global_pos_x = getprop("sim/hitches/winch/winch/global-pos-x");
  var winch_global_pos_y = getprop("sim/hitches/winch/winch/global-pos-y");
  var winch_global_pos_z = getprop("sim/hitches/winch/winch/global-pos-z");

  var winch_geod = carttogeod(winch_global_pos_x,winch_global_pos_y,winch_global_pos_z);

  var ai_lat = winch_geod[0];
  var ai_lon = winch_geod[1];
  #var ai_alt = winch_geod[2] * FT2M;
  var ai_alt = winch_geod[2];
  #print("ai_lat,lon,alt",ai_lat,ai_lon,ai_alt);

  var aiHitch_pos = geo.Coord.set_latlon( ai_lat, ai_lon, ai_alt );


  ###########################################  distance between hitches  #####################################

  var distance = (myHitch_pos.direct_distance_to(aiHitch_pos));    # distance to winch in meter
  var aiHitchheadto = (myHitch_pos.course_to(aiHitch_pos));
  var height = myHitch_pos.alt() - aiHitch_pos.alt();

  var aiHitchpitchto = -math.asin((myHitch_pos.alt()-aiHitch_pos.alt())/distance) / 0.01745;
  #print("  pitch: ", aiHitchpitchto);

  # update position of rope
  setprop("ai/models/winchrope/position/latitude-deg", myHitch_pos.lat());
  setprop("ai/models/winchrope/position/longitude-deg", myHitch_pos.lon());
  setprop("ai/models/winchrope/position/altitude-ft", myHitch_pos.alt() * M2FT);
  #print("ai_lat,lon,alt",myHitch_pos.lat(),"   ",myHitch_pos.lon(),"   ",myHitch_pos.alt() );

  # update pitch and heading of rope
  setprop("ai/models/winchrope/orientation/true-heading-deg", aiHitchheadto);
  setprop("ai/models/winchrope/orientation/pitch-deg", aiHitchpitchto);

  # update length of rope
  setprop("sim/hitches/winch/tow/dist", distance);
  #print("distance=",distance);


  #############################################  calc forces  ##################################################

  # calc forces only for JSBSim-aircraft

  # tow-end-forces must be reported in N to be consiststent to Yasim-aircraft
  # hitch-forces must be LBS to be consistent to the JSBSim "external_forces/.../magnitude" definition

  if ( getprop("sim/flight-model") == "jsb"  ) {

    var spool_max = getprop("sim/hitches/winch/winch/max-spool-speed-m-s");
    var unspool_max = getprop("sim/hitches/winch/winch/max-unspool-speed-m-s");
    var max_force_N = getprop("sim/hitches/winch/winch/max-force-N");
    var max_power_W = getprop("sim/hitches/winch/winch/max-power-kW") * 1000.;
    var breakforce_N = getprop("sim/hitches/winch/tow/break-force-N");
    var elastic_constant = getprop("sim/hitches/winch/tow/elastic-constant");
    var towlength_m = getprop("sim/hitches/winch/tow/length");
    var max_tow_length_m = getprop("sim/hitches/winch/winch/max-tow-length-m");
    var spoolspeed = getprop("sim/hitches/winch/winch/actual-spool-speed-m-s");
    var spool_acceleration = getprop("sim/hitches/winch/winch/spool-acceleration-m-s-s");
    var delta_t = getprop("sim/time/delta-sec");

    var towlength_new_m = towlength_m - spoolspeed * delta_t;
    var delta_towlength_m = distance - towlength_new_m;
    #print("towlength_m= ", towlength_m , "  elastic_constant= ", elastic_constant,"  delta_towlength_m= ", delta_towlength_m);

    if ( getprop("sim/hitches/winch/winch/clutched") ) {
      var delta_spoolspeed =  spool_acceleration * delta_t;
      spoolspeed = spoolspeed + delta_spoolspeed ;
      if ( spoolspeed > spool_max ) spoolspeed = spool_max;
    }
    else {   # un-clutched
      # --- experimental --- #

      # we assume that the the winch-operator avoids tow sagging ( => rigid rope; negativ forces allowed)
      var forcetow_N = elastic_constant * delta_towlength_m / towlength_new_m;

      # drag of tow-rope ( magic! )
      var magic_constant = getprop("sim/hitches/winch/winch/magic-constant");
      tow_drag_N = spoolspeed * spoolspeed * math.sqrt( math.sqrt( height * height ) * max_tow_length_m ) / magic_constant ;

      # mass = tow-mass only (drum-mass ignored)
      var mass_kg = max_tow_length_m * getprop("sim/hitches/winch/tow/weight-per-m-kg-m");

      var acceleration = ( forcetow_N - tow_drag_N ) / mass_kg;
      var delta_spoolspeed = acceleration * delta_t;
      spoolspeed = spoolspeed - delta_spoolspeed;
      if ( spoolspeed < - unspool_max ) spoolspeed = - unspool_max;
      #print("spoolspeed= ",spoolspeed,"  delta_spoolspeed= ",delta_spoolspeed,"  delta_towlength= ", delta_towlength_m);
      #print("forcetow_N= ",forcetow_N,"  tow_drag_N= ",tow_drag_N,"  acceleration= ", acceleration);
    }

    if ( delta_towlength_m < 0. ) {
      var forcetow_N = 0.;
    }
    else{
      var forcetow_N = elastic_constant * delta_towlength_m / towlength_new_m;
    }

    if ( forcetow_N > max_force_N ) {
      forcetow_N = max_force_N;
      var towlength_new_m = distance / ( forcetow_N / elastic_constant + 1. );
      spoolspeed = (towlength_m - towlength_new_m ) / delta_t;
    }

    var power = forcetow_N * spoolspeed;
    if ( power > max_power_W) {
      power = max_power_W;
      spoolspeed = power / forcetow_N;
      towlength_new_m = towlength_m - spoolspeed * delta_t;
    }
    #print("power=",power,"  spoolspeed=",spoolspeed,"  force=",forcetow_N);

    setprop("sim/hitches/winch/tow/length",towlength_new_m);
    setprop("sim/hitches/winch/winch/actual-spool-speed-m-s",spoolspeed);
    setprop("sim/hitches/winch/winch/actual-force-N",forcetow_N);

    # force due to tow-weight (acts in tow direction at the heigher hitch)
    var force_due_to_weight_N = getprop("sim/hitches/winch/tow/weight-per-m-kg-m") * 9.81 * height;
    if (height < 0. ) force_due_to_weight_N = 0.;

    forcetow_N = forcetow_N + force_due_to_weight_N;
    var forcetow_LBS = forcetow_N * 0.224809;   # N -> LBF
    #print(" forcetow_N ", forcetow_N , "  distance ", distance,"  ", breakforce_N);
    #print(" forcetow_N=", forcetow_N , "  force_due_to_weight_N=", force_due_to_weight_N,"  height=",height);

    if ( forcetow_N < breakforce_N ) {

      var distancepr = (myHitch_pos.distance_to(aiHitch_pos));

      # correct a failure, if the projected length is larger than direct length
      if (distancepr > distance) { distancepr = distance;}

      var alpha = math.acos( (distancepr / distance) );
      if ( aiHitch_pos.alt() > myHitch_pos.alt()) alpha = - alpha;
      var beta = ( aiHitchheadto - my_head_deg ) * DEG2RAD;
      var gamma = my_pitch_deg * DEG2RAD;
      var delta = my_roll_deg * DEG2RAD;

      var sina = math.sin(alpha);
      var cosa = math.cos(alpha);
      var sinb = math.sin(beta);
      var cosb = math.cos(beta);
      var sing = math.sin(gamma);
      var cosg = math.cos(gamma);
      var sind = math.sin(delta);
      var cosd = math.cos(delta);

      #var forcetow = forcetow_N;   # we deliver N to JSBSim
      var forcetow = forcetow_LBS;   # we deliver LBS to JSBSim

      # calculate unit vector of force direction in JSBSim-system
      var force = 1;

      # global forces: alpha beta
      var fglobalx = force * cosa * cosb;
      var fglobaly = force * cosa * sinb;
      var fglobalz = force * sina;

      # local forces by pitch: gamma
      var flpitchx = fglobalx * cosg - fglobalz * sing;
      var flpitchy = fglobaly;
      var flpitchz = fglobalx * sing + fglobalz * cosg;

      # local forces by roll: delta
      var flrollx  =   flpitchx;
      var flrolly  =   flpitchy * cosd + flpitchz * sind;
      var flrollz  = - flpitchy * sind + flpitchz * cosd;

      # asigning to LOCAL coord of plane
      var forcex = flrollx;
      var forcey = flrolly;
      var forcez = flrollz;
      #print("fx=",forcex,"  fy=",forcey,"  fz=",forcez);

      # JSBSim-body-frame:  x-> nose / y -> right wing / z -> down
      # apply forces to hook (forces are in LBS or N see above)
      var hitchname = getprop("sim/hitches/winch/force_name_jsbsim");
      setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/magnitude", forcetow);
      setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/x", forcex );
      setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/y", forcey );
      setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/z", forcez );

      # check, if auto-release condition is reached
      var rope_angle_deg = math.atan2(forcez , forcex ) * RAD2DEG;
      #print("rope_angle_deg=",rope_angle_deg);
      if (rope_angle_deg > getprop("sim/hitches/winch/automatic-release-angle-deg") ) releaseWinch();

    }  # end force < break force
    else {  # rope is broken
      props.globals.getNode("sim/hitches/winch/broken").setBoolValue(1);
      releaseWinch();
    }

    if ( towlength_new_m > max_tow_length_m ) {
      setprop("sim/messages/atc", sprintf("tow length exceeded!"));
      releaseWinch();
    }

  }  # end forces/JSBSim

  }  # end hitch is closed (open == 0)

}  # end function winch


# ######################################################################################################################
#                                                      create towrope
# ######################################################################################################################

var createTowrope = func (device){

  # create the towrope in the model property tree
  #print("createTowrope for ",device);

  if ( getprop("sim/hitches/" ~ device ~ "/rope/exist") == 0 ) {   # does the towrope exist?

    # get the next free model id
    var freeModelid = getFreeModelID();

    props.globals.getNode("sim/hitches/" ~ device ~ "/rope/model_id").setIntValue(freeModelid);
    props.globals.getNode("sim/hitches/" ~ device ~ "/rope/exist").setBoolValue(1);

    var towrope_ai  = props.globals.getNode("ai/models/" ~ device ~ "rope", 1);
    var towrope_mod  = props.globals.getNode("models", 1);

    towrope_ai.getNode("id", 1).setIntValue(4711);
    towrope_ai.getNode("callsign", 1).setValue("towrope");
    towrope_ai.getNode("valid", 1).setBoolValue(1);
    towrope_ai.getNode("position/latitude-deg", 1).setValue(0.);
    towrope_ai.getNode("position/longitude-deg", 1).setValue(0.);
    towrope_ai.getNode("position/altitude-ft", 1).setValue(0.);
    towrope_ai.getNode("orientation/true-heading-deg", 1).setValue(0.);
    towrope_ai.getNode("orientation/pitch-deg", 1).setValue(0.);
    towrope_ai.getNode("orientation/roll-deg", 1).setValue(0.);

    towrope_mod.model = towrope_mod.getChild("model", freeModelid, 1);
    towrope_mod.model.getNode("path", 1).setValue(getprop("sim/hitches/" ~ device ~ "/rope/path_to_model") );
    towrope_mod.model.getNode("longitude-deg-prop", 1).setValue("ai/models/" ~ device ~ "rope/position/longitude-deg");
    towrope_mod.model.getNode("latitude-deg-prop", 1).setValue("ai/models/" ~ device ~ "rope/position/latitude-deg");
    towrope_mod.model.getNode("elevation-ft-prop", 1).setValue("ai/models/" ~ device ~ "rope/position/altitude-ft");
    towrope_mod.model.getNode("heading-deg-prop", 1).setValue("ai/models/" ~ device ~ "rope/orientation/true-heading-deg");
    towrope_mod.model.getNode("roll-deg-prop", 1).setValue("ai/models/" ~ device ~ "rope/orientation/roll-deg");
    towrope_mod.model.getNode("pitch-deg-prop", 1).setValue("ai/models/" ~ device ~ "rope/orientation/pitch-deg");
    towrope_mod.model.getNode("load", 1).remove();
  }  # end towrope exist
}


# ######################################################################################################################
#                                     get the next free id of "models/model" members
# ######################################################################################################################

var getFreeModelID = func {
  #print("getFreeModelID");
  var modelid = 0;   # next unused id
  modelobjects = props.globals.getNode("models", 1).getChildren();
  foreach ( var member; modelobjects ) {
    if ( (var c = member.getIndex()) != nil) {
      modelid = c + 1;
    }
  }
  #print("modelid=",modelid);
  return(modelid);
}


# ######################################################################################################################
#                                                   close aerotow hitch
# ######################################################################################################################

var closeHitch = func {

  #print("closeHitch");

  # close only, if
  # - not yet closed
  # - connected to property-node
  # - distance < towrope length

  var open = getprop("sim/hitches/aerotow/open");
  if ( !open ) return;

  var aiNodeID = getprop("sim/hitches/aerotow/tow/connected-to-ai-or-mp-id");   # id of former found ai/mp aircraft
  if ( aiNodeID < 1 ) {
    setprop("sim/messages/atc", sprintf("No aircraft selected!"));
    return;
  }

  #####################################  calc distance between hitches  ######################

  ######################  my hitch position  #######################

  myPosition = geo.aircraft_position();
  var my_head_deg  = getprop("orientation/heading-deg");
  var my_roll_deg  = getprop("orientation/roll-deg");
  var my_pitch_deg = getprop("orientation/pitch-deg");

  # hook coordinates in Yasim-system (x-> nose / y -> left wing / z -> up)
  assignHitchLocations("aerotow");
  var x = getprop("sim/hitches/aerotow/local-pos-x");
  var y = getprop("sim/hitches/aerotow/local-pos-y");
  var z = getprop("sim/hitches/aerotow/local-pos-z");

  var alpha_deg = my_roll_deg * (1.);   # roll clockwise (looking in x-direction) := +
  var beta_deg  = my_pitch_deg * (-1.); # pitch clockwise (looking in y-direction) := -

  # transform hook coordinates
  var Xn = PointRotate3D(x:x,y:y,z:z,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:0.);

  var install_distance_m = Xn[0]; # in front of ref-point of glider
  var install_side_m     = Xn[1];
  var install_alt_m      = Xn[2];

  var myHitch_pos    = myPosition.apply_course_distance( my_head_deg , install_distance_m );
  var myHitch_pos    = myPosition.apply_course_distance( my_head_deg - 90. , install_side_m );
  myHitch_pos.set_alt(myPosition.alt() + install_alt_m);

  ######################  ai hitch position  #######################

  var found = 0;

  aiobjects = props.globals.getNode("ai/models").getChildren();
  foreach (var aimember; aiobjects) {
    if ( (var c = aimember.getNode("id") ) != nil ) {
      var testprop = c.getValue();
      if ( testprop ==  aiNodeID) {
        found = found + 1;

        # get coordinates
        var ai_lat = aimember.getNode("position/latitude-deg").getValue();
        var ai_lon = aimember.getNode("position/longitude-deg").getValue();
        var ai_alt = (aimember.getNode("position/altitude-ft").getValue()) * FT2M;

        var ai_pitch_deg = aimember.getNode("orientation/pitch-deg").getValue();
        var ai_roll_deg = aimember.getNode("orientation/roll-deg").getValue();
        var ai_head_deg = aimember.getNode("orientation/true-heading-deg").getValue();

        var aiHitchX = aimember.getNode("sim/hitches/aerotow/local-pos-x").getValue();
        var aiHitchY = aimember.getNode("sim/hitches/aerotow/local-pos-y").getValue();
        var aiHitchZ = aimember.getNode("sim/hitches/aerotow/local-pos-z").getValue();

        var aiPosition = geo.Coord.set_latlon( ai_lat, ai_lon, ai_alt );

        var alpha_deg = ai_roll_deg * (1.);
        var beta_deg  = ai_pitch_deg * (-1.);

        # transform hook coordinates
        var Xn = PointRotate3D(x:aiHitchX,y:aiHitchY,z:aiHitchZ,xr:0.,yr:0.,zr:0.,alpha_deg:alpha_deg,beta_deg:beta_deg,gamma_deg:0.);

        var install_distance_m =  Xn[0]; # in front of ref-point of glider
        var install_side_m     =  Xn[1];
        var install_alt_m      =  Xn[2];

        var aiHitch_pos    = aiPosition.apply_course_distance( ai_head_deg , install_distance_m );
        var aiHitch_pos    = aiPosition.apply_course_distance( ai_head_deg - 90. , install_side_m );
        aiHitch_pos.set_alt(aiPosition.alt() + install_alt_m);

        var distance = (myHitch_pos.direct_distance_to(aiHitch_pos));

	var towlength_m = props.globals.getNode("sim/hitches/aerotow/tow/length").getValue();
        if ( distance > towlength_m ) {
	  var aicallsign = getprop("sim/hitches/aerotow/tow/connected-to-ai-or-mp-callsign");
	  #setprop("sim/messages/atc", sprintf("Aircraft with callsign %s is too far away (distance is %4.0f meter).",aicallsign, distance));
	  setprop("sim/messages/atc", sprintf("Selected aircraft is too far away (distance to %s is %4.0f meter).",aicallsign, distance));
	  return;
        }

	setprop("sim/hitches/aerotow/tow/dist", distance);

      }
    }
  }

  setprop("sim/hitches/aerotow/open", "false");
  setprop("sim/hitches/aerotow/mp_oldOpen", "true");

} # End function closeHitch


# ######################################################################################################################
#                                                     release hitch
# ######################################################################################################################

var releaseHitch = func (device){

  #print("releaseHitch");

  if ( getprop("sim/flight-model") == "yasim" ) return;	# bypass this routine for Yasim-aircraft

  setprop("sim/hitches/" ~ device ~ "/open", "true");

  var hitchname = getprop("sim/hitches/" ~ device ~ "/force_name_jsbsim");
  setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/magnitude", 0.);
  setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/x", 0.);
  setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/y", 0.);
  setprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/z", 0.);

  if ( device == "aerotow" ) {
    setprop("sim/hitches/aerotow/tow/end-force-x", 0.);		 # MP tow-end forces
    setprop("sim/hitches/aerotow/tow/end-force-y", 0.);		 #
    setprop("sim/hitches/aerotow/tow/end-force-z", 0.);		 #
  }

} # End function releaseHitch


# ######################################################################################################################
#                                                  remove/delete towrope
# ######################################################################################################################

var removeTowrope = func (device){

  # remove the towrope from the property tree ai/models
  # remove the towrope from the property tree models/

  if ( getprop("sim/hitches/" ~ device ~ "/rope/exist") == 1 ) {   # does the towrope exist?

    # remove 3d model from scenery
    # identification is /models/model[x] with x=id_model
    var id_model = getprop("sim/hitches/" ~ device ~ "/rope/model_id");
    var modelsNode = "models/model[" ~ id_model ~ "]";
    props.globals.getNode(modelsNode).remove();
    props.globals.getNode("ai/models/" ~ device ~ "rope").remove();
    #print("towrope removed");
    setprop("sim/hitches/" ~ device ~ "/rope/exist", 0);
  }

}


# ######################################################################################################################
#                                           pull in towrope after hitch has been opened
# ######################################################################################################################

var pull_in_rope = func {

  var deg2rad = math.pi / 180.;
  var FT2M = 0.30480;

  if ( getprop("sim/hitches/winch/open") ) {

    # get length of rope
    #var distance = getprop("sim/hitches/winch/tow/dist");

    var towlength_m = getprop("sim/hitches/winch/tow/length");
    var spoolspeed = getprop("sim/hitches/winch/winch/max-spool-speed-m-s");
    var delta_t = getprop("sim/time/delta-sec");

    var delta_length_m = spoolspeed * delta_t;
    var towlength_new_m = towlength_m - delta_length_m;
    var towlength_min_m = getprop("sim/hitches/winch/winch/min-tow-length-m");

    if ( towlength_new_m > towlength_min_m ) {
      #print("actual towlength= ",towlength_new_m);

      # get position of rope end (former myHitch_pos)
      var tow_lat = getprop("ai/models/winchrope/position/latitude-deg");
      var tow_lon = getprop("ai/models/winchrope/position/longitude-deg");
      var tow_alt_m = getprop("ai/models/winchrope/position/altitude-ft") * FT2M;
      # get pitch and heading of rope
      var tow_heading_deg = getprop("ai/models/winchrope/orientation/true-heading-deg");
      var tow_pitch_rad = getprop("ai/models/winchrope/orientation/pitch-deg") * deg2rad;

      var aiTow_pos = geo.Coord.set_latlon( tow_lat, tow_lon, tow_alt_m );

      var delta_distance_m = delta_length_m * math.cos(tow_pitch_rad);
      var delta_alt_m      = delta_length_m * math.sin(tow_pitch_rad);
      # vertical sink rate not yet taken into account!
      aiTow_pos    = aiTow_pos.apply_course_distance( tow_heading_deg , delta_distance_m );
      aiTow_pos.set_alt(tow_alt_m + delta_alt_m);
      #print("aiTow_pos.alt()= ",aiTow_pos.alt(),"  ",tow_alt_m + delta_alt_m);

      # update position of rope
      setprop("ai/models/winchrope/position/latitude-deg", aiTow_pos.lat());
      setprop("ai/models/winchrope/position/longitude-deg", aiTow_pos.lon());
      setprop("ai/models/winchrope/position/altitude-ft", aiTow_pos.alt() * M2FT);

      # update length of rope
      setprop("sim/hitches/winch/tow/length",towlength_new_m);

      settimer( pull_in_rope , 0 );
    }  # end towlength > min
    else {
      #print("pull in finished!");
      setprop("sim/hitches/winch/winch/actual-spool-speed-m-s", 0. );
      removeTowrope("winch");   # remove towrope model
    }

  }  # end if open

}


# ######################################################################################################################
#                                              set some AI-object default values
# ######################################################################################################################

var setAIObjectDefaults = func (){

  # set some default variables, needed to identify, if the found object is an AI-object, a "non-interactiv MP-object or
  # an interactive MP-object

  var aiNodeID = getprop("sim/hitches/aerotow/tow/connected-to-ai-or-mp-id");   # id of former found ai/mp aircraft

  aiobjects = props.globals.getNode("ai/models").getChildren();
  foreach (var aimember; aiobjects) {
    if ( (var c = aimember.getNode("id") ) != nil ) {
      var testprop = c.getValue();
      if ( testprop ==  aiNodeID) {
	 # Set some dummy values. In case of an "interactive"-MP plane
	 # the correct values will be transmitted in the following loop.
	 # Create this variables if not present.
         aimember.getNode("sim/hitches/aerotow/local-pos-x",1).setValue(-5.);
         aimember.getNode("sim/hitches/aerotow/local-pos-y",1).setValue(0.);
         aimember.getNode("sim/hitches/aerotow/local-pos-z",1).setValue(0.);
	 aimember.getNode("sim/hitches/aerotow/tow/dist",1).setValue(-1.);
      }
    }
  }

}


# ######################################################################################################################
#                                                  place winch model
# ######################################################################################################################

var setWinchPositionAuto = func {

  # remove already existing winch model
  if ( getprop("/sim/hitches/winch/winch/winch-model-index") != nil ) {
    var id_model = getprop("/sim/hitches/winch/winch/winch-model-index");
    var modelsNode = "models/model[" ~ id_model ~ "]";
    props.globals.getNode(modelsNode).remove();
    #print("winch model removed");
  }

  var initial_length_m = getprop("sim/hitches/winch/winch/initial-tow-length-m");
  var ac_pos = geo.aircraft_position();	             # get position of aircraft
  var ac_hd  = getprop("orientation/heading-deg");   # get heading of aircraft

  # setup winch
  # get initial runway position
  var ipos_lat_deg = getprop("sim/presets/latitude-deg");
  var ipos_lon_deg = getprop("sim/presets/longitude-deg");
  var ipos_hd_deg  = getprop("sim/presets/heading-deg");
  var ipos_alt_m = geo.elevation(ipos_lat_deg,ipos_lon_deg);
  var ipos_geo = geo.Coord.new().set_latlon(ipos_lat_deg, ipos_lon_deg, ipos_alt_m);
  # offset to initial position
  var deviation = (ac_pos.distance_to(ipos_geo));
  # if deviation is too much, locate winch in front of glider, otherwise locate winch to end of runway
  if ( deviation > 200) {
    var w = ac_pos.apply_course_distance( ac_hd , initial_length_m -1. );
  }
  else {
    var w = ipos_geo.apply_course_distance( ipos_hd_deg , initial_length_m - 1. );
  }
  var wpalt = geo.elevation(w.lat(), w.lon());
  w.set_alt(wpalt);

  var winchModel = geo.put_model("Models/Airport/supacat_winch.xml", w.lat(), w.lon(), (w.alt()+0.81), (w.course_to(ac_pos) ));

  setprop("/sim/hitches/winch/winch/global-pos-x", w.x());
  setprop("/sim/hitches/winch/winch/global-pos-y", w.y());
  setprop("/sim/hitches/winch/winch/global-pos-z", w.z());

  setprop("sim/hitches/winch/tow/dist",initial_length_m - 1.);
  setprop("sim/hitches/winch/tow/length",initial_length_m);

  #print("name=",winchModel.getName(),"  Index=",winchModel.getIndex(),"  Type=",winchModel.getType() );
  #print("val=",winchModel.getValue(),"  children=",winchModel.getChildren(),"  size=",size(winchModel) );
  setprop("/sim/hitches/winch/winch/winch-model-index",winchModel.getIndex() );
  setprop("sim/messages/pilot", sprintf("Connected to winch!"));

  props.globals.getNode("sim/hitches/winch/open").setBoolValue(0);

} # End function setWinchPositionAuto


# ######################################################################################################################
#                                                  clutch / un-clutch winch
# ######################################################################################################################

var runWinch = func {

  if ( !getprop("sim/hitches/winch/winch/clutched") ) {
    setprop("sim/hitches/winch/winch/clutched","true");
    setprop("sim/messages/pilot", sprintf("Winch clutched!"));
  }
  else {
    setprop("sim/hitches/winch/winch/clutched","false");
    setprop("sim/messages/pilot", sprintf("Winch un-clutched!"));
  }

} # End function runWinch


# ######################################################################################################################
#                                                     release winch
# ######################################################################################################################

var releaseWinch = func {

  setprop("sim/hitches/winch/open","true");

} # End function releaseWinch


# ######################################################################################################################
#                                                  assignHitchLocations
# ######################################################################################################################

var assignHitchLocations = func (device){

  if ( getprop("sim/flight-model") == "yasim" ) return;	# bypass this routine for Yasim-aircraft

  if ( getprop("sim/hitches/" ~ device ~ "/decoupled-force-and-rope-locations") ) return; # bypass this routine

  #print("assignHitchLocations");

  var in2m = 0.0254;

  var hitchname = getprop("sim/hitches/" ~ device ~ "/force_name_jsbsim");

  # location-x(yz)-in: JSBSim Structural Frame: x points to tail, y points to right wing, z points upward
  # local-pos-x(yz):   YaSim frame:             x points to nose, y points to left wing,  z points upward

  setprop("sim/hitches/" ~ device ~ "/local-pos-x",
    - getprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/location-x-in") * in2m );
  setprop("sim/hitches/" ~ device ~ "/local-pos-y",
    - getprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/location-y-in") * in2m );
  setprop("sim/hitches/" ~ device ~ "/local-pos-z",
      getprop("fdm/jsbsim/external_reactions/" ~ hitchname ~ "/location-z-in") * in2m );

} # End function assignHitchLocations


# ######################################################################################################################
#                                                      point transformation
# ######################################################################################################################

var PointRotate3D = func (x,y,z,xr,yr,zr,alpha_deg,beta_deg,gamma_deg){

  # ---------------------------------------------------------------------------------
  #   rotates point (x,y,z) about all 3 cartesian axis
  #   center of rotation (xr,yr,zr)
  #   angle of rotation about x-axis = alpha
  #   angle of rotation about y-axis = beta
  #   angle of rotation about z-axis = gamma
  #   delivers new point coordinates (x_new,y_new,z_new)
  # ---------------------------------------------------------------------------------
  #
  #
  # Definitions:
  # ----------------
  #
  # x        y           z
  # alpha    beta        gamma
  #
  #
  #       z
  #       |  y
  #       | /
  #       |/
  #       ----->x
  #
  #----------------------------------------------------------------------------------

  # Transformation in rotation-system X_rel = X-Xr = (x-xr, y-yr, z-zr)
  var x_rel = x-xr;
  var y_rel = y-yr;
  var z_rel = z-zr;

  # Trigonometry
  var deg2rad = math.pi / 180.;

  var alpha_rad	   = deg2rad * alpha_deg;
  var beta_rad	   = deg2rad * beta_deg;
  var gamma_rad	   = deg2rad * gamma_deg;

  var sin_alpha = math.sin(alpha_rad);
  var cos_alpha = math.cos(alpha_rad);

  var sin_beta  = math.sin(beta_rad);
  var cos_beta  = math.cos(beta_rad);

  var sin_gamma = math.sin(gamma_rad);
  var cos_gamma = math.cos(gamma_rad);

  # Matrices
  #
  # Rotate about x-axis Rx(alpha)
  #
  #		Rx11 Rx12 Rx13      1	  0	       0
  # Rx(alpha)=  Rx21 Rx22 Rx23   =  0  cos(alpha)  -sin(alpha)
  #		Rx31 Rx32 Rx33      0  sin(alpha)   cos(alpha)
  #
  var Rx11 = 1.;
  var Rx12 = 0.;
  var Rx13 = 0.;
  var Rx21 = 0.;
  var Rx22 = cos_alpha;
  var Rx23 = - sin_alpha;
  var Rx31 = 0.;
  var Rx32 = sin_alpha;
  var Rx33 = cos_alpha;
  #
  # Rotate about y-axis Ry(beta)
  #
  #	       Ry11 Ry12 Ry13	   cos(beta)  0   sin(beta)
  # Ry(beta)=  Ry21 Ry22 Ry23	=      0      1      0
  #	       Ry31 Ry32 Ry33	  -sin(beta)  0   cos(beta)
  #
  var Ry11 = cos_beta;
  var Ry12 = 0.;
  var Ry13 = sin_beta;
  var Ry21 = 0.;
  var Ry22 = 1.;
  var Ry23 = 0.;
  var Ry31 = - sin_beta;
  var Ry32 = 0.;
  var Ry33 = cos_beta;
  #
  # Rotate about z-axis Rz(gamma)
  #
  #	       Rz11 Rz12 Rz13	   cos(gamma)  -sin(gamma)  0
  # Rz(gamma)= Rz21 Rz22 Rz23	=  sin(gamma)	cos(gamma)  0
  #	       Rz31 Rz32 Rz33	       0	    0	    1
  #
  var Rz11 = cos_gamma;
  var Rz12 = - sin_gamma;
  var Rz13 = 0.;
  var Rz21 = sin_gamma;
  var Rz22 = cos_gamma;
  var Rz23 = 0.;
  var Rz31 = 0.;
  var Rz32 = 0.;
  var Rz33 = 1.;
  #
  # First rotation about x-axis
  # X_x = Rx*X_rel
  var x_x = Rx11 * x_rel + Rx12 * y_rel + Rx13 * z_rel;
  var y_x = Rx21 * x_rel + Rx22 * y_rel + Rx23 * z_rel;
  var z_x = Rx31 * x_rel + Rx32 * y_rel + Rx33 * z_rel;
  #
  # subsequent rotation about y-axis
  # X_xy = Ry*X_x
  var x_xy = Ry11 * x_x + Ry12 * y_x + Ry13 * z_x;
  var y_xy = Ry21 * x_x + Ry22 * y_x + Ry23 * z_x;
  var z_xy = Ry31 * x_x + Ry32 * y_x + Ry33 * z_x;
  #
  # subsequent rotation about z-axis:
  # X_xyz = Rz*X_xy
  var x_xyz = Rz11 * x_xy + Rz12 * y_xy + Rz13 * z_xy;
  var y_xyz = Rz21 * x_xy + Rz22 * y_xy + Rz23 * z_xy;
  var z_xyz = Rz31 * x_xy + Rz32 * y_xy + Rz33 * z_xy;

  # Back transformation  X_rel = X-Xr = (x-xr, y-yr, z-zr)
  var xn = xr + x_xyz;
  var yn = yr + y_xyz;
  var zn = zr + z_xyz;

  var Xn = [xn,yn,zn];

  return Xn;

}

##################################################################################################################################


# todo:
# ------
#
# - animate rope slack
# - pull in towrope: take sink rate of rope into account
# - dynamic ID for ai-rope-model
#
# Please contact D_NXKT at yahoo.de for bug-reports, suggestions, ...
#