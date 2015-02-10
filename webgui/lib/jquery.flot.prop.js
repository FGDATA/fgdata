(function ($) {
    function init(plot) {

      function optionProcessor(plot, options) {
      }

      plot.hooks.processOptions.push(optionProcessor);

      var presample = { x: 0, y: 0, n: 0 };

      plot.plotPropertyNode = function(n) {
        var maxData = Math.floor(this.width() / 2);
        if( maxData < 10 ) return;

        var probeWidth = this.getOptions().historyLength / maxData;
        var x = Math.floor(n.ts/probeWidth)*probeWidth;
        var y = n.value * 1.0;

        // first call 
        if( presample.n == 0 ) {
          presample.x = x;
        }
        
        // same period as previous call?
        if( x == presample.x ) {
          // sum up the sample
          presample.y += y;
          presample.n++;
          return;
        }

        var sampledY = presample.y/presample.n;
        var sampledX = presample.x;

        // start sample next period
        presample.x = x;
        presample.y = y;
        presample.n = 1;
        
        var series = this.getData();
        var data;
        for( var  seriesNumber = 0; 
             seriesNumber < series.length; 
             seriesNumber++ ) {
          if( n.path == series[seriesNumber].propertyPath ) {
            data = series[seriesNumber].data;
            break;
          }
        }

        if( ! data ) return;

        data.push([sampledX, sampledY]);

        var toomany = data.length - maxData;
        if (toomany > 0) {
           // slice returns a new array, so set series data 
           series[seriesNumber].data = data.slice(toomany);;
        }

        this.setData(series);

        if( data.length >= 2 ) {
          var xaxis = this.getAxes().xaxis;
          var v = Math.ceil(data[data.length-1][0]);
          v = Math.ceil(v/5)*5;
          xaxis.options.max = v;
          xaxis.options.min = xaxis.options.max - this.getOptions().historyLength;
          var yaxis = this.getAxes().yaxis;
          yaxis.options.min = Math.floor(yaxis.datamin);
          yaxis.options.max = Math.ceil(yaxis.datamax);
          this.setupGrid();
        }
        this.draw();
      }
    }

    var options = { historyLength: 60 };

    $.plot.plugins.push({
        init: init,
        options: options,
        name: "propflot",
        version: "0.1"
    });
})(jQuery);
