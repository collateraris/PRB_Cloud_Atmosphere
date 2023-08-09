Shader "Render/CloudShader"
{
	Properties
	{
		_MainTex ("CloudVolumeTexture", 3D) = "white" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100
		Pass
		{
            CGPROGRAM
            // Physically based Standard lighting model, and enable shadows on all light types
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #include "Atmospheric.cginc"
            #pragma enable_d3d11_debug_symbols

            sampler2D _MainTex;
            float _CameraNearPlane;
            float4x4 _MainCameraInvProj;
            float4x4 _MainCameraInvView;

            struct vIn
            {
                float4 position		: POSITION;
                float2 uv			: TEXCOORD0;

            };

            struct v2f
            {
                float4 position	: SV_POSITION;
                float2 uv		: TEXCOORD1;
                float4 dir_ws	: TEXCOORD0;
            };

            v2f vert(vIn v)
            {
                v2f o = (v2f)0;
                o.position = UnityObjectToClipPos(v.position);
                o.uv = v.uv;

                float4 clip = float4(o.position.xyz, 1.0);
                float4 positionVS = mul(_MainCameraInvProj, clip);
                positionVS.w = 1;

                o.dir_ws = float4(mul((float3x3)_MainCameraInvView, positionVS.xyz), 0 );

                return o;           
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 skyColor = tex2D(_MainTex, i.uv);
                float3 dir = normalize(i.dir_ws.xyz);
                float4 cloudCol = calculateVolumetricClouds(dir, skyColor);

				return float4(hdr(cloudCol.xyz), cloudCol.w);
            }
            ENDCG
        }
	}
}
