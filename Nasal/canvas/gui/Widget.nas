gui.Widget = {
  #
  new: func(derived)
  {
    var m = canvas.Widget.new({
      parents: [derived, gui.Widget],
      _focused: 0,
      _focus_policy: gui.Widget.NoFocus,
      _hover: 0,
      _enabled: 1,
      _view: nil,
      _pos: [0, 0],
      _size: [32, 32]
    });

    m.setLayoutMinimumSize([16, 16]);
    m.setLayoutSizeHint([32, 32]);
    m.setLayoutMaximumSize([m._MAX_SIZE, m._MAX_SIZE]);

    m.setSetGeometryFunc(m._impl.setGeometry);

    return m;
  },
  setFixedSize: func(x, y)
  {
    me.setMinimumSize([x, y]);
    me.setSizeHint([x, y]);
    me.setMaximumSize([x, y]);
    return me;
  },
  setEnabled: func(enabled)
  {
    if( me._enabled == enabled )
      return me;

    me._enabled = enabled;
    me.clearFocus();

    me._onStateChange();
    return me;
  },
  # Move the widget to the given position (relative to its parent)
  move: func(x, y)
  {
    me._pos[0] = x;
    me._pos[1] = y;

    if( me._view != nil )
      me._view._root.setTranslation(x, y);
    return me;
  },
  #
  setSize: func(w, h)
  {
    me._size[0] = w;
    me._size[1] = h;

    if( me._view != nil )
      me._view.setSize(me, w, h);
    return me;
  },
  # Set geometry of widget (usually used by layouting system)
  #
  # @param geom [<x>, <y>, <width>, <height>]
  setGeometry: func(geom)
  {
    me.move(geom[0], geom[1]);
    me.setSize(geom[2], geom[3]);
    me._onStateChange();
    return me;
  },
  #
  setFocus: func
  {
    if( me._focused )
      return me;

    var canvas = me.getCanvas();
    if( canvas._impl['_focused_widget'] != nil )
      canvas._focused_widget.clearFocus();

    if( !me._enabled )
      return me;

    me._focused = 1;
    canvas._focused_widget = me;

    if( me._view != nil )
      me._view._root.setFocus();

    me._trigger("focus-in");
    me._onStateChange();

    return me;
  },
  #
  clearFocus: func
  {
    if( !me._focused )
      return me;

    me._focused = 0;
    me.getCanvas()._focused_widget = nil;
    me.getCanvas().clearFocusElement();

    me._trigger("focus-out");
    me._onStateChange();

    return me;
  },
  listen: func(type, cb)
  {
    me._view._root.addEventListener("cb." ~ type, cb);
    return me;
  },
  onRemove: func
  {
    if( me._view != nil )
    {
      me._view._root.del();
      me._view = nil;
    }

    if( me._focused )
      me.getCanvas()._focused_widget = nil;
  },
# protected:
  _MAX_SIZE: 32768, # size for "no size-limit"
  _onStateChange: func
  {
    if( me._view != nil and me._view.update != nil )
      me._view.update(me);
  },
  visibilityChanged: func(visible)
  {
    me._view._root.setVisible(visible);
  },
  _setView: func(view)
  {
    me._view = view;

    var root = view._root;
    var canvas = root.getCanvas();
    me.setCanvas(canvas);

    canvas.addEventListener("wm.focus-in", func {
      me._onStateChange();
    });
    canvas.addEventListener("wm.focus-out", func {
      me._onStateChange();
    });

    root.addEventListener("mouseenter", func {
      me._hover = 1;
      me._trigger("mouse-enter");
      me._onStateChange();
    });
    root.addEventListener("mousedown", func {
      if( me._focus_policy & me.ClickFocus )
        me.setFocus();
    });
    root.addEventListener("mouseleave", func {
      me._hover = 0;
      me._trigger("mouse-leave");
      me._onStateChange();
    });
  },
  _trigger: func(type, data = nil)
  {
    if( me._view != nil )
      me._view._root.dispatchEvent(
        canvas.CustomEvent.new("cb." ~ type, {detail: data})
      );
    return me;
  },
  _windowFocus: func
  {
    var canvas = me.getCanvas();
    return canvas != nil ? canvas.data("focused") : 0;
  }
};

# enum FocusPolicy:
gui.Widget.NoFocus = 0;
gui.Widget.TabFocus = 1;
gui.Widget.ClickFocus = 2;
gui.Widget.StrongFocus = gui.Widget.TabFocus
                       | gui.Widget.ClickFocus;
