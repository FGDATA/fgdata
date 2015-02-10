// -*-C++-*-
#version 120

varying float fogFactor;
varying vec3 hazeColor;

uniform float range; // From /sim/rendering/clouds3d-vis-range
uniform float detail_range; // From /sim/rendering/clouds3d_detail-range
uniform float scattering;
uniform float terminator;
uniform float altitude;
uniform float cloud_self_shading;
uniform float visibility;
uniform float moonlight;
uniform float air_pollution;

attribute vec3 usrAttr1;
attribute vec3 usrAttr2;

float alpha_factor = usrAttr1.r;
float shade_factor = usrAttr1.g;
float cloud_height = usrAttr1.b;
float bottom_factor = usrAttr2.r;
float middle_factor = usrAttr2.g;
float top_factor = usrAttr2.b;

const float EarthRadius = 5800000.0;

// light_func is a generalized logistic function fit to the light intensity as a function
// of scaled terminator position obtained from Flightgear core

float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
x = x-0.5;


// use the asymptotics to shorten computations
if (x > 30.0) {return e;}
if (x < -15.0) {return 0.03;}


return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}


float mie_func (in float x, in float Mie)
{
return x + 2.0 * x * Mie * (1.0 -0.8*x) * (1.0 -0.8*x);
}

void main(void)
{


  //shade_factor = shade_factor * cloud_self_shading; 
  //top_factor = top_factor * cloud_self_shading;
  //shade_factor = min(shade_factor, top_factor);
  //middle_factor = min(middle_factor, top_factor);
  //bottom_factor = min(bottom_factor, top_factor);

  float intensity;
  float mix_factor;


  vec3 shadedFogColor = vec3(0.55, 0.67, 0.88); 
  vec3 moonLightColor = vec3 (0.095, 0.095, 0.15) * moonlight * scattering;
  gl_TexCoord[0] = gl_MultiTexCoord0;
  vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
  vec4 l  = gl_ModelViewMatrixInverse * vec4(0.0,0.0,1.0,1.0);
  vec3 u = normalize(ep.xyz - l.xyz);

  // Find a rotation matrix that rotates 1,0,0 into u. u, r and w are
  // the columns of that matrix.
  vec3 absu = abs(u);
  vec3 r = normalize(vec3(-u.y, u.x, 0.0));
  vec3 w = cross(u, r);

  // Do the matrix multiplication by [ u r w pos]. Assume no
  // scaling in the homogeneous component of pos.
  gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
  gl_Position.xyz = gl_Vertex.x * u;
  gl_Position.xyz += gl_Vertex.y * r;
  gl_Position.xyz += gl_Vertex.z * w;
  // Apply Z scaling to allow sprites to be squashed in the z-axis
  gl_Position.z = gl_Position.z * gl_Color.w;

  // Now shift the sprite to the correct position in the cloud.
  gl_Position.xyz += gl_Color.xyz;

  // Determine a lighting normal based on the vertex position from the
  // center of the cloud, so that sprite on the opposite side of the cloud to the sun are darker.
  float n = dot(normalize(-gl_LightSource[0].position.xyz),
                normalize(vec3(gl_ModelViewMatrix * vec4(- gl_Position.x, - gl_Position.y, - gl_Position.z, 0.0))));

  // Determine the position - used for fog and shading calculations
  float fogCoord = length(vec3(gl_ModelViewMatrix * vec4(gl_Color.x, gl_Color.y, gl_Color.z, 1.0)));
  float center_dist = length(vec3(gl_ModelViewMatrix * vec4(0.0,0.0,0.0,1.0)));
  
  if ((fogCoord > detail_range) && (fogCoord > center_dist) && (shade_factor < 0.7)) {
    // More than detail_range away, so discard all sprites on opposite side of
    // cloud center by shifting them beyond the view fustrum
    gl_Position = vec4(0.0,0.0,10.0,1.0);
    gl_FrontColor.a = 0.0;
  } else {
  
    // Determine the shading of the vertex. We shade it based on it's position
    // in the cloud relative to the sun, and it's vertical position in the cloud.
    float shade = mix(shade_factor, top_factor,  smoothstep(-0.3, 0.3, n));
    //if (n < 0) {
    //  shade = mix(top_factor, shade_factor, abs(n));
    //} 
    
    if (gl_Position.z < 0.5 * cloud_height) {
      shade = min(shade, mix(bottom_factor, middle_factor, gl_Position.z * 2.0 / cloud_height));
    } else {
      shade = min(shade, mix(middle_factor, top_factor, gl_Position.z * 2.0 / cloud_height - 1.0));
    }
                  
    //float h = gl_Position.z / cloud_height;
    //if (h < 0.5) {
    //  shade = min(shade, mix(bottom_factor, middle_factor, smoothstep(0.0, 0.5, h)));
    //} else {
    //  shade = min(shade, mix(middle_factor, top_factor, smoothstep(2.0 * (h - 0.5)));    
   // }
    
    // Final position of the sprite
    vec3 relVector = gl_Position.xyz - ep.xyz;
    gl_Position = gl_ModelViewProjectionMatrix * gl_Position;


   // Light at the final position

   // first obtain normal to sun position

    vec3 lightFull = (gl_ModelViewMatrixInverse * gl_LightSource[0].position).xyz;
    vec3 lightHorizon = normalize(vec3(lightFull.x,lightFull.y, 0.0));



   // yprime is the distance of the vertex into sun direction, corrected for altitude
   // the altitude correction is clamped to reasonable values, sometimes altitude isn't parsed correctly, leading
   // to overbright or overdark clouds
   // float vertex_alt = clamp(altitude * 0.30480 + relVector.z,1000.0,10000.0); 
    float vertex_alt = clamp(altitude + relVector.z, 300.0, 10000.0); 
    float yprime = -dot(relVector, lightHorizon);
    float yprime_alt = yprime -sqrt(2.0 * EarthRadius * vertex_alt);

   // two times terminator width governs how quickly light fades into shadow
    float terminator_width = 200000.0;
    float earthShade = 1.0- 0.9*  smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt);
    float earthShadeFactor = 1.0 - smoothstep(0.4, 0.5, earthShade);

    // compute the light at the position
    vec4 light_diffuse;
    
    float lightArg = (terminator-yprime_alt)/100000.0;

    light_diffuse.b = light_func(lightArg -1.2 * air_pollution, 1.330e-05, 0.264, 2.227, 1.08e-05, 1.0);
    light_diffuse.g = light_func(lightArg -0.6 * air_pollution, 3.931e-06, 0.264, 3.827, 7.93e-06, 1.0);
    light_diffuse.r = light_func(lightArg, 8.305e-06, 0.161, 3.827, 3.04e-05, 1.0);
    light_diffuse.a = 1.0;

    //light_diffuse *= cloud_self_shading;
    intensity = (1.0 - (0.8 * (1.0 - earthShade))) *  length(light_diffuse.rgb);
    light_diffuse.rgb = intensity * normalize(mix(light_diffuse.rgb, shadedFogColor, (1.0 - smoothstep(0.5,0.9, min(scattering, cloud_self_shading)  ))));   

    // correct ambient light intensity and hue before sunrise
    if (earthShade < 0.6)
    {
    light_diffuse.rgb = intensity * normalize(mix(light_diffuse.rgb,  shadedFogColor, 1.0 -smoothstep(0.1, 0.6,earthShade ) ));
     
    }

    gl_FrontColor.rgb = intensity * shade * normalize(mix(light_diffuse.rgb, shadedFogColor, smoothstep(0.1,0.4, (1.0 - shade)  ))) ; 
     
    
    
    if ((fogCoord > (0.9 * detail_range)) && (fogCoord > center_dist) && (shade_factor < 0.7)) {
      // cloudlet is almost at the detail range, so fade it out.
      gl_FrontColor.a = 1.0 - smoothstep(0.9 * detail_range, detail_range, fogCoord);
    } else {
      // As we get within 100m of the sprite, it is faded out. Equally at large distances it also fades out.
      gl_FrontColor.a = min(smoothstep(10.0, 100.0, fogCoord), 1.0 - smoothstep(0.9 * range, range, fogCoord));    
    }
    gl_FrontColor.a = gl_FrontColor.a * (1.0 - smoothstep(visibility, 3.0* visibility, fogCoord));

    fogFactor = exp(-fogCoord/visibility);

    // haze of ground haze shader is slightly bluish
    hazeColor = light_diffuse.rgb;
    hazeColor.r = hazeColor.r * 0.83;
    hazeColor.g = hazeColor.g * 0.9; 
    hazeColor = hazeColor * scattering;

   
    // Mie correction
    float Mie;
    float MieFactor;

     if (bottom_factor > 0.6) 
    {
    MieFactor =   dot(normalize(lightFull), normalize(relVector));
    Mie = 1.5 * smoothstep(0.9,1.0, MieFactor) * smoothstep(0.6, 0.8, bottom_factor) * (1.0-earthShadeFactor) ;  
    }
     else {Mie = 0.0;}

     if (Mie > 0.0)
      {
    hazeColor.r = mie_func(hazeColor.r, Mie);
    hazeColor.g = mie_func(hazeColor.g, 0.8* Mie);
    hazeColor.b = mie_func(hazeColor.b, 0.5* Mie);

    gl_FrontColor.r = mie_func(gl_FrontColor.r, Mie);
    gl_FrontColor.g = mie_func(gl_FrontColor.g, 0.8* Mie);
    gl_FrontColor.b = mie_func(gl_FrontColor.b, 0.5*Mie);
    }
   
    gl_FrontColor.rgb = gl_FrontColor.rgb +  moonLightColor * earthShadeFactor;
    hazeColor.rgb = hazeColor.rgb + moonLightColor * earthShadeFactor;
    gl_FrontColor.a = gl_FrontColor.a * alpha_factor; 
    gl_BackColor = gl_FrontColor;
  }
}
