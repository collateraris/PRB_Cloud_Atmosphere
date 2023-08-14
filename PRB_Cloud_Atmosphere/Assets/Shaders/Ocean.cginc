#define DRAG_MULT 0.5 // changes how much waves pull on the water
#define WATER_DEPTH 1.0 // how deep is the water
#define CAMERA_HEIGHT 1.5 // how high the camera should be
#define ITERATIONS_RAYMARCH 12 // waves iterations of raymarching
#define ITERATIONS_NORMAL 40 // waves iterations when calculating normals


float intersectPlane(float3 origin, float3 direction, float3 p, float3 normal)
{ 
  float3 pMinusP0 = p - origin;
  float denorm = dot(direction, normal);
  return clamp(dot(pMinusP0, normal) / denorm, -1.0, 9991999.0); 
}

float2 wavedx(float2 position, float2 direction, float frequency, float timeshift)
{
    float x = dot(direction, position) * frequency + timeshift;
    float wave = exp(sin(x) - 1.);
    float dx = wave * cos(x);
    return float2(wave, -dx);
}

float getwaves(float2 position, int iterations) 
{
    float iter = 0.0; // this will help generating well distributed wave directions
    float frequency = 1.0; // frequency of the wave, this will change every iteration
    float timeMultiplier = 2.0; // time multiplier for the wave, this will change every iteration
    float weight = 1.0;// weight in final sum for the wave, this will change every iteration
    float sumOfValues = 0.0; // will store final sum of values
    float sumOfWeights = 0.0; // will store final sum of weights

    for(int i=0; i < iterations; i++)
    {
        float2 p = float2(sin(iter), cos(iter));

        float2 res = wavedx(position, p, frequency, iTime * timeMultiplier);

        position += p * res.y * weight * DRAG_MULT;

        sumOfValues += res.x * weight;
        sumOfWeights += weight;

        weight *= 0.82;
        frequency *= 1.18;
        timeMultiplier *= 1.07;

        iter += 1232.399963;        
    }

   return sumOfValues / sumOfWeights; 
}

float3 normal(float2 pos, float e, float depth)
{
    float2 ex = float2(e, 0);
    float H = getwaves(pos.xy, ITERATIONS_NORMAL) * depth;
    float3 a = float3(pos.x, H, pos.y);
    return normalize(
        cross(
        a - float3(pos.x - e, getwaves(pos.xy - ex.xy, ITERATIONS_NORMAL) * depth, pos.y), 
        a - float3(pos.x, getwaves(pos.xy + ex.yx, ITERATIONS_NORMAL) * depth, pos.y + e)
        )
    );
}

float raymarchwater(float3 cameraPos, float3 start, float3 end, float depth)
{
    float3 pos = start;
    float3 dir = normalize(end - start);
    
    for (int i = 0; i < 64; i++)
    {
        float height = getwaves(pos.xz, ITERATIONS_RAYMARCH) * depth - depth;
        if(height + 0.01 > pos.y) {
            return distance(pos, cameraPos);
        }

        pos += dir * (pos.y - height);
    }

    return distance(start, cameraPos);
}

float4 calculateOcean(in float3 viewDir, in float4 skyColor)
{
    if (viewDir.y > 0)
        return float4(skyColor);

    float3 waterPlaneHigh = float3(0.0, _CameraPosWS.y - WATER_DEPTH, 0.0);
    float3 waterPlaneLow = float3(0.0, _CameraPosWS.y - 2 * WATER_DEPTH, 0.0);

    // calculate intersections and reconstruct positions
    float highPlaneHit = intersectPlane(_CameraPosWS.xyz, viewDir, waterPlaneHigh, float3(0.0, 1.0, 0.0));
    float lowPlaneHit = intersectPlane(_CameraPosWS.xyz, viewDir, waterPlaneLow, float3(0.0, 1.0, 0.0));
    float3 highHitPos = _CameraPosWS.xyz + viewDir * highPlaneHit;
    float3 lowHitPos = _CameraPosWS.xyz + viewDir * lowPlaneHit;

    float dist = raymarchwater(_CameraPosWS.xyz, highHitPos, lowHitPos, WATER_DEPTH);
    float3 waterHitPos = _CameraPosWS.xyz + viewDir * dist;

    float3 N = normal(waterHitPos.xz, 0.01, WATER_DEPTH);

    float fresnel = (0.04 + (1.0-0.04)*(pow(1.0 - max(0.0, dot(-N, viewDir)), 5.0)));

    float3 scattering = float3(0.293, 0.698, 0.1717) * (0.2 + (waterHitPos.y + WATER_DEPTH) / WATER_DEPTH);

    float3 color = fresnel * float3(1., 1., 1.) + (1 - fresnel) * scattering;
    return float4(color, 1.);
}

