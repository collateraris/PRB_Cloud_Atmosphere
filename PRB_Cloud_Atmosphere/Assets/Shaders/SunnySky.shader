Shader "Atmosphere/SunnySky"
{
	SubShader 
	{
    	Pass 
    	{
    		//ZWrite Off
			Cull Front
			
			CGPROGRAM
			#pragma enable_d3d11_debug_symbols
			#include "UnityCG.cginc"
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			#include "Atmospheric.cginc"
		
			struct v2f 
			{
    			float4  pos : SV_POSITION;
    			float2  uv : TEXCOORD0;
    			float3 worldPos : TEXCOORD1;
			};
			

			v2f vert(appdata_base v)
			{
    			v2f OUT;
    			OUT.pos = UnityObjectToClipPos(v.vertex);
    			OUT.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    			OUT.uv = v.texcoord.xy;
    			return OUT;
			}
			
			float4 frag(v2f IN) : COLOR
			{
				float3 dir = normalize(IN.worldPos-_WorldSpaceCameraPos);
			    
			    float sun = step(cos(M_PI / 360.0 * 10), dot(dir, SUN_DIR));
			    
			    float3 sunColor = float3(sun,sun,sun) * SUN_INTENSITY;

				float sunDir = normalize(SUN_DIR);
				sunColor += atmosphereRealTime(dir, normalize(SUN_DIR));
				sunColor += atmosphereRealTime(dir, normalize(-SUN_DIR));

				sunColor=sunColor/(1+sunColor);
				sunColor = pow(sunColor, float3(1.0 / 2.2,1.0 / 2.2,1.0 / 2.2));
		
				return float4(sunColor, 1.0);
			}
			
			ENDCG

    	}
	}
}
