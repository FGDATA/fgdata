var AircraftCenter = {
  new: func
  {
    var m = {
      parents: [AircraftCenter],
      _dlg: canvas.Window.new([600,500], "dialog")
                         .set("title", "Aircraft Center")
                         .set("resize", 1),
      _active_button: nil,
      _show_more: nil
    };

    m._dlg.getCanvas(1)
          .set("background", canvas.style.getColor("bg_color"));
    m._root = m._dlg.getCanvas().createGroup();

    var vbox = VBoxLayout.new();
    m._dlg.setLayout(vbox);

    m._tab_bar = HBoxLayout.new();
    vbox.addItem(m._tab_bar);

    m._tab_bar.addStretch(1);
    m._tab_bar.addStretch(1);

    var scroll = gui.widgets.ScrollArea.new(m._root, style, {size: [96, 128]})
                                       .move(20, 100);
    vbox.addItem(scroll, 1);

    m._scroll_content =
      scroll.getContent()
            .set("font", "LiberationFonts/LiberationSans-Bold.ttf")
            .set("character-size", 16)
            .set("alignment", "left-center");

    m._list = VBoxLayout.new();
    scroll.setLayout(m._list);

    m._info_label = gui.widgets.Label.new(m._root, style, {wordWrap: 1});
    vbox.addItem(m._info_label);
    return m;
  },
  addPage: func(name, filter)
  {
    var b = gui.widgets.Button.new(me._root, style, {})
                              .setText(name)
                              .setCheckable(1);
    me._tab_bar.insertItem(me._tab_bar.count() - 1, b);

    b.listen("toggled", func(e)
    {
      if( !e.detail.checked )
        return;

      if( me._active_button != nil )
        me._active_button.setChecked(0);
      me._active_button = b;

      me._list.clear();
      me._show_more = nil;

      settimer(func me.fillList(pkg.root.search(filter)), 0, 1);
    });

    if( me._active_button == nil )
      b.setChecked(1);

    return me;
  },
  fillList: func(packages)
  {
    var num_packages = size(packages);
    var end = num_packages;

    if( num_packages > 55 )
      end = 50;

    me._addPackageEntries(packages, 0, end);
  },
  # @param packages
  # @param begin  index of first package
  # @param end    index after last package
  _addPackageEntries: func(packages, begin, end)
  {
    # remove stretch at end of list
    me._list.takeAt(-1);

    if( me._show_more != nil )
    {
      me._list.removeItem(me._show_more);
      me._show_more = nil;
    }

    for(var i = begin; i < end; i += 1)
    {
      var package = packages[i];
      var row = HBoxLayout.new();
      me._list.addItem(row);

      var image_label = gui.widgets.Label.new(me._scroll_content, style, {});
      image_label.setFixedSize(171, 128);
      row.addItem(image_label);

      var thumbs = package.thumbnails;
      if( size(thumbs) > 0 )
        image_label.setImage(thumbs[0]);
      else
        image_label.setText("No thumbnail available");

      var detail_box = VBoxLayout.new();
      row.addItem(detail_box);
      row.addSpacing(5);

      var title_box = HBoxLayout.new();
      detail_box.addItem(title_box);

      title_box.addItem(
        gui.widgets.Label.new(me._scroll_content, style, {})
                         .setText(package.name)
      );
      title_box.addStretch(1);
      (func {
        var p = package;
        var b = gui.widgets.Button.new(me._scroll_content, style, {});
        var install_text = sprintf("Install (%.1fMB)", p.fileSize/1024/1024);

        if( p.installed )
          b.setText("Remove");
        else
          b.setText(install_text);

        b.listen("clicked", func
        {
          if( p.installed )
          {
            p.uninstall();
            b.setText(install_text);
          }
          else
          {
            b.setText("Wait...").setEnabled(0);
            p.install();
          }
        });

        p.existingInstall(func(pkg, ins) {
          ins.progress(func(i, cur, total)
            b.setText(sprintf("%.1f%%", (cur / total) * 100))
          );
          ins.fail(func b.setText('Failed'));
          ins.done(func b.setText("Remove").setEnabled(1));
        });

        title_box.addItem(b);
      })();

      var description = parse_markdown(package.description);
      if( size(description) <= 0 )
      {
        foreach(var cat; ["FDM", "systems", "cockpit", "model"])
          description ~= cat ~ ": " ~ package.lprop("rating/" ~ cat) ~ "\n";
      }

      detail_box.addItem(
        gui.widgets.Label.new(me._scroll_content, style, {wordWrap: 1})
                         .setText(description)
      );

      if( package.installed )
      {
        var launch_bar = HBoxLayout.new();
        detail_box.addItem(launch_bar);

        var variants = keys(package.variants);
        foreach(var variant; variants)
        {(func{
          var b = gui.widgets.Button.new(me._scroll_content, style, {})
                                    .setText(package.variants[variant]);
          var acft_id = variant;
          b.listen("clicked", func
          {
            printlog("warn", "Switching to aircraft '" ~ acft_id ~ "'");
            fgcommand("switch-aircraft", props.Node.new({"aircraft": acft_id}));
          });
          launch_bar.addItem(b);
        })();}
        launch_bar.addStretch(1);
      }

      detail_box.addStretch(1);
    }

    # get rid of references to widgets of last package
    row = nil;
    image_label = nil;
    detail_box = nil;
    title_box = nil;
    launch_bar = nil;

    var num_info = size(packages);

    if( end < size(packages) )
    {
      num_info = end ~ " of " ~ num_info;

      # range of next "page"
      start = end;
      end = math.min(end + 50, size(packages));

      me._show_more =
        gui.widgets.Button.new(me._scroll_content, style, {})
                          .setText("Show more...")
                          .listen("clicked", func
                            me._addPackageEntries(packages, start, end)
                          );
      me._show_more.setContentsMargin(5);
      me._list.addItem(me._show_more, 0, canvas.AlignHCenter);
    }

    # Add some stretch in case the scroll area is larger than the list
    me._list.addStretch(1);

    me._info_label.setText(
      "Install/remove aircraft (Showing " ~ num_info ~ " aircraft)"
    );
    me._dlg.getCanvas().update();
  }
};

MessageBox.warning(
  "Experimental Feature...",
  "The Aircraft Center is only a preview and not yet in a stable state!",
  func(sel)
  {
    if( sel != MessageBox.Ok )
      return;

    var ac = AircraftCenter.new();
    ac.addPage("Rated", {
      'rating-FDM': 2,
      'rating-cockpit': 2,
      'rating-model': 2,
      'rating-systems': 1
    });
    ac.addPage("Installed", {
      'installed': 1
    });
    ac.addPage("All", {});
  },
  MessageBox.Ok | MessageBox.Cancel | MessageBox.DontShowAgain
);
