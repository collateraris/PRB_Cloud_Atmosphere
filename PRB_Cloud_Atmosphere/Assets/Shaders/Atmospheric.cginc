#define M_PI 3.141592
#define HALF_PI 1.570796
#define R_PI 0.3183099

#define LOG2 log(2.)
#define RLOG2 1./log(2.)

#define RAYLEIGH_HEIGHT   8e3
#define MIE_HEIGHT        1.2e3
#define MIE_G          0.75

#define BETA_RAY   float3(5.8e-6, 13.5e-6, 33.1e-6) // vec3(5.5e-6, 13.0e-6, 22.4e-6)
#define BETA_MIE   float3(3e-6,3e-6,3e-6)
#define Y_DIR   float3(0,1,0)

#define Rg 6360000.0
#define Rt 6420000.0
#define RL 6421000.0
#define RES_R 32.0
#define RES_MU 128.0
#define RES_MU_S 32.0
#define RES_NU 8.0

#define cloudSpeed 0.02
#define cloudHeight 1600.0
#define cloudThickness 500.0
#define cloudMinHeight cloudHeight
#define cloudMaxHeight (cloudThickness + cloudMinHeight)
#define cloudDensity 0.03

int ATMOSPHERE_SAMPLES;
float ATMOSPHERE_RADIUS;
float3 EARTH_POS;
float3 SUN_DIR;
float SUN_INTENSITY;
float iTime;

sampler2D _Transmittance, _Irradiance;
Texture2D _PerlinNoise2D;
SamplerState sampler_PerlinNoise2D;
sampler3D _Inscatter;

#define d0(x) (abs(x) + 1e-8)
#define d02(x) (abs(x) + 1e-3)

float3 scatter(float3 coeff, float cosTheta)
{
	return coeff * cosTheta;
}

float3 transmittance(float3 coeff, float cosTheta)
{
	return exp2(scatter(coeff, -cosTheta));
}

float calcParticleThickness(float depth)
{
   	
    depth = depth * 2.0;
    depth = max(depth + 0.01, 0.01);
    depth = 1.0 / depth;
    
	return 100000.0 * depth;   
}

float calcParticleThicknessConst(const float depth)
{
    
	return 100000.0 / max(depth * 2.0 - 0.01, 0.01);   
}

float powder(float od)
{
	return 1.0 - exp2(-od * 2.0);
}

float calculateScatterIntergral(float opticalDepth, float coeff)
{
    float a = -coeff * RLOG2;
    float b = -1.0 / coeff;
    float c =  1.0 / coeff;

    return exp2(a * opticalDepth) * b + c;
}

float3 calculateScatterIntergral(float opticalDepth, float3 coeff)
{
    float3 a = -coeff * RLOG2;
    float3 b = -1.0 / coeff;
    float3 c =  1.0 / coeff;

    return exp2(a * opticalDepth) * b + c;
}

float bayer2(float2 a)
{
    a = floor(a);
    return frac( dot(a, float2(.5, a.y * .75)) );
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) (bayer64(.5*(a))*.25+bayer2(a))


float GetPlanetRadius()
{
    return EARTH_POS.y;
}

float GetAtmosphereHeight()
{
    return ATMOSPHERE_RADIUS - GetPlanetRadius();
}

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

float Get3DNoise(float3 pos) 
{
    float p = floor(pos.z);
    float f = pos.z - p;
    
    const float invNoiseRes = 1.0 / 64.0;
    
    float zStretch = 17.0 * invNoiseRes;
    
    float2 coord = pos.xy * invNoiseRes + (p * zStretch);
    
    float2 noise = float2(_PerlinNoise2D.Sample(sampler_PerlinNoise2D, coord).x,
					  _PerlinNoise2D.Sample(sampler_PerlinNoise2D, coord + zStretch).x);
    
    return lerp(noise.x, noise.y, f);
}

float getClouds(float3 p)
{
    p = float3(p.x, length(p) - GetPlanetRadius(), p.z);
    
    if (p.y < cloudMinHeight || p.y > cloudMaxHeight)
        return 0.0;
    
    float time = iTime * cloudSpeed;
    float3 movement = float3(time, 0.0, time);
    
    float3 cloudCoord = (p * 0.001) + movement;
    
	float noise = Get3DNoise(cloudCoord) * 0.5;
    	  noise += Get3DNoise(cloudCoord * 2.0 + movement) * 0.25;
    	  noise += Get3DNoise(cloudCoord * 7.0 - movement) * 0.125;
    	  noise += Get3DNoise((cloudCoord + movement) * 16.0) * 0.0625;
    
    const float top = 0.004;
    const float bottom = 0.01;
    
    float horizonHeight = p.y - cloudMinHeight;
    float treshHold = (1.0 - exp2(-bottom * horizonHeight)) * exp2(-top * horizonHeight);
    
    float clouds = smoothstep(0.55, 0.6, noise);
          clouds *= treshHold;
    
    return clouds * cloudDensity;
}

float3 calcAtmosphericScatterTop()
{
    float sunDirDotY = dot(SUN_DIR, Y_DIR);

    float opticalDepth = calcParticleThicknessConst(1.0);
    float opticalDepthLight = calcParticleThickness(sunDirDotY);

    float3 totalCoeff = BETA_MIE + BETA_RAY;

    float3 scatterView = scatter(totalCoeff, opticalDepth);
    float3 transmittanceView = transmittance(totalCoeff, opticalDepth);
    
    float3 scatterLight = scatter(totalCoeff, opticalDepthLight);
    float3 transmittanceLight = transmittance(totalCoeff, opticalDepthLight);

    float3 transmittanceSun = d02(transmittanceLight - transmittanceView) / d02((scatterLight - scatterView) * LOG2);

    float3 mieScatter = scatter(BETA_MIE, opticalDepth) * 0.25;
    float3 rayleighScatter = scatter(BETA_RAY, opticalDepth) * 0.375;

    float3 scatterSun = mieScatter + rayleighScatter;
    
    return scatterSun * transmittanceSun * SUN_INTENSITY;
}

float getSunVisibility(float3 pos)
{
    const int steps = ATMOSPHERE_SAMPLES;
    const float iSteps = 1.0 / float(steps);
    
    float topSphere = raySphereIntersect(pos, SUN_DIR, ATMOSPHERE_RADIUS).y;

    float delta = topSphere * iSteps;
    float3 sunPos = pos + SUN_DIR * delta;

    float transmittance = 1.0;

    [loop]
    for (int i = 0; i < ATMOSPHERE_SAMPLES; i++)
    {
        float opticalDepth = getClouds(sunPos) * delta;
        sunPos += SUN_DIR * delta;

        if (opticalDepth > 0.)
        {
            transmittance *= exp2(-opticalDepth); 
        }
    }

    return transmittance;
}

float3 getVolumetricCloudsScattering(float opticalDepth, float phase, float3 pos, float3 skyLight)
{
    float intergal = calculateScatterIntergral(opticalDepth, 1.11);

	float3 sunlighting = getSunVisibility(pos) * phase * HALF_PI * SUN_INTENSITY;
    float3 skylighting = skyLight * 0.25 * R_PI;
    
    return (sunlighting + skylighting) * intergal * M_PI;
}


float3 hdr(float3 L) 
{
    L = L * 0.4;
    L.r = L.r < 1.413 ? pow(L.r * 0.38317, 1.0 / 2.2) : 1.0 - exp(-L.r);
    L.g = L.g < 1.413 ? pow(L.g * 0.38317, 1.0 / 2.2) : 1.0 - exp(-L.g);
    L.b = L.b < 1.413 ? pow(L.b * 0.38317, 1.0 / 2.2) : 1.0 - exp(-L.b);
    return L;
}

float4 Texture4D(sampler3D table, float r, float mu, float muS, float nu)
{
   	float H = sqrt(Rt * Rt - Rg * Rg);
   	float rho = sqrt(r * r - Rg * Rg);

    float rmu = r * mu;
    float delta = rmu * rmu - r * r + Rg * Rg;
    float4 cst = rmu < 0.0 && delta > 0.0 ? float4(1.0, 0.0, 0.0, 0.5 - 0.5 / RES_MU) : float4(-1.0, H * H, H, 0.5 + 0.5 / RES_MU);
    float uR = 0.5 / RES_R + rho / H * (1.0 - 1.0 / RES_R);
    float uMu = cst.w + (rmu * cst.x + sqrt(delta + cst.y)) / (rho + cst.z) * (0.5 - 1.0 / float(RES_MU));
    // paper formula
    //float uMuS = 0.5 / RES_MU_S + max((1.0 - exp(-3.0 * muS - 0.6)) / (1.0 - exp(-3.6)), 0.0) * (1.0 - 1.0 / RES_MU_S);
    // better formula
    float uMuS = 0.5 / RES_MU_S + (atan(max(muS, -0.1975) * tan(1.26 * 1.1)) / 1.1 + (1.0 - 0.26)) * 0.5 * (1.0 - 1.0 / RES_MU_S);

    float lep = (nu + 1.0) / 2.0 * (RES_NU - 1.0);
    float uNu = floor(lep);
    lep = lep - uNu;

    return tex3D(table, float3((uNu + uMuS) / RES_NU, uMu, uR)) * (1.0 - lep) + tex3D(table, float3((uNu + uMuS + 1.0) / RES_NU, uMu, uR)) * lep;
}

float3 GetMie(float4 rayMie) 
{	
	// approximated single Mie scattering (cf. approximate Cm in paragraph "Angular precision")
	// rayMie.rgb=C*, rayMie.w=Cm,r
   	return rayMie.rgb * rayMie.w / max(rayMie.r, 1e-4) * (BETA_RAY.r / BETA_RAY);
}

float PhaseFunctionR(float mu) 
{
	// Rayleigh phase function
    return (3.0 / (16.0 * M_PI)) * (1.0 + mu * mu);
}

float PhaseFunctionM(float mu) 
{
	// Mie phase function
   	 return 1.5 * 1.0 / (4.0 * M_PI) * (1.0 - MIE_G*MIE_G) * pow(1.0 + (MIE_G*MIE_G) - 2.0*MIE_G*mu, -3.0/2.0) * (1.0 + mu * mu) / (2.0 + MIE_G*MIE_G);
}

float3 Transmittance(float r, float mu) 
{
	// transmittance(=transparency) of atmosphere for infinite ray (r,mu)
	// (mu=cos(view zenith angle)), intersections with ground ignored
   	float uR, uMu;
    uR = sqrt((r - Rg) / (Rt - Rg));
    uMu = atan((mu + 0.15) / (1.0 + 0.15) * tan(1.5)) / 1.5;
    
    return tex2D(_Transmittance, float2(uMu, uR)).rgb;
}

float3 SkyRadiance(float3 camera, float3 viewdir, out float3 extinction)
{
	// scattered sunlight between two points
	// camera=observer
	// viewdir=unit vector towards observed point
	// sundir=unit vector towards the sun
	// return scattered light

	camera += EARTH_POS;

   	float3 result = float3(0,0,0);
    float r = length(camera);
    float rMu = dot(camera, viewdir);
    float mu = rMu / r;
    float r0 = r;
    float mu0 = mu;

    float deltaSq = sqrt(rMu * rMu - r * r + Rt*Rt);
    float din = max(-rMu - deltaSq, 0.0);
    if (din > 0.0) 
    {
       	camera += din * viewdir;
       	rMu += din;
       	mu = rMu / Rt;
       	r = Rt;
    }
    
    float nu = dot(viewdir, SUN_DIR);
    float muS = dot(camera, SUN_DIR) / r;

    float4 inScatter = Texture4D(_Inscatter, r, rMu / r, muS, nu);
    extinction = Transmittance(r, mu);

    if(r <= Rt) 
    {
        float3 inScatterM = GetMie(inScatter);
        float phase = PhaseFunctionR(nu);
        float phaseM = PhaseFunctionM(nu);
        result = inScatter.rgb * phase + inScatterM * phaseM;
    }
    else
    {
    	result = float3(0,0,0);
    	extinction = float3(1,1,1);
    }

    return result * SUN_INTENSITY;
}


float phaseFunMieScattering(float cosTheta, in float g)
{
    float gg = g * g;
	return (1.0 - gg) / (4.0 * M_PI * pow(1.0 + gg - 2.0 * g * cosTheta, 1.5));
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

float phase2Lobes(float x)
{
    const float m = 0.6;
    const float gm = 0.8;
    
	float lobe1 = phaseFunMieScattering(x, 0.8 * gm);
    float lobe2 = phaseFunMieScattering(x, -0.5 * gm);
    
    return lerp(lobe2, lobe1, m);
}

float3 calculateVolumetricClouds(in float3 dir, in float3 skyColor)
{
    float bottomSphere = raySphereIntersect(EARTH_POS, dir, GetPlanetRadius() + cloudMinHeight).y;
    float topSphere = raySphereIntersect(EARTH_POS, dir, GetPlanetRadius() + cloudMaxHeight).y;
    
    const int steps = ATMOSPHERE_SAMPLES;
    const float iSteps = 1.0 / float(steps);
    
    float delta = abs(bottomSphere - topSphere) * iSteps;
    float3 cloudPos = EARTH_POS + dir * bottomSphere;

    float3 cloudRes = float3(0., 0., 0.);

    float3 scattering = float3(0., 0., 0.);
    float transmittance = 1.0;

    float3 skyLight = calcAtmosphericScatterTop();

    float sunDirDotView = dot(SUN_DIR, dir);
    float phase = phase2Lobes(sunDirDotView);

    [loop]
    for (int i = 0; i < ATMOSPHERE_SAMPLES; i++)
    {
        float opticalDepth = getClouds(cloudPos) * delta;
        cloudPos += dir * delta;

        if (opticalDepth > 0.)
        {
            scattering += getVolumetricCloudsScattering(opticalDepth, phase, cloudPos, skyLight) * transmittance;
            transmittance *= exp2(-opticalDepth); 
        }
    }

    return skyColor * transmittance + scattering;
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

    [loop]
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
       // sumMie += scattered * densities.y;

        rayOffset += i_delta;
    }

    float cosTheta = dot(dir, lightDir);

    return max(phaseFunMieScattering(cosTheta, MIE_G) * sumMie + phaseFunRayScattering(cosTheta)* sumRay, 0);

}