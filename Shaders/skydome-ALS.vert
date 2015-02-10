#version 120
 
// Atmospheric scattering shader for flightgear
// Written by Lauri Peltonen (Zan)
// Implementation of O'Neil's algorithm
 
 
uniform mat4 osg_ViewMatrix;
uniform mat4 osg_ViewMatrixInverse;
uniform float hazeLayerAltitude;
uniform float terminator;
uniform float avisibility;
uniform float visibility;
uniform float terrain_alt; 
uniform float air_pollution;

varying vec3 rayleigh;
varying vec3 mie;
varying vec3 eye;
varying vec3 hazeColor;
varying float ct;
varying float cphi;
varying float delta_z;
varying float alt; 
varying float earthShade;

// Dome parameters from FG and screen
const float domeSize = 80000.0;
const float realDomeSize = 100000.0;
const float groundRadius = 0.984503332 * domeSize;
const float altitudeScale = domeSize - groundRadius;
const float EarthRadius = 5800000.0; 

// Dome parameters when calculating scattering
// Assuming dome size is 5.0
const float groundLevel = 0.984503332 * 5.0;
const float heightScale = (5.0 - groundLevel);
 
// Integration parameters
const int nSamples = 7;
const float fSamples = float(nSamples);
 
// Scattering parameters
uniform float rK = 0.0003; //0.00015;
uniform float mK = 0.003; //0.0025;
uniform float density = 0.5; //1.0
//vec3 rayleighK = rK * vec3(5.602, 7.222, 19.644);
vec3 rayleighK = rK * vec3(4.5, 8.62, 17.3);
vec3 mieK = vec3(mK);
vec3 sunIntensity = 10.0*vec3(120.0, 125.0, 130.0);
 
// light_func is a generalized logistic function fit to the light intensity as a function
// of scaled terminator position obtained from Flightgear core

float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
x = x - 0.5;

// use the asymptotics to shorten computations
if (x > 30.0) {return e;}
if (x < -15.0) {return 0.0;}

return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}


// Find intersections of ray to skydome
// ray must be normalized
// cheight is camera height
float intersection (in float cheight, in vec3 ray, in float rad2)
{
  float B = 2.0 * cheight*ray.y;
  float C = cheight*cheight - rad2;  // 25.0 is skydome radius * radius
  float fDet = max(0.0, B*B - 4.0 * C);
  return 0.5 * (-B - sqrt(fDet));
}
 
// Return the scale function at height = 0 for different thetas
float outscatterscale(in float costheta)
{


  float x = 1.0 - costheta;
 
  float a = 1.16941;
  float b = 0.618989;
  float c = 6.34484;
  float d = -31.4138;
  float e = 75.3249;
  float f = -80.1643;
  float g = 32.2878;
 
  return exp(a+x*(b+x*(c+x*(d+x*(e+x*(f+x*g))))));
}
 
// Return the amount of outscatter for different heights and thetas
// assuming view ray hits the skydome
// height is 0 at ground level and 1 at space
// Assuming average density of atmosphere is at 1/4 height
// and atmosphere height is 100 km
float outscatter(in float costheta, in float height)
{
  return density * outscatterscale(costheta) * exp(-4.0 * height);
}
 
 
void main()
{
    // Make sure the dome is of a correct size
    vec4 realVertex = gl_Vertex; //vec4(normalize(gl_Vertex.xyz) * domeSize, 1.0);
 
    // Ground point (skydome center) in eye coordinates
    vec4 groundPoint = gl_ModelViewMatrix * vec4(0.0, 0.0, 0.0, 1.0);
 
    // Calculate altitude as the distance from skydome center to camera
    // Make it so that 0.0 is ground level and 1.0 is 100km (space) level
    float altitude = distance(groundPoint, vec4(0.0, 0.0, 0.0, 1.0));
    float scaledAltitude = altitude / realDomeSize;

    // the local horizon angle
    float radiusEye = EarthRadius + altitude;
    float ctterrain = -sqrt(radiusEye * radiusEye - EarthRadius * EarthRadius)/radiusEye; 


    // Camera's position, z is up!
    float cameraRealAltitude = groundLevel + heightScale*scaledAltitude;
    vec3 camera = vec3(0.0, 0.0, cameraRealAltitude);
    vec3 sample = 5.0 * realVertex.xyz / domeSize; // Sample is the dome vertex
    vec3 relativePosition = camera - sample; // Relative position
 
    // Find intersection of skydome and view ray
    float space = intersection(cameraRealAltitude, -normalize(relativePosition), 25.0);
    if(space > 0.0) {
      // We are in space, calculate correct positiondelta!
      relativePosition -= space * normalize(relativePosition);
    }
 

    vec3 positionDelta = relativePosition / fSamples;
    float deltaLength = length(positionDelta); // Should multiply by something?
 
    vec3 lightDirection = gl_LightSource[0].position.xyz;
 
    // Cos theta of camera's position and sample point
    // Since camera is 0,0,z, dot product is just the z coordinate
    float cameraCosTheta;
 
    // If sample is above camera, reverse ray direction
    if(positionDelta.z < 0.0) cameraCosTheta = -positionDelta.z / deltaLength;
    else cameraCosTheta = positionDelta.z / deltaLength;
 
    
    float cameraCosTheta1 = -positionDelta.z / deltaLength;


    // Total attenuation from camera to skydome
    float totalCameraScatter = outscatter(cameraCosTheta, scaledAltitude);
 
 
    // Do numerical integration of scattering function from skydome to camera
    vec3 color = vec3(0.0);

    // no scattering integrations where terrain is later drawn
    if (cameraCosTheta1 > (ctterrain-0.05))
    {
    for(int i = 0; i < nSamples; i++) 
    {
      // Altitude of the sample point 0...1
      float sampleAltitude = (length(sample) - groundLevel) / heightScale;
 
      // Cosine between the angle of sample's up vector and sun
      // Since lightDirection is in eye space, we must transform sample too
      vec3 sampleUp = gl_NormalMatrix * normalize(sample);
      float cosTheta = dot(sampleUp, lightDirection);
 
      // Scattering from sky to sample point
      float skyScatter = outscatter(cosTheta, sampleAltitude);
 
      // Calculate the attenuation from this point to camera
      // Again, reverse the direction if vertex is over the camera
      float cameraScatter;
      if(relativePosition.z < 0.0) {  // Vertex is over the camera
        cameraCosTheta = -dot(normalize(positionDelta), normalize(sample));

        cameraScatter = totalCameraScatter - outscatter(cameraCosTheta, sampleAltitude);
      } else {  // Vertex is below camera
        cameraCosTheta = dot(normalize(positionDelta), normalize(sample));
        cameraScatter = outscatter(cameraCosTheta, sampleAltitude) - totalCameraScatter;
      }
 
      // Total attenuation
      vec3 totalAttenuate = 4.0 * 3.14159 * (rayleighK + mieK) * (-skyScatter - cameraScatter);
 
      vec3 inScatter = exp(totalAttenuate - sampleAltitude*4.0);
 
      color += inScatter * deltaLength;
      sample += positionDelta;
    }
    }
    color *= sunIntensity;
    ct = cameraCosTheta1;
    rayleigh = rayleighK * color;
    mie = mieK * color;
    eye = gl_NormalMatrix * positionDelta;
 

   // We need to move the camera so that the dome appears to be centered around earth
    // to make the dome render correctly!
    float moveDown = -altitude; // Center dome on camera
    moveDown += groundRadius;
    moveDown += scaledAltitude * altitudeScale; // And move correctly according to altitude
 
    // Vertex transformed correctly so that at 100km we are at space border
    vec4 finalVertex = realVertex - vec4(0.0, 0.0, 1.0, 0.0) * moveDown;

    // prepare some stuff for a ground haze layer
  
    delta_z = hazeLayerAltitude - altitude;
    alt = altitude;
    

    // establish coordinates relative to sun position
    vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
    vec3 lightFull = (gl_ModelViewMatrixInverse * gl_LightSource[0].position).xyz;
    vec3 lightHorizon = normalize(vec3(lightFull.x,lightFull.y, 0.0) );
 

    vec3 relVector = normalize(finalVertex.xyz - ep.xyz);
    
    // and compute the twilight shading
    

    // yprime is the coordinate from/towards terminator
    float yprime;
	
    if (alt > hazeLayerAltitude) // we're looking from above and can see far
	{
    	if (ct < 0.0)
    		{
		yprime = -dot(relVector,lightHorizon) * altitude/-ct;//(ct-0.001);
		yprime = yprime -sqrt(2.0 * EarthRadius * hazeLayerAltitude);
		}
   	 else  // the only haze we see looking up is overcast, assume its altitude
		{
		yprime = -dot(relVector,lightHorizon) * avisibility; 
		yprime = yprime -sqrt(2.0 * EarthRadius * 10000.0);
		}
	}
     else 
	{yprime = -dot(relVector,lightHorizon) * avisibility;
	yprime = yprime -sqrt(2.0 * EarthRadius * hazeLayerAltitude);
	}

    if (terminator > 1000000.0){yprime = -sqrt(2.0 * EarthRadius * hazeLayerAltitude);}

    float terminator_width = 200000.0;
    earthShade = 0.9 * smoothstep((terminator_width+ terminator), (-terminator_width + terminator), yprime) + 0.1;

     float lightArg = (terminator-yprime)/100000.0;

     hazeColor.r = light_func(lightArg, 8.305e-06, 0.161, 4.827-3.0*air_pollution, 3.04e-05, 1.0);
     hazeColor.g = light_func(lightArg, 3.931e-06, 0.264, 3.827, 7.93e-06, 1.0);
     hazeColor.b = light_func(lightArg, 1.330e-05, 0.264, 1.527+2.0*air_pollution, 1.08e-05, 1.0);
     
     //new
     //hazeColor.r = light_func(lightArg, 3.495e-05, 0.161, 3.878, 0.000129, 1.0);
     //hazeColor.g = light_func(lightArg, 1.145e-05, 0.161, 3.827, 1.783e-05, 1.0);
     //hazeColor.b = light_func(lightArg, 0.234, 0.141, 2.572, 0.257, 1.0);

     float intensity = length(hazeColor.xyz);
     float mie_magnitude = 0.5 * smoothstep(350000.0, 150000.0, terminator -sqrt(2.0 * EarthRadius * terrain_alt)); 
     cphi = dot(normalize(relVector), normalize(lightHorizon));
     float mie_angle = (0.5 *  dot(normalize(relVector), normalize(lightFull)) ) + 0.5;
     hazeColor = intensity * ((1.0 - mie_magnitude) + mie_magnitude * mie_angle) * normalize(mix(hazeColor,  vec3 (0.5, 0.58, 0.65), mie_magnitude * (0.5 - 0.5 * mie_angle)) ); 


    // Transform
    gl_Position = gl_ModelViewProjectionMatrix * finalVertex;
}
