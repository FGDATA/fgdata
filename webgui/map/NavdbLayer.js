    var MAP_ICON = {};
    MAP_ICON["VOR"] = L.icon({
      iconSize : [ 30, 30 ],
      iconAnchor : [ 15, 15 ],
      popupAncor : [ 0, -17 ],
      iconUrl : "images/vor.svg",
    });
    MAP_ICON["NDB"] = L.icon({
      iconSize : [ 30, 30 ],
      iconAnchor : [ 15, 15 ],
      popupAncor : [ 0, -17 ],
      iconUrl : "images/ndb.svg",
    });
    MAP_ICON["dme"] = L.icon({
      iconSize : [ 30, 30 ],
      iconAnchor : [ 15, 15 ],
      popupAncor : [ 0, -17 ],
      iconUrl : "images/dme.svg",
    });
    MAP_ICON["airport-paved"] = L.icon({
      iconSize : [ 30, 30 ],
      iconAnchor : [ 15, 15 ],
      popupAncor : [ 0, -17 ],
      iconUrl : "images/airport-paved.svg",
    });
    MAP_ICON["airport-unpaved"] = L.icon({
      iconSize : [ 30, 30 ],
      iconAnchor : [ 15, 15 ],
      popupAncor : [ 0, -17 ],
      iconUrl : "images/airport-unpaved.svg",
    });
    MAP_ICON["airport-unknown"] = L.icon({
      iconSize : [ 30, 30 ],
      iconAnchor : [ 15, 15 ],
      popupAncor : [ 0, -17 ],
      iconUrl : "images/airport-unknown.svg",
    });
    MAP_ICON["arp"] = L.icon({
      iconSize : [ 30, 30 ],
      iconAnchor : [ 15, 15 ],
      popupAncor : [ 0, -17 ],
      iconUrl : "images/arp.svg",
    });
    MAP_ICON["aircraft"] = L.icon({
      iconSize : [ 20, 20 ],
      iconAnchor : [ 10, 10 ],
      popupAncor : [ 0, -12 ],
      iconUrl : "images/aircraft.svg",
    });

L.NavdbLayer = L.GeoJSON.extend({
  options: {
    pointToLayer : function(feature, latlng) {
      var options = {
        title : feature.properties.id + ' (' + feature.properties.name + ')',
        alt : feature.properties.id,
        riseOnHover : true,
      };

      if (feature.properties.type == "airport") {
        if( map.getZoom() >= 13 ) {
              options.icon = MAP_ICON['arp'];
        } else {
          options.angle = feature.properties.longestRwyHeading_deg;
          switch (feature.properties.longestRwySurface) {
            case 'asphalt':
            case 'concrete':
              options.icon = MAP_ICON['airport-paved'];
              break;
            case 'unknown':
              options.icon = MAP_ICON['airport-unknown'];
              break;
            default:
              options.icon = MAP_ICON['airport-unpaved'];
              break;
          }
        }
      } else {
        if (feature.properties.type in MAP_ICON) {
          options.icon = MAP_ICON[feature.properties.type];
        }
      }

      return L.rotatedMarker(latlng, options);
    },

/*
    onEachFeature : function(feature, layer) {
      if (feature.properties) {
        var popupString = '<div class="popup">';
        for ( var k in feature.properties) {
          var v = feature.properties[k];
          popupString += k + ': ' + v + '<br />';
        }
        popupString += '</div>';
        layer.bindPopup(popupString, {
          maxHeight : 200
        });
      }
    },
*/

    filter : function(feature, layer) {
      var zoom = map.getZoom();
      switch (feature.properties.type) {
        case 'airport':
          if (zoom >= 10)
            return true;
          return feature.properties.longestRwyLength_m >= 2000;
          break;

        case 'NDB':
          if (zoom >= 10)
            return true;
          if (zoom >= 8)
            return feature.properties.range_nm >= 30;
          return feature.properties.range_nm > 50;
      }
      return true;
    },

    style : function(feature) {
      if (feature.properties.type == "ILS" || feature.properties.type == "localizer") {
        return {
          color : 'black',
          weight : 1,
        };
      }
      if (feature.properties.type == "airport") {
        return {
          color : 'black',
          weight : 3,
          fill : 'true',
          fillColor : '#606060',
          fillOpacity : 1.0,
          lineJoin : 'bevel',
        };
      }
    },
  },

  onAdd: function( map ) {
    L.GeoJSON.prototype.onAdd.call(this,map);
    this.dirty = true;
    this.update();
  },

  onRemove: function( map ) {
    L.GeoJSON.prototype.onRemove.call(this,map);
    if( this.timeoutid != null )
      clearTimeout( this.timeoutid );
  },


  invalidate: function() {
    this.dirty = true;
  },

  dirty: true,
  timeoutid: null,
  update: function() {
    if (this.dirty) {
      this.dirty = false;
      var bounds = this._map.getBounds();
      var radius = bounds.getSouthWest().distanceTo(bounds.getNorthEast()) / 3704; // radius in NM

      if (radius > 250)
        radius = 250;
      if (radius < 10)
        radius = 10;

      var filter = "vor,ndb,airport";
      if (radius < 60)
        filter += ",ils,dme,loc,om";
      if (radius < 20)
        filter += ",mm";

      var center = this._map.getCenter();
      var lat = center.lat;
      var lon = center.lng;

      var url = "/navdb?q=findWithinRange&type=" + filter + "&range=" + radius + "&lat=" + lat + "&lon=" + lon;

      var that = this;
      var jqxhr = $.get(url).done(function(data) {
        that.clearLayers();
        that.addData(data);
      }).fail(function() {
        alert('failed to load navdb data');
      }).always(function() {
      });
    }
    var that = this;
    timeoutid = setTimeout(function() { that.update() }, 5000);
  },

});

L.navdbLayer = function(options) {
  return new L.NavdbLayer(null,options);
}
