gui.widgets.ScrollArea = {
  new: func(parent, style, cfg)
  {
    var cfg = Config.new(cfg);
    var m = gui.Widget.new(gui.widgets.ScrollArea);
    m._focus_policy = m.NoFocus;
    m._content_pos = [0, 0];
    m._scroller_pos = [0, 0];
    m._max_scroll = [0, 0];
    m._layout = nil;

    if( style != nil )
      m._setView( style.createWidget(parent, "scroll-area", cfg) );

    m.setMinimumSize([32, 32]);

    return m;
  },
  setLayout: func(l)
  {
    me._layout = l;
    l.setParent(me);
    return me.update();
  },
  getContent: func()
  {
    return me._view.content;
  },
  # Set the background color for the content area.
  #
  # @param color  Vector of 3 or 4 values in [0, 1]
  setColorBackground: func
  {
    if( size(arg) == 1 )
      var arg = arg[0];
    me._view.setColorBackground(arg);
    return me;
  },
  # Reset the size of the content area, e.g. on window resize.
  #
  # @param sz  Vector of [x,y] values.
  setSize: func
  {
    if( size(arg) == 1 )
      var arg = arg[0];
    var (x,y) = arg;
    me._size = [x,y];
    return me.update();
  },
  # Move contents to the coordinates x,y (or as far as possible)
  #
  # @param x The x coordinate (positive is right)
  # @param y The y coordinate (positive is down)
  scrollTo: func(x, y)
  {
    me._content_pos[0] = x;
    me._content_pos[1] = y;

    return me.update();
  },
  # Move the scrollable area to the top-most position
  scrollToTop:    func me.scrollTo( me._content_pos[0], 0 ),
  # Move the scrollable area to the bottom-most position
  scrollToBottom: func me.scrollTo( me._content_pos[0], me._max_scroll[1] ),
  # Move the scrollable area to the left-most position
  scrollToLeft:   func me.scrollTo( 0,                  me._content_pos[1] ),
  # Move the scrollable area to the right-most position
  scrollToRight:  func me.scrollTo( me._max_scroll[0],  me._content_pos[1] ),
  # Move content by given delta
  scrollBy: func(x, y)
  {
    return me.scrollTo( me._content_pos[0] + x,
                        me._content_pos[1] + y );
  },
  # Set horizontal scrollbar position
  horizScrollBarTo: func(x)
  {
    if( me._scroller_delta[0] < 1 )
      return me;

    me.scrollTo( me._max_scroll[0] * (x / me._scroller_delta[0]),
                 me._content_pos[1] );
  },
  # Set vertical scrollbar position
  vertScrollBarTo: func(y)
  {
    if( me._scroller_delta[1] < 1 )
      return me;

    me.scrollTo( me._content_pos[0],
                 me._max_scroll[1] * (y / me._scroller_delta[1]) );
  },
  # Move horizontal scrollbar by given offset
  horizScrollBarBy: func(dx)
  {
    me.horizScrollBarTo(me._scroller_pos[0] + dx);
  },
  # Move vertical scrollbar by given offset
  vertScrollBarBy: func(dy)
  {
    me.vertScrollBarTo(me._scroller_pos[1] + dy);
  },
  # Update scroll bar and content area.
  #
  # Needs to be called when the size of the content changes.
  update: func(bb=nil)
  {
    if (bb == nil) bb = me._updateBB();
    if (bb == nil) return me;

    var offset = [ me._content_offset[0] - me._content_pos[0],
                   me._content_offset[1] - me._content_pos[1] ];
    me.getContent().setTranslation(offset);

    me._view.update(me);
    me.getContent().update();

    return me;
  },
# protected:
  _setView: func(view)
  {
    call(gui.Widget._setView, [view], me);

    view.vert.addEventListener("mousedown", func(e) me._dragStart(e));
    view.horiz.addEventListener("mousedown", func(e) me._dragStart(e));
    view._root.addEventListener("mousedown", func(e)
    {
      me._drag_offsetX = me._content_pos[0] + e.clientX;
      me._drag_offsetY = me._content_pos[1] + e.clientY;
    });

    view.vert.addEventListener
    (
      "drag",
      func(e)
      {
        if( !me._enabled )
          return;

        me.vertScrollBarTo(me._drag_offsetY + e.clientY);
        e.stopPropagation();
      }
    );
    view.horiz.addEventListener
    (
      "drag",
      func(e)
      {
        if( !me._enabled )
          return;

        me.horizScrollBarTo(me._drag_offsetX + e.clientX);
        e.stopPropagation();
      }
    );

    view._root.addEventListener
    (
      "drag",
      func(e)
      {
        if( !me._enabled )
          return;

        me.scrollTo( me._drag_offsetX - e.clientX,
                     me._drag_offsetY - e.clientY );
        e.stopPropagation();
      }
    );
    view._root.addEventListener
    (
      "wheel",
      func(e)
      {
        if( !me._enabled )
          return;

        me.scrollBy(0, 30 * -e.deltaY); # TODO make step size configurable
        e.stopPropagation();
      }
    );
  },
  _dragStart: func(e)
  {
    me._drag_offsetX = me._scroller_pos[0] - e.clientX;
    me._drag_offsetY = me._scroller_pos[1] - e.clientY;
    e.stopPropagation();
  },
  _updateBB: func()
  {
    # TODO only update on content resize
    if( me._layout == nil )
    {
      var bb = me.getContent().getTightBoundingBox();

      if( bb[2] < bb[0] or bb[3] < bb[1] )
        return nil;
      var w = bb[2] - bb[0];
      var h = bb[3] - bb[1];

      var cur_offset = me.getContent().getTranslation();
      me._content_offset = [cur_offset[0] - bb[0], cur_offset[1] - bb[1]];
    }
    else
    {
      var min_size = me._layout.minimumSize();
      var max_size = me._layout.maximumSize();
      var size_hint = me._layout.sizeHint();
      var w = math.min(max_size[0], math.max(size_hint[0], me._size[0]));
      var h = math.max(
              math.min(max_size[1], math.max(size_hint[1], me._size[1])),
              me._layout.heightForWidth(w)
            );

      me._layout.setGeometry([0, 0, w, h]);

      # Layout always has the origin at (0, 0)
      me._content_offset = [0, 0];
    }

    me._max_scroll[0] = math.max(0, w - me._size[0]);
    me._max_scroll[1] = math.max(0, h - me._size[1]);
    me._content_size = [w, h];

    # keep position within limit and only integer (to prevent artifacts on text,
    # lines, etc. not alligned with pixel grid)
    me._content_pos[0] =
      math.max(0, math.min( math.round(me._content_pos[0]), me._max_scroll[0]));
    me._content_pos[1] =
      math.max(0, math.min( math.round(me._content_pos[1]), me._max_scroll[1]));

    me._scroller_size = [0, 0];   # scroller size
    me._scroller_offset = [0, 0]; # scroller minimum pos (eg. add offset for
                                  # scrolling with buttons)
    me._scroller_delta = [0, 0];  # scroller max travel distance

    # update scroller size/offset/max delta
    me._view._updateScrollMetrics(me, 0);
    me._view._updateScrollMetrics(me, 1);

    # update current scrollbar positions
    me._scroller_pos[0] =
        me._max_scroll[0] > 0
      ? (me._content_pos[0] / me._max_scroll[0]) * me._scroller_delta[0]
      : 0;
    me._scroller_pos[1] =
        me._max_scroll[1] > 0
      ? (me._content_pos[1] / me._max_scroll[1]) * me._scroller_delta[1]
      : 0;
  }
};
