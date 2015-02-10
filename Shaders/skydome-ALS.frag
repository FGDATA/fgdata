// -*-C++-*-

#version 120
 
// Atmospheric scattering shader for flightgear
// Written by Lauri Peltonen (Zan)
// Implementation of O'Neil's algorithm
// Ground haze layer added by Thorsten Renk
 
varying vec3 rayleigh;
varying vec3 mie;
varying vec3 eye;
varying vec3 hazeColor;
varying float ct;
varying float cphi;
varying float delta_z;
varying float alt;
varying float earthShade;
 
uniform float overcast;
uniform float saturation;
uniform float visibility;
uniform float avisibility;
uniform float scattering;
uniform float terminator;
uniform float cloud_self_shading;
uniform float horizon_roughness;
uniform float landing_light1_offset;
uniform float landing_light2_offset;

uniform int use_searchlight;
uniform int use_landing_light;
uniform int use_alt_landing_light;

const float EarthRadius = 5800000.0;

float Noise2D(in vec2 coord, in float wavelength);
float fog_backscatter(in float avisibility);

vec3 searchlight();
vec3 landing_light(in float offset);

float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
x = x - 0.5;

// use the asymptotics to shorten computations
if (x > 30.0) {return e;}
if (x < -15.0) {return 0.0;}

return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}

float miePhase(in float cosTheta, in float g)
{
  float g2 = g*g;
  float a = 1.5 * (1.0 - g2);
  float b = (2.0 + g2);
  float c = 1.0 + cosTheta*cosTheta;
  float d = pow(1.0 + g2 - 2.0 * g * cosTheta, 0.6667);
 
  return (a*c) / (b*d);
}
 
float rayleighPhase(in float cosTheta)
{
  //return 1.5 * (1.0 + cosTheta*cosTheta);
  return 1.5 * (2.0 + 0.5*cosTheta*cosTheta);
}
 

void main()
{

  //vec3 shadedFogColor = vec3(0.65, 0.67, 0.78);
   vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
  float cosTheta = dot(normalize(eye), gl_LightSource[0].position.xyz);
 
  // position of the horizon line

  float lAltitude = alt + delta_z;
  float radiusEye = EarthRadius + alt;
  float radiusLayer = EarthRadius + lAltitude;
  float cthorizon;
  float ctterrain;

  if (radiusEye > radiusLayer) cthorizon = -sqrt(radiusEye * radiusEye - radiusLayer * radiusLayer)/radiusEye;
  else cthorizon = sqrt(radiusLayer * radiusLayer - radiusEye * radiusEye)/radiusLayer;

  ctterrain = -sqrt(radiusEye * radiusEye - EarthRadius * EarthRadius)/radiusEye;

  vec3 color = rayleigh * rayleighPhase(cosTheta);
  color += mie * miePhase(cosTheta, -0.8);

  vec3 black = vec3(0.0,0.0,0.0);

  
  float ovc = overcast;



  float sat = 1.0 - ((1.0 - saturation) * 2.0);
  if (sat < 0.3) sat = 0.3;


  

if (color.r > 0.58) color.r = 1.0 - exp(-1.5 * color.r);
if (color.g > 0.58) color.g = 1.0 - exp(-1.5 * color.g);
if (color.b > 0.58) color.b = 1.0 - exp(-1.5 * color.b);
  


// fog computations for a ground haze layer, extending from zero to lAltitude



float transmission;
float vAltitude;
float delta_zv;

float costheta = ct;

float vis = min(visibility, avisibility);


 if (delta_z > 0.0) // we're inside the layer
	{
  	if (costheta>0.0 + ctterrain) // looking up, view ray intersecting upper layer edge
		{
		transmission  = exp(-min((delta_z/max(costheta,0.1)),25000.0)/vis);
		//transmission = 1.0;
		vAltitude = min(vis * costheta, delta_z);
  		delta_zv = delta_z - vAltitude;
		}

	else // looking down, view range intersecting terrain (which may not be drawn)
		{
		transmission = exp(alt/vis/costheta);
		vAltitude = min(-vis * costheta, alt);
  		delta_zv = delta_z + vAltitude;
		}
	}
  else // we see the layer from above
	{	
	if (costheta < 0.0 + cthorizon) 
		{
		transmission = exp(-min(lAltitude/abs(costheta),25000.0)/vis);
		transmission = transmission * exp(-alt/avisibility/abs(costheta));
		transmission = 1.0 - (1.0 - transmission) * smoothstep(0+cthorizon, -0.02+cthorizon, costheta);
   		vAltitude = min(lAltitude, -vis * costheta);
		delta_zv = vAltitude; 
		}
	else
		{	
		transmission = 1.0;
		delta_zv = 0.0;
		}
	}

// combined intensity reduction by cloud shading and fog self-shading, corrected for Weber-Fechner perception law
float eqColorFactor = 1.0 - 0.1 * delta_zv/vis - (1.0 - min(scattering,cloud_self_shading));


// there's always residual intensity, we should never be driven to zero
if (eqColorFactor < 0.2) eqColorFactor = 0.2;


// postprocessing of haze color
vec3 hColor = hazeColor;


// high altitude desaturation
float intensity = length(hColor);
hColor = intensity * normalize (mix(hColor, intensity * vec3 (1.0,1.0,1.0), 0.7 * smoothstep(5000.0, 50000.0, alt)));

hColor = clamp(hColor,0.0,1.0);

// blue hue
hColor.x = 0.83 * hColor.x;
hColor.y = 0.9 * hColor.y;



// further blueshift when in shadow, either cloud shadow, or self-shadow or Earth shadow, dependent on indirect 
// light

float fade_out = max(0.65 - 0.3 *overcast, 0.45);
intensity = length(hColor);
vec3 oColor = hColor;
oColor = intensity * normalize(mix(oColor,  shadedFogColor, (smoothstep(0.1,1.0,ovc)))); 
oColor = clamp(oColor,0.0,1.0);
color = ovc *  mix(color, oColor * earthShade ,smoothstep(-0.1+ctterrain, 0.0+ctterrain, ct)) + (1.0-ovc) * color; 


hColor = intensity * normalize(mix(hColor,  1.5 * shadedFogColor, 1.0 -smoothstep(0.25, fade_out,earthShade) ));
hColor = intensity * normalize(mix(hColor,  shadedFogColor, (1.0 - smoothstep(0.5,0.9,eqColorFactor)))); 
hColor = hColor * earthShade;

// accounting for overcast and saturation 



color = sat * color + (1.0 - sat) * mix(color, black, smoothstep(0.4+cthorizon,0.2+cthorizon,ct));


// the terrain below the horizon gets drawn in one optical thickness
vec3 terrainHazeColor = eqColorFactor * hColor;	

// determine a visibility-dependent angle for how smoothly the haze blends over the skydome

float hazeBlendAngle = max(0.01,1000.0/avisibility + 0.3 * (1.0 - smoothstep(5000.0, 30000.0, avisibility)));
float altFactor = smoothstep(-300.0, 0.0, delta_z);
float altFactor2 =  0.2 + 0.8 * smoothstep(-3000.0, 0.0, delta_z);
hazeBlendAngle = hazeBlendAngle + 0.1 * altFactor;
hazeBlendAngle = hazeBlendAngle +  (1.0-horizon_roughness) * altFactor2 * 0.1 *  Noise2D(vec2(0.0,cphi), 0.3);

terrainHazeColor = clamp(terrainHazeColor,0.0,1.0);


// don't let the light fade out too rapidly
float lightArg = (terminator + 200000.0)/100000.0;
float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);

// this is for the bare Rayleigh and Mie sky, highly altitude dependent
color.rgb = max(color.rgb, minLight.rgb * (1.0- alt/100000.0) * (1.0 - costheta));

// this is for the terrain drawn
terrainHazeColor = max(terrainHazeColor.rgb, minLight.rgb);

color = mix(color, terrainHazeColor ,smoothstep(hazeBlendAngle + ctterrain, 0.0+ctterrain, ct));


// add the brightening of fog by lights

    vec3 secondary_light = vec3 (0.0,0.0,0.0);

    if (use_searchlight == 1)
	{
	secondary_light.rgb += searchlight();
	}
    if (use_landing_light == 1)
	{
	secondary_light += landing_light(landing_light1_offset);
	}
    if (use_alt_landing_light == 1)
	{
	secondary_light += landing_light(landing_light2_offset);
	}




// mix fog the skydome with the right amount of haze

hColor *= eqColorFactor;
hColor = max(hColor.rgb, minLight.rgb);

hColor = clamp(hColor,0.0,1.0);

color = mix(hColor+secondary_light * fog_backscatter(avisibility),color, transmission);



  gl_FragColor = vec4(color, 1.0);
  gl_FragDepth = 0.1;
}

