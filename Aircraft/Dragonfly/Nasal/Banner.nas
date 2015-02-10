##############################################################################
var AircraftBanner = {};
AircraftBanner.new = func {
  var obj = {};
  obj.parents = [AircraftBanner];
  obj.onHookNode = props.globals.getNode( "sim/model/banner-on-hook", 1 );
  obj.speedbrakeNode = props.globals.getNode( "controls/flight/speedbrake" );

  obj.releaseNode = props.globals.getNode( "controls/banner-release", 1 );

  obj.timer();
  return obj;
}

AircraftBanner.timer = func {
  if( me.releaseNode.getValue() != 0 and me.onHookNode.getValue() == 1 ) {
    print( "banner-release" );
    me.onHookNode.setBoolValue( 0 );
    me.releaseNode.setBoolValue( 0 );
    me.speedbrakeNode.setBoolValue( 0 );
  }
  settimer( func { me.timer() }, 0.5 );
}

AircraftBanner.hook = func {
  print( "banner-pickup" );
  me.onHookNode.setBoolValue( 1 );
  me.speedbrakeNode.setBoolValue( 1 );
}

##############################################################################
var GroundBanner = {};
GroundBanner.new = func {
  var obj = {};
  obj.parents = [GroundBanner];
  obj.modelNode = arg[0];
  obj.hooked = 0;
  print( "GroundBanner created" );
  return obj;
}

GroundBanner.hook = func {
  me.hooked = 1; 
}


##############################################################################
var BannerMgr = {};
BannerMgr.new = func {
  var obj = {};
  obj.parents = [BannerMgr];

  obj.aircraftBanner = arg[0];
  obj.banners = [];

  obj.hookDistance = 1e-9;

  obj.lonNode = props.globals.getNode("/position/longitude-deg", 1);
  obj.latNode = props.globals.getNode("/position/latitude-deg", 1);
  obj.altNode = props.globals.getNode( "/position/altitude-agl-ft", 1 );

  obj.timer();
  return obj;
}

BannerMgr.addBanner = func {
  var elev_m = geo.elevation(arg[1], arg[2]);
  if( elev_m == nil ) {
    print("can't get elevation for " ~ arg[1] ~ "/" ~ arg[2] ~ " - groundbanner ignored" );
    return;
  }
  var banner = GroundBanner.new( geo._put_model( arg[0], arg[1], arg[2], nil, arg[3] ) );
  append( me.banners, banner );
}

# periodically check the position of the aircraft relative to the configured groundbanners
#
BannerMgr.timer = func {

  var lon = me.lonNode.getValue();
  var lat = me.latNode.getValue();
  var alt = me.altNode.getValue();

  var minDist = 999;

  if( aircraftBanner.onHookNode.getValue() == 0 and alt < 15 ) {
    foreach( var banner; me.banners ) {
      if( banner.hooked == 0 ) {
        var dlat = banner.modelNode.getNode( "latitude-deg" ).getValue() - lat;
        var dlon = banner.modelNode.getNode( "longitude-deg" ).getValue() - lon;
        var dist = dlat * dlat + dlon*dlon;
        if( dist < minDist ) {
          minDist = dist;
        }
  
        if( dist <= me.hookDistance ) {
          banner.hook();
          aircraftBanner.hook();
        }
      }
    }
  }

  # shorten interval when closing in
  var interval = 2.0;

  if( minDist < 1e-6 ) {
    interval = 1.0;
  }
  if( minDist < 1e-7 ) {
    interval = .5;
  }
  if( minDist < 1e-8 ) {
    interval = .1;
  }
  settimer( func { me.timer() } , interval );
}

##############################################################################
var bannerMgr = nil;
var aircraftBanner = nil;

var init_banner = func {
  aircraftBanner = AircraftBanner.new();
  bannerMgr = BannerMgr.new( aircraftBanner );
  fgcommand("loadxml", props.Node.new({
    "filename": getprop("/sim/fg-home") ~ "/" ~ "groundbanner.xml",
    "targetnode": "/sim/groundbanners/",
  }));
  
  foreach( var bannerN; props.globals.getNode( "/sim/groundbanners", 1 ).getChildren( "groundbanner" ) ) {
    bannerMgr.addBanner( 
      bannerN.getNode( "path" ).getValue(),
      bannerN.getNode( "lat" ).getValue(),
      bannerN.getNode( "lon" ).getValue(),
      bannerN.getNode( "heading" ).getValue()
    );
  }
  
}

setlistener("/sim/signals/fdm-initialized", init_banner );
##############################################################################
