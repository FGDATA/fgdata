# Becker AR-3201 transciever

var ar3201 = func {

setprop("instrumentation/comm/serviceable" ,0);

var chan = 0;
setprop("instrumentation/AR-3201/chan", chan);

var ch=[ 0,0,0,0,0 ];
 ch[0] = getprop("instrumentation/comm/frequencies/selected-mhz");
 ch[1] = 121.5 ;
 ch[2] = 121.5 ;
 ch[3] = 121.5 ;
 ch[4] = 121.5 ;

setprop("instrumentation/AR-3201/stby", ch[0]);
setprop("instrumentation/AR-3201/dummy", ch[0]);
setprop("instrumentation/comm/frequencies/selected-mhz", ch[0]);

setlistener("instrumentation/AR-3201/power", func { 

         if ( getprop("instrumentation/AR-3201/power") == 1 and getprop("instrumentation/comm/serviceable") == 0  )
	      {
		setprop("instrumentation/AR-3201/starting", 1);
                settimer(func { 
				if (getprop("instrumentation/AR-3201/power") > 0) 
				{
				  setprop("instrumentation/AR-3201/starting", 0);
				  setprop("instrumentation/comm/serviceable" ,1)
				}
			      }, 2);			      
	      }

         if (getprop("instrumentation/AR-3201/power") == 0)
	      {
                setprop("instrumentation/AR-3201/starting", 0);
		setprop("instrumentation/comm/serviceable" ,0 );
	      }

 });

setlistener("instrumentation/AR-3201/dummy", func { 

    settimer(func {
    if ( chan  == 0 ) 
    {
        ch[0] = getprop("instrumentation/AR-3201/stby") ;           
        setprop("instrumentation/comm/frequencies/selected-mhz" ,ch[0] );        
    } 
    }, 0.02);

 });

setlistener("instrumentation/AR-3201/chan", func { 

    chan = getprop("instrumentation/AR-3201/chan" );
    setprop("instrumentation/comm/frequencies/selected-mhz", ch[chan] );

 });



setlistener("instrumentation/AR-3201/store", func { 

    chan = getprop("instrumentation/AR-3201/chan" );
    ch[chan] = getprop("instrumentation/AR-3201/stby");
    setprop("instrumentation/comm/frequencies/selected-mhz", ch[chan] );

 });

}

# Start the transciever ASAP
ar3201();
