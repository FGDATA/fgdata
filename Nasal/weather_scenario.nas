#
# find a weather scenario by it's <name> element
# returns /environment/weather-scenarios/scenario[name=$name]
#
find_weather_scenario = func(name) {
	var wsn = props.globals.getNode( "/environment/weather-scenarios" );
	if( wsn == nil ) return nil;
	var scenarios = 
	foreach (var scenario; wsn.getChildren("scenario") )
		if( scenario.getNode("name").getValue() == name )
			return scenario;
	return nil;
}

var initialize_weather_scenario = func {
  getprop( "/environment/params/metar-updates-environment" ) == 0 and return;
  getprop( "/environment/realwx/enabled" ) and return;
  getprop( "/environment/metar/data" ) != "" and return;

  # preset configured scenario
  var scn = getprop("/environment/weather-scenario", "");
  var wsn = props.globals.getNode( "/environment/weather-scenarios" );
  if( wsn != nil ) {
    var scenarios = wsn.getChildren("scenario");
    forindex (var i; scenarios ) {
      if( scenarios[i].getNode("name").getValue() == scn ) {
        setprop("/environment/metar/data", scenarios[i].getNode("metar").getValue() );
        break;
      }
    }
  }
};

_setlistener("/sim/signals/nasal-dir-initialized", func {

	initialize_weather_scenario();

	setlistener("/environment/weather-scenario", func(n) {
		var scenario = find_weather_scenario( n.getValue() );
		if( scenario == nil ) return;
		var scenarioName = scenario.getNode("name",1).getValue();
		if( scenarioName == "Disabled" ) {
			setprop( "/environment/params/metar-updates-environment", 0 );
			setprop( "/environment/realwx/enabled", 0 );
			setprop( "/environment/config/enabled", 0 );
		} else if( scenarioName == "Live data" ) {
			setprop( "/environment/params/metar-updates-environment", 1 );
			setprop( "/environment/realwx/enabled", 1 );
			setprop( "/environment/config/enabled", 1 );
		} else if( scenarioName == "Manual input" ) {
			setprop( "/environment/params/metar-updates-environment", 1 );
			setprop( "/environment/realwx/enabled", 0 );
			setprop( "/environment/config/enabled", 1 );
		} else {
			setprop( "/environment/params/metar-updates-environment", 1 );
			setprop( "/environment/realwx/enabled", 0 );
			setprop( "/environment/config/enabled", 1 );
			var metar = scenario.getNode("metar",1).getValue();
			setprop( "environment/metar/data", metar );
		}
	});
});

