// -*-C++-*-

uniform sampler2D texture;

uniform float visibility;
uniform float avisibility;
uniform float hazeLayerAltitude;
uniform float eye_alt;
uniform float terminator;
uniform float size;


varying vec3 relPos;
varying vec2 rawPos;
varying float pixelSize;

float alt;

float Noise2D(in vec2 coord, in float wavelength);

float fog_func (in float targ)
{


float fade_mix;

// for large altitude > 30 km, we switch to some component of quadratic distance fading to
// create the illusion of improved visibility range

targ = 1.25 * targ * smoothstep(0.04,0.06,targ); // need to sync with the distance to which terrain is drawn


if (alt < 30000.0)
	{return exp(-targ - targ * targ * targ * targ);}
else if (alt < 50000.0)
	{
	fade_mix = (alt - 30000.0)/20000.0;
	return fade_mix * exp(-targ*targ - pow(targ,4.0)) + (1.0 - fade_mix) * exp(-targ - pow(targ,4.0));
	}
else
	{
	return exp(- targ * targ - pow(targ,4.0));
	}

}


vec4 light_sprite (in vec2 coord, in float transmission, in float noise)
{

coord.s = coord.s - 0.5;
coord.t = coord.t - 0.5;

float r = length(coord);

if (pixelSize<1.3) {return vec4 (1.0,1.0,1.0,1.0) * 0.08;}

float angle = noise * 6.2832;

float sinphi = dot(vec2 (sin(angle),cos(angle)), normalize(coord));
float sinterm = sin(mod((sinphi-3.0) * (sinphi-3.0),6.2832));
float ray = 0.0;
if (sinterm == 0.0)
	{ray = 0.0;}
else
	{ray = clamp(pow(sinterm,10.0),0.0,1.0);}

float fogEffect =  (1.0-smoothstep(0.4,0.8,transmission));

float intensity = clamp(ray * exp(-40.0 * r * r) + exp(-80.0*r*r),0.0,1.0) + 0.1 * fogEffect * (1.0-smoothstep(0.3, 0.6,r));

return vec4 (1.0,1.0,1.0,1.0) * intensity;

}


void main()
{

    float dist = length(relPos);
    float delta_z = hazeLayerAltitude - eye_alt;
    float transmission;
    float vAltitude;
    float delta_zv;
    float H;
    float distance_in_layer;
    float transmission_arg;

    // Discard the second and third vertex, which are used for directional lighting
    if (gl_Color.a == 0.0) {discard;}

    float noise = Noise2D(rawPos.xy ,1.0);

    // angle with horizon
    float ct = dot(vec3(0.0, 0.0, 1.0), relPos)/dist;


    // we solve the geometry what part of the light path is attenuated normally and what is through the haze layer

    if (delta_z > 0.0) // we're inside the layer
	{
	if (ct < 0.0) // we look down
		{
		distance_in_layer = dist;
		vAltitude = min(distance_in_layer,min(visibility, avisibility)) * ct;
  		delta_zv = delta_z - vAltitude;
		}
	else 	// we may look through upper layer edge
		{
		H = dist * ct;
		if (H > delta_z) {distance_in_layer = dist/H * delta_z;}
		else {distance_in_layer = dist;}
		vAltitude = min(distance_in_layer,visibility) * ct;
  		delta_zv = delta_z - vAltitude;
		}
	}
   else // we see the layer from above, delta_z < 0.0
	{
	H = dist * -ct;
	if (H  < (-delta_z)) // we don't see into the layer at all, aloft visibility is the only fading
		{
		distance_in_layer = 0.0;
		delta_zv = 0.0;
		}
	else
		{
		vAltitude = H + delta_z;
		distance_in_layer = vAltitude/H * dist;
		vAltitude = min(distance_in_layer,visibility) * (-ct);
		delta_zv = vAltitude;
		}
	}


    // ground haze cannot be thinner than aloft visibility in the model,
    // so we need to use aloft visibility otherwise


    transmission_arg = (dist-distance_in_layer)/avisibility;
    if (visibility < avisibility)
	{
	transmission_arg = transmission_arg + (distance_in_layer/visibility);
	}
   else
	{
	transmission_arg = transmission_arg + (distance_in_layer/avisibility);
	}



    transmission =  fog_func(transmission_arg);
    float lightArg = terminator/100000.0;
    float attenuationScale = 1.0 + 20.0 * (1.0 -smoothstep(-15.0, 0.0, lightArg));
    //float dist_att =  exp(-100.0/attenuationScale/size);
   float dist_att = exp(-dist/200.0/size/attenuationScale);

    //vec4 texel = texture2D(texture,gl_TexCoord[0].st);
    vec4 texel = light_sprite(gl_TexCoord[0].st,transmission, noise);
    gl_FragColor =   vec4 (clamp(gl_Color.rgb,0.0,1.0), texel.a * transmission * dist_att);


}
