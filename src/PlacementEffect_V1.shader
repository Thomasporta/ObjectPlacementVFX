Shader "Custom/PlacementEffect_V1"
{
    Properties{
            //Normal Specular light setup, can be replaced with any lighting system and any texturing setup
            _MainTex("Albedo (RGB)", 2D) = "white" {}
            _Glossiness("Smoothness", Range(0,1)) = 0.5
            _Metallic("Metallic", Range(0,1)) = 0.0

            //Parameters for the effect

            //Color of the Overlay, the Outline and the Occlusion. Could be separated into several colors if required
            _Color("Color", Color) = (1,1,1,1)

            //Strength of the Overlay Color
            _EmissionStrength ("Emission", Range(0,5)) = 0.5

            //Size of the Outline, can be tweaked for each material
            _Outline("Outline Strength", Range(0,0.5)) = 0
    }
        SubShader{

            
            //Pass to create the outline. Using vertex extrusion based off normals and then a simple color given to those pixels.
            //The surface shader will write over the pixels that are not extruding in a subsequent pass.
            Pass {
                Tags { "RenderType" = "Opaque"}
                //We cull the front faces so that the outline effect is written over in the shading pass. This occurs because the shading pass culls
                //the back faces, and the front faces will write over any back pixel, except those that have been extruded.
                Cull Front

                CGPROGRAM

                #pragma vertex vert
                #pragma fragment frag
                #include "UnityCG.cginc"

                struct v2f {
                    float4 pos : SV_POSITION;
                };

                float _Outline;
                float4 _Color;

                float4 vert(appdata_base v) : SV_POSITION {
                    v2f o;
                    
                    //Getting Clip space position of the vertices so we can extrude along normal
                    o.pos = UnityObjectToClipPos(v.vertex);

                    //Clip space normals
                    float3 normal = mul((float3x3) UNITY_MATRIX_MV, v.normal);
                    normal.x *= UNITY_MATRIX_P[0][0];
                    normal.y *= UNITY_MATRIX_P[1][1];

                    //Extrude vertices based off normals
                    o.pos.xy += normal.xy * _Outline;
                    return o.pos;
                }

                half4 frag(v2f i) : COLOR {

                    //Color the vertices
                    return _Color;
                }

                ENDCG
            }

            //Pass to create the Occlusion Effect. 
            //When objects using this shader are behind other geometry, we render the object above anything else and then color it.
            Pass
            {
                //Must happen after all the Opaque Geometry has been rendered because we need to Ztest against other Geometry and determine occlusion
                Tags { "Queue" = "Geometry+1" }

                //Only render if the pixel is behind something
                ZTest Greater
                ZWrite Off

                CGPROGRAM
                #pragma vertex vert            
                #pragma fragment frag
                #pragma fragmentoption ARB_precision_hint_fastest

                #include "UnityCG.cginc"

                half4 _Color;

                struct appdata
                {
                    float4 vertex : POSITION;
                    float3 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float2 uv : TEXCOORD0;
                    float4 vertex : SV_POSITION;
                };

                v2f vert(appdata v)
                {
                    v2f o;
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    return o;
                }

                half4 frag(v2f i) : SV_TARGET
                {

                    //Not much to do except color those occluded pixels with the chosen color
                    fixed4 c = _Color;
                    return c;
                }

                ENDCG
            }

            //This pass is for shading. Can use any lighting model and texturing.
            Tags { "RenderType" = "Opaque" "Queue" = "Geometry"}
            LOD 200
            //ZWrite On
            //ZTest LEqual

            CGPROGRAM
                    // Physically based Standard lighting model, and enable shadows on all light types
                    #pragma surface surf Standard fullforwardshadows

                    // Use shader model 3.0 target, to get nicer looking lighting
                    #pragma target 3.0

                    sampler2D _MainTex;

                    struct Input {
                        float2 uv_MainTex;
                    };

                    half _Glossiness;
                    half _Metallic;
                    half4 _Color;
                    float _EmissionStrength;

                    void surf(Input IN, inout SurfaceOutputStandard o) {

                        //Read the texture, and any texture if needed (all the required maps)
                        fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
                        o.Albedo = c.rgb;

                        //This is for the Overlay Effect on top of the texturing, using the Emission channel so it is not affected by lighting
                        o.Emission = _Color * _EmissionStrength;

                        //Traditional Specular Setup
                        o.Metallic = _Metallic;
                        o.Smoothness = _Glossiness;
                    }
                    ENDCG
            }
                FallBack "Diffuse"
}
