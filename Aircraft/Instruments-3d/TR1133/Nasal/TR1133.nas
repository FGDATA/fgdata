#####################################################################################
#  This script provides the gui to set up the TR1133 radio                          #
#                                                                                   #
#  Author Vivian Meazza   June 2011                                                 #
#####################################################################################

# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted 
# for, and that they have sane default values.

var channelA_node = props.globals.initNode("instrumentation/comm/channels/A-mhz", 0, "DOUBLE");
var channelB_node = props.globals.initNode("instrumentation/comm/channels/B-mhz", 0, "DOUBLE");
var channelC_node = props.globals.initNode("instrumentation/comm/channels/C-mhz", 0, "DOUBLE");
var channelD_node = props.globals.initNode("instrumentation/comm/channels/D-mhz", 0, "DOUBLE");

var channel_selected_node = props.globals.initNode("systems/comm/SCR-522C/frequencies/channel-selected", 0, "INT");
var tr_node = props.globals.initNode("systems/comm/SCR-522C/tr", 1, "INT");
props.globals.initNode("systems/comm/SCR-522C/frequencies/channel", "", "STRING");
props.globals.initNode("systems/comm/SCR-522C/channel-dimmer", 0, "BOOL");
props.globals.initNode("systems/comm/SCR-522C/tr-lock", 1, "BOOL");

var comm_selected_node = props.globals.getNode("instrumentation/comm/frequencies/selected-mhz", 1);
var comm_standby_node = props.globals.getNode("instrumentation/comm/frequencies/standby-mhz", 1);
var comm1_selected_node = props.globals.getNode("instrumentation/comm[1]/frequencies/selected-mhz", 1);
var comm1_standby_node = props.globals.getNode("instrumentation/comm[1]/frequencies/standby-mhz", 1);

var radio_dlg = gui.Dialog.new("dialog","Aircraft/Instruments-3d/TR1133/Dialogs/radios.xml");

var channel = ["OFF","A","B","C","D"];
#getprop("systems/comm/SCR-522C/frequencies/channel", 1);
setprop("systems/comm/SCR-522C/frequencies/channel", channel[channel_selected_node.getValue()]);

var TR1133_init = func(){

    print ("initializing TR1133 ...");

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

    # override F12
    setprop("input/keyboard/key[268]/binding/command", "nasal");
    setprop("input/keyboard/key[268]/binding/script", "TR1133.radio_dlg.open()");

    # Disable the menu item "Equipment > radio" so we use our own gui: " > Radio".
    print("Disabling Menu: Equipment -> Radios GUI using TR1133 -> Radio");

    gui.menuBind("radio", "TR1133.radio_dlg.open()");


# =============================== listeners ===============================
#

    setlistener("systems/comm/SCR-522C/frequencies/channel-selected", func(n) {
        var channel_no = n.getValue();

        if (channel_no == nil) channel_no = 0;

#       print("channel", channel_no, " ", channel[channel_no]);
        setprop("systems/comm/SCR-522C/frequencies/channel", channel[channel_no]);
    },
        1,
        0); #end listener

    setlistener("systems/comm/SCR-522C/tr", func(t) {
        var tr = t.getValue();
#        print("tr ",tr);

        if (tr == nil) tr = 1;

        if (tr == 0)
            setprop("instrumentation/comm/ptt", 1);
        else
            setprop("instrumentation/comm/ptt", 0);


    },
        1,
        0); # end listener

    print("... done");

}#end func initialize

setlistener("sim/signals/fdm-initialized", TR1133_init);























