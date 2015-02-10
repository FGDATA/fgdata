#####################################################################################
#  This script activates and controls the RP3-25 lb model and effects                  #
#                                                                                   #
#  Author Vivian Meazza   May 2011                                                  #
#####################################################################################


var init = func() {

# =============================== Listeners ===============================
#

    setlistener("sim/ai/aircraft/impact/RP3-25", func(n) {
        var node = props.globals.getNode(n.getValue(), 1);
        var solid = node.getNode("material/solid").getValue();
        var mat_name = node.getNode("material/name").getValue();
        var name = node.getNode("name").getValue();

        print (name, " mat_name ", mat_name);

        var impact = geo.Coord.new().set_latlon(
            node.getNode("impact/latitude-deg").getValue(),
            node.getNode("impact/longitude-deg").getValue(),
            node.getNode("impact/elevation-m").getValue());

        if (!solid){
            var spray = geo.put_model("Models/Geometry/Crater/spray-effect.xml", impact,
                node.getNode("impact/heading-deg").getValue(),
                0,
                0);

            settimer(func {spray.remove()}, 3);

            settimer(func {

                var splash = geo.put_model("Models/Geometry/Crater/splash-effect.xml",
                    node.getNode("impact/latitude-deg").getValue(),
                    node.getNode("impact/longitude-deg").getValue(),
                    node.getNode("impact/elevation-m").getValue()+ 0.25,
                    node.getNode("impact/heading-deg").getValue(),
                    0,
                    0);

                settimer(func {splash.remove()}, 8);
            }, 2);

        } else {

            geo.put_model("Models/Geometry/RP-3/RP3-25-HOT.xml",impact,
                node.getNode("impact/heading-deg").getValue(),
                node.getNode("impact/pitch-deg").getValue(),
                node.getNode("impact/roll-deg").getValue());

        }

        screen.log.write(sprintf("%.3f km",
            geo.aircraft_position().distance_to(impact) / 1000), 1, 0.9, 0.9);

}); # end listener

}

# Fire it up

setlistener("sim/signals/fdm-initialized", init);

# end 
