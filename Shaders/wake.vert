// This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  © Michael Horsch - 2005
//  Major update and revisions - 2011-10-07
//  © Emilian Huminiuc and Vivian Meazza
//  Optimisation - 2012-5-05
//  © Emilian Huminiuc and Vivian Meazza

#version 120
#define fps2kts 0.5925

varying vec4 waterTex1;
varying vec4 waterTex2;
varying vec3 viewerdir;
varying vec3 lightdir;
varying vec3 normal;

uniform float osg_SimulationTime;
uniform float WindE, WindN, spd, hdg;

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

    vec4 t1 = vec4(osg_SimulationTime*0.005217, 0.0, 0.0, 0.0);
    vec4 t2 = vec4(osg_SimulationTime*-0.0012, 0.0, 0.0, 0.0);

    float windFactor = -relWindspd * 0.1;
//    float windFactor = sqrt(pow(abs(WindE),2)+pow(abs(WindN),2)) * 0.6;

    waterTex1 = gl_MultiTexCoord0 + t1 * windFactor;
    waterTex2 = gl_MultiTexCoord0 + t2 * windFactor;

    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    gl_Position = ftransform();

}
