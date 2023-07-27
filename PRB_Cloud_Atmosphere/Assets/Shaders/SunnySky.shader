Shader "Atmosphere/SunnySky"
{
	SubShader 
	{
    	Pass 
    	{
    		//ZWrite Off
			Cull Front
			
			CGPROGRAM
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
				float3 col = float3(1., 0.5, 0.);
		
				return float4(col, 1.0);
			}
			
			ENDCG

    	}
	}
}
