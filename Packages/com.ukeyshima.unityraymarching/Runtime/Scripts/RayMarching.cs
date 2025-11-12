using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

namespace UnityRayMarching
{
    public class RayMarching : MonoBehaviour
    {
        [SerializeField] protected Material _material;
        [SerializeField] protected PostProcess _postProcess;
        [SerializeField] protected bool _onInit;

        protected Dictionary<Camera, ShaderUniformData> _uniformDataDic = new Dictionary<Camera, ShaderUniformData>();

        public UnityEvent OnInit;

        protected virtual void Start()
        {
            Init();
        }

        protected virtual void Update()
        {
            if(_onInit)
            {
                Init();
                _onInit = false;
            }
        }

        protected virtual void OnRenderObject()
        {
            RenderTexture source = RenderTexture.active;

            if(!_uniformDataDic.TryGetValue(Camera.current, out ShaderUniformData data))
            {
                data = new ShaderUniformData()
                {
                    Time = Time.time,
                    FrameCount = 0,
                    Resolution = new Vector2Int(source.width, source.height),
                    RenderBuffer = new RenderTexture(source.width, source.height, 0, RenderTextureFormat.ARGBFloat)
                };
                _uniformDataDic.Add(Camera.current, data);
            }

            data.Time += Time.deltaTime;
            data.FrameCount++;

            if(data.Resolution.x != source.width || data.Resolution.y != source.height)
            {
                data.Resolution = new Vector2Int(source.width, source.height);
                data.RenderBuffer.Release();
                data.RenderBuffer = new RenderTexture(source.width, source.height, 0, RenderTextureFormat.ARGBFloat);
            }
            
            Render(data, source);
        }

        protected void Render(ShaderUniformData data, RenderTexture target)
        {
            RenderTexture normalDepth = RenderTexture.GetTemporary(data.Resolution.x, data.Resolution.y, 0, RenderTextureFormat.ARGBFloat);
            RenderTexture position =  RenderTexture.GetTemporary(data.Resolution.x, data.Resolution.y, 0, RenderTextureFormat.ARGBFloat);
            RenderTexture id =  RenderTexture.GetTemporary(data.Resolution.x, data.Resolution.y, 0, RenderTextureFormat.ARGBFloat);
            RenderBuffer[] colorBuffers = {data.RenderBuffer.colorBuffer, normalDepth.colorBuffer, position.colorBuffer, id.colorBuffer};
            
            _material.SetFloat("_FrameCount", data.FrameCount);
            _material.SetFloat("_ElapsedTime", data.Time);
            _material.SetVector("_Resolution", new Vector2(data.Resolution.x, data.Resolution.y));
            _material.SetTexture("_BackBuffer", data.RenderBuffer);
            _material.SetVector("_CameraPos", Camera.current.transform.position);
            _material.SetVector("_CameraDir", Camera.current.transform.forward);
            _material.SetVector("_CameraUp", Camera.current.transform.up);
            MRTBlit(null, colorBuffers, data.RenderBuffer.depthBuffer, _material);
            
            if(_postProcess == null)
            {
                Graphics.Blit(data.RenderBuffer, target);
            }
            else
            {
                _postProcess.Render(data, target, normalDepth, position, id);
            }
            RenderTexture.ReleaseTemporary(normalDepth);
            RenderTexture.ReleaseTemporary(position);
            RenderTexture.ReleaseTemporary(id);
        }

        protected virtual void MRTBlit(RenderTexture source, RenderBuffer[] destColors, RenderBuffer destDepth, Material material)
        {
            material.SetPass(0);
            material.mainTexture = source;
            Graphics.SetRenderTarget(destColors, destDepth);
            GL.PushMatrix();
            GL.LoadOrtho();
            GL.Begin(GL.QUADS);
            GL.TexCoord2(0.0f, 0.0f);
            GL.Vertex3(0.0f, 0.0f, 0.0f);
            GL.TexCoord2(1.0f, 0.0f);
            GL.Vertex3(1.0f, 0.0f, 0.0f);
            GL.TexCoord2(1.0f, 1.0f);
            GL.Vertex3(1.0f, 1.0f, 0.0f);
            GL.TexCoord2(0.0f, 1.0f);
            GL.Vertex3(0.0f, 1.0f, 0.0f);
            GL.End();
            GL.PopMatrix();
            Graphics.SetRenderTarget(null);
        }
        }

        protected virtual void OnDestroy()
        {
            foreach(var data in _uniformDataDic.Values)
            {
                data.RenderBuffer.Release();
            }
            _uniformDataDic.Clear();
        }

        protected virtual void Init()
        {
            foreach(var data in _uniformDataDic.Values)
            {
                data.Time = Time.time;
                data.FrameCount = 0;
            }
            OnInit?.Invoke();
        }
    }
}
