L.RotatedMarker = L.Marker.extend({

  options : {
    angle : 0
  },

  _setPos : function(pos) {
    L.Marker.prototype._setPos.call(this, pos);

    if (L.DomUtil.TRANSFORM) {
      // use the CSS transform rule if available
      this._icon.style[L.DomUtil.TRANSFORM] += ' rotate(' + this.options.angle + 'deg)';
    } else if (L.Browser.ie) {
      // fallback for IE6, IE7, IE8
      var rad = this.options.angle * (Math.PI / 180), costheta = Math.cos(rad), sintheta = Math.sin(rad);
      this._icon.style.filter += ' progid:DXImageTransform.Microsoft.Matrix(sizingMethod=\'auto expand\', M11=' + costheta
          + ', M12=' + (-sintheta) + ', M21=' + sintheta + ', M22=' + costheta + ')';
    }
  },

  initialize: function(latlng,options) {
    L.Marker.prototype.initialize(latlng,options);
    if( options )
      L.Util.setOptions(this,options);
  },

});

L.rotatedMarker = function(pos,options) {
  return new L.RotatedMarker(pos,options);
}

L.AircraftMarker = L.RotatedMarker.extend({
  options : {
    angle : 0,
    clickable: false,
    keyboard: false,
    getProperties:function() {
      return {};
    },
    icon : L.divIcon({
      iconSize : [ 60, 60 ],
      iconAnchor : [ 30, 30 ],
      className: 'aircraft-marker-icon',
      html:  '<svg xmlns="http://www.w3.org/2000/svg" height="100%" width="100%" viewBox="0 0 500 500" preserveAspectRatio="xMinYMin meet"><path d="M250.2,59.002c11.001,0,20.176,9.165,20.176,20.777v122.24l171.12,95.954v42.779l-171.12-49.501v89.227l40.337,29.946v35.446l-60.52-20.18-60.502,20.166v-35.45l40.341-29.946v-89.227l-171.14,49.51v-42.779l171.14-95.954v-122.24c0-11.612,9.15-20.777,20.16-20.777z" fill="#808080" stroke="black" stroke-width="5"/></svg>',
    }),
    zIndexOffset : 10000,
    updateInterval: 100,
  },

  initialize: function(latlng,options) {
    L.RotatedMarker.prototype.initialize(latlng,options);
    L.Util.setOptions(this,options);
  },

  onAdd: function( map ) {
    L.RotatedMarker.prototype.onAdd.call(this,map);
    this.popup = L.popup( {
      autoPan: false,
      keepInView: false,
      closeButton: false,
      className:   'aircraft-marker-popup',
      closeOnClick: false,
      maxWidth: 200,
      minWidth: 100,
      offset: [30,30],
    }, this );
    this.popup.setContent("");
    this.bindPopup( this.popup );
    this.addTo(this._map);
    this.openPopup();

    this.timeout();
  },

  onRemove: function( map ) {
    if( this.timeoutid != null )
      clearTimeout(this.timeoutid);
    L.RotatedMarker.prototype.onRemove.call(this,map);
  },

  timeoutid: null,
  timeout: function() {
    var props = this.options.getProperties.call(this);
    var popup = 
      '<div class="aircraft-marker-callsign">' +  props.callsign + '</div>' +
      '<div class="aircraft-marker-model">' + props.model + '</div>' +
      '<div class="aircraft-marker-altitude">' + props.altitude + '</div>' +
      '<div class="aircraft-marker-gs">' + props.speed + '</div><div style="clear: both"/>';
    this.popup.setContent(popup);

    this.options.angle = props.heading;
//    this.options.title = props.callsign + ' Heading ' + props.heading + '°';
//    this.options.alt = this.options.title;
    this.setLatLng( props.position );
    var that = this;
    this.timeoutid = setTimeout( function() { that.timeout(); }, this.options.updateInterval );
  },
});

L.aircraftMarker = function(latlng,options) {
  return new L.AircraftMarker(latlng,options);
}

