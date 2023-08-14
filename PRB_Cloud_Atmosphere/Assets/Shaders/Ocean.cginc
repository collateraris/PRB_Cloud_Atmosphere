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

float4 calculateOcean(in float3 viewDir, in float4 skyColor)
{
    if (viewDir.y > 0)
        return float4(skyColor);

    float3 waterPlaneHigh = float3(0.0, _CameraPosWS.y - WATER_DEPTH, 0.0);
    float3 waterPlaneLow = float3(0.0, _CameraPosWS.y - 2 * WATER_DEPTH, 0.0);

    // calculate intersections and reconstruct positions
    float highPlaneHit = intersectPlane(_CameraPosWS, viewDir, waterPlaneHigh, float3(0.0, 1.0, 0.0));
    float lowPlaneHit = intersectPlane(_CameraPosWS, viewDir, waterPlaneLow, float3(0.0, 1.0, 0.0));

    return float4(0., 0., 1., 1.);
}

