# ==============================================================================
# K14 Reticle
# ==============================================================================

var propertyTreeRoot = "/controls/armament/gunsight/";    
var sideEdge = 0.08;
var zCenterLine = getprop(propertyTreeRoot, "zCenterLine");
var topEdge = zCenterLine + 0.04; 

var pipperVisibility = func()
{
    if (getprop(propertyTreeRoot, "reticleSelectorPos") < 2 and  
	    getprop(propertyTreeRoot, "power-on") != 0 and
		getprop("/controls/engines/engine/master-bat") == 1)
	{ 
	   setprop(propertyTreeRoot, "fixedReticleOn", 1);
	}
	else
	{
	   setprop(propertyTreeRoot, "fixedReticleOn", 0);
	}

    if (getprop(propertyTreeRoot, "computer-on") == 1 and 
	    getprop(propertyTreeRoot, "reticleSelectorPos") > 0 and 
		getprop(propertyTreeRoot, "power-on") != 0 and
		getprop("/controls/engines/engine/master-bat") == 1)
    {
        var elevation = call(func getprop(propertyTreeRoot, "elevation"), var err = []);
        if (!size(err))
        {
    	    elevation = elevation * 0.401885 + zCenterLine;
            var azimuth = call(func getprop(propertyTreeRoot, "azimuth"), var err1 = []);
            if (!size(err1)) 
            { 		  
		       azimuth = azimuth * 0.401885;
  	           var ringSize = call(func getprop(propertyTreeRoot, "rangeRingSize"), var err2 = []);
			   if (!size(err2))
			   {	
				  if (elevation + ringSize > topEdge 
					  or (azimuth > 0 and azimuth > sideEdge)
					  or (azimuth < 0 and azimuth < -sideEdge))
				  {
					 setprop(propertyTreeRoot, "diamondTopVisibility", 0);
				  }
				  else
				  {
					 setprop(propertyTreeRoot, "diamondTopVisibility", 1);
				  }
				
				  if (elevation - ringSize > topEdge 
					  or (azimuth > 0 and azimuth > sideEdge)
					  or (azimuth < 0 and azimuth < -sideEdge))
				  {
					 setprop(propertyTreeRoot, "diamondBottomVisibility", 0);
				  }
				  else
				  {
					 setprop(propertyTreeRoot, "diamondBottomVisibility", 1);
				  }
				  
				  if (elevation + (0.5 * ringSize) > topEdge 
					   or (azimuth > 0 and azimuth + (0.866025 * ringSize) > sideEdge)
					   or (azimuth < 0 and azimuth + (0.866025 * ringSize) < -sideEdge))
				  { 
					 setprop(propertyTreeRoot, "diamondURVisibility", 0);
				  }
				  else
				  {
					 setprop(propertyTreeRoot, "diamondURVisibility", 1);
				  }
				
				  if (elevation + (0.5 * ringSize) > topEdge 
					   or (azimuth < 0  and azimuth - (0.866025 * ringSize) < -sideEdge)
					   or (azimuth > 0  and azimuth - (0.866025 * ringSize) > sideEdge))
				  { 
					 setprop(propertyTreeRoot, "diamondULVisibility", 0);
				  }
				  else
				  {
					 setprop(propertyTreeRoot, "diamondULVisibility", 1);
				  }
				
				  if (elevation - (0.5 * ringSize) > topEdge
					  or (azimuth > 0 and azimuth + (0.866025 * ringSize) > sideEdge)
					  or (azimuth < 0  and azimuth + (0.866025 * ringSize) < -sideEdge))
				  {
					 setprop(propertyTreeRoot, "diamondLRVisibility", 0);
				  }
				  else
				  {
					 setprop(propertyTreeRoot, "diamondLRVisibility", 1);
				  }
				
				  if (elevation - (0.5 * ringSize) > topEdge
					  or (azimuth < 0 and azimuth - (0.866025 * ringSize) < -sideEdge)
					  or (azimuth > 0  and azimuth - (0.866025 * ringSize) > sideEdge))
				  {
					 setprop(propertyTreeRoot, "diamondLLVisibility", 0);
				  }
				  else
				  {
					 setprop(propertyTreeRoot, "diamondLLVisibility", 1);
				  }

				  if (elevation > topEdge
					  or (azimuth > 0 and azimuth > sideEdge)
					  or (azimuth < 0 and azimuth < -sideEdge))
				  {
					 setprop(propertyTreeRoot, "pipperVisibility", 0);
				  }
				  else
				  {
					 setprop(propertyTreeRoot, "pipperVisibility", 1);
				  }
				}
		    }
		}
	}
	else
	{
	   setprop(propertyTreeRoot, "diamondTopVisibility", 0);
	   setprop(propertyTreeRoot, "diamondBottomVisibility", 0);
	   setprop(propertyTreeRoot, "diamondURVisibility", 0);
	   setprop(propertyTreeRoot, "diamondULVisibility", 0);
	   setprop(propertyTreeRoot, "diamondLRVisibility", 0);
	   setprop(propertyTreeRoot, "diamondLLVisibility", 0);
	   setprop(propertyTreeRoot, "pipperVisibility", 0);  
	}
}

var scaleRangeFindingReticle = func()
{
   if (getprop(propertyTreeRoot, "gunsightComputerInitialized") == 1)
   {   
      var span = getprop(propertyTreeRoot, "span");   
      if (span < 30)
      {
     	 setprop(propertyTreeRoot, "span", 30);
      }
      else if (span > 120)
      {
	    setprop(propertyTreeRoot, "span", 120);
      }
   
      var range = getprop(propertyTreeRoot, "range");
      if (range < 600)
      {
	     setprop(propertyTreeRoot, "range", 600);
      }
      else if (range > 2400)
      {
	     setprop(propertyTreeRoot, "range", 2400);
     }
   
      var mils = 1000 * (span / range);
      setprop(propertyTreeRoot, "mils", mils); 
      var newRangeRingSize = 0.00019 * mils; # scale mils to meters
      setprop(propertyTreeRoot, "rangeRingSize", newRangeRingSize);  
   }
}   

setlistener("/controls/armament/gunsight/gunsightComputerInitialized", scaleRangeFindingReticle, 1, 0);
setlistener("/controls/armament/gunsight/span", scaleRangeFindingReticle, 1, 0);
setlistener("/controls/armament/gunsight/range", scaleRangeFindingReticle, 1, 0);
setlistener("/controls/armament/gunsight/elevation", pipperVisibility, 1, 0);
setlistener("/controls/armament/gunsight/gunsightComputerInitialized", pipperVisibility, 1, 0);
setlistener("/controls/armament/gunsight/reticleSelectorPos", pipperVisibility, 1, 0);
setlistener("/controls/armament/gunsight/power-on", pipperVisibility, 1, 0);
