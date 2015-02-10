// This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  © Michael Horsch - 2005
//  Major update and revisions - 2011-10-07
//  © Emilian Huminiuc and Vivian Meazza

#version 120

varying vec4 waterTex1;
varying vec4 waterTex2;
varying vec4 waterTex4;
varying vec3 relPos;
varying vec3 rawPos;
varying vec2 TopoUV;

varying vec3 viewerdir;
varying vec3 lightdir;
varying float steepness;


varying float earthShade;
varying float yprime_alt;
varying float mie_angle;

uniform float osg_SimulationTime;
uniform float WindE, WindN;
uniform float hazeLayerAltitude;
uniform float terminator;
uniform float terrain_alt;
uniform float avisibility;
uniform float visibility;
uniform float overcast;
uniform float ground_scattering;

uniform int ocean_flag;

uniform mat4 osg_ViewMatrixInverse;

// constants for the cartesian to geodetic conversion.

const float a = 6378137.0;                  //float a = equRad;
const float squash = 0.9966471893352525192801545;
const float latAdjust = 0.9999074159800018; //geotiff source for the depth map
const float lonAdjust = 0.9999537058469516; //actual extents: +-180.008333333333326/+-90.008333333333340


vec3 specular_light;

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


////fog "include"////////
// uniform int fogType;
//
// void fog_Func(int type);
/////////////////////////

/////// functions /////////

void rotationmatrix(in float angle, out mat4 rotmat)
{
    rotmat = mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
        sin( angle ),  cos( angle ), 0.0, 0.0,
        0.0         ,  0.0         , 1.0, 0.0,
        0.0         ,  0.0         , 0.0, 1.0 );
}

void main(void)
{

    mat4 RotationMatrix;
  

    vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
    rawPos = (osg_ViewMatrixInverse *gl_ModelViewMatrix * gl_Vertex).xyz;

    vec4 ecPosition = gl_ModelViewMatrix * gl_Vertex;

    viewerdir = vec3(gl_ModelViewMatrixInverse[3]) - vec3(gl_Vertex);
    lightdir = normalize(vec3(gl_ModelViewMatrixInverse * gl_LightSource[0].position));
    if (ocean_flag == 1)
    	{steepness = dot(normalize(gl_Normal), vec3 (0.0, 0.0, 1.0));}
    else
	{steepness = 0.0;}


    waterTex4 = vec4( ecPosition.xzy, 0.0 );

    vec4 t1 = vec4(0.0, osg_SimulationTime * 0.005217, 0.0, 0.0);
    vec4 t2 = vec4(0.0, osg_SimulationTime * -0.0012, 0.0, 0.0);

    float Angle;

    float windFactor = sqrt(WindE * WindE + WindN * WindN) * 0.05;
    if (WindN == 0.0 && WindE == 0.0) {
        Angle = 0.0;
    }else{
        Angle = atan(-WindN, WindE) - atan(1.0);
    }

    rotationmatrix(Angle, RotationMatrix);
    waterTex1 = gl_MultiTexCoord0 * RotationMatrix - t1 * windFactor;

    rotationmatrix(Angle, RotationMatrix);
    waterTex2 = gl_MultiTexCoord0 * RotationMatrix - t2 * windFactor;

//     fog_Func(fogType);
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

    //vec3 lightFull = (gl_ModelViewMatrixInverse * gl_LightSource[0].position).xyz;
    //vec3 lightHorizon = normalize(vec3(lightFull.x,lightFull.y, 0.0));
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

	// correct ambient light intensity and hue before sunrise - seems unnecessary and create artefacts though...
	//if (earthShade < 0.5)
	//{
	//specular_light.rgb = intensity * normalize(mix(specular_light.rgb,  shadedFogColor, 1.0 -smoothstep(0.1, 0.7,earthShade) ));
	//}

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

   float shade_depth =  1.0 * smoothstep (0.6,0.95,ground_scattering) * (1.0-smoothstep(0.1,0.5,overcast)) * smoothstep(0.4,1.5,earthShade);

  specular_light.rgb *= (1.0 + 1.2 * shade_depth);

    yprime_alt = -sqrt(2.0 * EarthRadius * hazeLayerAltitude);

}

// Geodesy lookup for depth map
	float e2 = abs(1.0 - squash * squash);
	float ra2 = 1.0/(a * a);
	float e4 = e2 * e2;
	float XXpYY = rawPos.x * rawPos.x + rawPos.y * rawPos.y;
	float Z = rawPos.z;
	float sqrtXXpYY = sqrt(XXpYY);
	float p = XXpYY * ra2;
	float q = Z*Z*(1.0-e2)*ra2;
	float r = 1.0/6.0*(p + q - e4);
	float s = e4 * p * q/(4.0*r*r*r);
	if ( s >= 2.0 && s <= 0.0)
		s = 0.0;
	float t = pow(1.0+s+sqrt(s*2.0+s*s), 1.0/3.0);
	float u = r + r*t + r/t;
	float v = sqrt(u*u + e4*q);
	float w = (e2*u+ e2*v-e2*q)/(2.0*v);
	float k = sqrt(u+v+w*w)-w;
	float D = k*sqrtXXpYY/(k+e2);

	vec2 NormPosXY = normalize(rawPos.xy);
	vec2 NormPosXZ = normalize(vec2(D, rawPos.z));
	float signS = sign(rawPos.y);
	if (-0.00015 <= rawPos.y && rawPos.y<=.00015)
		signS = 1.0;
	float signT = sign(rawPos.z);
	if (-0.0002 <= rawPos.z && rawPos.z<=.0002)
		signT = 1.0;
	float cosLon = dot(NormPosXY, vec2(1.0,0.0));
	float cosLat = dot(abs(NormPosXZ), vec2(1.0,0.0));
	TopoUV.s = signS * lonAdjust * degrees(acos(cosLon))/180.;
	TopoUV.t = signT * latAdjust * degrees(acos(cosLat))/90.;
	TopoUV.s = TopoUV.s * 0.5 + 0.5;
	TopoUV.t = TopoUV.t * 0.5 + 0.5;

//




gl_FrontColor.rgb = specular_light;
gl_BackColor.rgb = gl_FrontColor.rgb;


}
