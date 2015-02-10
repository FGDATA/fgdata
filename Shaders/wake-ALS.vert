// This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  © Michael Horsch - 2005
//  Major update and revisions - 2011-10-07
//  © Emilian Huminiuc and Vivian Meazza
//  Optimisation - 2012-5-05
//  © Emilian Huminiuc and Vivian Meazza
//  Ported to the Atmospheric Light Scattering Framework
//  by Thorsten Renk, Aug. 2013

#version 120
#define fps2kts 0.5925

varying vec4 waterTex1;
varying vec4 waterTex2;
varying vec3 relPos;
varying vec3 rawPos;
varying vec3 viewerdir;
varying vec3 lightdir;
varying vec3 normal;

varying float steepness;
varying float earthShade;
varying float yprime_alt;
varying float mie_angle;

uniform float osg_SimulationTime;
uniform float WindE, WindN, spd, hdg;
uniform float hazeLayerAltitude;
uniform float terminator;
uniform float terrain_alt;
uniform float avisibility;
uniform float visibility;
uniform float overcast;
uniform float ground_scattering;

uniform mat4 osg_ViewMatrixInverse;

vec3 specular_light;

// This is the value used in the skydome scattering shader - use the same here for consistency?
const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

/////////////////////////


/////// functions /////////

void relWind(out float rel_wind_speed_kts, float rel_wind_from_deg)
{
    //calculate the carrier speed north and east in kts
    float speed_north_kts = cos(radians(hdg)) * spd ;
    float speed_east_kts  = sin(radians(hdg)) * spd ;

    //calculate the relative wind speed north and east in kts
    float rel_wind_speed_from_east_kts = WindE*fps2kts + speed_east_kts;
    float rel_wind_speed_from_north_kts = WindN*fps2kts + speed_north_kts;

    //combine relative speeds north and east to get relative windspeed in kts
    rel_wind_speed_kts = sqrt((rel_wind_speed_from_east_kts * rel_wind_speed_from_east_kts) + (rel_wind_speed_from_north_kts * rel_wind_speed_from_north_kts));

    //calculate the relative wind direction
    rel_wind_from_deg = degrees(atan(rel_wind_speed_from_east_kts, rel_wind_speed_from_north_kts));
}

float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
//x = x - 0.5;

// use the asymptotics to shorten computations
if (x < -15.0) {return 0.0;}

return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}



void main(void)
{

    float relWindspd=0;
    float relWinddir=0;
    //compute relative wind speed and direction
    relWind (relWindspd, relWinddir);

    vec3 N = normalize(gl_Normal);
    normal = N;

    viewerdir = vec3(gl_ModelViewMatrixInverse[3]) - vec3(gl_Vertex);
    lightdir = normalize(vec3(gl_ModelViewMatrixInverse * gl_LightSource[0].position));

    vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
    rawPos = (osg_ViewMatrixInverse *gl_ModelViewMatrix * gl_Vertex).xyz;
	
    vec4 t1 = vec4(osg_SimulationTime*0.005217, 0.0, 0.0, 0.0);
    vec4 t2 = vec4(osg_SimulationTime*-0.0012, 0.0, 0.0, 0.0);

    float windFactor = -relWindspd * 0.1;
//    float windFactor = sqrt(pow(abs(WindE),2)+pow(abs(WindN),2)) * 0.6;

    waterTex1 = gl_MultiTexCoord0 + t1 * windFactor;
    waterTex2 = gl_MultiTexCoord0 + t2 * windFactor;

    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    gl_Position = ftransform();

	// here start computations for the haze layer


  float yprime;
  float lightArg;
  float intensity;
  float vertex_alt;
  float scattering;

    // we need several geometrical quantities

    // first current altitude of eye position in model space
    vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);

    // and relative position to vector
    relPos = gl_Vertex.xyz - ep.xyz;

	
    // unfortunately, we need the distance in the vertex shader, although the more accurate version
    // is later computed in the fragment shader again
    float dist = length(relPos);


// altitude of the vertex in question, somehow zero leads to artefacts, so ensure it is at least 100m
    vertex_alt = max(gl_Vertex.z,100.0);
    scattering = 0.5 + 0.5 * ground_scattering + 0.5* (1.0 - ground_scattering) * smoothstep(hazeLayerAltitude -100.0, hazeLayerAltitude + 100.0, vertex_alt);

    // branch dependent on daytime

if (terminator < 1000000.0) // the full, sunrise and sunset computation
{


    // establish coordinates relative to sun position
    vec3 lightHorizon = normalize(vec3(lightdir.x,lightdir.y, 0.0));

    // yprime is the distance of the vertex into sun direction
    yprime = -dot(relPos, lightHorizon);

    // this gets an altitude correction, higher terrain gets to see the sun earlier
    yprime_alt = yprime - sqrt(2.0 * EarthRadius * vertex_alt);

    // two times terminator width governs how quickly light fades into shadow
    // now the light-dimming factor
    earthShade = 0.6 * (1.0 - smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt)) + 0.4;

   // parametrized version of the Flightgear ground lighting function
    lightArg = (terminator-yprime_alt)/100000.0;

	specular_light.b = light_func(lightArg, 1.330e-05, 0.264, 3.827, 1.08e-05, 1.0);
    specular_light.g = light_func(lightArg, 3.931e-06, 0.264, 3.827, 7.93e-06, 1.0);
   	specular_light.r = light_func(lightArg, 8.305e-06, 0.161, 3.827, 3.04e-05, 1.0);

	specular_light = max(specular_light * scattering, vec3 (0.05, 0.05, 0.05));

	intensity = length(specular_light.rgb);
	specular_light.rgb = intensity * normalize(mix(specular_light.rgb,  shadedFogColor, 1.0 -smoothstep(0.1, 0.6,ground_scattering) ));

	specular_light.rgb = intensity * normalize(mix(specular_light.rgb,  shadedFogColor, 1.0 -smoothstep(0.5, 0.7,earthShade)));


    // directional scattering for low sun
    if (lightArg < 10.0)
	{mie_angle = (0.5 *  dot(normalize(relPos), lightdir) ) + 0.5;}
    else
	{mie_angle = 1.0;}





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
    //vertex_alt = max(gl_Vertex.z,100.0);

    earthShade = 1.0;
    mie_angle = 1.0;

    if (terminator > 3000000.0)
    	{specular_light = vec3 (1.0, 1.0, 1.0);}
    else
	{

	lightArg = (terminator/100000.0 - 10.0)/20.0;
  	specular_light.b = 0.78  + lightArg * 0.21;
  	specular_light.g = 0.907 + lightArg * 0.091;
  	specular_light.r = 0.904 + lightArg * 0.092;
	}

   specular_light = specular_light * scattering;

    yprime_alt = -sqrt(2.0 * EarthRadius * hazeLayerAltitude);

}

gl_FrontColor.rgb = specular_light;
gl_BackColor.rgb = gl_FrontColor.rgb;
	
}
