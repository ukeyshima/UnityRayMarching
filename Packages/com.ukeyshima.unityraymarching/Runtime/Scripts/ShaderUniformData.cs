using UnityEngine;

namespace UnityRayMarching
{
    public class ShaderUniformData
    {
        public float Time;
        public int FrameCount;
        public Vector2Int Resolution;
        public RenderTexture BackBuffer;
    }
}