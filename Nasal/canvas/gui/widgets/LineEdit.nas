gui.widgets.LineEdit = {
  new: func(parent, style, cfg)
  {
    var m = gui.Widget.new(gui.widgets.LineEdit);
    m._cfg = Config.new(cfg);
    m._focus_policy = m.StrongFocus;
    m._setView( style.createWidget(parent, "line-edit", m._cfg) );
    
    m.setLayoutMinimumSize([28, 16]);
    m.setLayoutSizeHint([150, 28]);

    m._text = "";
    m._max_length = 32767;
    m._cursor = 0;
    m._selection_start = 0;
    m._selection_end = 0;

    return m;
  },
  setText: func(text)
  {
    me._text = utf8.substr(text, 0, me._max_length);
    me._cursor = utf8.size(me._text);
    me._selection_start = me._cursor;
    me._selection_end = me._cursor;

    if( me._view != nil )
      me._view.setText(me, me._text);

    return me;
  },
  text: func()
  {
    return me._text;
  },
  setMaxLength: func(len)
  {
    me._max_length = len;

    if( utf8.size(me._text) <= len )
      return me;

    me._text = utf8.substr(me._text, 0, me._max_length);
    me.moveCursor(me._cursor);
    return me;
  },
  moveCursor: func(pos, mark = 0)
  {
    var len = utf8.size(me._text);
    me._cursor = math.max(0, math.min(pos, len));

    me._selection_start = me._cursor;
    me._selection_end = me._cursor;

    me._onStateChange();
    return me;
  },
  home: func()
  {
    me.moveCursor(0);
  },
  end: func()
  {
    me.moveCursor(utf8.size(me._text));
  },
  # Insert given text after cursor (and first remove selection if set)
  insert: func(text)
  {
    var after = utf8.substr(me._text, me._selection_end);
    me._text = utf8.substr(me._text, 0, me._selection_start);

    # Replace selected text, insert new text and place cursor after inserted
    # text
    var remaining = me._max_length - me._selection_start - utf8.size(after);
    if( remaining != 0 )
      me._text ~= utf8.substr(text, 0, remaining);

    me._cursor = utf8.size(me._text);
    me._selection_start = me._cursor;
    me._selection_end = me._cursor;

    me._text ~= after;

    if( me._view != nil )
      me._view.setText(me, me._text);

    return me;
  },
  paste: func(mode = nil)
  {
    me.insert(clipboard.getText(mode != nil ? mode : clipboard.CLIPBOARD));
  },
  # Remove selected text
  removeSelection: func()
  {
    if( me._selection_start == me._selection_end )
      return me;

    me._text = utf8.substr(me._text, 0, me._selection_start)
             ~ utf8.substr(me._text, me._selection_end);

    me._cursor = me._selection_start;
    me._selection_end = me._selection_start;

    if( me._view != nil )
      me._view.setText(me, me._text);

    return me;
  },
  # Remove selection or if nothing is selected the character before the cursor
  backspace: func()
  {
    if( me._selection_start == me._selection_end )
    {
      if( me._selection_start == 0 )
        # Before first character...
        return me;

      me._selection_start -= 1;
    }

    me.removeSelection();
    return me;
  },
  # Remove selection or if nothing is selected the character after the cursor
  del: func()
  {
    if( me._selection_start == me._selection_end )
    {
      if( me._selection_end == utf8.size(me._text) )
        # After last character...
        return me;

      me._selection_end += 1;
    }

    me.removeSelection();
    return me;
  },
# protected:
  _setView: func(view)
  {
    call(gui.Widget._setView, [view], me);

    var el = view._root;
    el.addEventListener("keypress", func (e) me.insert(e.key));
    el.addEventListener("keydown", func (e)
    {
      if( me._view == nil )
        return;

      if( e.key == "Backspace" )
        me.backspace();
      else if( e.key == "Delete" )
        me.del();
      else if( e.key == "Left" )
        me.moveCursor(me._cursor - 1);
      else if( e.key == "Right")
        me.moveCursor(me._cursor + 1);
      else if( e.key == "Home" )
        me.home();
      else if( e.key == "End" )
        me.end();
      else if( e.keyCode == `v` and e.ctrlKey )
        me.paste();
    });
  }
};
