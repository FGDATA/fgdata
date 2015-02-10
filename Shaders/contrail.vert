// -*-C++-*-
#version 120

varying float fogFactor;
varying float distanceFactor;

uniform sampler3D Noise;

uniform float scale_x;
uniform float scale_y;
uniform float scale_z;

uniform float offset_x;
uniform float offset_y;
uniform float offset_z;

uniform float fade_max;
uniform float fade_min;

void main(void)
{
    vec4 rawpos     = gl_Vertex;

    float shade = 0.9;
    float cloud_height = 30000.0;

    // map noise vectors
    vec4 noisevec = texture3D(Noise, rawpos.xyz);
    float noise0 = (noisevec.r * 2.0) - 1.0;
    float noise1 =(noisevec.g * 2.0) - 1.0;
    vec2 noise2 = noisevec.xy;

    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    //gl_TexCoord[0] = gl_MultiTexCoord0 + vec4(textureIndexX, textureIndexY, 0.0, 0.0);
    vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
    vec4 l  = gl_ModelViewMatrixInverse * vec4(0.0,0.0,1.0,1.0);
    vec3 u = normalize(ep.xyz - l.xyz);

    // Find a rotation matrix that rotates 1,0,0 into u. u, r and w are
    // the columns of that matrix.
    vec3 absu = abs(u);
    vec3 r = normalize(vec3(-u.y, u.x, 0.0));
    vec3 w = cross(u, r);

    // Do the matrix multiplication by [ u r w pos]. Scale
    // the x component first
    gl_Position = vec4(gl_Vertex.x * scale_x, 0.0, 0.0, 1.0);
    gl_Position.xyz += gl_Vertex.x * u;
    gl_Position.xyz += gl_Vertex.y * r * scale_y;
    gl_Position.xyz += gl_Vertex.z * w * scale_z;

    // Adjust the position post-rotation and scaling
    gl_Position.yz -= 3.0/2.0;

    // Offset in y and z directions using a random noise factor
    float offset_Y = (noise0 * offset_y) + offset_y/2.0;
    float offset_Z = (noise0 * offset_z) + offset_z/2.0;

    distanceFactor = 1.0 - clamp(abs(noise0), fade_min, fade_max);
//    distanceFactor = 0.5;

    gl_Position.y += offset_Y;
    gl_Position.z += offset_Z;

    gl_Position.xyz += gl_Color.xyz;

    // Determine a lighting normal based on the vertex position from the
    // center of the cloud, so that sprite on the opposite side of the cloud to the sun are darker.
    float n = dot(normalize(-gl_LightSource[0].position.xyz),
        normalize(mat3x3(gl_ModelViewMatrix) * (- gl_Position.xyz)));;

    // Determine the position - used for fog and shading calculations
    vec3 ecPosition = vec3(gl_ModelViewMatrix * gl_Position);
    float fogCoord = abs(ecPosition.z);
    float fract = smoothstep(0.0, cloud_height, gl_Position.z + cloud_height);

    // Final position of the sprite
    gl_Position = gl_ModelViewProjectionMatrix * gl_Position;

    // Calculate the total offset distance in the yx plane, normalised
    /*float distance = normalize(sqrt(pow(gl_Position.y, 2) + pow(gl_Position.z, 2)));
    distanceFactor = 1.0 - clamp(distance, 0.5, 1.0);*/
    // Determine the shading of the sprite based on its vertical position and position relative to the sun.
    n = min(smoothstep(-0.5, 0.0, n), fract);

    // Determine the shading based on a mixture from the backlight to the front
    vec4 backlight = gl_LightSource[0].diffuse * shade;

    gl_FrontColor = mix(backlight, gl_LightSource[0].diffuse, n);
    gl_FrontColor += gl_FrontLightModelProduct.sceneColor;

    // As we get within 100m of the sprite, it is faded out. Equally at large distances it also fades out.
    gl_FrontColor.a = min(smoothstep(10.0, 100.0, fogCoord), 1.0 - smoothstep(60000.0, 80000.0, fogCoord));
    gl_BackColor = gl_FrontColor;

    // Fog doesn't affect clouds as much as other objects.
    fogFactor = exp( -gl_Fog.density * fogCoord);
    fogFactor = clamp(fogFactor, 0.0, 1.0);
}
