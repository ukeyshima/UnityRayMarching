using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

namespace UnityRayMarching
{
    public class PostProcess : MonoBehaviour
    {
        [SerializeField] protected Material _material;

        public virtual void Render(ShaderUniformData data, RenderTexture target, RenderTexture normalDepth = null, RenderTexture position = null, RenderTexture id = null)
        {
            Graphics.Blit(data.RenderBuffer, target, _material);
        }
    }
}