var DefaultStyle = {
  new: func(name, name_icon_theme)
  {
    return {
      parents: [ gui.Style.new(name, name_icon_theme),
                 DefaultStyle ]
    };
  },
  createWidget: func(parent, type, cfg)
  {
    var factory = me.widgets[type];
    if( factory == nil )
    {
      debug.warn("DefaultStyle: unknown widget type (" ~ type ~ ")");
      return nil;
    }

    var w = {
      parents: [factory],
      _style: me
    };
    call(factory.new, [parent, cfg], w);
    return w;
  },
  widgets: {}
};

# A button
DefaultStyle.widgets.button = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "button");
    me._bg =
      me._root.createChild("path");
    me._border =
      me._root.createChild("image", "button")
              .set("slice", "10 12"); #"7")
    me._label =
      me._root.createChild("text")
              .set("font", "LiberationFonts/LiberationSans-Regular.ttf")
              .set("character-size", 14)
              .set("alignment", "center-baseline");
  },
  setSize: func(model, w, h)
  {
    me._bg.reset()
          .rect(3, 3, w - 6, h - 6, {"border-radius": 5});
    me._border.setSize(w, h);
  },
  setText: func(model, text)
  {
    me._label.set("text", text);

    var min_width = math.max(80, me._label.maxWidth() + 16);
    model.setLayoutMinimumSize([min_width, 16]);
    model.setLayoutSizeHint([min_width, 28]);

    return me;
  },
  update: func(model)
  {
    var backdrop = !model._windowFocus();
    var (w, h) = model._size;
    var file = me._style._dir_widgets ~ "/";

    # TODO unify color names with image names
    var bg_color_name = "button_bg_color";
    if( backdrop )
      bg_color_name = "button_backdrop_bg_color";
    else if( !model._enabled )
      bg_color_name = "button_bg_color_insensitive";
    else if( model._down )
      bg_color_name = "button_bg_color_down";
    else if( model._hover )
      bg_color_name = "button_bg_color_hover";
    me._bg.set("fill", me._style.getColor(bg_color_name));

    if( backdrop )
    {
      file ~= "backdrop-";
      me._label.set("fill", me._style.getColor("backdrop_fg_color"));
    }
    else
      me._label.set("fill", me._style.getColor("fg_color"));
    file ~= "button";

    if( model._down )
    {
      file ~= "-active";
      me._label.setTranslation(w / 2 + 1, h / 2 + 6);
    }
    else
      me._label.setTranslation(w / 2, h / 2 + 5);

    if( model._enabled )
    {
      if( model._focused and !backdrop )
        file ~= "-focused";

      if( model._hover and !model._down )
        file ~= "-hover";
    }
    else
      file ~= "-disabled";

    me._border.set("src", file ~ ".png");
  }
};

# A checkbox
DefaultStyle.widgets.checkbox = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "checkbox");
    me._icon =
      me._root.createChild("image", "checkbox-icon")
              .setSize(18, 18);
    me._label =
      me._root.createChild("text")
              .set("font", "LiberationFonts/LiberationSans-Regular.ttf")
              .set("character-size", 14)
              .set("alignment", "left-center");
  },
  setSize: func(model, w, h)
  {
    me._icon.setTranslation(0, int((h - 18) / 2));
    me._label.setTranslation(24, int(h / 2) + 1);

    return me;
  },
  setText: func(model, text)
  {
    me._label.set("text", text);

    var min_width = me._label.maxWidth() + 24;
    model.setLayoutMinimumSize([min_width, 18]);
    model.setLayoutSizeHint([min_width, 24]);

    return me;
  },
  update: func(model)
  {
    var backdrop = !model._windowFocus();
    var (w, h) = model._size;
    var file = me._style._dir_widgets ~ "/";

    if( backdrop )
    {
      file ~= "backdrop-";
      me._label.set("fill", me._style.getColor("backdrop_fg_color"));
    }
    else
      me._label.set("fill", me._style.getColor("fg_color"));
    file ~= "check";

    if( model._down )
      file ~= "-selected";
    else
      file ~= "-unselected";

    if( model._enabled )
    {
      if( model._hover )
        file ~= "-hover";
    }
    else
      file ~= "-disabled";

    me._icon.set("src", file ~ ".png");
  }
};

# A label
DefaultStyle.widgets.label = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "label");
  },
  setSize: func(model, w, h)
  {
    if( me['_bg'] != nil )
      me._bg.reset().rect(0, 0, w, h);
    if( me['_img'] != nil )
      me._img.set("size[0]", w)
             .set("size[1]", h);
    if( me['_text'] != nil )
    {
      # TODO different alignment
      me._text.setTranslation(2, 2 + h / 2);
      me._text.set(
        "max-width",
        model._cfg.get("wordWrap", 0) ? (w - 4) : 0
      );
    }
    return me;
  },
  setText: func(model, text)
  {
    if( text == nil or size(text) == 0 )
    {
      model.setHeightForWidthFunc(nil);
      return me._deleteElement('text');
    }

    me._createElement("text", "text")
      .set("text", text);

    var hfw_func = nil;
    var min_width = me._text.maxWidth() + 4;
    var width_hint = min_width;

    if( model._cfg.get("wordWrap", 0) )
    {
      var m = me;
      hfw_func = func(w) m.heightForWidth(w);
      min_width = math.min(32, min_width);

      # prefer approximately quadratic text blocks
      if( width_hint > 24 )
        width_hint = int(math.sqrt(width_hint * 24));
    }

    model.setHeightForWidthFunc(hfw_func);
    model.setLayoutMinimumSize([min_width, 14]);
    model.setLayoutSizeHint([width_hint, 24]);

    return me.update(model);
  },
  setImage: func(model, img)
  {
    if( img == nil or size(img) == 0 )
      return me._deleteElement('img');

    me._createElement("img", "image")
      .set("src", img)
      .set("preserveAspectRatio", "xMidYMid slice");

    return me;
  },
  # @param bg CSS color or 'none'
  setBackground: func(model, bg)
  {
    if( bg == nil or bg == "none" )
      return me._deleteElement("bg");

    me._createElement("bg", "path")
      .set("fill", bg);

    me.setSize(model, model._size[0], model._size[1]);
    return me;
  },
  heightForWidth: func(w)
  {
    if( me['_text'] == nil )
      return -1;

    return math.max(14, me._text.heightForWidth(w - 4));
  },
  update: func(model)
  {
    if( me['_text'] != nil )
    {
      var color_name = model._windowFocus() ? "fg_color" : "backdrop_fg_color";
      me._text.set("fill", me._style.getColor(color_name));
    }
  },
# protected:
  _createElement: func(name, type)
  {
    var mem = '_' ~ name;
    if( me[ mem ] == nil )
    {
      me[ mem ] = me._root.createChild(type, "label-" ~ name);

      if( type == "text" )
      {
         me[ mem ].set("font", "LiberationFonts/LiberationSans-Regular.ttf")
                  .set("character-size", 14)
                  .set("alignment", "left-center");
      }
    }
    return me[ mem ];
  },
  _deleteElement: func(name)
  {
    name = '_' ~ name;
    if( me[ name ] != nil )
    {
      me[ name ].del();
      me[ name ] = nil;
    }
    return me;
  }
};

# A one line text input field
DefaultStyle.widgets["line-edit"] = {
  new: func(parent, cfg)
  {
    me._hpadding = cfg.get("hpadding", 8);

    me._root = parent.createChild("group", "line-edit");
    me._border =
      me._root.createChild("image", "border")
              .set("slice", "10 12"); #"7")
    me._text =
      me._root.createChild("text", "input")
              .set("font", "LiberationFonts/LiberationSans-Regular.ttf")
              .set("character-size", 14)
              .set("alignment", "left-baseline")
              .set("clip-frame", Element.PARENT);
    me._cursor =
      me._root.createChild("path", "cursor")
              .set("stroke", "#333")
              .set("stroke-width", 1)
              .moveTo(me._hpadding, 5)
              .vert(10);
    me._hscroll = 0;
  },
  setSize: func(model, w, h)
  {
    me._border.setSize(w, h);
    me._text.set(
      "clip",
      "rect(0, " ~ (w - me._hpadding) ~ ", " ~ h ~ ", " ~ me._hpadding ~ ")"
    );
    me._cursor.setDouble("coord[2]", h - 10);

    return me.update(model);
  },
  setText: func(model, text)
  {
    me._text.set("text", text);
    model._onStateChange();
  },
  update: func(model)
  {
    var backdrop = !model._windowFocus();
    var file = me._style._dir_widgets ~ "/";

    if( backdrop )
      file ~= "backdrop-";

    file ~= "entry";

    if( !model._enabled )
      file ~= "-disabled";
    else if( model._focused and !backdrop )
      file ~= "-focused";

    me._border.set("src", file ~ ".png");

    var color_name = backdrop ? "backdrop_fg_color" : "fg_color";
    me._text.set("fill", me._style.getColor(color_name));

    me._cursor.setVisible(model._enabled and model._focused and !backdrop);

    var width = model._size[0] - 2 * me._hpadding;
    var cursor_pos = me._text.getCursorPos(0, model._cursor)[0];
    var text_width = me._text.getCursorPos(0, me._text.lineLength(0))[0];

    if( text_width <= width )
      # fit -> align left (TODO handle different alignment)
      me._hscroll = 0;
    else if( me._hscroll + cursor_pos > width )
      # does not fit, cursor to the right
      me._hscroll = width - cursor_pos;
    else if( me._hscroll + cursor_pos < 0 )
      # does not fit, cursor to the left
      me._hscroll = -cursor_pos;
    else if( me._hscroll + text_width < width )
      # does not fit, limit scroll to align with right side
      me._hscroll = width - text_width;

    var text_pos = me._hscroll + me._hpadding;

    me._text
      .setTranslation(text_pos, model._size[1] / 2 + 5)
      .update();
    me._cursor
      .setDouble("coord[0]", text_pos + cursor_pos)
      .update();
  }
};

# ScrollArea
DefaultStyle.widgets["scroll-area"] = {
  new: func(parent, cfg)
  {
    me._root = parent.createChild("group", "scroll-area");

    me._bg     = me._root.createChild("path", "background")
                         .set("fill", "#e0e0e0");
    me.content = me._root.createChild("group", "scroll-content")
                         .set("clip-frame", Element.PARENT);
    me.vert  = me._newScroll(me._root, "vert");
    me.horiz = me._newScroll(me._root, "horiz");
  },
  setColorBackground: func
  {
    if( size(arg) == 1 )
    	  var arg = arg[0];
    	me._bg.setColorFill(arg);
  },
  update: func(model)
  {
    me.horiz.reset();
    if( model._max_scroll[0] > 1 )
      # only show scroll bar if horizontally scrollable
      me.horiz.moveTo( model._scroller_offset[0] + model._scroller_pos[0],
                       model._size[1] - 2 )
              .horiz(model._scroller_size[0]);

    me.vert.reset();
    if( model._max_scroll[1] > 1 )
      # only show scroll bar if vertically scrollable
      me.vert.moveTo( model._size[0] - 2,
                      model._scroller_offset[1] + model._scroller_pos[1] )
             .vert(model._scroller_size[1]);

    me._bg.reset()
          .rect(0, 0, model._size[0], model._size[1]);
    me.content.set(
      "clip",
      "rect(0, " ~ model._size[0] ~ ", " ~ model._size[1] ~ ", 0)"
    );
  },
# private:
  _newScroll: func(el, orient)
  {
    return el.createChild("path", "scroll-" ~ orient)
             .set("stroke", "#f07845")
             .set("stroke-width", 4);
  },
  # Calculate size and limits of scroller
  #
  # @param model
  # @param dir 0 for horizontal, 1 for vertical
  # @return [scroller_size, min_pos, max_pos]
  _updateScrollMetrics: func(model, dir)
  {
    if( model._content_size[dir] <= model._size[dir] )
      return;

    model._scroller_size[dir] =
      math.max(
        12,
        model._size[dir] * (model._size[dir] / model._content_size[dir])
      );
    model._scroller_offset[dir] = 0;
    model._scroller_delta[dir] = model._size[dir] - model._scroller_size[dir];
  }
};
