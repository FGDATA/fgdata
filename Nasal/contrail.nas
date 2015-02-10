#########
# contrail calculator. Based on an approxmation to the "Appleman Chart"
# y = -0.077x2 + 2.7188x - 64.36
#
########

updateContrail = func{
    var pressure_Node = props.globals.getNode("environment/pressure-inhg");
    var temperature_Node = props.globals.getNode("environment/temperature-degc");
    var contrail_Node = props.globals.getNode("environment/contrail");
    var contrail_temp_Node = props.globals.getNode("environment/contrail-temperature-degc");

    var x = pressure_Node.getValue();
    var y = temperature_Node.getValue();
    var con_temp = -0.077 * x * x + 2.7188 * x - 64.36;
    contrail_temp_Node.setValue(con_temp);

    if (y < con_temp and y < -40){
        contrail_Node.setValue(1);
    } else {
        contrail_Node.setValue(0);
    }

    settimer(updateContrail,30)
}

### Contrail

_setlistener("/sim/signals/nasal-dir-initialized", func {
    printlog ("debug", "init contrail");
    props.globals.initNode("environment/pressure-inhg", 1, "DOUBLE");
    props.globals.initNode("environment/temperature-degc", 1, "DOUBLE");
    props.globals.initNode("environment/contrail", 1, "BOOL");
    props.globals.initNode("environment/contrail-temperature-degc", 1, "DOUBLE");
    var static_contrail_node = props.globals.getNode("sim/ai/aircraft/contrail", 1);
    var time_node = props.globals.getNode("sim/time/elapsed-sec", 1);

    updateContrail();
});
