// -*- mode: C; -*-
// Licence: GPL v2
// Author: Frederic Bouvier.
//

varying vec3 ecNormal;
varying float alpha;
void main() {
    // Determine the rotation for the building.  The Color alpha value provides rotation information
    float sr = sin(6.28 * gl_Color.a);
    float cr = cos(6.28 * gl_Color.a);
    
    vec3 position = gl_Vertex.xyz;
    
    // Rotation of the building and movement into position
    position.xy = vec2(dot(position.xy, vec2(cr, sr)), dot(position.xy, vec2(-sr, cr)));
    position = position + gl_Color.xyz;
    
    gl_Position  = gl_ModelViewProjectionMatrix * vec4(position,1.0);

    // Rotate the normal.
    ecNormal = gl_Normal;
    ecNormal.xy = vec2(dot(ecNormal.xy, vec2(cr, sr)), dot(ecNormal.xy, vec2(-sr, cr)));
    ecNormal = gl_NormalMatrix * ecNormal;
  
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    gl_FrontColor = vec4(1.0, 1.0, 1.0, 1.0);
    gl_BackColor = vec4(1.0, 1.0, 1.0, 1.0);
    alpha = 1.0;
}
