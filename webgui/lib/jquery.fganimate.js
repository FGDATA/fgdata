(function($) {
  
  function makeTranslate(a) {
    return makeTransform("translate", a);
  }

  function makeRotate(a) {
    return makeTransform("rotate", a);
  }
  
  function makeTransform( type, a ) {
    var t = type.concat("(");
    if( a != null ) {
      a.forEach( function(ele) {
        t = t.concat(ele).concat(" ");
      });
    }
    return t.concat(") ");
  }

  function evaluate( context,exp ) {
    if( typeof(exp) == 'function' )
      return exp.call(context);
    return exp;
  }

  $.fn.fgAnimateSVG = function(props) {
    if (props) {
      if (props.type == "transform" && props.transforms) {

        // remember predefined transforms
        if( typeof(this.originalTransform) === 'undefined' ) {
          this.originalTransform = this.attr("transform");
          if( typeof(this.originalTransform) === 'undefined' ) {
            this.originalTransform = "";
          }
        }

        var a = "";
        props.transforms.forEach(function(transform) {
          switch (transform.type) {
            case "rotate":
              a = a.concat(makeRotate([ 
                evaluate(transform.props.context,transform.props.a), 
                evaluate(transform.props.context,transform.props.x), 
                evaluate(transform.props.context,transform.props.y) ]));
              break;
            case "translate":
              a = a.concat(makeTranslate([ 
                evaluate(transform.props.context,transform.props.x), 
                evaluate(transform.props.context,transform.props.y) ]));
              break;
          }
        });
        if( this.originalTransform != "" ) {
          a = a.concat(' ').concat(this.originalTransform);
        }
        this.attr("transform", a );
      
      } else if( props.type == "text" ) {
        var tspans = this.children("tspan");
        if( 0 == tspans.length ) {
          this.text(props.text);
        } else {
          tspans.text(props.text);
        }
      }
    }
    return this;
  };

  $.fn.fgLoadInstruments = function( dataTag ) {
    var reply = [];

    this.each(function() {
      var instrumentDefinitionFile = $(this).data(dataTag);
      $.ajax({
        type: "GET",
        url: instrumentDefinitionFile,
        context: this,
        async: false,
        success: function (data,status,xhr) {
          var i = new FGFS.Instrument(data);
          reply.push(i);
          $(this).append(i.svg);
          // set inkscape pagecolor as div background-color
          // somewhat awkward get the namespaced sodipodi:namedview element
          var pagecolor = $(i.svg.getElementsByTagNameNS('http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd', 'namedview')).attr("pagecolor");
          if( pagecolor != null )
            $(this).css("background-color", pagecolor );
        },
        error: function(xhr,status,msg) {
          alert(status + " while reading '" + instrumentDefinitionFile + "': " + msg.toString() );
        },
    });
  });
  return reply;
}

}(jQuery));
