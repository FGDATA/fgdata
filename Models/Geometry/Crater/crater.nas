#####################################################################################
#  This script activates and controls the crater model and effects                  #
#                                                                                   #
#  Author Vivian Meazza   May 2011                                                  #
#####################################################################################


var crater_init = func() {

# =============================== Listeners ===============================
#

    setlistener("/sim/armament/weapons/bomb", func(n) {
        var node = props.globals.getNode(n.getValue(), 1);
        var solid = node.getNode("material/solid").getValue();
        var mat_name = node.getNode("material/name").getValue();
        var name = node.getNode("name").getValue();

        print ("mat_name ", mat_name, " ", solid);

        var impact = geo.Coord.new().set_latlon(
            node.getNode("impact/latitude-deg").getValue(),
            node.getNode("impact/longitude-deg").getValue(),
            node.getNode("impact/elevation-m").getValue());

        if (solid){
            var time = props.globals.getNode("sim/time/elapsed-sec", 1).getValue();
            var duration = 300;

            var explosion = geo.put_model("Models/Geometry/Crater/explosion.xml", impact,
                node.getNode("impact/heading-deg").getValue(),
                0,
                0);

            explosion.getNode("start-time",1).setDoubleValue(time);
            explosion.getNode("duration-sec",1).setDoubleValue(duration);
            settimer(func {explosion.remove()}, 5);

            settimer(func {
                var model = geo.put_model("Models/Geometry/Crater/crater.xml", impact,
                    node.getNode("impact/heading-deg").getValue(),
                    0,
                    0);

                var smoke = geo.put_model("Models/Geometry/Crater/crater-smoke.xml", impact,
                    node.getNode("impact/heading-deg").getValue(),
                    0,
                    0);

                smoke.getNode("start-time",1).setDoubleValue(time);
                smoke.getNode("duration-sec",1).setDoubleValue(duration);
                settimer(func {smoke.remove()}, duration);
            }, 2);

            var distance = geo.aircraft_position().distance_to(impact) / 1000;
            screen.log.write(sprintf("bomb impact: %.3f km", distance, 1, 0.9, 0.9));

            vol = 0.3/math.sqrt(distance) ;

            fgcommand("play-audio-sample", props.Node.new(
            {
path : getprop("/sim/fg-root") ~ "/Models/Geometry/Crater",
file : "explosion.wav",
volume : vol,}
                )); # end fgcommand

        } else {

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

        }# endif 


    }); # end func

} # end listener

# Fire it up

setlistener("sim/signals/fdm-initialized", crater_init);

# end 
