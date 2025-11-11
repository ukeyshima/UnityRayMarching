using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

namespace UnityRayMarching
{
    public class PostProcess : MonoBehaviour
    {
        [SerializeField] protected Material _material;

        public virtual void Render(ShaderUniformData data, RenderTexture normalDepth, RenderTexture position, RenderTexture target)
        {
            Graphics.Blit(data.RenderBuffer, target, _material);
        }
    }
}