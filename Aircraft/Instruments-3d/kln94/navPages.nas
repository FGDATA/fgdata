

var Nav1Page = 
{
    a:2,
  
  
    new: func()
    {
      m = {parents: [Nav1Page, KLN94.Page.new(KLN94.PAGE_NAV, 0)]};
      return m;
    },
    
    hasActiveIdent: func { 1 },
    showsCDI: func { 1 },
    
    display: func(gps)
    {
      if (gps.isDirectToActive()) {
        
      } else {
        # leg mode
        gps.setLine(0, sprintf('%6s->%6s', 
          gps.props.previousIdent.getStringValue(), 
          gps.props.activeIdent.getStringValue())
        );
      }
      
      
      gps.setLine(3, '   VNV  Off');
      
      var toFrom = gps.isTo() ? 'To' : 'Fr';
      var eteToWp1 = gps.formatDuration(gps.props.timeToWaypoint.getIntValue());
      gps.setLine(4, sprintf('%03d*%s   ', bearingToWp1, toFrom) ~ eteToWp1);
    },
    
    refresh: func(gps)
    {
    
    }
};

var Nav2Page = 
{
    new: func()
    {
      m = {parents: [Nav2Page, KLN94.Page.new(KLN94.PAGE_NAV, 1)]};
      return m;
    },
    
    display: func(gps)
    {
      # select refnavaid!
      
      gps.setLine(0, ' PRESENT POSN'),
      gps.setLine(1, '    Ref:%s', gps.refNavaid.id);
      
      gps.setLine(3, '  ' + gps.formatLatitude(gps.props.indicatedLat.getDoubleValue()));
      gps.setLine(4, '  ' + gps.formatLongitude(gps.props.indicatedLon.getDoubleValue()));
    }
};

var Nav3Page = 
{
    new: func()
    {
      m = {parents: [Nav3Page, KLN94.Page.new(KLN94.PAGE_NAV, 2)]};
      return m;
    },
};

var nav1 = Nav1Page.new();
gps.addPage(nav1);


gps.addPage(Nav2Page.new());
gps.addPage(Nav3Page.new());



