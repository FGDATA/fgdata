    L.FollowControl = L.Control.extend({
      options: {
        getPosition: function() { return L.latLng(53.5,10); },
        element:   'div',
        cssClass:  '',
        innerHTML: '',
        initialFollow: true,
        followUpdateInterval: 100,
        noFollowUpdateInterval: 1000,
      },

      initialize: function(options) {
        L.Control.prototype.initialize.call(this,options);
        L.Util.setOptions(this,options);
      },

      onAdd: function(map) {
        this._map = map;
        this._div = L.DomUtil.create(this.options.element, this.options.cssClass );
        this._div.innerHTML = this.options.innerHTML;
        this._doFollow = this.options.initialFollow;
        var that = this;
        this._div.onclick = function() {
          that.setFollow(true);
          return true;
        };
        this.update();
        return this._div;
      },

      onRemove: function(map) {
        this._map = null;
      },

      setFollow: function( v ) {
        this._doFollow = v;
      },

      update: function() {
        if( this._map && this._doFollow ) {
          this._map.setView( this.options.getPosition() );
          var that = this;
          setTimeout( function() { that.update(); }, this.options.noFollowUpdateInterval );
        } else {
          var that = this;
          setTimeout( function() { that.update(); }, this.options.followUpdateInterval );
        }
      },

      _map: null,
      _doFollow: true,
    });

    L.followControl = function( options ) {
      return new L.FollowControl( options );
    }


