# ==============================================================================
# DEMO
# ==============================================================================
var canvas_demo = {
  new: func()
  {
    debug.dump("Creating new canvas demo...");

    var m = { parents: [canvas_demo] };
    
    # create a new canvas...
    m.canvas = canvas.new({
      "name": "PFD-Test",
      "size": [1024, 1024],
      "view": [768, 1024],
      "mipmapping": 1
    });
    
    # ... and place it on the object called PFD-Screen
    m.canvas.addPlacement({"node": "PFD-Screen"});
    m.canvas.setColorBackground(0,0.04,0);
    
    # and now do something with it
    m.dt = props.globals.getNode("sim/time/delta-sec");
    m.gmt  = props.globals.getNode("sim/time/gmt");
    
    var g = m.canvas.createGroup();
    var g_tf = g.createTransform();
    g_tf.setRotation(0.1 * math.pi);
    
    m.text_title =
      g.createChild("text", "line-title")
       .setDrawMode(canvas.Text.TEXT + canvas.Text.FILLEDBOUNDINGBOX)
       .setColor(0,0,0)
       .setColorFill(0,1,0)
       .setAlignment("center-top")
       .setFont("LiberationFonts/LiberationMono-Bold.ttf")
       .setFontSize(70, 1.5)
       .setTranslation(384, 5);

    m.dynamic_text =
      g.createChild("text", "dynamic-text")
       .setText("Text node created at runtime.")
       .setFont("Helvetica.txf")
       .setFontSize(50)
       .setAlignment("center-center");
    m.tf = m.dynamic_text.createTransform();
    m.tf.setTranslation(384, 200);

    m.path =
      g.createChild("path")
       .moveTo(25, 12.5)
       .lineTo(325, 25)
       .lineTo(150, 200)
       .cubicTo(150, 225, 50, 225, 50, 200)
       .close()
       .setTranslation(200, 70)
       .setStrokeLineWidth(4)
       .setStrokeDashArray([10,6,3,3,6])
       .setColor(0.2,0.3,1);

    m.rot = 0;
    m.pos = 200;
    m.move = 50;
    
    return m;
  },
  update: func()
  {
    var dt = me.dt.getValue();

    # Change the value of a text element    
    me.text_title.setText(me.gmt.getValue());
    
    # Animate a text node a bit
    me.rot += dt * 0.3 * math.pi;
    me.tf.setRotation(me.rot);
    
    me.pos += me.move * dt;
    if( me.pos > 900 )
    {
      me.pos = 900;
      me.move *= -1;
    }
    else if( me.pos < 150 )
    {
      me.pos = 150;
      me.move *= -1;
    }
    me.tf.setTranslation(384, me.pos);

    settimer(func me.update(), 0);
  },
};

setlistener("/nasal/canvas/loaded", func {
  var demo = canvas_demo.new();
  demo.update();
}, 1);
