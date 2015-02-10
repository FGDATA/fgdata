// -*-C++-*-

// Shader that uses OpenGL state values to do per-pixel lighting
//
// The only light used is gl_LightSource[0], which is assumed to be
// directional.
//
// Diffuse colors come from the gl_Color, ambient from the material. This is
// equivalent to osg::Material::DIFFUSE.
// Haze part added by Thorsten Renk, Oct. 2011


#define MODE_OFF 0
#define MODE_DIFFUSE 1
#define MODE_AMBIENT_AND_DIFFUSE 2

// The constant term of the lighting equation that doesn't depend on
// the surface normal is passed in gl_{Front,Back}Color. The alpha
// component is set to 1 for front, 0 for back in order to work around
// bugs with gl_FrontFacing in the fragment shader.


varying vec3 relPos;
varying float yprime_alt;

uniform int colorMode;
uniform int wind_effects;
uniform int forest_effects;
uniform float hazeLayerAltitude;
uniform float terminator;
uniform float terrain_alt; 
uniform float avisibility;
uniform float visibility;
uniform float overcast;
uniform float ground_scattering;
uniform float snow_level;
uniform float season;
uniform float WindN;
uniform float WindE;

uniform float osg_SimulationTime;

uniform int cloud_shadow_flag;

float earthShade;
float mie_angle;

float shadow_func (in float x, in float y, in float noise, in float dist);
float VoronoiNoise2D(in vec2 coord, in float wavelength, in float xrand, in float yrand);	

// This is the value used in the skydome scattering shader - use the same here for consistency?
const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
//x = x - 0.5;

// use the asymptotics to shorten computations
if (x < -15.0) {return 0.0;}

return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}


void main()
{

  //vec4 light_diffuse;
  vec4 light_ambient;

  vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);

  float yprime;
  float lightArg;
  float intensity;
  float vertex_alt;
  float scattering;

// this code is copied from tree.vert

  float numVarieties = gl_Normal.z;
  float texFract = floor(fract(gl_MultiTexCoord0.x) * numVarieties) / numVarieties;
  texFract += floor(gl_MultiTexCoord0.x) / numVarieties;
  
  // Determine the rotation for the tree.  The Fog Coordinate provides rotation information
  // to rotate one of the quands by 90 degrees.  We then apply an additional position seed
  // so that trees aren't all oriented N/S
  float sr = sin(gl_FogCoord + gl_Color.x);
  float cr = cos(gl_FogCoord + gl_Color.x);
  gl_TexCoord[0] = vec4(texFract, gl_MultiTexCoord0.y, 0.0, 0.0);
  
  // Determine the y texture coordinate based on whether it's summer, winter, snowy.
  gl_TexCoord[0].y =  gl_TexCoord[0].y + 0.25 * step(snow_level, gl_Color.z) + 0.5 * season;

  // scaling
  vec3 position = gl_Vertex.xyz * gl_Normal.xxy;

  // Rotation of the generic quad to specific one for the tree.
  position.xy = vec2(dot(position.xy, vec2(cr, sr)), dot(position.xy, vec2(-sr, cr)));


 // Shear by wind.  Note that this only applies to the top vertices    
  if (wind_effects > 0)           
  	{
	position.x = position.x + position.z * (sin(osg_SimulationTime * 1.8 + (gl_Color.x + gl_Color.y + gl_Color.z) * 0.01) + 1.0) * 0.0025 * WindN;
  	position.y = position.y + position.z * (sin(osg_SimulationTime * 1.8 + (gl_Color.x + gl_Color.y + gl_Color.z) * 0.01) + 1.0) * 0.0025 * WindE;
	}
	
  // Scale by random domains	
  float voronoi;
  if (forest_effects > 0)
	{
	voronoi = 0.5 + 1.0 * VoronoiNoise2D(gl_Color.xy, 200.0, 1.5, 1.5);	
	position.xyz = position.xyz * voronoi;  
 	}
 
  // Move to correct location (stored in gl_Color)
  position = position + gl_Color.xyz;
  gl_Position   = gl_ModelViewProjectionMatrix * vec4(position,1.0);

  vec3 ecPosition = vec3(gl_ModelViewMatrix * vec4(position, 1.0));
  //normal = normalize(-ecPosition);

  //float n = dot(normalize(gl_LightSource[0].position.xyz), normalize(-ecPosition));
  

  //vec4 diffuse_color = gl_FrontMaterial.diffuse * max(0.1, n);
  //diffuse_color.a = 1.0;
  vec4 ambient_color = gl_FrontMaterial.ambient;

    // here start computations for the haze layer
    // we need several geometrical quantities

    // first current altitude of eye position in model space
    vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
    
    // and relative position to vector
    relPos = position - ep.xyz;

    // unfortunately, we need the distance in the vertex shader, although the more accurate version
    // is later computed in the fragment shader again
    float dist = length(relPos);

    // altitude of the vertex in question, somehow zero leads to artefacts, so ensure it is at least 100m
    vertex_alt = max(position.z,100.0);
    scattering = ground_scattering + (1.0 - ground_scattering) * smoothstep(hazeLayerAltitude -100.0, hazeLayerAltitude + 100.0, vertex_alt); 

    // branch dependent on daytime

if (terminator < 1000000.0) // the full, sunrise and sunset computation
{
    

    // establish coordinates relative to sun position

    vec3 lightFull = (gl_ModelViewMatrixInverse * gl_LightSource[0].position).xyz;
    vec3 lightHorizon = normalize(vec3(lightFull.x,lightFull.y, 0.0));
  

    
    // yprime is the distance of the vertex into sun direction
    yprime = -dot(relPos, lightHorizon);

    // this gets an altitude correction, higher terrain gets to see the sun earlier
    yprime_alt = yprime - sqrt(2.0 * EarthRadius * vertex_alt);

    // two times terminator width governs how quickly light fades into shadow
    // now the light-dimming factor
    earthShade = 0.6 * (1.0 - smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt)) + 0.4;
  
   // parametrized version of the Flightgear ground lighting function
    lightArg = (terminator-yprime_alt)/100000.0;

    // directional scattering for low sun
    if (lightArg < 10.0)
    	{mie_angle = (0.5 *  dot(normalize(relPos), normalize(lightFull)) ) + 0.5;}
    else 
	{mie_angle = 1.0;}


   light_ambient.r = light_func(lightArg, 0.236, 0.253, 1.073, 0.572, 0.33);
   light_ambient.g = light_ambient.r * 0.4/0.33; 
   light_ambient.b = light_ambient.r * 0.5/0.33; 
   light_ambient.a = 1.0;

   




// correct ambient light intensity and hue before sunrise
if (earthShade < 0.5)
	{
	//light_ambient = light_ambient * (0.4 + 0.6 * smoothstep(0.2, 0.5, earthShade));
	intensity = length(light_ambient.rgb); 
	light_ambient.rgb = intensity * normalize(mix(light_ambient.rgb,  shadedFogColor, 1.0 -smoothstep(0.1, 0.8,earthShade) ));

	
	}


// the haze gets the light at the altitude of the haze top if the vertex in view is below
// but the light at the vertex if the vertex is above

vertex_alt = max(vertex_alt,hazeLayerAltitude);

if (vertex_alt > hazeLayerAltitude)
	{
	if (dist > 0.8 * avisibility)
		{
		vertex_alt = mix(vertex_alt, hazeLayerAltitude, smoothstep(0.8*avisibility, avisibility, dist));
		yprime_alt = yprime -sqrt(2.0 * EarthRadius * vertex_alt);
		}
	}
else
	{
	vertex_alt = hazeLayerAltitude;
	yprime_alt = yprime -sqrt(2.0 * EarthRadius * vertex_alt);
	}

}
else // the faster, full-day version without lightfields
{

 
    earthShade = 1.0;
    mie_angle = 1.0;
    
    if (terminator > 3000000.0)
	{light_ambient = vec4 (0.33, 0.4, 0.5, 1.0); }
    else
	{

	lightArg = (terminator/100000.0 - 10.0)/20.0;
	
	light_ambient.r = 0.316 + lightArg * 0.016;
	light_ambient.g = light_ambient.r * 0.4/0.33; 
   	light_ambient.b = light_ambient.r * 0.5/0.33;
	light_ambient.a = 1.0;
	}  
    

    yprime_alt = -sqrt(2.0 * EarthRadius * hazeLayerAltitude);
}
 
 light_ambient.rgb = light_ambient.rgb * (1.0 + smoothstep(1000000.0, 3000000.0,terminator));

// tree shader lighting

if (cloud_shadow_flag == 1) 
		{light_ambient.rgb = light_ambient.rgb * (0.5 + 0.5 * shadow_func(relPos.x, relPos.y, 1.0, dist));}


  //vec4 ambientColor = gl_FrontLightModelProduct.sceneColor + 
  //gl_FrontColor = ambientColor;
  gl_FrontColor = light_ambient * gl_FrontMaterial.ambient;
  gl_FrontColor.a = mie_angle; gl_BackColor.a = mie_angle; 




}

