// This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  © Michael Horsch - 2005
//  Major update and revisions - 2011-10-07
//  © Emilian Huminiuc and Vivian Meazza

#version 120

varying vec4    waterTex1;
varying vec4    waterTex2;

varying vec3    viewerdir;
varying vec3    lightdir;
varying vec3    normal;
varying vec3    rawNormal;

varying vec3    VTangent;
varying vec3    VBinormal;

varying vec3 WorldPos;
varying vec2 TopoUV;


uniform float   WindE, WindN;
uniform int     rembrandt_enabled;

uniform float   osg_SimulationTime;
uniform mat4    osg_ViewMatrixInverse;

attribute vec3    tangent;
attribute vec3    binormal;

// constants for the cartezian to geodetic conversion.

const float a = 6378137.0;                  //float a = equRad;
const float squash = 0.9966471893352525192801545;
const float latAdjust = 0.9999074159800018; //geotiff source for the depth map
const float lonAdjust = 0.9999537058469516; //actual extents: +-180.008333333333326/+-90.008333333333340


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
	rawNormal= gl_Normal;
    normal = gl_NormalMatrix * gl_Normal;
    VTangent = normalize(gl_NormalMatrix * tangent);
    VBinormal = normalize(gl_NormalMatrix * binormal);

    viewerdir = vec3(gl_ModelViewMatrixInverse[3]) - vec3(gl_Vertex);

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

    WorldPos = (osg_ViewMatrixInverse *gl_ModelViewMatrix * gl_Vertex).xyz;
    
    ///FIXME: convert cartezian coordinates to geodetic, this
    ///FIXME: duplicates parts of code in SGGeodesy.cxx
    ////////////////////////////////////////////////////////////////////////////
    float e2 = abs(1.0 - squash * squash);
    float ra2 = 1.0/(a * a);
    float e4 = e2 * e2;
    float XXpYY = WorldPos.x * WorldPos.x + WorldPos.y * WorldPos.y;
    float Z = WorldPos.z;
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

    vec2 NormPosXY = normalize(WorldPos.xy);
    vec2 NormPosXZ = normalize(vec2(D, WorldPos.z));
    float signS = sign(WorldPos.y);
    if (-0.00015 <= WorldPos.y && WorldPos.y<=.00015)
        signS = 1.0;
    float signT = sign(WorldPos.z);
    if (-0.0002 <= WorldPos.z && WorldPos.z<=.0002)
        signT = 1.0;
    float cosLon = dot(NormPosXY, vec2(1.0,0.0));
    float cosLat = dot(abs(NormPosXZ), vec2(1.0,0.0));
    TopoUV.s = signS * lonAdjust * degrees(acos(cosLon))/180.;
    TopoUV.t = signT * latAdjust * degrees(acos(cosLat))/90.;
    TopoUV.s = TopoUV.s * 0.5 + 0.5;
    TopoUV.t = TopoUV.t * 0.5 + 0.5;

    //FIXME end/////////////////////////////////////////////////////////////////

    gl_Position = ftransform();
    }