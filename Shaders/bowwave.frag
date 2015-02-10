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

uniform sampler2D water_normalmap;
uniform sampler2D water_reflection;
uniform sampler2D water_dudvmap;
uniform sampler2D water_reflection_grey;
uniform sampler2D sea_foam;
uniform sampler2D alpha_tex;
uniform sampler2D bowwave_nmap;

uniform float saturation, Overcast, WindE, WindN, spd, hdg;
uniform float CloudCover0, CloudCover1, CloudCover2, CloudCover3, CloudCover4;
uniform int 	Status;

varying vec4 waterTex1; //moving texcoords
varying vec4 waterTex2; //moving texcoords
varying vec3 viewerdir;
varying vec3 lightdir;
varying vec3 normal;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

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
    //calculate the carrier speed north and east in kts
    float speed_north_kts = cos(radians(hdg)) * spd ;
    float speed_east_kts  = sin(radians(hdg)) * spd ;

    //calculate the relative wind speed north and east in kts
    float rel_wind_speed_from_east_kts = WindE*fps2kts + speed_east_kts;
    float rel_wind_speed_from_north_kts = WindN*fps2kts + speed_north_kts;

    //combine relative speeds north and east to get relative windspeed in kts
    rel_wind_speed_kts = sqrt(rel_wind_speed_from_east_kts*rel_wind_speed_from_east_kts
        + rel_wind_speed_from_north_kts*rel_wind_speed_from_north_kts);

    //calculate the relative wind direction
    float rel_wind_from_deg = degrees(atan(rel_wind_speed_from_east_kts, rel_wind_speed_from_north_kts));
    // rel_wind_from_rad = atan(rel_wind_speed_from_east_kts, rel_wind_speed_from_north_kts);
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

//////////////////////

void main(void)
    {
    const vec4 sca = vec4(0.005, 0.005, 0.005, 0.005);
    const vec4 sca2 = vec4(0.02, 0.02, 0.02, 0.02);
    const vec4 tscale = vec4(0.25, 0.25, 0.25, 0.25);

    mat4 RotationMatrix;

    float relWindspd=0;
    float relWinddir=0;

    // compute relative wind speed and direction
    relWind (relWindspd, relWinddir);

    rotationmatrix(relWinddir, RotationMatrix);

    // compute direction to viewer
    vec3 E = normalize(viewerdir);

    // compute direction to light source
    vec3 L = normalize(lightdir);

    // half vector
    vec3 H = normalize(L + E);

    const float water_shininess = 240.0;
    // approximate cloud cover
    float cover = 0.0;
    //bool Status = true;

    float windEffect = relWindspd;                                              //wind speed in kt
    //    float windEffect = sqrt(pow(abs(WindE),2)+pow(abs(WindN),2)) * 0.6;       //wind speed in kt
    float windScale = 15.0/(5.0 + windEffect);                                  //wave scale
    float waveRoughness = 0.05 + smoothstep(0.0, 50.0, windEffect);             //wave roughness filter


    if (Status == 1){
        cover = min(min(min(min(CloudCover0, CloudCover1),CloudCover2),CloudCover3),CloudCover4);
        } else {
            // hack to allow for Overcast not to be set by Local Weather

            if (Overcast == 0){
                cover = 5;
                } else {
                    cover = Overcast * 5;
                }

        }

    //vec4 viewt = normalize(waterTex4);
    vec4 viewt = vec4(-E, 0.0) * 0.6;

    vec4 disdis = texture2D(water_dudvmap, vec2(waterTex2 * tscale)* windScale * 2.0) * 2.0 - 1.0;
    vec4 dist   = texture2D(water_dudvmap, vec2(waterTex1 + disdis*sca2)* windScale * 2.0) * 2.0 - 1.0;
    vec4 fdist  = normalize(dist);
    fdist = -fdist;
    fdist *= sca;

    //normalmap
    rotationmatrix(-relWinddir, RotationMatrix);

    vec4 nmap0 = texture2D(water_normalmap, vec2((waterTex1 + disdis*sca2) * RotationMatrix ) * windScale * 2.0) * 2.0 - 1.0;
    vec4 nmap2 = texture2D(water_normalmap, vec2(waterTex2 * tscale * RotationMatrix ) * windScale * 2.0) * 2.0 - 1.0;
    vec4 nmap3 = texture2D(bowwave_nmap, gl_TexCoord[0].st) * 2.0 - 1.0;
    vec4 vNorm = normalize(mix(nmap3, nmap0 + nmap2, 0.3 )* waveRoughness);
    vNorm = -vNorm;

	//load reflection
    vec4 tmp = vec4(lightdir, 0.0);
    vec4 refTex = texture2D(water_reflection, vec2(tmp + waterTex1) * 32.0) ;
    vec4 refTexGrey = texture2D(water_reflection_grey, vec2(tmp + waterTex1) * 32.0) ;
    vec4 refl ;
	//    cover = 0;

	if(cover >= 1.5){
		refl= normalize(refTex);
		} 
	else
		{
		refl = normalize(refTexGrey);
		refl.r *= (0.75 + 0.15 * cover);
		refl.g *= (0.80 + 0.15 * cover);
		refl.b *= (0.875 + 0.125 * cover);
		refl.a  *= 1.0;
		}

    vec3 N0 = vec3(texture2D(water_normalmap, vec2((waterTex1 + disdis*sca2)* RotationMatrix) * windScale * 2.0) * 2.0 - 1.0); 
    vec3 N1 = vec3(texture2D(water_normalmap, vec2(waterTex2 * tscale * RotationMatrix ) * windScale * 2.0) * 2.0 - 1.0);
    vec3 N2 = vec3(texture2D(bowwave_nmap, gl_TexCoord[0].st)*2.0-1.0);
    //vec3 Nf = normalize((normal+N0+N1)*waveRoughness);
    vec3 N  = normalize(mix(normal+N2, normal+N0+N1, 0.3)* waveRoughness);
    N  = -N;

    // specular
    vec3 specular_color = vec3(gl_LightSource[0].diffuse)
        * pow(max(0.0, dot(N, H)), water_shininess) * 6.0;
    vec4 specular = vec4(specular_color, 0.5);

    specular = specular * saturation * 0.3;

    //calculate fresnel
    vec4 invfres = vec4( dot(vNorm, viewt) );
    vec4 fres = vec4(1.0) + invfres;
    refl *= fres;

    vec4 alpha0 = texture2D(alpha_tex, gl_TexCoord[0].st);

    //calculate final colour
    vec4 ambient_light = gl_LightSource[0].diffuse;
    vec4 finalColor;

    //    cover = 0;

    if(cover >= 1.5){
        finalColor = refl + specular;
        } else {
            finalColor = refl;
        }

    //add foam

    float foamSlope = 0.05 + 0.01 * windScale;
    //float waveSlope = mix(N0.g, N1.g, 0.25);

    vec4 foam_texel = texture2D(sea_foam, vec2(waterTex2 * tscale) * 50.0);
    float waveSlope = N.g; 

    if (windEffect >= 12.0)
        if (waveSlope >= foamSlope){
            finalColor = mix(finalColor, max(finalColor, finalColor + foam_texel), smoothstep(foamSlope, 0.5, N.g));
            }
            
    //generate final colour
        finalColor *= ambient_light+ alpha0 * 0.35;
        finalColor.rgb = fog_Func(finalColor.rgb, fogType);
        gl_FragColor = vec4(finalColor.rgb, alpha0.a * 1.35);

    }
