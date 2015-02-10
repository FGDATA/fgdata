
# Search the canvas texture created by the GPSmap196
var gps196CanvasInstance = canvas.get({name: "GPSmap196-screen"});

# Create a new Canvas window (calling that the "widget")
var dlg = canvas.Window.new([1024, 512], "dialog").set("title", "Garmin GPSmap196");

# A list of all button available in the SVG file of the widget
# and associate the button with the property he will trigger
var buttons = [
                ["gps196.widget.button.in", "button-in"], ["gps196.widget.button.out", "button-out"],
                ["gps196.widget.button.dto", "button-dto"], ["gps196.widget.button.page", "button-page"],
                ["gps196.widget.button.quit", "button-quit"], ["gps196.widget.button.nrst", "button-nrst"],
                ["gps196.widget.button.menu", "button-menu"], ["gps196.widget.button.enter", "button-enter"],
                ["gps196.widget.button.power", "button-power"], ["gps196.widget.rocker.up", "rocker-up"],
                ["gps196.widget.rocker.down", "rocker-down"], ["gps196.widget.rocker.left", "rocker-left"],
                ["gps196.widget.rocker.right", "rocker-right"]
              ];

# Create the content of the Canvas window with a white background
var gps196Widget = dlg.createCanvas().setColorBackground(1,1,1,1);

# Create the main (root) group of our canvas
var root = gps196Widget.createGroup();

# Load the SVG file of the widget providing all buttons
canvas.parsesvg(root, "Aircraft/Instruments-3d/GPSmap196/widget/gpsmap196-widget.svg");

# An helper function who add the event listener for each button
var setButtonListener = func(btn, prop) {
  root.getElementById(btn).addEventListener("mousedown", func(e) { setprop("instrumentation/gps196/inputs/"~prop, 1); });
  root.getElementById(btn).addEventListener("mouseup", func(e) { setprop("instrumentation/gps196/inputs/"~prop, 0); });
  root.getElementById(btn).set("z-index", 11);
}

# Run through all our buttons in order to setup the event listener
for( var i=0; i<size(buttons); i=i+1){
  setButtonListener(buttons[i][0], buttons[i][1]);
}

# Add a background image to our Canvas window
var background = root.createChild("image");
background.setFile("Aircraft/Instruments-3d/GPSmap196/widget/gpsmap196-widget.png").setSize(1024,512).set("z-index",10);

# Include the canvas texture in the display of the widget
var canvasScreenWidget = root.createChild("image");
canvasScreenWidget.setFile(gps196CanvasInstance.getPath()).setSize(563,359).setTranslation(87,53).set("z-index", 11);
