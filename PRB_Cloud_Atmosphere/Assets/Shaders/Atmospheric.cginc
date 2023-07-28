#define M_PI 3.141592

#define RAYLEIGH_HEIGHT   8e3
#define MIE_HEIGHT        1.2e3
#define G          0.75

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

float phaseFunMieScattering(float cosTheta, in float g)
{
    float gg = g * g;
	return (1.0 - gg) / (4.0 * M_PI * pow(1.0 + gg - 2.0 * g * cosTheta, 1.5));
}

float GetPlanetRadius()
{
    return EARTH_POS.y;
}

float GetAtmosphereHeight()
{
    return ATMOSPHERE_RADIUS - GetPlanetRadius();
}

float2 calculateDensities(in float3 pos) {
    float planetRadius = GetPlanetRadius();
	float height = length(pos) - GetPlanetRadius(); // Height above surface
	float2 density;
	density.x = exp(-height / RAYLEIGH_HEIGHT);
	density.y = exp(-height / MIE_HEIGHT);
    return density;
}

float phaseFunRayScattering(float cosTheta)
{
    return 3 * M_PI / 16 * (1 + cosTheta * cosTheta);
}


float3 atmosphereRealTime(in float3 dir, in float3 lightDir)
{
    float2 intersect = raySphereIntersect(EARTH_POS, dir, ATMOSPHERE_RADIUS);

    float rayOffset = max(0.0, intersect.x);
    float maxLen = GetAtmosphereHeight();
    float i_delta = min(intersect.y - rayOffset, maxLen) / ATMOSPHERE_SAMPLES;
    rayOffset += i_delta * 0.5;

    float3 sumMie = float3(0, 0, 0);
    float3 sumRay = float3(0, 0, 0);

    float2 opticalDepth = float2(0, 0);

    for (int i = 0; i <= ATMOSPHERE_SAMPLES; i++)
    {
        float3 samplePos = EARTH_POS + dir * rayOffset;

        float2 lightIntersect = raySphereIntersect(samplePos, SUN_DIR, ATMOSPHERE_RADIUS);

        float j_delta = lightIntersect.y / ATMOSPHERE_SAMPLES;
        float lightRayOffset = j_delta;

        float2 lightOpticalDepth = float2(0, 0);

        //AXi optical depth
        for (int j = 0; j <= ATMOSPHERE_SAMPLES; j++)
        {
            float3 lightSamplePos = samplePos + SUN_DIR * lightRayOffset;

            lightOpticalDepth += calculateDensities(lightSamplePos) * j_delta;

            lightRayOffset += j_delta;
        }

        float2 densities = calculateDensities(samplePos) * i_delta;
        opticalDepth += densities;

        float3 scattered = exp(-(BETA_RAY * (opticalDepth.x + lightOpticalDepth.x) + BETA_MIE * (opticalDepth.y + lightOpticalDepth.y)));
        sumRay += scattered * densities.x;
        sumMie += scattered * densities.y;

        rayOffset += i_delta;
    }

    float cosTheta = dot(dir, lightDir);

    return max(phaseFunMieScattering(cosTheta, G) * sumMie + phaseFunRayScattering(cosTheta)* sumRay, 0);

}