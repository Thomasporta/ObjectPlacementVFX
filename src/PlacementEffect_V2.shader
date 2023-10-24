Shader "Unlit/PlacementEffect_V2"
{
    Properties
    {
        //Texture for Triplanar Mapping, could be extended to support different textures for each face
        _Tex("Texture", 2D) = "white" {}
        //Scale of Triplanar Mapping
        _Scale("Scale", Range(0.001, 10)) = 0.1

        //Panning speed of texture if movement is desired
        _PanningSpeed("Panning Speed", Vector) = (0,0,0,0)
        
        //Color of the Effect
        _Color ("Color", Color) = (1,1,1,1)

        //Control on the opacity. 
        //Upper alpha is the maximum alpha of the effect, lower alpha is the minimum alpha of the effect
        _UpperAlpha ("Upper Alpha", Range(0,1)) = 0.5
        _LowerAlpha ("Lower Alpha", Range(0,1)) = 0.2

        //Parameters for intersection effects with other objects
        _IntersectionAlpha("Intersection Alpha", Range(0,1)) = 0.5
        _IntersectionPower("Intersection Power", Range(0,10)) = 1
        _IntersectionSize("Intersection Size", Range(0,10)) = 1

        //Control on backside culling
        [Space(20)]
        [Enum(UnityEngine.Rendering.CullMode)] _Culling("Cull Mode", Int) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
        LOD 100
        Cull[_Culling]
        ZWrite Off
        
        //Traditional Blend
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD2;
                float4 scrPos : TEXCOORD3;
                float3 normal : NORMAL;
            };

            sampler2D _CameraDepthTexture;

            sampler2D _Tex;
            float _Scale;

            half4 _Color;

            float4 _PanningSpeed;

            float _UpperAlpha;
            float _LowerAlpha;

            float _IntersectionAlpha;
            float _IntersectionPower;
            float _IntersectionSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);

                //World position of the vertex, screenPosition of vertex and normal for triplanar
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.scrPos = ComputeScreenPos(o.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                //Triplanar Mapping for Effect Texture
                half4 col1 = tex2D(_Tex, (i.worldPos.yz + _Time.y * _PanningSpeed.yz) * _Scale);
                half4 col2 = tex2D(_Tex, (i.worldPos.xz + _Time.y * _PanningSpeed.xz)* _Scale);
                half4 col3 = tex2D(_Tex, (i.worldPos.xy + _Time.y * _PanningSpeed.xy) * _Scale);

                float3 vec = abs(i.normal);
                vec /= vec.x + vec.y + vec.z + 0.001f;
                vec = (vec.x * col1 + vec.y * col2 + vec.z * col3).x;
                //texture to grayscale so we can read choose correct transparency value later.
                //Could've used one grayscale texture instead of color textures
                float grayscale = (0.2125 * vec.r) + (0.7154 * vec.g) + (0.0721 * vec.b);

                half4 col = _Color;

                //Get the depth at that pixel fragment from the depth texture
                float depth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.scrPos));

                //Get the linear depth
                depth = LinearEyeDepth(depth);

                //Check whether there is something close to you by checking the difference between the depth (this object does not write to the depth buffer) and the pixel depth
                //Control how big this intersection effect is with the IntersectionSize parameter
                float intersection = saturate((depth - i.scrPos.w)/ _IntersectionSize);

                //Modify the maximum alpha based on whether we are close another object. Should be less transaprent if we are so that intersections are visible.
                float upperAlpha = lerp(_UpperAlpha, _UpperAlpha + _IntersectionAlpha, pow(1 - intersection, _IntersectionPower));

                //Lerp between those alphas based off the texture value.
                col.a = lerp(_LowerAlpha, upperAlpha, grayscale);

                return col;
            }
            ENDCG
        }
    }
}
