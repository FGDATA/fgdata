###############################################################################
##
## Nasal for dual control of the ZLT-NT over the multiplayer network.
##
##  Copyright (C) 2008 - 2013  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Renaming (almost :)
var DCT = dual_control_tools;

######################################################################
# Pilot/copilot aircraft identifiers. Used by dual_control.
var pilot_type   = "Aircraft/ZLT-NT/Models/ZLT-NT.xml";
var copilot_type = "Aircraft/ZLT-NT/Models/ZLT-NT-copilot.xml";

props.globals.initNode("/sim/remote/pilot-callsign", "", "STRING");

######################################################################
# MP enabled properties.
# NOTE: These must exist very early during startup - put them
#       in the -set.xml file.

var pilot_switches1_mpp  = "sim/multiplay/generic/int[0]";
var pilot_TDM1_mpp       = "sim/multiplay/generic/string[1]";
var pilot_TDM2_mpp       = "sim/multiplay/generic/string[2]";
var pilot_TDM3_mpp       = "sim/multiplay/generic/string[3]";
var pilot_TDM4_mpp       = "sim/multiplay/generic/string[4]";
var pilot_rmi_head_mpp   = "sim/multiplay/generic/float[3]";
var pilot_ai_pitch_mpp   = "sim/multiplay/generic/float[4]";
var pilot_ai_roll_mpp    = "sim/multiplay/generic/float[5]";
#var pilot_ai_hoffset_mpp = "sim/multiplay/generic/float[6]";

var copilot_rudder_mpp   = "surface-positions/rudder-pos-norm";
var copilot_elevator_mpp = "surface-positions/elevator-pos-norm";
var copilot_elevator_trim_mpp = "surface-positions/left-aileron-pos-norm";
var copilot_rpm_cmd_mpp    =  ["sim/multiplay/generic/float[0]",
                               "sim/multiplay/generic/float[1]",
                               "sim/multiplay/generic/float[2]"];
var copilot_thrust_cmd_mpp =  ["sim/multiplay/generic/float[3]",
                               "sim/multiplay/generic/float[4]",
                               "sim/multiplay/generic/float[5]"];
var copilot_mixture_cmd_mpp = ["sim/multiplay/generic/float[6]",
                               "sim/multiplay/generic/float[7]",
                               "sim/multiplay/generic/float[8]"];
var copilot_switches1_mpp =    "sim/multiplay/generic/int[0]";
var copilot_TDM1_mpp      =    "sim/multiplay/generic/string[0]";

######################################################################
# Useful local property paths.

# Flight controls
var l_rudder_cmd   = "controls/flight/rudder";
var l_aileron_cmd  = "controls/flight/aileron";
var l_elevator_cmd = "controls/flight/elevator";
var l_elevator_trim_cmd = "controls/flight/elevator-trim";

# Engines
var l_pilot_rpm_cmd =
    ["controls/engines/engine[0]/throttle",
     "controls/engines/engine[1]/throttle",
     "controls/engines/engine[2]/throttle"];
var l_pilot_thrust_cmd =
    ["controls/engines/engine[0]/propeller-pitch",
     "controls/engines/engine[1]/propeller-pitch",
     "controls/engines/engine[2]/propeller-pitch"];
var l_pilot_mixture_cmd =
    ["controls/engines/engine[0]/mixture",
     "controls/engines/engine[1]/mixture",
     "controls/engines/engine[2]/mixture"];
var l_manifold_pressure =
    ["engines/engine[0]/mp-inhg",
     "engines/engine[1]/mp-inhg",
     "engines/engine[2]/mp-inhg"];
var l_EGT =
    ["engines/engine[0]/egt-degc",
     "engines/engine[1]/egt-degc",
     "engines/engine[2]/egt-degc"];
var l_CHT =
    ["engines/engine[0]/cht-degc",
     "engines/engine[1]/cht-degc",
     "engines/engine[2]/cht-degc"];
var l_oil_temperature =
    ["engines/engine[0]/oil-temperature-degc",
     "engines/engine[1]/oil-temperature-degc",
     "engines/engine[2]/oil-temperature-degc"];
var l_oil_pressure =
    ["engines/engine[0]/oil-pressure-psi",
     "engines/engine[1]/oil-pressure-psi",
     "engines/engine[2]/oil-pressure-psi"];
var l_fuel_quantity =
    ["consumables/fuel/tank[0]/level-lbs",
     "consumables/fuel/tank[1]/level-lbs",
     "consumables/fuel/tank[2]/level-lbs"];
var l_fuel_flow =
    ["engines/engine[0]/fuel-flow-gph",
     "engines/engine[1]/fuel-flow-gph",
     "engines/engine[2]/fuel-flow-gph"];

# Instruments
var l_altimeter_setting = "instrumentation/altimeter[1]/setting-inhg";
var l_gas_pressure      = "fdm/jsbsim/instrumentation/gas-pressure-psf";
var l_ballonet_volume   =
    ["fdm/jsbsim/buoyant_forces/gas-cell/ballonet[0]/volume-ft3",
     "fdm/jsbsim/buoyant_forces/gas-cell/ballonet[1]/volume-ft3"];
var l_net_lift          = "/fdm/jsbsim/static-condition/net-lift-lbs";
var l_cg_position       = "/fdm/jsbsim/inertia/cg-x-in";
var l_rmi_heading = "instrumentation/rmi/indicated-heading-deg";
var l_ai_pitch    = "instrumentation/attitude-indicator/indicated-pitch-deg";
var l_ai_roll     = "instrumentation/attitude-indicator/indicated-roll-deg";
#var l_ai_hoffset  = "instrumentation/attitude-indicator/horizon-offset-deg";

######################################################################
# Slow state properties for replication.

var fcs = "fdm/jsbsim/fcs";

###############################################################################
# Pilot MP property mappings and specific copilot connect/disconnect actions.
var l_dual_control         = "fdm/jsbsim/fcs/dual-control/enabled";

# Engines
var l_shared_rpm_cmd =
    ["fdm/jsbsim/fcs/dual-control/propeller-speed-cmd-norm[0]",
     "fdm/jsbsim/fcs/dual-control/propeller-speed-cmd-norm[1]",
     "fdm/jsbsim/fcs/dual-control/propeller-speed-cmd-norm[2]"];
# The final RPM cmd after the FCS. 
var l_final_rpm_cmd =
    ["fdm/jsbsim/fcs/propeller-speed-cmd-norm[0]",
     "fdm/jsbsim/fcs/propeller-speed-cmd-norm[1]",
     "fdm/jsbsim/fcs/propeller-speed-cmd-norm[2]"];
var l_final_rpm_cmd_rpm =
    ["fdm/jsbsim/fcs/etc/propeller-speed-cmd-rpm[0]",
     "fdm/jsbsim/fcs/etc/propeller-speed-cmd-rpm[1]",
     "fdm/jsbsim/fcs/etc/propeller-speed-cmd-rpm[2]"];

var l_shared_thrust_cmd =
    ["fdm/jsbsim/fcs/dual-control/thrust-cmd-norm[0]",
     "fdm/jsbsim/fcs/dual-control/thrust-cmd-norm[1]",
     "fdm/jsbsim/fcs/dual-control/thrust-cmd-norm[2]"];
var l_final_thrust_cmd =
    ["fdm/jsbsim/fcs/thrust-cmd-norm[0]",
     "fdm/jsbsim/fcs/thrust-cmd-norm[1]",
     "fdm/jsbsim/fcs/thrust-cmd-norm[2]"];

var l_shared_mixture_cmd =
    ["fdm/jsbsim/fcs/dual-control/mixture-cmd-norm[0]",
     "fdm/jsbsim/fcs/dual-control/mixture-cmd-norm[1]",
     "fdm/jsbsim/fcs/dual-control/mixture-cmd-norm[2]"];
var l_final_mixture_cmd =
    ["fdm/jsbsim/fcs/mixture-cmd-norm[0]",
     "fdm/jsbsim/fcs/mixture-cmd-norm[1]",
     "fdm/jsbsim/fcs/mixture-cmd-norm[2]"];

var l_ballonet_inflation_cmd =
    ["fdm/jsbsim/fcs/ballonet-inflation-cmd-norm[0]",
     "fdm/jsbsim/fcs/ballonet-inflation-cmd-norm[1]"];

######################################################################
# Used by dual_control to set up the mappings for the pilot.
var pilot_connect_copilot = func (copilot) {
    # Make sure dual-control is activated in the FDM FCS.
    settimer(func { setprop(l_dual_control, 1); }, 1);

    # VHF 22 Comm. Comm 1 is owned by pilot, 2 by copilot.
    VHF22.make_master(0);
    VHF22.make_slave_to(1, copilot);
    # VIR 32 Nav. Nav 1 is owned by pilot, 2 by copilot.
    VIR32.make_master(0);
    VIR32.make_slave_to(1, copilot);

    return 
        [
         ######################################################################
         # Process received properties.
         ######################################################################
         ##################################################
         # Copilot main flight control
         DCT.Translator.new
         (copilot.getNode(copilot_elevator_mpp),
          props.globals.getNode("/fdm/jsbsim/fcs/copilot/pitch-cmd-norm")),
         DCT.Translator.new
         (copilot.getNode(copilot_rudder_mpp),
          props.globals.getNode("/fdm/jsbsim/fcs/copilot/yaw-cmd-norm")),
         ##################################################
         # Copilot elevator trim control
         DCT.DeltaAdder.new
         (copilot.getNode(copilot_elevator_trim_mpp),
          props.globals.getNode(l_elevator_trim_cmd)),
         ##################################################
         # Copilot engine control inputs
         # RPM select sharing
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_rpm_cmd[0]),
          copilot.getNode(copilot_rpm_cmd_mpp[0]),
          props.globals.getNode(l_shared_rpm_cmd[0], 1),
          0.02),
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_rpm_cmd[1]),
          copilot.getNode(copilot_rpm_cmd_mpp[1]),
          props.globals.getNode(l_shared_rpm_cmd[1], 1),
          0.02),
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_rpm_cmd[2]),
          copilot.getNode(copilot_rpm_cmd_mpp[2]),
          props.globals.getNode(l_shared_rpm_cmd[2], 1),
          0.02),
         # Thrust sharing
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_thrust_cmd[0]),
          copilot.getNode(copilot_thrust_cmd_mpp[0]),
          props.globals.getNode(l_shared_thrust_cmd[0]),
          0.02),
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_thrust_cmd[1]),
          copilot.getNode(copilot_thrust_cmd_mpp[1]),
          props.globals.getNode(l_shared_thrust_cmd[1]),
          0.02),
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_thrust_cmd[2]),
          copilot.getNode(copilot_thrust_cmd_mpp[2]),
          props.globals.getNode(l_shared_thrust_cmd[2]),
          0.02),
         # Mixture sharing
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_mixture_cmd[0]),
          copilot.getNode(copilot_mixture_cmd_mpp[0]),
          props.globals.getNode(l_shared_mixture_cmd[0]),
          0.02),
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_mixture_cmd[1]),
          copilot.getNode(copilot_mixture_cmd_mpp[1]),
          props.globals.getNode(l_shared_mixture_cmd[1]),
          0.02),
         DCT.MostRecentSelector.new
         (props.globals.getNode(l_pilot_mixture_cmd[2]),
          copilot.getNode(copilot_mixture_cmd_mpp[2]),
          props.globals.getNode(l_shared_mixture_cmd[2]),
          0.02),
         ##################################################
         # Decode copilot cockpit switch states.
         #   NOTE: Actions are only triggered on change.
         DCT.SwitchDecoder.new
         (copilot.getNode(copilot_switches1_mpp),
          [
           # 0 - 1: "flaps"/side engines up / down. 
           func (b) {
               if (b) controls.flapsDown(1);
           },
           func (b) {
               if (b) controls.flapsDown(-1);
           },
           # 2 - 3: "gear"/rear engine up / down. 
           func (b) {
               if (b) controls.gearDown(-1);
           },
           func (b) {
               if (b) controls.gearDown(1);
           }
          ] ~
          ########################################
          #  4 - 8: VHF22 Comm 1
          VHF22.master_receive_slave_buttons(0) ~
          ########################################
          #  9 - 13: VIR32 Nav 1
          VIR32.master_receive_slave_buttons(0) ~
          [
           ########################################
           # 14 - 17: Ballonet cmd inc/dec
           func (b) {
               if (b) { ZLTNT.step_ballonet_cmd(0, 0.05); }
           },
           func (b) {
               if (b) { ZLTNT.step_ballonet_cmd(0, -0.05); }
           },
           func (b) {
               if (b) { ZLTNT.step_ballonet_cmd(1, 0.05); }
           },
           func (b) {
               if (b) { ZLTNT.step_ballonet_cmd(1, -0.05); }
           },
          ] ~
          ########################################
          #  18 - 22: ADF 462
          ADF462.master_receive_slave_buttons(0)
          ),
         ##################################################
         # Set up TDM reception of slow state properties.
         DCT.TDMDecoder.new
         (copilot.getNode(copilot_TDM1_mpp),
          #  0 - 1 Comm 2 frequencies
          VHF22.slave_receive_master_state(1) ~
          #  2 - 3 Nav 2 frequencies
          VIR32.slave_receive_master_state(1)
         ),

         ######################################################################
         # Process properties to send.
         ######################################################################
         ##################################################
         # Encoding of on/off switches.
         DCT.SwitchEncoder.new
         (
          #  0 - 4: VHF22 Comm 2
          VHF22.slave_send_buttons(1) ~
          #  5 - 9: VIR32 Nav 2
          VIR32.slave_send_buttons(1),
          props.globals.getNode(pilot_switches1_mpp)
         ),
         ##################################################
         # Set up TDM transmission of slow state properties.
         DCT.TDMEncoder.new
         ([
           # 1 - 3 RPM sel cmd
           props.globals.getNode(l_final_rpm_cmd[0]),
           props.globals.getNode(l_final_rpm_cmd[1]),
           props.globals.getNode(l_final_rpm_cmd[2]),
           # 4 - 6 thrust cmd
           props.globals.getNode(l_final_thrust_cmd[0]),
           props.globals.getNode(l_final_thrust_cmd[1]),
           props.globals.getNode(l_final_thrust_cmd[2]),
           # 7 - 9 mixture cmd
           props.globals.getNode(l_final_mixture_cmd[0]),
           props.globals.getNode(l_final_mixture_cmd[1]),
           props.globals.getNode(l_final_mixture_cmd[2]),
           # 10 - 12 Engine swivel cmd
           props.globals.getNode(fcs ~ "/etc/side-engine-swivel-cmd-rad[0]"),
           props.globals.getNode(fcs ~ "/etc/side-engine-swivel-cmd-rad[1]"),
           props.globals.getNode(fcs ~ "/etc/rear-engine-swivel-cmd-rad"),
           # 13 - 14 ballonet inflation cmd
           props.globals.getNode(l_ballonet_inflation_cmd[0]),
           props.globals.getNode(l_ballonet_inflation_cmd[1]),
           # 15 Altimeter
           props.globals.getNode(l_altimeter_setting),
          ],
          props.globals.getNode(pilot_TDM1_mpp),
         ),
         ##################################################
         # Set up TDM transmission of slow state properties.
         DCT.TDMEncoder.new
         ([
           # 1 gas pressure
           props.globals.getNode(l_gas_pressure),
           # 2 - 3 ballonet volume
           props.globals.getNode(l_ballonet_volume[0]),
           props.globals.getNode(l_ballonet_volume[1]),
           # 4 net lift
           props.globals.getNode(l_net_lift),
           # 5 CG position
           props.globals.getNode(l_cg_position),
          ] ~
          #  6 - 7 Comm 1 frequencies
          VHF22.master_send_state(0) ~
          #  8 - 9 Nav 1 frequencies
          VIR32.master_send_state(0) ~
          #  10 -11 ADF frequencies
          ADF462.master_send_state(0),
          props.globals.getNode(pilot_TDM2_mpp),
         ),
         ##################################################
         # Set up TDM transmission of slow state properties.
         DCT.TDMEncoder.new
         (CenterMFD.master_send_state(),
          props.globals.getNode(pilot_TDM3_mpp),
         ),
         ##################################################
         # Set up TDM transmission of slow state properties.
         DCT.TDMEncoder.new
         (EPI.master_send_state() ~
          OAT_superheat.master_send_state(),
          props.globals.getNode(pilot_TDM4_mpp),
         )
        ];
}

######################################################################
var pilot_disconnect_copilot = func {
    # Reset copilot controls. Slightly dangerous.
    setprop("/fdm/jsbsim/fcs/copilot/pitch-cmd-norm", 0.0);
    setprop("/fdm/jsbsim/fcs/copilot/yaw-cmd-norm", 0.0);
    setprop(l_dual_control, 0);

    # VHF 22 Comm. Regain control of Comm 2.
    VHF22.make_master(1);
    # VIR 32 Nav. Regain control of Nav 2.
    VIR32.make_master(1);
}


###############################################################################
# Copilot MP property mappings and specific pilot connect/disconnect actions.

var l_flap_up_cmd   = "controls/flight/flaps-up";
var l_flap_down_cmd = "controls/flight/flaps-down";
var l_gear_up_cmd   = "controls/flight/gear-up";
var l_gear_down_cmd = "controls/flight/gear-down";
var l_ballonet_cmd_inc = ["controls/ballonet/inc[0]",
                          "controls/ballonet/inc[1]"];
var l_ballonet_cmd_dec = ["controls/ballonet/dec[0]",
                          "controls/ballonet/dec[1]"];

######################################################################
# Used by dual_control to set up the mappings for the copilot.
var copilot_connect_pilot = func (pilot) {
    # Initialize Nasal wrappers for copilot pick anaimations.
    set_copilot_wrappers(pilot);

    # Map (some) properties needed to (e.g.) animate the MP/AI model.
    copilot_alias_aimodel(pilot);

    # VHF 22 Comm. Comm 1 is owned by pilot, 2 by copilot.
    VHF22.make_slave_to(0, pilot);
    VHF22.make_master(1);
    VHF22.animate_aimodel(0, pilot);
    VHF22.animate_aimodel(1, pilot);
    # VIR 32 Nav. Nav 1 is owned by pilot, 2 by copilot.
    VIR32.make_slave_to(0, pilot);
    VIR32.make_master(1);
    VIR32.animate_aimodel(0, pilot);
    VIR32.animate_aimodel(1, pilot);
    # KDI 572 DME indicator. Replicated.
    KDI572.animate_aimodel(0, pilot);
    # ADF 462. Owned by the pilot.
    ADF462.make_slave_to(0, pilot);
    ADF462.animate_aimodel(0, pilot);
    # Center MFD. Owned by the pilot.
    CenterMFD.animate_aimodel(pilot);
    # EPI. Owned by the pilot.
    EPI.animate_aimodel(pilot);
    # OAT and superheat. Owned by the pilot.
    OAT_superheat.animate_aimodel(pilot);
    # KNS-80 Integrated NAV System.
    systems.animate_aimodel(pilot);

    return
        [
         ######################################################################
         # Process received properties.
         ######################################################################
         ##################################################
         # Map engine RPMs to the appropriate properties for the thrusters.
         DCT.Translator.new
         (pilot.getNode("engines/engine[0]/rpm"),
          props.globals.getNode("engines/engine[0]/thruster/rpm", 1),
          0.46),
         DCT.Translator.new
         (pilot.getNode("engines/engine[1]/rpm"),
          props.globals.getNode("engines/engine[1]/thruster/rpm", 1),
          0.46),
         DCT.Translator.new
         (pilot.getNode("engines/engine[2]/rpm"),
          props.globals.getNode("engines/engine[2]/thruster/rpm", 1),
          0.46),
         ##################################################
         # Decode pilot cockpit switch states.
         #   NOTE: Actions are only triggered on change.
         DCT.SwitchDecoder.new
         (pilot.getNode(pilot_switches1_mpp),
          #  0 - 4: VHF22 Comm 2
          VHF22.master_receive_slave_buttons(1) ~
          #  5 - 9: VIR32 Nav 2
          VIR32.master_receive_slave_buttons(1)
         ),
         ##################################################
         # Set up TDM reception of slow state properties.
         DCT.TDMDecoder.new
         (pilot.getNode(pilot_TDM1_mpp),
          [
           # 1 - 3 RPM sel cmd
           func (v) {
               pilot.getNode(l_final_rpm_cmd[0]).setValue(v);
               props.globals.getNode
                   (l_final_rpm_cmd_rpm[0], 1).setValue(950 * v + 300);
           },
           func (v) {
               pilot.getNode(l_final_rpm_cmd[1]).setValue(v);
               props.globals.getNode
                   (l_final_rpm_cmd_rpm[1], 1).setValue(950 * v + 300);
           },
           func (v) {
               pilot.getNode(l_final_rpm_cmd[2]).setValue(v);
               props.globals.getNode
                   (l_final_rpm_cmd_rpm[2], 1).setValue(950 * v + 300);
           },
           # 4 - 6 thrust cmd
           func (v) {
               pilot.getNode(l_final_thrust_cmd[0]).setValue(v);
               props.globals.getNode
                   ("/fdm/jsbsim/propulsion/engine[0]/blade-angle",
                    1).setValue(60*v - 25);
           },
           func (v) {
               pilot.getNode(l_final_thrust_cmd[1]).setValue(v);
               props.globals.getNode
                   ("/fdm/jsbsim/propulsion/engine[1]/blade-angle",
                    1).setValue(60*v - 25);
           },
           func (v) {
               pilot.getNode(l_final_thrust_cmd[2]).setValue(v);
               props.globals.getNode
                   ("/fdm/jsbsim/propulsion/engine[2]/blade-angle",
                    1).setValue(60*v - 25);
           },
           # 7 - 9 mixture cmd
           func (v) {
               pilot.getNode(l_final_mixture_cmd[0]).setValue(v);
           },
           func (v) {
               pilot.getNode(l_final_mixture_cmd[1]).setValue(v);
           },
           func (v) {
               pilot.getNode(l_final_mixture_cmd[2]).setValue(v);
           },
           # 10 - 12 Engine swivel cmd
           func (v) {
               pilot.getNode
                   (fcs ~ "/etc/side-engine-swivel-cmd-rad[0]").setValue(v);
               props.globals.getNode
                   (fcs ~ "/etc/side-engine-swivel-cmd-rad[0]", 1).setValue(v);
           },
           func (v) {
               pilot.getNode
                   (fcs ~ "/etc/side-engine-swivel-cmd-rad[1]").setValue(v);
               props.globals.getNode
                   (fcs ~ "/etc/side-engine-swivel-cmd-rad[1]", 1).setValue(v);
           },
           func (v) {
               pilot.getNode
                   (fcs ~ "/etc/rear-engine-swivel-cmd-rad").setValue(v);
               props.globals.getNode
                   (fcs ~ "/etc/rear-engine-swivel-cmd-rad", 1).setValue(v);
           },
           # 13 - 14 ballonet inflation cmd
           func (v) {
               pilot.getNode(l_ballonet_inflation_cmd[0]).setValue(v);
               props.globals.getNode
                   (l_ballonet_inflation_cmd[0], 1).setValue(v);
           },
           func (v) {
               pilot.getNode(l_ballonet_inflation_cmd[1]).setValue(v);
               props.globals.getNode
                   (l_ballonet_inflation_cmd[1], 1).setValue(v);
           },
           # 15 Altimeter
           func (v) {
               props.globals.getNode(l_altimeter_setting).setValue(v);
           },
          ]),
         ##################################################
         # Set up TDM reception of slow state properties.
         DCT.TDMDecoder.new
         (pilot.getNode(pilot_TDM2_mpp),
          [
           # 1 gas pressure
           func (v) {
               props.globals.getNode(l_gas_pressure).setValue(v);
               pilot.getNode(l_gas_pressure, 1).setValue(v);
           },
           # 2 - 3 ballonet volumes
           func (v) {
               props.globals.getNode(l_ballonet_volume[0]).setValue(v);
               pilot.getNode(l_ballonet_volume[0], 1).setValue(v);
           },
           func (v) {
               props.globals.getNode(l_ballonet_volume[1]).setValue(v);
               pilot.getNode(l_ballonet_volume[1], 1).setValue(v);
           },
           # 4 net lift
           func (v) {
               props.globals.getNode(l_net_lift).setValue(v);
           },
           # 5 CG position
           func (v) {
               props.globals.getNode(l_cg_position).setValue(v);
           },
          ] ~
          #  6 - 7 Comm 1 frequencies
          VHF22.slave_receive_master_state(0) ~
          #  8 - 9 Nav 1 frequencies
          VIR32.slave_receive_master_state(0) ~
          #  10 - 11 ADF frequencies
          ADF462.slave_receive_master_state(0)
         ),
         ##################################################
         # Set up TDM reception of slow state properties.
         DCT.TDMDecoder.new
         (pilot.getNode(pilot_TDM3_mpp),
          CenterMFD.slave_receive_master_state()
         ),
         ##################################################
         # Set up TDM reception of slow state properties.
         DCT.TDMDecoder.new
         (pilot.getNode(pilot_TDM4_mpp),
          EPI.slave_receive_master_state() ~
          OAT_superheat.slave_receive_master_state()
         ),

         ######################################################################
         # Process properties to send.
         ######################################################################
         ##################################################
         # Map copilot flight controls to MP properties.
         DCT.Translator.new
         (props.globals.getNode(l_aileron_cmd),
          props.globals.getNode(copilot_rudder_mpp), 1),
         DCT.Translator.new
         (props.globals.getNode(l_elevator_cmd),
          props.globals.getNode(copilot_elevator_mpp)),
         DCT.Translator.new
         (props.globals.getNode(l_elevator_trim_cmd),
          props.globals.getNode(copilot_elevator_trim_mpp)),
         ##################################################
         # Encoding of on/off switches.
         DCT.SwitchEncoder.new
         ([
           # 0 - 1: "flaps"/side engines up / down.
           props.globals.initNode(l_flap_up_cmd, 0, "BOOL"),
           props.globals.initNode(l_flap_down_cmd, 0, "BOOL"),
           # 2 - 3: "gear"/rear engine up / down.
           props.globals.initNode(l_gear_up_cmd, 0, "BOOL"),
           props.globals.initNode(l_gear_down_cmd, 0, "BOOL"),
          ] ~
          #  4 - 8: VHF22 Comm 1
          VHF22.slave_send_buttons(0) ~
          #  9 - 13: VIR32 Nav 1
          VIR32.slave_send_buttons(0) ~
          [
           # 14 - 17: Ballonet cmd inc/dec
           props.globals.getNode(l_ballonet_cmd_inc[0], 1),
           props.globals.getNode(l_ballonet_cmd_dec[0], 1),
           props.globals.getNode(l_ballonet_cmd_inc[1], 1),
           props.globals.getNode(l_ballonet_cmd_dec[1], 1)
          ] ~
          #  18 - 22: ADF 462
          ADF462.slave_send_buttons(0),
          props.globals.getNode(copilot_switches1_mpp)),
         ##################################################
         # Set up TDM transmission of slow state properties.
         DCT.TDMEncoder.new
         (
          #  0 - 1 Comm 2 frequencies
          VHF22.master_send_state(1) ~
          #  2 - 3 Nav 2 frequencies
          VIR32.master_send_state(1),
          props.globals.getNode(copilot_TDM1_mpp),
         )
        ];
}

######################################################################
var copilot_disconnect_pilot = func {
    # VHF 22 Comm. Regain control of Comm 1.
    VHF22.make_master(0);
    # VIR 32 Nav. Regain control of Nav 1.
    VIR32.make_master(0);

    # Silence the pressure alarm.
    setprop("instrumentation/envelope-pressure-indicator/indicated-gas-pressure-psf", -1);
}

######################################################################
# Copilot Nasal wrappers

var set_copilot_wrappers = func (pilot) {
    #######################################################
    # controls.nas wrapper overrides.

    # Flap control input is -1 for step decrease; 1 for step increase; 0 idle
    controls.flapsDown = func (v) {
        if(v > 0) {
            setprop(l_flap_up_cmd, 1);
            settimer(func { setprop(l_flap_up_cmd, 0); },
                     1.0);
        } elsif(v < 0) {
            setprop(l_flap_down_cmd, 1);
            settimer(func { setprop(l_flap_down_cmd, 0); },
                     1.0);
        } else
            return;
        var n = -12*v + 57.29578*getprop(fcs ~ "/etc/side-engine-swivel-cmd-rad");
        gui.popupTip("Side engine swivel " ~
                     int((n < 0 ? 0 : (n > 120 ? 120 : n))) ~ " deg.");
    }
    # Gear control input is -1 for retract; 1 for extend; 0 idle
    controls.gearDown = func(v) {
        if(v < 0) {
            setprop(l_gear_up_cmd, 1);
            settimer(func { setprop(l_gear_up_cmd, 0); },
                     1.0);
        } elsif(v > 0) {
            setprop(l_gear_down_cmd, 1);
            settimer(func { setprop(l_gear_down_cmd, 0); },
                     1.0);
        } else {
            return;
        }
        gui.popupTip("Aft engine swivel " ~ int(v < 0 ? 0 : 90) ~ " deg.");
    }
    # Ballonet control
    ZLTNT.step_ballonet_cmd = func(n, d) {
        if (d < 0) {
            setprop(l_ballonet_cmd_dec[n], 1);
            settimer(func { setprop(l_ballonet_cmd_dec[n], 0); },
                     1.0);
        } elsif (d > 0) {
            setprop(l_ballonet_cmd_inc[n], 1);
            settimer(func { setprop(l_ballonet_cmd_inc[n], 0); },
                     1.0);
        }
        var t = getprop(l_ballonet_inflation_cmd[n]) + d;
        gui.popupTip((n ? "Aft" : "Forward") ~ " ballonet " ~
                     (t <= 0 ? ("valve " ~ int(-100*t + 0.005) ~ "% open.")
                      : ("blower " ~ int(100*t + 0.005) ~ "%.")));
    }
    # Gas valve control
    ZLTNT.step_gas_valve_cmd = func(n, d) {
    }
}

######################################################################
# More property aliases to animate the MP/AI model for the copilot.
#  Contains all 1:1 mappings that are not provided by other modules
#  (e.g. instruments).
var copilot_alias_aimodel = func(pilot) {
    # Map the pilot's engine RPMs to local properties for the OSD.
    var p = "engines/engine[0]/rpm";
    props.globals.getNode(p, 1).alias(pilot.getNode(p));
    p = "engines/engine[1]/rpm";
    props.globals.getNode(p, 1).alias(pilot.getNode(p));
    p = "engines/engine[2]/rpm";
    props.globals.getNode(p, 1).alias(pilot.getNode(p));

    # Map the the local stick input to the copilot's side-stick.
    pilot.getNode("fdm/jsbsim/fcs/copilot/pitch-cmd-norm").
        alias(props.globals.getNode("controls/flight/elevator"));
    pilot.getNode("fdm/jsbsim/fcs/copilot/yaw-cmd-norm").
        alias(props.globals.getNode("controls/flight/aileron"));

    # Map airspeed for airspeed indicator. This is cheating!
    props.globals.
        getNode("/instrumentation/airspeed-indicator[0]/indicated-speed-kt", 1).
            alias(pilot.getNode("velocities/true-airspeed-kt"));
    props.globals.
        getNode("/instrumentation/airspeed-indicator[1]/indicated-speed-kt", 1).
            alias(pilot.getNode("velocities/true-airspeed-kt"));

    # Map RMI indicated heading for animation and other uses.
    pilot.getNode(l_rmi_heading, 1).alias(pilot.getNode(pilot_rmi_head_mpp));
    props.globals.getNode(l_rmi_heading, 1).
        alias(pilot.getNode(pilot_rmi_head_mpp));

    # Map Attitude Indicator for animation. NOTE: global properties.
    props.globals.getNode(l_ai_pitch, 1).
        alias(pilot.getNode(pilot_ai_pitch_mpp));
    props.globals.getNode(l_ai_roll, 1).
        alias(pilot.getNode(pilot_ai_roll_mpp));
#    props.globals.getNode(l_ai_hoffset, 1).
#        alias(pilot.getNode(pilot_ai_hoffset_mpp));

    # Map M877 clock properties to pilot 3d model. Local replica.
    var m877_props =
        [
         "instrumentation/clock/m877/ET-hr",
         "instrumentation/clock/m877/ET-min",
#         "instrumentation/clock/m877/ET-string",
         "instrumentation/clock/m877/FT-hr",
         "instrumentation/clock/m877/FT-min",
         "instrumentation/clock/m877/digit[0]",
         "instrumentation/clock/m877/digit[1]",
         "instrumentation/clock/m877/digit[2]",
         "instrumentation/clock/m877/digit[3]",
         "instrumentation/clock/m877/et-alarm",
         "instrumentation/clock/m877/flight-meter-sec",
         "instrumentation/clock/m877/ft-alarm-time",
         "instrumentation/clock/m877/ft-alert",
         "instrumentation/clock/m877/indicated-hour",
         "instrumentation/clock/m877/indicated-min",
#         "instrumentation/clock/m877/mode",
         "instrumentation/clock/m877/mode-string",
         "instrumentation/clock/m877/power",
         "instrumentation/clock/m877/tenths"
        ];
    foreach (var p; m877_props) {
        pilot.getNode(p, 1).alias(props.globals.getNode(p));
    }

    # Map some more instrument related properties.
    var panel_props =
        [
         "controls/lighting/panel-norm",
         # For the RMI.
         "instrumentation/nav[0]/heading-deg",
         "instrumentation/nav[1]/heading-deg",
         "instrumentation/adf[0]/indicated-bearing-deg",
         "instrumentation/rmi/button[0]",
         "instrumentation/rmi/button[1]"
        ];
    foreach (var p; panel_props) {
        pilot.getNode(p, 1).alias(props.globals.getNode(p, 1));
    }
    # Hide the RMI warning flag.
    pilot.getNode("instrumentation/rmi/spin").setValue(1.0);
}

