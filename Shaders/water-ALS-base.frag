// This shader is mostly an adaptation of the shader found at
//  http://www.bonzaisoftware.com/water_tut.html and its glsl conversion
//  available at http://forum.bonzaisoftware.com/viewthread.php?tid=10
//  © Michael Horsch - 2005
//  Major update and revisions - 2011-10-07
//  © Emilian Huminiuc and Vivian Meazza
// ported to lightfield shading Thorsten Renk 2012

#version 120

uniform sampler2D water_normalmap;
uniform sampler2D water_dudvmap;
uniform sampler2D sea_foam;
uniform sampler2D perlin_normalmap;


uniform float saturation, Overcast, WindE, WindN;
uniform float osg_SimulationTime;

varying vec4 waterTex1; //moving texcoords
varying vec4 waterTex2; //moving texcoords
varying vec4 waterTex4; //viewts
varying vec3 viewerdir;
varying vec3 lightdir;
//varying vec3 specular_light;
varying vec3 relPos;

varying float earthShade;
varying float yprime_alt;
varying float mie_angle;

uniform    float WaveFreq ;
uniform    float WaveAmp ;
uniform    float WaveSharp ;
uniform    float WaveAngle ;
uniform    float WaveFactor ;
uniform    float WaveDAngle ;
uniform    float normalmap_dds;


uniform float hazeLayerAltitude;
uniform float terminator;
uniform float terrain_alt; 
uniform float avisibility;
uniform float visibility;
uniform float overcast;
uniform float scattering;
uniform float ground_scattering;
uniform float cloud_self_shading;
uniform float eye_alt;
uniform float sea_r;
uniform float sea_g;
uniform float sea_b;


vec3 specular_light;

//uniform int wquality_level;

const float terminator_width = 200000.0;
const float EarthRadius = 5800000.0;

float fog_func (in float targ, in float alt);
vec3 get_hazeColor(in float light_arg);

/////// functions /////////

void rotationmatrix(in float angle, out mat4 rotmat)
	{
	rotmat = mat4( cos( angle ), -sin( angle ), 0.0, 0.0,
		sin( angle ),  cos( angle ), 0.0, 0.0,
		0.0         ,  0.0         , 1.0, 0.0,
		0.0         ,  0.0         , 0.0, 1.0 );
	}

// wave functions ///////////////////////

struct Wave {
	float freq;  // 2*PI / wavelength
	float amp;   // amplitude
	float phase; // speed * 2*PI / wavelength
	vec2 dir;
	};

Wave wave0 = Wave(1.0, 1.0, 0.5, vec2(0.97, 0.25));
Wave wave1 = Wave(2.0, 0.5, 1.3, vec2(0.97, -0.25));
Wave wave2 = Wave(1.0, 1.0, 0.6, vec2(0.95, -0.3));
Wave wave3 = Wave(2.0, 0.5, 1.4, vec2(0.99, 0.1));




float evaluateWave(in Wave w, vec2 pos, float t)
	{
	return w.amp * sin( dot(w.dir, pos) * w.freq + t * w.phase);
	}

// derivative of wave function
float evaluateWaveDeriv(Wave w, vec2 pos, float t)
	{
	return w.freq * w.amp * cos( dot(w.dir, pos)*w.freq + t*w.phase);
	}

// sharp wave functions
float evaluateWaveSharp(Wave w, vec2 pos, float t, float k)
	{
	return w.amp * pow(sin( dot(w.dir, pos)*w.freq + t*w.phase)* 0.5 + 0.5 , k);
	}

float evaluateWaveDerivSharp(Wave w, vec2 pos, float t, float k)
	{
	return k*w.freq*w.amp * pow(sin( dot(w.dir, pos)*w.freq + t*w.phase)* 0.5 + 0.5 , k - 1) * cos( dot(w.dir, pos)*w.freq + t*w.phase);
	}

void sumWaves(float angle, float dangle, float windScale, float factor, out float ddx, float ddy)
	{
	mat4 RotationMatrix;
	float deriv;
	vec4 P = waterTex1 * 1024;

	rotationmatrix(radians(angle + dangle * windScale + 0.6 * sin(P.x * factor)), RotationMatrix);
	P *= RotationMatrix;

	P.y += evaluateWave(wave0, P.xz, osg_SimulationTime);
	deriv = evaluateWaveDeriv(wave0, P.xz, osg_SimulationTime );
	ddx = deriv * wave0.dir.x;
	ddy = deriv * wave0.dir.y;

	//P.y += evaluateWave(wave1, P.xz, osg_SimulationTime);
	//deriv = evaluateWaveDeriv(wave1, P.xz, osg_SimulationTime);
	//ddx += deriv * wave1.dir.x;
	//ddy += deriv * wave1.dir.y;

	P.y += evaluateWaveSharp(wave2, P.xz, osg_SimulationTime, WaveSharp);
	deriv = evaluateWaveDerivSharp(wave2, P.xz, osg_SimulationTime, WaveSharp);
	ddx += deriv * wave2.dir.x;
	ddy += deriv * wave2.dir.y;

	//P.y += evaluateWaveSharp(wave3, P.xz, osg_SimulationTime, WaveSharp);
	//deriv = evaluateWaveDerivSharp(wave3, P.xz, osg_SimulationTime, WaveSharp);
	//ddx += deriv * wave3.dir.x;
	//ddy += deriv * wave3.dir.y;
	}



void main(void)
	{


        vec3 shadedFogColor = vec3(0.55, 0.67, 0.88);
	float effective_scattering = min(scattering, cloud_self_shading);

	float dist = length(relPos);
	const vec4 sca = vec4(0.005, 0.005, 0.005, 0.005);
	const vec4 sca2 = vec4(0.02, 0.02, 0.02, 0.02);
	const vec4 tscale = vec4(0.25, 0.25, 0.25, 0.25);

	mat4 RotationMatrix;

	// compute direction to viewer
	vec3 E = normalize(viewerdir);

	// compute direction to light source
	vec3 L = lightdir; // normalize(lightdir);

	// half vector
	vec3 Hv = normalize(L + E);

	//vec3 Normal = normalize(normal);
	vec3 Normal = vec3 (0.0, 0.0, 1.0);

	const float water_shininess = 240.0;

	// approximate cloud cover
	//float cover = 0.0;
	//bool Status = true;

	float windEffect = sqrt( WindE*WindE + WindN*WindN ) * 0.6; 				//wind speed in kt
	float windScale =  15.0/(3.0 + windEffect);             											//wave scale
	float windEffect_low = 0.3 + 0.7 * smoothstep(0.0, 5.0, windEffect);    				//low windspeed wave filter
	float waveRoughness = 0.01 + smoothstep(0.0, 40.0, windEffect);						//wave roughness filter

	float mixFactor = 0.2 + 0.02 * smoothstep(0.0, 50.0, windEffect);
	//mixFactor = 0.2;
	mixFactor = clamp(mixFactor, 0.3, 0.8);

	// there's no need to do wave patterns or foam for pixels which are so far away that we can't actually see them
	// we only need detail in the near zone or where the sun reflection is

	int detail_flag;
	if ((dist > 15000.0) && (dot(normalize(vec3 (lightdir.x, lightdir.y, 0.0) ), normalize(relPos)) < 0.7 ))  {detail_flag = 0;} 
	else {detail_flag = 1;}
	
	//detail_flag = 1;

	// sine waves
	float ddx, ddx1, ddx2, ddx3, ddy, ddy1, ddy2, ddy3;
	float angle;


	ddx = 0.0, ddy = 0.0;
	ddx1 = 0.0, ddy1 = 0.0;
	ddx2 = 0.0, ddy2 = 0.0;
	ddx3 = 0.0, ddy3 = 0.0;
	if (detail_flag == 1)
	{
	angle = 0.0;

	wave0.freq = WaveFreq ;
	wave0.amp = WaveAmp;
	wave0.dir =  vec2 (0.0, 1.0); //vec2(cos(radians(angle)), sin(radians(angle)));

	angle -= 45;
	wave1.freq = WaveFreq * 2.0 ;
	wave1.amp = WaveAmp * 1.25;
	wave1.dir =  vec2(0.70710, -0.7071); //vec2(cos(radians(angle)), sin(radians(angle)));

	angle += 30;
	wave2.freq = WaveFreq * 3.5;
	wave2.amp = WaveAmp * 0.75;
	wave2.dir =  vec2(0.96592, -0.2588);// vec2(cos(radians(angle)), sin(radians(angle)));

	angle -= 50;
	wave3.freq = WaveFreq * 3.0 ;
	wave3.amp = WaveAmp * 0.75;
	wave3.dir =  vec2(0.42261, -0.9063); //vec2(cos(radians(angle)), sin(radians(angle)));

	// sum waves

	sumWaves(WaveAngle, -1.5, windScale, WaveFactor, ddx, ddy);
	sumWaves(WaveAngle, 1.5, windScale, WaveFactor, ddx1, ddy1);

	//reset the waves
	angle = 0.0;
	float waveamp = WaveAmp * 0.75;

	wave0.freq = WaveFreq ;
	wave0.amp = waveamp;
	wave0.dir =  vec2 (0.0, 1.0); //vec2(cos(radians(angle)), sin(radians(angle)));

	angle -= 20;
	wave1.freq = WaveFreq * 2.0 ;
	wave1.amp = waveamp * 1.25;
	wave1.dir =  vec2(0.93969, -0.34202);// vec2(cos(radians(angle)), sin(radians(angle)));

	angle += 35;
	wave2.freq = WaveFreq * 3.5;
	wave2.amp = waveamp * 0.75;
	wave2.dir =  vec2(0.965925, 0.25881);  //vec2(cos(radians(angle)), sin(radians(angle)));

	angle -= 45;
	wave3.freq = WaveFreq * 3.0 ;
	wave3.amp = waveamp * 0.75;
	wave3.dir =  vec2(0.866025, -0.5); //vec2(cos(radians(angle)), sin(radians(angle)));


	//sumWaves(WaveAngle + WaveDAngle, -1.5, windScale, WaveFactor, ddx2, ddy2);
	//sumWaves(WaveAngle + WaveDAngle, 1.5, windScale, WaveFactor, ddx3, ddy3);
		
	}
	// end sine stuff

	//cover = 5.0 * smoothstep(0.6, 1.0, scattering);
	//cover = 5.0 * ground_scattering;

	vec4 viewt = normalize(waterTex4);

	vec4 disdis = texture2D(water_dudvmap, vec2(waterTex2 * tscale)* windScale) * 2.0 - 1.0;

	vec4 vNorm;	

	
	//normalmaps
	vec4 nmap   = texture2D(water_normalmap, vec2(waterTex1 + disdis * sca2) * windScale) * 2.0 - 1.0;
	vec4 nmap1  = texture2D(perlin_normalmap, vec2(waterTex1 + disdis * sca2) * windScale) * 2.0 - 1.0;

	rotationmatrix(radians(3.0 * sin(osg_SimulationTime * 0.0075)), RotationMatrix);
	nmap  += texture2D(water_normalmap, vec2(waterTex2 * RotationMatrix * tscale) * windScale) * 2.0 - 1.0;
	//nmap1 += texture2D(perlin_normalmap, vec2(waterTex2 * RotationMatrix * tscale) * windScale) * 2.0 - 1.0;

	nmap  *= windEffect_low;
	nmap1 *= windEffect_low;

	// mix water and noise, modulated by factor
	vNorm = normalize(mix(nmap, nmap1, mixFactor) * waveRoughness);
	vNorm.r += ddx + ddx1 + ddx2 + ddx3;

	
   	if (normalmap_dds > 0)
        	{vNorm = -vNorm;}		//dds fix
		

	//load reflection
	
	vec4 refl ;

	refl.r = sea_r;
	refl.g = sea_g;
	refl.b = sea_b;
	refl.a = 1.0; 
	

	float intensity;
	// de-saturate for reduced light
	refl.rgb = mix(refl.rgb,  vec3 (0.248, 0.248, 0.248), 1.0 - smoothstep(0.1, 0.8, ground_scattering)); 

  	// de-saturate light for overcast haze
	intensity = length(refl.rgb);
	refl.rgb = mix(refl.rgb,  intensity * vec3 (1.0, 1.0, 1.0), 0.5 * smoothstep(0.1, 0.9, overcast)); 	

	vec3 N;


	

	vec3 N0 = vec3(texture2D(water_normalmap, vec2(waterTex1 + disdis * sca2) * windScale) * 2.0 - 1.0);
	vec3 N1 = vec3(texture2D(perlin_normalmap, vec2(waterTex1 + disdis * sca) * windScale) * 2.0 - 1.0);

	N0 += vec3(texture2D(water_normalmap, vec2(waterTex1 * tscale) * windScale) * 2.0 - 1.0);
	N1 += vec3(texture2D(perlin_normalmap, vec2(waterTex2 * tscale) * windScale) * 2.0 - 1.0);


		
	rotationmatrix(radians(2.0 * sin(osg_SimulationTime * 0.005)), RotationMatrix);
	N0 += vec3(texture2D(water_normalmap, vec2(waterTex2 * RotationMatrix * (tscale + sca2)) * windScale) * 2.0 - 1.0);
	N1 += vec3(texture2D(perlin_normalmap, vec2(waterTex2 * RotationMatrix * (tscale + sca2)) * windScale) * 2.0 - 1.0);

	rotationmatrix(radians(-4.0 * sin(osg_SimulationTime * 0.003)), RotationMatrix);
	N0 += vec3(texture2D(water_normalmap, vec2(waterTex1 * RotationMatrix + disdis * sca2) * windScale) * 2.0 - 1.0);
	N1 += vec3(texture2D(perlin_normalmap, vec2(waterTex1 * RotationMatrix + disdis * sca) * windScale) * 2.0 - 1.0);
		

	N0 *= windEffect_low;
	N1 *= windEffect_low;

	N0.r += (ddx + ddx1 + ddx2 + ddx3);
	N0.g += (ddy + ddy1 + ddy2 + ddy3);

	N = normalize(mix(Normal + N0, Normal + N1, mixFactor) * waveRoughness);

         if (normalmap_dds > 0)
                {N = -N;} //dds fix


	


       specular_light = gl_Color.rgb * earthShade;

	
	vec3 specular_color = vec3(specular_light)
		* pow(max(0.0, dot(N, Hv)), water_shininess) * 6.0;

	// secondary reflection of sky irradiance

	vec3 ER = E - 2.0 * N * dot(E,N);
	float ctrefl = dot(vec3(0.0,0.0,1.0), -normalize(ER));
	//float fresnel = -0.5 + 8.0 * (1.0-smoothstep(0.0,0.4, dot(E,N)));
	float fresnel =  8.0 * (1.0-smoothstep(0.0,0.4, dot(E,N)));
	//specular_color += (ctrefl*ctrefl) * fresnel*  specular_light.rgb;

	specular_color += ((0.15*(1.0-ctrefl* ctrefl) * fresnel) - 0.3) * specular_light.rgb;



	vec4 specular = vec4(specular_color, 0.5);

	specular = specular * saturation * 0.3  * earthShade  ;

	//calculate fresnel
	vec4 invfres = vec4( dot(vNorm, viewt) );
	vec4 fres = vec4(1.0) + invfres;
	refl *= fres;



	vec4 ambient_light;
	//intensity = length(specular_light.rgb);
	ambient_light.rgb = max(specular_light.rgb, vec3(0.05, 0.05, 0.05));
	//ambient_light.rgb = max(intensity * normalize(vec3 (0.33, 0.4, 0.5)), vec3 (0.1,0.1,0.1));
   	ambient_light.a = 1.0;
   	
	
	vec4 finalColor;



	finalColor = refl + specular * smoothstep(0.3, 0.6, ground_scattering);

	//add foam
	vec4 foam_texel = texture2D(sea_foam, vec2(waterTex2 * tscale) * 25.0);
	
	if (dist < 10000.0)
	{
	float foamSlope = 0.10 + 0.1 * windScale;
	float waveSlope = N.g;

	if (windEffect >= 8.0)
		if (waveSlope >= foamSlope){
			finalColor = mix(finalColor, max(finalColor, finalColor + foam_texel), smoothstep(0.01, 0.50, N.g));
			}
	}
		


		finalColor *= ambient_light;



// here comes the terrain haze model


float delta_z = hazeLayerAltitude - eye_alt;
float mvisibility = min(visibility,avisibility);


if (dist > 0.04 * mvisibility)
{


float transmission;
float vAltitude;
float delta_zv;
float H;
float distance_in_layer;
float transmission_arg;


// angle with horizon
float ct = dot(vec3(0.0, 0.0, 1.0), relPos)/dist;


// we solve the geometry what part of the light path is attenuated normally and what is through the haze layer

if (delta_z > 0.0) // we're inside the layer
	{
	if (ct < 0.0) // we look down 
		{
		distance_in_layer = dist;
		vAltitude = min(distance_in_layer,mvisibility) * ct;
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


float eqColorFactor;


if (visibility < avisibility)
	{
	transmission_arg = transmission_arg + (distance_in_layer/visibility);
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/visibility - (1.0 -effective_scattering);

	}
else 
	{
	transmission_arg = transmission_arg + (distance_in_layer/avisibility);
	// this combines the Weber-Fechner intensity
	eqColorFactor = 1.0 - 0.1 * delta_zv/avisibility - (1.0 -effective_scattering);
	}


transmission =  fog_func(transmission_arg, eye_alt);

// there's always residual intensity, we should never be driven to zero
if (eqColorFactor < 0.2) {eqColorFactor = 0.2;}


float lightArg = (terminator-yprime_alt)/100000.0;
vec3 hazeColor = get_hazeColor(lightArg);


// now dim the light for haze
float eShade = 1.0 - 0.9 * smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt);

// Mie-like factor

if (lightArg < 10.0)
	{intensity = length(hazeColor);
	float mie_magnitude = 0.5 * smoothstep(350000.0, 150000.0, terminator-sqrt(2.0 * EarthRadius * terrain_alt));
	hazeColor = intensity * ((1.0 - mie_magnitude) + mie_magnitude * mie_angle) * normalize(mix(hazeColor,  vec3 (0.5, 0.58, 0.65), mie_magnitude * (0.5 - 0.5 * mie_angle)) ); 
	}

// high altitude desaturation of the haze color

intensity = length(hazeColor);


if (intensity > 0.0) // this needs to be a condition, because otherwise hazeColor doesn't come out correctly
	{
	hazeColor = intensity * normalize (mix(hazeColor, intensity * vec3 (1.0,1.0,1.0), 0.7* smoothstep(5000.0, 50000.0, eye_alt)));

	// blue hue of haze
	
	hazeColor.x = hazeColor.x * 0.83;
	hazeColor.y = hazeColor.y * 0.9; 


	// additional blue in indirect light
	float fade_out = max(0.65 - 0.3 *overcast, 0.45);
	intensity = length(hazeColor);
	hazeColor = intensity * normalize(mix(hazeColor,  1.5* shadedFogColor, 1.0 -smoothstep(0.25, fade_out,eShade) )); 

	// change haze color to blue hue for strong fogging
	hazeColor = intensity * normalize(mix(hazeColor,  shadedFogColor, (1.0-smoothstep(0.5,0.9,eqColorFactor)))); 
	}

	// don't let the light fade out too rapidly
	lightArg = (terminator + 200000.0)/100000.0;
	float minLightIntensity = min(0.2,0.16 * lightArg + 0.5);
	vec3 minLight = minLightIntensity * vec3 (0.2, 0.3, 0.4);

	hazeColor *= eqColorFactor * eShade;
	hazeColor.rgb = max(hazeColor.rgb, minLight.rgb);	


	finalColor.rgb = mix(hazeColor, finalColor.rgb,transmission);


	}
	gl_FragColor = finalColor;

}
