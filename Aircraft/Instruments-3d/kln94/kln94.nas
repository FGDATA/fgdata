var kln94 = nil;

var KLN94 = {

  Page: {
    new : func(owner, s, idx)
    {
        m = { 
            parents:[KLN94.Page],
            section: s,
            index: idx
        };
        return m;
    },
    
    # encode various behavioural flags as predicates
    # real Pages can over-ride these defaults as needed
    hasActiveIdent: func { return 0; },    
    numberOfCyanLines: func { return 0; },
    showsCDI: func { return 0; },
    isMulti: func { return 0; },
    
    # cursor stuff
    
    display: func(gps)
    {
    
    },
    
    refresh: func(gps)
    {
    
    },
  
  },

  pageNames : ['APT', 'VOR', 'NDB', 'INT', 'USR', 'ACT', 'NAV', 'FPL', 'SET', 'AUX'],
  
  PAGE_APT: 0,
  PAGE_VOR: 1,
  PAGE_NDB: 2,
  PAGE_INT: 3,
  PAGE_USR: 4,
  PAGE_ACT: 5,
  PAGE_NAV: 6,
  PAGE_FPL: 7,
  PAGE_SET: 8,
  PAGE_AUX: 9,
  
  
  PAGE_BAR_HEIGHT: 20,
  NAV_DATA_WIDTH: 128,
  
  canvas_settings: {
      "name": "KLN94",
      "size": [512, 256],
      "view": [480, 160],
      "mipmapping": 1,
  },
  
  new : func(prop1, placement)
  {
      m = { parents : [KLN94]};

      m.rootNode = props.globals.initNode(prop1);   
      m._setupCanvas(placement);
      m._page = nil;
      
      m._messageScreenActive = 0;
      m._messages = [];
      
      m._cursorActive = 0;
      m._cursorField = 0;
      m._enterAction = nil;
      
      
      m._setupProps();
      
      return m;
  },
  
  _setupCanvas: func(placement)
  {
      me._canvas = canvas.new(KLN94.canvas_settings);        
      var text_style = {
          'font': "LiberationFonts/LiberationMono-Bold.ttf",
          'character-size': 34,
          'character-aspect-ratio': 1.2
      };
      
      me.rootNode.initNode('brightness-norm', 0.5, 'DOUBLE');
      
      me._canvas.setColorBackground(1.0, 0.0, 0.0);
      me._canvas.addPlacement(placement);
      
      me._navDataArea = me._canvas.createGroup();
      me._navDataArea.setTranslation(0, 0);
      me._navDataLines = [];
      
      var navAreaH = (KLN94.canvas_settings.view[1] - KLN94.PAGE_BAR_HEIGHT) / 2;
      var r1 = me._navDataArea.rect(0, 0, KLN94.NAV_DATA_WIDTH, navAreaH);
      var r2 = me._navDataArea.rect(0, navAreaH, KLN94.NAV_DATA_WIDTH, navAreaH);
      r1.setColor(0,1,1); # cyan
      r2.setColor(0,1,1);
      
      var lineH = (KLN94.canvas_settings.view[1] - KLN94.PAGE_BAR_HEIGHT) / 5;
      
      for (var i=0; i<4; i +=1) {
        var t = me._navDataArea.createChild("text");
        t.setColor(1, 1, 1);
        t._node.setValues(text_style);
        t.setAlignment("left-center");
        t.setTranslation(0.0, (i + 0.5) * lineH);        
        append(me._navDataLines, t);
      }
      
      me._pageBarArea = me._canvas.createGroup();
      me._pageBarArea.setTranslation(0, KLN94.canvas_settings.view[1] - KLN94.PAGE_BAR_HEIGHT);
      
      var ln = me._pageBarArea.createChild('path');
      ln.setColor(0,1,1); # cyan
      
      me._pageBarText = me._pageBarArea.createChild("text");
      me._pageBarText._node.setValues(text_style);
      me._pageBarText.setAlignment("left-center");
      me._pageBarText.setColor(0, 0, 1);
      
      me._pageBarInverseText = me._pageBarArea.createChild("text");
      me._pageBarInverseText._node.setValues(text_style);
      me._pageBarInverseText.setAlignment("left-center");
      me._pageBarInverseText.setColor(1, 1, 1);
      me._pageBarInverseText.setColorFill(0, 0, 1);
      
      me._pageArea = me._canvas.createGroup();
      me._pageBarArea.setTranslation(100, 0);
      
      me._pageAreaLines = [];
      for (var i=0; i<5; i +=1) {
        var t = me._pageArea.createChild("text");
        t.setColor(0, 1, 0);
        t._node.setValues(text_style);
        t.setAlignment("left-center");
        t.setTranslation(0.0, (i + 0.5) * lineH);        
        append(me._pageAreaLines, t);
      }
      
      # inverted text block
      me._pageAreaInverted = me._pageArea.createChild("text");
      me._pageAreaInverted.setColor(0, 0, 0);
      me._pageAreaInverted.setColorFill(0, 1, 0);
      me._pageAreaInverted._node.setValues(text_style);
      me._pageAreaInverted.setAlignment("left-center");
      
      me._cdiGroup = me._pageArea.createChild("group");
      canvas.parsesvg(me._cdiGroup, resolvepath('Aircraft/Instruments-3d/kln94/cdi.svg'));
      me._cdiGroup.setTranslation(0, lineH);
  },
  
  _setupProps: func
  {
    var p = me.rootNode;
    me.props = {
      distanceToActiveNm: p.getNode(),
      groundspeedKt: p.getNode(),
      activeIdent: p.getNode(),
      previousIdent: p.getNode(),
      obsBearing: p.getNode(),
      legTrack: p.getNode(),
      groundTrack: p.getNode(),
      cdiDeviationNm: p.getNode(),
    };
  },
  
  _setActivePage: func(pg)
  {
    me._page = pg;
    if (pg == nil) return;
    
    # update line colors
    for (var l=0; l<4; l+=1) {
      me._pageAreaLines[l].setColor(0, 1, l < pg.numberOfCyanLines() ? 1 : 0);
    }
    
    # hide or show the CDI area as appropriate
    me._cdiGroup.setVisible(pg.showsCDI());
  },
  
  _updateNavData : func
  {
    me._navDataLines[0].setText(sprintf('%4dnm', me._props.distanceToActiveNm.getValue()));
    if (me._page.hasActiveIdent()) {
      me._navDataLines[1].setText(sprintf('%4dkt', me._props.groundspeedKt.getValue()));
    } else {
      me._navDataLines[1].setText(me._props.activeIdent.getValue());
    }
    if (me._obsMode) {
      me._navDataLines[2].setText(sprintf('OBS%03d*', me._props.obsBearing.getValue()));      
    } else {
      me._navDataLines[2].setText(sprintf('DTK%03d*', me._props.legTrack.getValue()));
    }
    me._navDataLines[3].setText(sprintf(' TK%03d*', me._props.groundTrack.getValue()));
  },
  
  _updateAnnunciationArea : func
  {
    if (size(me._messages) > 0) {
      # show 'M' symbol
    }
    
    if (me._enterAction != nil) {
      # show 'ENT' symbol
    }
  
  },
  
  _updatePageBar : func
  {
    # hide in NAV-4 mode
    if (me.inNav4Mode()) {
      me._pageBarGroup.setVisible(0);
      return;
    }
    
    if (me._cursorActive) {
      me._pageBarText.setText('');
      var t = '    * CRSR *  ' ~ me.pageNames[activePage] ~ ' * CRSR *';
      me._pageBarInverseText.setText(t);
      return;
    }
    
    # assemble the string
    var barString = '';
    var inverseBarString = '';
    var activePage = me.pageIndex[0];
    
    for (var i=0; i < 10; i += 1) {
      if (activePage == i) {
        var sep = me.isMultiPage() ? '+' : ' ';
        inverseBarString ~= me.pageNames[i] ~ sep ~ me.pageIndex[1];
        barString ~= '     '; # 5 spaces
      } else {
        barString ~= ' ' ~ me.pageNames[i];
        if (i < activePage)
          inverseBarString ~= '    '; # 4 spaces
      }
    }
    
    me._pageBarText.setText(barString);
    me._pageBarInverseText.setText(inverseBarString);
  },
  
  _setInverted: func(line, firstcol, numcols=1)
  {
    var t = me._pageAreaInverted;
    var cellW = 20.0;
    var lineH = (KLN94.canvas_settings.view[1] - KLN94.PAGE_BAR_HEIGHT) / 5;
    t.setTranslation(firstcol * cellW, (line + 0.5) * lineH);        
    t.setText(substr(me._pageAreaLines[line].getText(), firstcol, numcols));
    t.setVisible(1);
  },
  
  _setBlink: func(line, firstcol, numcols=1)
  {
    
  },
  
  isPageActive: func(nm, idx) 
  {
    if (me._page == nil) return 0;
    return (me._page.section == nm) and (me._page.index == idx);
  },
  
  isMultiPage: func { return me._page.isMulti(); },
  
  toggleCursor: func
  {
    me._cursorActive = !me._cursorActive;
    if (me._cursorActive) {
      me._cursorField = 0;
    }
    
    me._updatePageBar();
  },
  
  messageButton: func
  {
    if (me._messageScreenActive) {
      me._messages = me._messages[1:]; # pop front
      if (size(me._messages) == 0) {
        me._messageScreenActive = 0;
        # refresh normal screen
        return;
      }
      
      me._buildMessageScreen();
      return;
    }
    
    if (size(me._messages) == 0) {
      debug.dump('no messages to show');
      return;
    }
    
    me._messageScreenActive = 1;
    me._buildMessageScreen();
  },
  
  _buildMessageScreen: func
  {
    
  },
  
  # Nav4 mode is special
  inNav4Mode: func { return me.isPageActive(NAV, 4); },
  
  formatDuration: func(timeInSeconds)
  {
    if (timeInSeconds > 60) {
      return sprintf("0:%02d", timeInSeconds);
    }
    
    if (timeInSeconds > 3600) {
      var mins = int(timeInSeconds / 60);
      var secs = timeInSeconds - (mins * 60);
      return sprintf("%d:%02d", mins, secs);
    }
    
    var hours = int(timeInSeconds / 3600);
    timeInSeconds -= (hours * 3600);
    var mins = int(timeInSeconds / 60);
    var secs = timeInSeconds - (mins * 60);
    return sprintf("%d:%02d:%02d", hours, mins, secs); 
  },
  
  formatLatitude: func(lat)
  {
      var north = (lat >= 0.0);
      var latDeg = int(lat);
      var latMinutes = math.abs(lat - latDeg) * 60;
      return sprintf('%s%02d*%04.1f', north ? "N" : "S", abs(latDeg), latMinutes);
  },
  
  formatLongitude: func(lon)
  {
       var east = (lon >= 0.0);
       var lonDeg = int(lon);
       var lonMinutes = math.abs(lon - lonDeg) * 60;
       sprintf("%s%03d*%04.1f", east ? 'E' : 'W', abs(lonDeg), lonMinutes);        
  },
};


reload_gps = func 
{    
    kln94._setActivePage(nil); # force existing page to be undisplayed cleanly
  
    # make the cdu instance available inside the module namespace
    # we are going to load into.
    # for a reload this also wipes the existing namespace, which we want
    globals['kln94_NS'] = { gps: kln94, KLN94:KLN94 };

    var pages = ['navPages.nas', 'infoPages.nas', 'flightplanPages.nas', 'settingPages.nas', 'auxPages.nas'];

    #var settings = props.globals.getNode('/instrumentation/cdu/settings');
    foreach (var path; pages) {        
        # resolve the path in FG_ROOT, and --fg-aircraft dir, etc
        var abspath = resolvepath('Aircraft/Instruments-3d/kln94/' ~ path);
        if (io.stat(abspath) == nil) {
            debug.dump('KN94 page not found:', path, abspath);
            continue;
        }

        # load pages code into a seperate namespace which we defined above
        # also means we can clean out that namespace later
        io.load_nasal(abspath, 'kln94_NS');
    }
 #   cdu.displayPageByTag(getprop('/instrumentation/cdu/settings/boot-page'));
};

setlistener("/nasal/canvas/loaded", func 
{
    # create base PGS
    kln94 = KLN94.new('/instrumentation/gps', {"node": "screen"});
    reload_gps();
}, 1);
