using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.Events;

namespace UnityRayMarching
{
    public class RayMarching : MonoBehaviour
    {
        [SerializeField] protected Material _material;
        [SerializeField] protected Material _postProcessMaterial;
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

            if(_uniformDataDic.TryGetValue(Camera.current, out ShaderUniformData data))
            {
                _material.SetFloat("_FrameCount", data.FrameCount);
                _material.SetFloat("_ElapsedTime", data.Time);
                _material.SetVector("_Resolution", new Vector2(data.Resolution.x, data.Resolution.y));
                _material.SetTexture("_BackBuffer", data.BackBuffer);
            }
            else
            {
                data = new ShaderUniformData()
                {
                    Time = 0,
                    FrameCount = 0,
                    Resolution = new Vector2Int(source.width, source.height),
                    BackBuffer = new RenderTexture(source.descriptor)
                };
                _uniformDataDic.Add(Camera.current, data);
            }

            data.Time += Time.deltaTime;
            data.FrameCount++;

            if(data.Resolution.x != source.width || data.Resolution.y != source.height)
            {
                data.Resolution = new Vector2Int(source.width, source.height);
                data.BackBuffer.Release();
                data.BackBuffer = new RenderTexture(source.descriptor);
            }

            RenderTexture temp = RenderTexture.GetTemporary(source.descriptor);
            Graphics.Blit(null, temp, _material);
            Graphics.Blit(temp, data.BackBuffer);
            RenderTexture.ReleaseTemporary(temp);

            if(_postProcessMaterial == null)
            {
                Graphics.Blit(data.BackBuffer, source);
            }
            else
            {
                Graphics.Blit(data.BackBuffer, source, _postProcessMaterial);
            }
        }

        protected virtual void OnDestroy()
        {
            foreach(var data in _uniformDataDic.Values)
            {
                data.BackBuffer.Release();
            }
            _uniformDataDic.Clear();
        }

        protected virtual void Init()
        {
            foreach(var data in _uniformDataDic.Values)
            {
                data.Time = 0;
                data.FrameCount = 0;
            }
            OnInit?.Invoke();
        }
    }
}
