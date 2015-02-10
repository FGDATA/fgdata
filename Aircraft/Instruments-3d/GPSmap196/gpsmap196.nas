

var GPSmap196 = {

  id:0,

  ############
  new: func(placement='gps196.screen') {
    print("Load Garmin GPSmap196 canvas");
    m             = { parents : [GPSmap196] };
    m.buttons     = {};
    m.pages       = {panel:nil, map:nil, route:nil, position:nil};
    m.gmt         = props.globals.getNode("sim/time/gmt");
    m.node        = props.globals.initNode("/instrumentation/gps196",GPSmap196.id+=1);

    m.selectedPage = m.node.initNode("selected-page", 0, "INT");

    var buttons = [ 'rocker-up', 'button-in', 'button-dto', 'button-out',
                    'button-menu', 'button-nrst', 'button-page', 'button-quit',
                    'button-down', 'rocker-left', 'button-power', 'rocker-right',
                    'button-enter' ];

    # to access, use: m.buttons['rocker-up']
    foreach(var btn; buttons)
       m.buttons[btn]    = m.node.initNode("inputs/"~btn, 0, "BOOL");

    m.gpsmap196Screen = canvas.new({
      "name": "GPSmap196-screen",
      "size": [512, 512],
      "view": [320, 240],
      "mipmapping": 1
    });

    m.gpsmap196Screen.addPlacement({"node": placement});
    m.root = m.gpsmap196Screen.createGroup();

    m.timers = [];
    m.initMap();
    m.initPanel();
if(0){
    m.initRoute();
    m.initPosition();
}
    append( m.timers, var update_timer=maketimer(0.1, func m.update()) );
    update_timer.start();

    return m;
  },

  ############
  del: func {
    foreach(var t; me.timers) {
      t.stop();
      t=nil;
    }
    print("GPSmap196: cleanup finished");
  },

  ############
  initRoute: func() {
    canvas.parsesvg(var data = me.root.createChild("group", "page-route"), 'Aircraft/Instruments-3d/GPSmap196/pages/page-route.svg');
    me.pages.route = data;
    data.hide();
  },

  ############
  initPosition: func() {
    canvas.parsesvg(var data = me.root.createChild("group", "page-position"), 'Aircraft/Instruments-3d/GPSmap196/pages/page-position.svg');
    me.pages.position = data;
    data.hide();
  },

  ############
  initPanel: func() {
    canvas.parsesvg(var data = me.root.createChild("group", "page-panel"), 'Aircraft/Instruments-3d/GPSmap196/pages/page-panel.svg');
    me.pages.panel = data;
    data.hide();
  },

  ############
  initMap:func() {
    me.pages.map = me.root.createChild("map").hide();
    me.pages.map.setController("Aircraft position");
    me.pages.map.setRange(10);

    me.pages.map.setTranslation(
                            me.gpsmap196Screen.get("view[0]")/2,
                            me.gpsmap196Screen.get("view[1]")/2
                         );
    var style = {scale_factor:0.3, line_width:2, animation_test:0, color_default:[1,0,0], color_tuned:[0,1,1]};
    var r = func(name,vis=1,zindex=nil) return caller(0)[0];
    foreach(var type; [r('DME',0),r('APT'),  ] )
      me.pages.map.addLayer(factory: canvas.SymbolLayer, type_arg: type.name, visible: type.vis, priority: type.zindex,style:style);

    canvas.parsesvg( var symbol=me.pages.map.createChild("group","airplane-symbol"), 'Nasal/canvas/map/boeingAirplane.svg');
    symbol.setScale( 0.25 );
  },

  ############
  update: func() {

  if(me.buttons['button-page'].getBoolValue()){
    me.selectedPage.setIntValue( me.selectedPage.getValue() + 1 );
    if(me.selectedPage.getValue() > 3) me.selectedPage.setIntValue(0);
  }

  me.pages.map.hide();
  me.pages.panel.hide();
if(0){
  me.pages.route.hide();
  me.pages.position.hide();
}

  if(me.selectedPage.getValue() == 0)
    me.pages.map.show();
  elsif(me.selectedPage.getValue() == 1)
    me.pages.panel.show();
#  elsif(me.selectedPage.getValue() == 2)
#    me.pages.route.show();
#  elsif(me.selectedPage.getValue() == 3)
#    me.pages.position.show();

  }

};

setlistener("sim/signals/fdm-initialized", func() {
  gpsmap196Canvas = GPSmap196.new();
});

