// -*-C++-*-
//  © Vivian Meazza - 2011

// Shader that uses OpenGL state values to do per-pixel lighting
//
// The only light used is gl_LightSource[0], which is assumed to be
// directional.
//
// Diffuse colors come from the gl_Color, ambient from the material. This is
// equivalent to osg::Material::DIFFUSE.

#version 120
#define fps2kts 0.5925

#define MODE_OFF 0
#define MODE_DIFFUSE 1
#define MODE_AMBIENT_AND_DIFFUSE 2

// The ambient term of the lighting equation that doesn't depend on
// the surface normal is passed in gl_{Front,Back}Color. The alpha
// component is set to 1 for front, 0 for back in order to work around
// bugs with gl_FrontFacing in the fragment shader.
varying vec4 diffuse_term;
varying vec3 normal;
//varying float fogCoord;

uniform int colorMode;
uniform float osg_SimulationTime;
uniform float Offset, AmpFactor, WindE, WindN, spd, hdg;
uniform sampler3D Noise;

////fog "include"////////
//uniform int fogType;
//
//void fog_Func(int type);
/////////////////////////

/////// functions /////////

float normalize_range(float _val)
    {
    if (_val > 180.0)
        return _val - 360.0;
    else
        return _val;
    }

void relWind(out float rel_wind_speed_kts, out float rel_wind_from_rad)
    {
    //calculate speed north and east in kts
    float speed_north_kts = cos(radians(hdg)) * spd ;
    float speed_east_kts  = sin(radians(hdg)) * spd ;

    //calculate the relative wind speed north and east in kts
    float rel_wind_speed_from_east_kts = WindE*fps2kts + speed_east_kts;
    float rel_wind_speed_from_north_kts = WindN*fps2kts + speed_north_kts;

    //combine relative speeds north and east to get relative windspeed in kts
    rel_wind_speed_kts = sqrt(pow(abs(rel_wind_speed_from_east_kts), 2.0)
        + pow(abs(rel_wind_speed_from_north_kts), 2.0));

    //calculate the relative wind direction
    float rel_wind_from_deg = degrees(atan(rel_wind_speed_from_east_kts, rel_wind_speed_from_north_kts));
    //rel_wind_from_rad = atan(rel_wind_speed_from_east_kts, rel_wind_speed_from_north_kts);
    float rel_wind = rel_wind_from_deg - hdg;
    rel_wind = normalize_range(rel_wind);
    rel_wind_from_rad = radians(rel_wind);
    }

void rotationmatrix(in float angle, out mat4 rotmat)
    {
    rotmat = mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
        sin( angle ),  cos( angle ), 0.0, 0.0,
        0.0         ,  0.0         , 1.0, 0.0,
        0.0         ,  0.0         , 0.0, 1.0 );
    }

void main()
    {
    mat4 RotationMatrix;

    float relWindspd=0.0;
    float relWinddir=0.0;

    // compute relative wind speed and direction
    relWind (relWindspd, relWinddir);

    // map noise vector
    vec4 noisevec = texture3D(Noise, gl_Vertex.xyz);

    //waving effect
    float tsec = osg_SimulationTime;
    vec4 pos = gl_Vertex;
    vec4 oldpos = gl_Vertex;

    float freq = (10.0 * relWindspd) + 10.0;
    pos.y = sin((pos.x * 5.0 + tsec * freq )/5.0) * 0.5 ;
    pos.y += sin((pos.z * 5.0 + tsec * freq/2.0)/5.0) * 0.125 ;

    pos.y *= pow(pos.x - Offset, 2.0) * AmpFactor;

    //rotate the flag to align with relative wind
    rotationmatrix(-relWinddir, RotationMatrix);
    pos *= RotationMatrix;
    gl_Position = gl_ModelViewProjectionMatrix * pos;

    //do the colour and fog
    vec4 ecPosition = gl_ModelViewMatrix * gl_Vertex;

    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    normal = gl_NormalMatrix * gl_Normal;
    vec4 ambient_color, diffuse_color;

    if (colorMode == MODE_DIFFUSE) {
        diffuse_color = gl_Color;
        ambient_color = gl_FrontMaterial.ambient;
        } else if (colorMode == MODE_AMBIENT_AND_DIFFUSE) {
            diffuse_color = gl_Color;
            ambient_color = gl_Color;
        } else {
            diffuse_color = gl_FrontMaterial.diffuse;
            ambient_color = gl_FrontMaterial.ambient;
            }

        diffuse_term = diffuse_color * gl_LightSource[0].diffuse;
        vec4 ambient_term = ambient_color * gl_LightSource[0].ambient;

        // Super hack: if diffuse material alpha is less than 1, assume a
        // transparency animation is at work
        if (gl_FrontMaterial.diffuse.a < 1.0)
            diffuse_term.a = gl_FrontMaterial.diffuse.a;
        else
            diffuse_term.a = gl_Color.a;

        // Another hack for supporting two-sided lighting without using
        // gl_FrontFacing in the fragment shader.
        gl_FrontColor.rgb = ambient_term.rgb;  gl_FrontColor.a = 0.0;
        gl_BackColor.rgb = ambient_term.rgb; gl_FrontColor.a = 1.0;
//        fogCoord = abs(ecPosition.z / ecPosition.w);

        //fog_Func(fogType);

    }
