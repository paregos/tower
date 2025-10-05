shader_type spatial;

uniform vec4 color : source_color = vec4(1.0);
uniform float roughness = 1.0;
uniform int lightSteps = 2;
uniform bool useRim = true;



void fragment() {
ALBEDO = color.rgb;
ROUGHNESS = roughness;
}

void light() {
//Diffuse lighting
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float NdotLRound = (round(NdotL * float(lightSteps))/ float(lightSteps));


	float rim = 1.0 - dot(NORMAL, VIEW);
	rim = round((rim - .1) * NdotL * float(useRim));
	float shadows = 0.0;
	if(LIGHT_IS_DIRECTIONAL){
		shadows += floor(ATTENUATION);
		DIFFUSE_LIGHT += NdotLRound * ALBEDO * (LIGHT_COLOR) * shadows + (rim * LIGHT_COLOR / PI);
	}
	else{
		shadows += round(ATTENUATION * float(lightSteps)) / float(lightSteps);
		DIFFUSE_LIGHT += (LIGHT_COLOR / PI) * shadows;
	}
}
