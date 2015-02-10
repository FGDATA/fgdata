var InputDialog = {
  Ok:             0x0001,
  Cancel:         0x0002,
  new: func( title = "Input",
             label = "",
             text  = "" )
  {
    return {
      parents: [InputDialog],
      _title: title,
      _label: label,
      _text: text
    };
  },
  setTitle: func(title)
  {
    me._title = title;
    return me;
  },
  setLabel: func(label)
  {
    me._label = label;
    return me;
  },
  setText: func(text)
  {
    me._text = text;
    return me;
  },
  exec: func(cb = nil)
  {
    var MARGIN = 12;
    var dlg = canvas.Window.new([300,120], "dialog")
                           .setTitle(me._title);
    var root = dlg.getCanvas(1)
                  .set("background", style.getColor("bg_color"))
                  .createGroup();
    var vbox = VBoxLayout.new();
    vbox.setContentsMargin(MARGIN);
    dlg.setLayout(vbox);

    vbox.addItem(
      gui.widgets.Label.new(root, style, {wordWrap: 1})
                       .setText(me._label)
    );

    var input = gui.widgets.LineEdit.new(root, style, {});
    vbox.addItem(input);
    input.setText(me._text);
    input.setFocus();

    var button_box = HBoxLayout.new();
    vbox.addItem(button_box);

    button_box.addStretch(1);
    foreach(var button; [me.Ok, me.Cancel])
    {
      (func{
        var b_id = button;
        button_box.addItem(
          gui.widgets.Button.new(root, style, {})
                            .setText(me._button_names[button])
                            .listen("clicked", func {
                              dlg.del();
                              if( cb != nil )
                                cb(b_id, b_id == me.Ok ? input.text() : nil);
                            })
        );
      })();
    }

    var w = math.max(300, vbox.sizeHint()[0]);
    dlg.setSize(w, vbox.heightForWidth(w));

    return me;
  },
  # Show an input dialog to get a text string
  #
  # @param title
  # @param label
  # @param cb       Dialog close callback
  # @param text     Default text
  getText: func(title, label, cb, text = "")
  {
    var dlg = InputDialog.new(title, label, text);
    return dlg.exec(cb);
  },
# private:
  _button_names: {}
};

# Standard button names
InputDialog._button_names[ InputDialog.Ok     ] = "Ok";
InputDialog._button_names[ InputDialog.Cancel ] = "Cancel";
