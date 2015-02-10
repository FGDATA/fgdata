var PropertyChangeListenerObjects = {
  _ws : null,
  _listeners : {},
};

var PropertyChangeListener = function(callback) {
  PropertyChangeListenerObjects._ws = new WebSocket('ws://' + location.host + '/PropertyListener');
  PropertyChangeListenerObjects._ws.onopen = callback;
  PropertyChangeListenerObjects._ws.onclose = function(ev) {
    alert('Lost connection to FlightGear. Please reload this page and/or restart FlightGear.');
    PropertyChangeListenerObjects._ws = null;
  };
  PropertyChangeListenerObjects._ws.onerror = function(ev) {
    alert('Error communicating with FlightGear. Please reload this page and/or restart FlightGear.');
    PropertyChangeListenerObjects._ws = null;
  };
  PropertyChangeListenerObjects._ws.onmessage = function(ev) {
    try {
      var node = JSON.parse(ev.data);
      var cb = PropertyChangeListenerObjects._listeners[node.path];
      for (var i = 0; i < cb.length; i++) {
        var o = cb[i];
        o.context ? o.context.call(o.cb(node)) : o.cb(node);
      }
    } catch (e) {
    }
  };
};

var NextListenerId = 0;

var SetListener = function(path, callback, context ) {
  var o = PropertyChangeListenerObjects._listeners[path];
  if (typeof (o) == 'undefined') {
    o = new Array();
    PropertyChangeListenerObjects._listeners[path] = o;
    PropertyChangeListenerObjects._ws.send(JSON.stringify({
      command : 'addListener',
      node : path
    }));
    PropertyChangeListenerObjects._ws.send(JSON.stringify({
      command : 'get',
      node : path
    }));
  }
  o.push({ cb: callback, ctx: context, id: NextListenerId });
  return NextListenerId++;
};

var RemoveListener = function(id) {
  // send unsubscribe over the socket.
  var a = PropertyChangeListenerObjects._listeners;
  for( var k in a ) {
    var o = a[k];
    for( var i = 0; i < o.length; i++ ) {
      if( o[i].id == id ) {
        //remote element from array
        var rest = o.slice(i+1);
        o.length = i;
        o.push.apply(o,rest);
        return;
      }
    }
    if( o.length == 0 ) {
      //TODO: send removeListener
    }
  };

}
