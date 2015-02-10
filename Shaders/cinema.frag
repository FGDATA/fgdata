uniform sampler2D lighting_tex;
uniform sampler2D bloom_tex;
uniform sampler2D film_tex;

uniform bool colorShift;
uniform vec3 redShift;
uniform vec3 greenShift;
uniform vec3 blueShift;

uniform bool vignette;
uniform float innerCircle;
uniform float outerCircle;

uniform bool distortion;
uniform vec3 distortionFactor;

uniform bool colorFringe;
uniform float colorFringeFactor;

uniform bool filmWear;

uniform vec2 fg_BufferSize;
uniform float osg_SimulationTime;
// uniform float shutterFreq;
// uniform float shutterDuration;

uniform bool bloomEnabled;
uniform float bloomStrength;
uniform bool bloomBuffers;

void main() {
    vec2 c1 = gl_TexCoord[0].xy;
	vec2 initialCoords = c1;
	vec2 c2;

	if (distortion) {
		c1 = 2.0 * initialCoords - vec2(1.,1.);
		c1 *= vec2( 1.0, fg_BufferSize.y / fg_BufferSize.x );
		float r = length(c1);

		c1 += c1 * dot(distortionFactor.xy, vec2(r*r, r*r*r*r));
		c1 /= distortionFactor.z;

		c1 *= vec2( 1.0, fg_BufferSize.x / fg_BufferSize.y );
		c1 = c1 * .5 + .5;

		if (colorFringe) {
			c2 = 2.0 * initialCoords - vec2(1.,1.);
			c2 *= vec2( 1.0, fg_BufferSize.y / fg_BufferSize.x );
			r = length(c2);

			c2 += c2 * dot(distortionFactor.xy*colorFringeFactor, vec2(r*r, r*r*r*r));
			c2 /= distortionFactor.z;

			c2 *= vec2( 1.0, fg_BufferSize.x / fg_BufferSize.y );
			c2 = c2 * .5 + .5;
		}
	}

	vec3 dirt = vec3(1.0);
	if (filmWear) {
		dirt = texture2D(film_tex, initialCoords*vec2( 1.0, fg_BufferSize.y / fg_BufferSize.x ) + vec2(0.0, osg_SimulationTime * 7.7)).rgb;
	}

    vec4 color = texture2D( lighting_tex, c1 );
	if (bloomEnabled && bloomBuffers)
		color += bloomStrength * texture2D( bloom_tex, c1 );

	if (distortion && colorFringe) {
		color.g = texture2D( lighting_tex, c2 ).g;
		if (bloomEnabled && bloomBuffers)
			color.g += bloomStrength * texture2D( bloom_tex, c2 ).g;
	}

	if (colorShift) {
		vec3 col2;
		col2.r = dot(color.rgb, redShift);
		col2.g = dot(color.rgb, greenShift);
		col2.b = dot(color.rgb, blueShift);
		color.rgb = col2;
	}

	if (vignette) {
		vec2 c = 2.0 * initialCoords - vec2(1.,1.);
		c = c * vec2( 1.0, fg_BufferSize.y / fg_BufferSize.x );
		float l = length(c);
		float f = smoothstep( innerCircle, innerCircle * outerCircle, l );
		color.rgb = (1.0 - f) * color.rgb;
	}
	// if ((osg_FrameNumber % 6) == 0)
		// f = 1.0;

    gl_FragColor = color * vec4(dirt, 1.0);
}
