#define M_PI 3.141592

float3 EARTH_POS;
float3 SUN_DIR;
float SUN_INTENSITY;

float2 raySphereIntersect(in float3 origin, in float3 dir, in float radius) {
    float3 originToCenter = -origin;
    float3 normalizeDir = normalize(dir);
    float cosOriginToCenterAndDir = dot(normalize(originToCenter), normalizeDir);
    float originToCenterLen = sqrt(dot(originToCenter, originToCenter));
    float projOriginToCenterToDir = cosOriginToCenterAndDir * originToCenterLen;
    float sqC = originToCenterLen * originToCenterLen - projOriginToCenterToDir * projOriginToCenterToDir;
    float delta = sqrt(radius * radius - sqC);
    float pointEntryPos = projOriginToCenterToDir - delta;
    float pointExitPos = projOriginToCenterToDir + delta;
    return float2(pointEntryPos, pointExitPos);
}