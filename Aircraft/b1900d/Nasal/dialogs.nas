var Radio = gui.Dialog.new("/sim/gui/dialogs/radios/dialog",
        "Aircraft/b1900d/Systems/tranceivers.xml");
var ap_settings = gui.Dialog.new("/sim/gui/dialogs/collins-autopilot/dialog",
        "Aircraft/b1900d/Systems/autopilot-dlg.xml");
var options = gui.Dialog.new("/sim/gui/dialogs/options/dialog",
        "Aircraft/b1900d/Systems/options.xml");
var ap_help = gui.Dialog.new("/sim/gui/dialogs/ap_help/dialog",
        "Aircraft/b1900d/Systems/ap_help.xml");
gui.menuBind("radio", "dialogs.Radio.open()");
gui.menuBind("autopilot-settings", "dialogs.ap_settings.open()");
gui.menuBind("aircraft-keys", "dialogs.ap_help.open()");
