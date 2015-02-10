###############################################################################
# KeyHandler by Tatsuhiro Nishioka
# - key event handler class
# Copyright (C) 2008 Tatsuhiro Nishioka (tat dot fgmacosx at gmail dot com)
# This file is licensed under the GPL license version 2 or later.
# $Id$
# 
###############################################################################

#
# Key Handler
# - add/removes key handler
# - monitors key events
# - calls key handler on registered key-press event
#
var KeyHandler = {};

KeyHandler.ALT  = 16;
KeyHandler.CTRL =  8;
KeyHandler.META =  4;
KeyHandler.SHIFT = 2;
KeyHandler.SUPER = 1;

KeyHandler.new = func () {
  var obj = { parents : [KeyHandler] };
  obj.handlers = [];
  obj.modifiers = ["alt", "ctrl", "meta", "shift", "super"];
  obj.eventNode = props.globals.getNode("/devices/status/keyboard/event");
  obj.modifierNode = obj.eventNode.getNode("modifier");
  obj.listener = setlistener(obj.eventNode, func(event) {
    obj.handle(event);
  });
  return obj;
}

# _getKeyCode() - gets key code from device node; private method
KeyHandler._getKeyCode = func() {
  return me.eventNode.getNode("key").getValue();
}

# _getModifiers - gets key modifiers from device node; private method
KeyHandler._getModifiers = func() {
  var modifier = 0;
  foreach (var propname; me.modifiers) {
    modifier *= 2;
    modifier += me.modifierNode.getNode(propname).getValue();
  }
  return modifier;
}

#
# addHandler(keycode, modifier, procObj)
# - keycode: a key code at /devices/status/keyboard/event/key
# - modifier: a combination of KeyHandler.ALT, CTRL, META, SHIFT and SUPER
# 
KeyHandler.add = func(keycode, modifier, procObj ) {
  append(me.handlers, { key : keycode, mod : modifier, proc : procObj });
}

#
# handle(event) - handles key events and calls registered key handler if matched; private method
#
KeyHandler.handle = func(event) {
  var key = me._getKeyCode();
  var modifier = me._getModifiers();

  foreach (var handler; me.handlers) {
    if (handler.key == key and handler.mod == modifier and handler.proc != nil) {
      handler.proc();
      # eat key event when handled
      me.eventNode.getNode("key").setValue(0);
    }
  }
}

