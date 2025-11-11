using UnityEngine;

namespace UnityRayMarching
{
    public class WaveletTransform : PostProcess
    {
        [SerializeField] private int _iterations;
        
        public override void Render(ShaderUniformData data, RenderTexture normalDepth, RenderTexture position, RenderTexture target)
        {
            RenderTexture temp1 = RenderTexture.GetTemporary(data.RenderBuffer.descriptor);
            RenderTexture temp2 = RenderTexture.GetTemporary(data.RenderBuffer.descriptor);
            Graphics.Blit(data.RenderBuffer, temp1);
            for (int i = 0; i < _iterations; i++)
            {
                _material.SetInt("_Count", i);
                _material.SetTexture("_NormalDepthTex", normalDepth);
                _material.SetTexture("_PositionTex", position);
                _material.mainTexture = temp1;
                Graphics.Blit(temp1, temp2, _material);
                (temp1, temp2) = (temp2, temp1);
            }
            Graphics.Blit(temp1, target);
            RenderTexture.ReleaseTemporary(temp1);
            RenderTexture.ReleaseTemporary(temp2);
        }
    }
}