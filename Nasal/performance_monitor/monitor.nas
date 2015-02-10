# GUI displaying FG system performance statistics 
# performance_monitor.dialog.show() -- displays pilot list dialog

var PERFMON_RUNNING = 0;

var dialog = {
    init: func(x = nil, y = nil) {
        me.x = x;
        me.y = y;
        me.bg = [0, 0, 0, 0.3];    # background color
        me.fg = [[0.9, 0.9, 0.2, 1], [1, 1, 1, 1]]; # alternative active

        # "private"
        var font = { name: "FIXED_8x13" };
        me.header = ["  submodule", "cumulative/ms", "total/ms", "max/ms", "min/ms", "mean/ms", "stddev/ms", "iterations" ];
        me.columns = [
            { type: "text", property: "name",          format:   " %s", label: "------------------", halign: "fill", font: font },
            { type: "text", property: "cumulative-ms", format: "%9.2f", label: "-------------",      halign: "fill", font: font },
            { type: "text", property: "total-ms",      format: "%6.2f", label: "----------",         halign: "fill", font: font },
            { type: "text", property: "max-ms",        format: "%5.2f", label: "---------",          halign: "fill", font: font },
            { type: "text", property: "min-ms",        format: "%5.2f", label: "---------",          halign: "fill", font: font },
            { type: "text", property: "mean-ms",       format: "%5.2f", label: "---------",          halign: "fill", font: font },
            { type: "text", property: "stddev-ms",     format: "%5.2f", label: "---------",          halign: "fill", font: font },
            { type: "text", property: "count",         format: "%3d",   label: "------",             halign: "fill", font: font },
        ];
        me.name = "performance-monitor";
        me.dialog = nil;
        me.loopid = 0;

        me.listeners=[];
        append(me.listeners, setlistener("/sim/startup/xsize", func me._redraw_()));
        append(me.listeners, setlistener("/sim/startup/ysize", func me._redraw_()));
        append(me.listeners, setlistener("/sim/signals/reinit-gui", func me._redraw_()));
    },
    create: func {
        if (me.dialog != nil)
            me.close();

        setprop("/sim/performance-monitor/enabled",1);

        me.dialog = gui.dialog[me.name] = gui.Widget.new();
        me.dialog.set("name", me.name);
        me.dialog.set("dialog-name", me.name);
        if (me.x != nil)
            me.dialog.set("x", me.x);
        if (me.y != nil)
            me.dialog.set("y", me.y);

        me.dialog.set("layout", "vbox");
        me.dialog.set("default-padding", 0);

        me.dialog.setColor(me.bg[0], me.bg[1], me.bg[2], me.bg[3]);

        var titlebar = me.dialog.addChild("group");
        titlebar.set("layout", "hbox");

        var w = titlebar.addChild("button");
        w.node.setValues({ "pref-width": 32, "pref-height": 16, legend: "sort", default: 0 });
        w.setBinding("nasal", "performance_monitor.dialog._redraw_()");

        titlebar.addChild("empty").set("stretch", 1);
        titlebar.addChild("text").set("label", "worst/average frame rate: ");
        titlebar.addChild("text").node.setValues({ live: 1, property: "/sim/frame-rate-worst", label: "--" });
        titlebar.addChild("text").set("label", "/");
        titlebar.addChild("text").node.setValues({ live: 1, property: "/sim/frame-rate", label: "-- fps,", format: "%2d fps," });
        titlebar.addChild("text").set("label", " worst frame delay: ");
        titlebar.addChild("text").node.setValues({ live: 1, property: "/sim/frame-latency-max-ms", label: "----.-", format: "%4d ms" });
        titlebar.addChild("empty").set("stretch", 1);

        var w = titlebar.addChild("button");
        w.node.setValues({ "pref-width": 16, "pref-height": 16, legend: "", default: 0 });
        # "Esc" causes dialog-close
        w.set("key", "Esc");
        w.setBinding("nasal", "performance_monitor.dialog.del()");

        me.dialog.addChild("hrule");

        var content = me.dialog.addChild("group");
        content.set("layout", "table");
        content.set("default-padding", 0);

        var modulelist = props.globals.getNode( "/sim/performance-monitor/subsystems", 1 ).getChildren();
        var DataReady = size(modulelist) > 0;
        if (!DataReady)
        {
            content.addChild("text").set("label", "wait...");
        }
        else
        {
            var row = 0;
            var col = 0;
            foreach (var h; me.header) {
                var w = content.addChild("text");
                var l = typeof(h) == "func" ? h() : h;
                w.node.setValues({ "label": l, "row": row, "col": col, halign: me.columns[col].halign });
                w = content.addChild("hrule");
                w.node.setValues({ "row": row + 1, "col": col });
                col += 1;
            }
            row += 2;
            var odd = 1;
            modulelist = sort (modulelist, func (a,b) a.getChild("cumulative-ms",0,1).getValue() < b.getChild("cumulative-ms",0,1).getValue());
            foreach (var mp; modulelist) {
                var col = 0;
                var color = me.fg[odd = !odd];
                foreach (var column; me.columns) {
                    var p = column.property;
                    var w = nil;
                    if (column.type == "text") {
                        w = content.addChild("text");
                        w.node.setValues(column);
                    }
                    w.setColor(color[0], color[1], color[2], color[3]);
                    w.node.setValues({ row: row, col: col, live: 1, property: mp.getPath() ~ "/" ~ p });
                    col += 1;
                }
                row += 1;
            }
        }
        if (me.x != nil)
            me.dialog.set("x", me.x);
        if (me.y != nil)
            me.dialog.set("y", me.y);

        fgcommand("dialog-new", me.dialog.prop());
        fgcommand("dialog-show", me.dialog.prop());
        if (!DataReady)
            settimer(func me.update(me.loopid+=1), 1, 1);
    },
    update: func(id) {
        id == me.loopid or return;
        if (!PERFMON_RUNNING)
            return;
        me._redraw_();
    },
    _redraw_: func {
        if (me.dialog != nil) {
            me.close();
            me.create();
        }
    },
    close: func {
        if (me.dialog != nil) {
            me.x = me.dialog.prop().getNode("x").getValue();
            me.y = me.dialog.prop().getNode("y").getValue();
        }
        fgcommand("dialog-close", me.dialog.prop());
        setprop("/sim/performance-monitor/enabled",0);
    },
    del: func {
        PERFMON_RUNNING = 0;
        me.close();
        foreach (var l; me.listeners)
            removelistener(l);
        delete(gui.dialog, me.name);
    },
    show: func {
        if (!PERFMON_RUNNING) {
            PERFMON_RUNNING = 1;
            me.init(2, 20);
            me.create();
        }
    },
    toggle: func {
        if (!PERFMON_RUNNING)
            me.show();
        else
            me.del();
    },
};

