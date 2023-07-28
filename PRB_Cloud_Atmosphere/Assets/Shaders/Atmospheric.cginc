#define M_PI 3.141592

#define RAYLEIGH_HEIGHT   8e3
#define MIE_HEIGHT        1.2e3

#define BETA_RAY   float3(5.8e-6, 13.5e-6, 33.1e-6) // vec3(5.5e-6, 13.0e-6, 22.4e-6)
#define BETA_MIE   float3(3e-6,3e-6,3e-6)


int ATMOSPHERE_SAMPLES;
float ATMOSPHERE_RADIUS;
float3 EARTH_POS;
float3 SUN_DIR;
float SUN_INTENSITY;

float2 raySphereIntersect(in float3 origin, in float3 dir, in float radius) {
	float a = dot(dir, dir);
	float b = 2.0 * dot(dir, origin);
	float c = dot(origin, origin) - (radius * radius);
	float d = (b * b) - 4.0 * a * c;
    
	if(d < 0.0)return float2(1.0, -1.0);
	float2 res =  float2(
		(-b - sqrt(d)) / (2.0 * a),
		(-b + sqrt(d)) / (2.0 * a)
	);
    return res;
}

float phaseFunMieScattering(float cosTheta)
{
    return 3 * M_PI / 16 * (1 + cosTheta * cosTheta);
}

float3 atmosphereRealTime(in float3 dir, in float3 lightDir)
{
    float2 intersect = raySphereIntersect(EARTH_POS, dir, ATMOSPHERE_RADIUS);
    

    //check ray intersection algo
    float3 samplePos = EARTH_POS + dir * intersect.x;
    float len = length(samplePos);
    if (abs(len - ATMOSPHERE_RADIUS) < 1e-3)
        return float3(0., 1., 0.);
    return float3(1., 0., 0.);

    // float rayEntryDelta = intersect.x;
    // float stepSize = rayEntryDelta / ATMOSPHERE_SAMPLES;

    // float3 sumMie = float3(0, 0, 0);

    // for (int i = 0; i <= ATMOSPHERE_SAMPLES; i++)
    // {
    //     float3 samplePos = EARTH_POS + dir * stepSize * i;

    //     float2 lightIntersect = raySphereIntersect(samplePos, SUN_DIR, ATMOSPHERE_RADIUS);

    //     float rayLightEntryDelta = lightIntersect.x;
    //     float lightStepSize = rayLightEntryDelta / ATMOSPHERE_SAMPLES;

    //     float lightAXi_MieOpticalDepth = 0.;
    //     float planetRadius = EARTH_POS.y;

    //     //AXi optical depth
    //     for (int j = 0; j <= ATMOSPHERE_SAMPLES; j++)
    //     {
    //         float3 lightSamplePos = samplePos + SUN_DIR * lightStepSize * i;

    //         float height = lightSamplePos.y - planetRadius;
    //         lightAXi_MieOpticalDepth += exp(-height / MIE_HEIGHT) * lightStepSize;
    //     }

    //     float XiO_StepSize = length(EARTH_POS - samplePos) / ATMOSPHERE_SAMPLES;
    //     float XiO_MieOpticalDepth = 0.;
    //     //XiO optical depth
    //     for (int j = 0; j <= ATMOSPHERE_SAMPLES; j++)
    //     {
    //         float3 XiO_SamplePos = EARTH_POS + dir * XiO_StepSize * i;

    //         float height = XiO_SamplePos.y - planetRadius;
    //         XiO_MieOpticalDepth += exp(-height / MIE_HEIGHT) * XiO_StepSize;
    //     }

    //     float height = samplePos.y - planetRadius;
    //     sumMie += exp(BETA_MIE * (lightAXi_MieOpticalDepth + XiO_MieOpticalDepth)) * BETA_MIE * exp(-height / MIE_HEIGHT) * stepSize;
    // }

    // float cosTheta = dot(dir, lightDir);

    // return SUN_INTENSITY * phaseFunMieScattering(cosTheta) * sumMie;

}