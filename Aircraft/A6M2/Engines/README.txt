Engine / Prop configuration - still in progress!
by Tatsuhiro Nishioka
Last Updated: Jun-16-2011

Note on how I got the prop configuration:
  This is a temporal configuration that I made using javaprop by the
  following steps:

  1) Calcurate the advance ratio (J) for typical configurations
     such as take-off, top-speed, and economy-cruise.
  2) Get Ct and Cp using javaprop at each J number for typical configuration
     by adjusting power, speed, and prop-rpm on the propeller design tab
     
  3) Plot C_THRUST and C_POWER table using Typical Cp / Ct exmaples [1]
     on MS-Excel, and then copy these tables to CS-40B.xml

  3) Adjust cp_factor, ct_factor, and C_THRUST / C_POWER table by flying 
     and monitoring the info obtained with the 2D Panel.
     You also need to volumetric-efficiency and bsfc in Sakae-Type12 for
     better Prop-pitch - EngineRPM - HP matching.

Therefore, there are some known issues shown below:
- Higher engine RPM at low manihold pressure (-200mmHg or lower)
- Too much gas consumed in economy cruise mode
  shuold be 20 US-GAL/H or less at 135Kt-IAS/1850 RPM/-170mmHg @ 3000m, but
  it consumes 25 to 35 US-GAL/H. Top-speed (288Kt-TAS/2500 RPM / +150mmHg @ 4200m)
  configuration has more reasonable gas consumption (should be 85 US-GAL/H, 92 actual).
- Engine RPM at Typical configuration can be revised a bit more.

Note: 
  Gas Milage and gas consumption per hour in cruise condition
  This shows that 135 kt gives the longest distance
  5.649 nm/gal @ 140 kt / 10,500ft, 28.64 gal/h
  5.657 nm/gal @ 135 kt / 10,500ft, 27.49 gal/h
  5.640 nm/gal @ 130 kt / 10,500ft, 26.67 gal/h
  5.610 nm/gal @ 125 kt / 10,500ft, 25.77 gal/h         
  5.580 nm/gal @ 120 kt / 10,500ft, 24.88 gal/h

References:
[1] Unified Propulsion, Chapter VII-E Typical properller performance, MIT cource text
    http://web.mit.edu/16.unified/www/SPRING/propulsion/UnifiedPropulsion7/UnifiedPropulsion7.htm

