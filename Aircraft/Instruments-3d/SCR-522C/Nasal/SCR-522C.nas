#####################################################################################
#  This script provides the gui to set up the TR1133/SCR-522C radio                 #
#  using a BC-602-A control box                                                     #
#                                                                                   #
#  Author Vivian Meazza   June 2011                                                 #
#                                                                                   #
#  mods   Hal V. Engel    June 2011                                                 #
#                                                                                   #
#####################################################################################

# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted 
# for, and that they have sane default values.

var channelA_node = props.globals.initNode("instrumentation/comm/channels/A-mhz", 0, "DOUBLE");
var channelB_node = props.globals.initNode("instrumentation/comm/channels/B-mhz", 0, "DOUBLE");
var channelC_node = props.globals.initNode("instrumentation/comm/channels/C-mhz", 0, "DOUBLE");
var channelD_node = props.globals.initNode("instrumentation/comm/channels/D-mhz", 0, "DOUBLE");

var channel_selected_node = props.globals.initNode("instrumentation/comm/SCR-522C/frequencies/channel-selected", 0, "INT");
var tr_node = props.globals.initNode("instrumentation/comm/SCR-522C/tr", 0, "INT");
props.globals.initNode("instrumentation/comm/SCR-522C/frequencies/channel", "", "STRING");
props.globals.initNode("instrumentation/comm/SCR-522C/mask", 0, "BOOL");
props.globals.initNode("instrumentation/comm/SCR-522C/tr-lock", 0, "BOOL");
props.globals.initNode("instrumentation/comm/SCR-522C/remote-pushed", 0, "BOOL");

# turn the radio off
props.globals.initNode("instrumentation/comm/serviceable", 0, "BOOL");

var comm_selected_node = props.globals.getNode("instrumentation/comm/frequencies/selected-mhz", 1);
var comm_standby_node = props.globals.getNode("instrumentation/comm/frequencies/standby-mhz", 1);
var comm1_selected_node = props.globals.getNode("instrumentation/comm[1]/frequencies/selected-mhz", 1);
var comm1_standby_node = props.globals.getNode("instrumentation/comm[1]/frequencies/standby-mhz", 1);

var channel = ["OFF","A","B","C","D"];
setprop("instrumentation/comm/SCR-522C/frequencies/channel", channel[channel_selected_node.getValue()]);

# override default Equipment --> radio menu item
# Radio needs to be global in scope since it needs to presist for this to work

var Radio = gui.Dialog.new("sim/gui/dialogs/SCR-522C/dialog",
                           "Aircraft/Instruments-3d/SCR-522C/Dialogs/radios.xml");

gui.menuBind("radio", "SCR_522C.Radio.open()");

# override controls.ptt.  This implements a REMote ptt switch.

controls.ptt = func {    
    # T/R/REM set to REM remote ptt switch controls transmitter
    # print("intercept ptt for BC-602-A");
    if (getprop("instrumentation/comm/SCR-522C/tr") == 0 and                       # in REMote ptt switch mode
        getprop("instrumentation/comm/SCR-522C/frequencies/channel-selected") > 0) # and radio is on
       setprop("instrumentation/comm/ptt", arg[0]);                                # let remote ptt control transmitter
    else                                                                           # otherwise
       setprop("instrumentation/comm/ptt", 0);                                     # the remote ptt does nothing
    setprop("instrumentation/comm/SCR-522C/remote-pushed", arg[0]);                # use to animate remote ptt button
}

# =============================== listeners ===============================
#

# listener for channel selector.  Will cause the frequency of the transceiver to be changed.
# will also turn the radio on and off

var listenChannelSelected = func(n) {
    var channel_no = n.getValue();

    if (channel_no == nil) channel_no = 0;

    # print("channel", channel_no, " ", channel[channel_no]);
    setprop("instrumentation/comm/SCR-522C/frequencies/channel", channel[channel_no]);
    if (channel_no == 0)
        setprop("instrumentation/comm/serviceable", 0);
    else {
        setprop("instrumentation/comm/serviceable", 1);
	if (channel_no == 1) {
	    setprop("instrumentation/comm/frequencies/selected-mhz", getprop("instrumentation/comm/channels/A-mhz"));
	    setprop("instrumentation/comm/frequencies/standby-mhz", getprop("instrumentation/comm/channels/A-mhz"));
	}
	else if (channel_no == 2){
	    setprop("instrumentation/comm/frequencies/selected-mhz", getprop("instrumentation/comm/channels/B-mhz"));
	    setprop("instrumentation/comm/frequencies/standby-mhz", getprop("instrumentation/comm/channels/B-mhz"));
	}
	else if (channel_no == 3){
	    setprop("instrumentation/comm/frequencies/selected-mhz", getprop("instrumentation/comm/channels/C-mhz"));
	    setprop("instrumentation/comm/frequencies/standby-mhz", getprop("instrumentation/comm/channels/C-mhz"));
	}
	else if (channel_no == 4){
	    setprop("instrumentation/comm/frequencies/selected-mhz", getprop("instrumentation/comm/channels/D-mhz"));
	    setprop("instrumentation/comm/frequencies/standby-mhz", getprop("instrumentation/comm/channels/D-mhz"));
	} 
    }
}

# listener for the local TR switch.

var listenTr = func(t) {
    var tr = t.getValue();
    # print("tr ",tr);

    if (tr == nil) tr = 0;
    if (tr == 2 and getprop("instrumentation/comm/SCR-522C/frequencies/channel-selected") > 0)
        setprop("instrumentation/comm/ptt", 1);
    else if (tr == 1)
        setprop("instrumentation/comm/ptt", 0);
    if (tr == 0 and getprop("/instrumentation/comm/SCR-522C/tr-lock"))
        setprop("/instrumentation/comm/SCR-522C/tr", 1);
}

# listener for the local TR lock.
        
var listenTrLock = func(i) {
    var tr_lock = i.getValue();
    # print("tr_lock");

    if (tr_lock == nil) tr_lock = false;
    if (tr_lock and getprop("/instrumentation/comm/SCR-522C/tr") == 0)
        setprop("/instrumentation/comm/SCR-522C/tr", 1);
    # else if (getprop("/instrumentation/comm/SCR-522C/tr") == 2)
    #     setprop("/instrumentation/comm/SCR-522C/tr", 1);

}

var SCR_522C_init = func(){

    var channelA_init = comm_selected_node.getValue();
    var channelB_init = comm_standby_node.getValue();
    var channelC_init = comm1_selected_node.getValue();
    var channelD_init = comm1_standby_node.getValue();

    channelA_node.setValue(channelA_init);
    channelB_node.setValue(channelB_init);
    channelC_node.setValue(channelC_init);
    channelD_node.setValue(channelD_init);

    comm_selected_node.setValue(0);
    comm_standby_node.setValue(0);
    comm1_selected_node.setValue(0);
    comm1_standby_node.setValue(0);

    # over ride F12
    setprop("input/keyboard/key[268]/binding/dialog-name", "SCR-522C-radio");
    setprop("input/keyboard/key[268]/binding/command", "dialog-show");


# =============================== start listeners ===============================
#

    setlistener("instrumentation/comm/SCR-522C/frequencies/channel-selected", listenChannelSelected, 1, 0);

    setlistener("instrumentation/comm/SCR-522C/tr", listenTr, 1, 0);
      
    setlistener("instrumentation/comm/SCR-522C/tr-lock", listenTrLock, 1, 0);

    # print("... done");

} # end func initialize

# run initialization

setlistener("sim/signals/fdm-initialized", SCR_522C_init);