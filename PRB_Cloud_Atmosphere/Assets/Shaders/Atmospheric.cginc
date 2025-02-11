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
#define cloudHeight 1500.0
#define cloudThickness 2500.0
#define cloudMinHeight cloudHeight
#define cloudMaxHeight (cloudThickness + cloudMinHeight)
#define cloudDensity 0.03

#define fogDensity 0.00003

int ATMOSPHERE_SAMPLES;
float ATMOSPHERE_RADIUS;
float3 EARTH_POS;
float4 _CameraPosWS;
float3 SUN_DIR;
float SUN_INTENSITY;
float iTime;

float _CoverageScale;
float _SunAttenuation;
float _ScatteringCoEff;
float _PowderCoEff;
float _PowderScale;
float _HG;
float _CloudDensityScale;

float _SilverIntensity;
float _SilverSpread;


sampler2D _Transmittance, _Irradiance;
sampler2D _WeatherMapTex;
Texture2D _PerlinNoise2D;
SamplerState sampler_PerlinNoise2D;
sampler3D _Inscatter;
sampler3D _NoiseTex;
sampler3D _CloudDetailTexture;


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

float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
{
    if(abs(original_max - original_min)<10e-5) return new_min;
    return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
}

float cloudGetHeight(float3 position)
{   
    float heightFraction = (position.y - cloudMinHeight) / (cloudMaxHeight - cloudMinHeight);

	return saturate(heightFraction);
}

float cloudSampleDensity(float3 position)
{
    float2 weather_uv = position.xz * 5 * 1e-5;
    weather_uv += 0.8;
    float4 weather = tex2Dlod(_WeatherMapTex, float4(weather_uv, 0, 0));

    position.xz += 100 * iTime;
    float scale1 = 5 * 1e-5;
    float4 low_frequency_noises = tex3Dlod(_NoiseTex , float4 ( position * scale1 , 0 ));
    float low_freq_fBm = ( low_frequency_noises.g * 0.625 ) + ( low_frequency_noises.b * 0.25 ) + ( low_frequency_noises.a * 0.125 );
    float base_cloud = remap(low_frequency_noises.r, -(1.0 - low_freq_fBm), 1.0, 0.0, 1.0);

    float scale2 = 40 * 1e-5;
    float3 high_frequency_noises = tex3Dlod(_CloudDetailTexture , float4 ( position * scale2 , 0 )).rgb;
	float high_freq_fBm = ( high_frequency_noises.r * 0.625 ) + ( high_frequency_noises.g * 0.25 ) + ( high_frequency_noises.b * 0.125 );
	
    float SNsample = base_cloud * 0.85 + high_freq_fBm * 0.15;

    float height = cloudGetHeight(position);
    
    float cloud_coverage = weather.r;
    cloud_coverage = pow(cloud_coverage, remap(height, 0.7, 0.8, 1.0, lerp(1.0, 0.5, 0.3)));
				
    float base_cloud_with_coverage = remap(base_cloud, saturate(cloud_coverage * _CoverageScale), 1.0, 0.0, 1.0);
    base_cloud_with_coverage *= cloud_coverage;

    float final_cloud = base_cloud_with_coverage;
    float high_freq_noise_modifier = lerp(high_freq_fBm, 1.0 - high_freq_fBm, saturate(height * 10.0));

    final_cloud = remap(base_cloud_with_coverage, high_freq_noise_modifier * 0.2 , 1.0, 0.0, 1.0);

    return saturate(final_cloud * _CloudDensityScale);
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
    float treshHold = (1.0 - exp(-bottom * horizonHeight)) * exp(-top * horizonHeight);
    
    float clouds = smoothstep(0.55, 0.6, noise);
          clouds *= treshHold;
    
    return clouds * cloudDensity;
}

float BeerLambert(float opticalDepth)
{
    //original paper add a rain parameter here
    //to make a darker clooud for weather texture's g chanel
    float ExtinctionCoEff = _ScatteringCoEff; // * weather.g
    return exp( -ExtinctionCoEff * opticalDepth);
}

float Powder(float opticalDepth)
{
    float ExtinctionCoEff = _PowderCoEff;
    return 1.0f - exp( - 2 * ExtinctionCoEff * opticalDepth) * _PowderScale;
}

float cloudSunDirectDensity(float3 pos)
{
    const float3 RandomUnitSphere[6] = 
    {
        {0.3f, -0.8f, -0.5f},
        {0.9f, -0.3f, -0.2f},
        {-0.9f, -0.3f, -0.1f},
        {-0.5f, 0.5f, 0.7f},
        {-1.0f, 0.3f, 0.0f},
        {-0.3f, 0.9f, 0.4f}
    };

    int steps = 6;
    float delta = abs(cloudMinHeight-cloudMaxHeight) / steps;
    float3 lightDir = _WorldSpaceLightPos0.xyz;
    float3 sunPos = pos;

    float sumDensity=0.0;

    [loop]
    for (int i = 0; i < steps; i++)
    {
		float3 random_sample = RandomUnitSphere[i] * delta * lightDir * (i + 1);
		float3 sample_pos = sunPos + random_sample;        
        float opticalDepth = cloudSampleDensity(sample_pos) * delta;

        sunPos += lightDir * delta;
        if (opticalDepth > 0.)
        {
            sumDensity += opticalDepth;
        } 
    }

    return sumDensity;
}

float3 getVolumetricCloudsScattering(float3 pos)
{
    float densitySum = cloudSunDirectDensity(pos);
    float lightEnergy1 = BeerLambert(densitySum);
    float lightEnergy2 = BeerLambert(densitySum*0.25)*0.7;
    float lightEnergy = max(lightEnergy1,lightEnergy2);
    float powder = Powder(densitySum);

    return lightEnergy * powder * 2;
}

float getCloudShadow(float3 pos)
{
	const int steps = ATMOSPHERE_SAMPLES;
    float rSteps = cloudThickness / float(steps) / abs(SUN_DIR.y);
    
    float3 increment = SUN_DIR * rSteps;
    float3 position = SUN_DIR * (cloudMinHeight - pos.y) / SUN_DIR.y + pos;
    
    float transmittance = 0.0;
    
    [loop]
    for (int i = 0; i < steps; i++, position += increment)
    {
		transmittance += cloudSampleDensity(position);
    }
    
    return exp2(-transmittance * rSteps);
}

float3 getVolumetricLightScattering(float3 pos)
{
    return getCloudShadow(pos) * SUN_INTENSITY;
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

float phase2Lobes(float cosThea)
{   
	float hgForward = phaseFunMieScattering(cosThea, _HG);
    float hgBackward = phaseFunMieScattering(cosThea, 0.99 - _SilverSpread) * _SilverIntensity;
    
    return hgForward + hgBackward;
}

float getHeightFogOD(float height)
{
	const float falloff = 0.001;
    
    return exp2(-height * falloff) * fogDensity;
}

float4 calculateVolumetricClouds(in float3 viewDir, in float3 skyColor)
{   
    if (viewDir.y < 0)
        return float4(skyColor, 1);

    const int steps = 128;
    const float iSteps = 1.0 / float(steps);

    float bottom = cloudMinHeight / viewDir.y;
    float top = cloudMaxHeight / viewDir.y;
    
    float delta = abs(top - bottom) * iSteps;
    float3 startPosition = _CameraPosWS + viewDir * bottom;
    float3 cloudPos = startPosition;

    float3 scattering = float3(0., 0., 0.);
    float transmittance = 1.0;

    float3 lightDir = _WorldSpaceLightPos0.xyz;
    float sunDirDotView = dot(viewDir, lightDir);
    float phase = phase2Lobes(sunDirDotView);

    [loop]
    for (int i = 0; i < steps; i++)
    {       
        float opticalDepth = cloudSampleDensity(cloudPos) * delta;
        if (opticalDepth > 0.)
        {
            scattering += phase * opticalDepth * getVolumetricCloudsScattering(cloudPos) * transmittance;
            transmittance *= BeerLambert(opticalDepth);
        }

        cloudPos += viewDir * delta;
    }

    float4 final = float4(1., 1., 1., 1.);
    final.a = saturate(1. - transmittance);
    final.rgb = scattering;

    float horizonFade = (1.0f - saturate(top / 50000));
	final *= horizonFade;

    return final + saturate(1. - final.a) * float4(skyColor, 0);
}


float3 calculateVolumetricLight(in float3 viewDir, in float3 skyColor)
{
	const int steps = ATMOSPHERE_SAMPLES;
    const float iSteps = 1.0 / float(steps);
    
    float3 increment = viewDir * cloudMinHeight / 0.1f  * iSteps;
    float3 godRayPos = EARTH_POS  + increment;
    
    float stepLength = length(increment);
    
    float3 scattering = float3(0., 0., 0.);
    float3 transmittance = float3(1., 1., 1.);
    
    float sunDirDotView = max(0, dot(SUN_DIR, viewDir));
    float phase = phase2Lobes(sunDirDotView);

    [loop]
    for (int i = 0; i < ATMOSPHERE_SAMPLES; i++)
    {
        float opticalDepth = getHeightFogOD(godRayPos.y) * stepLength;
        if (opticalDepth > 0.)
        {
            scattering += phase * opticalDepth * getVolumetricLightScattering(godRayPos) * transmittance;
            transmittance *= exp(-opticalDepth);
        }

        godRayPos += increment;
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