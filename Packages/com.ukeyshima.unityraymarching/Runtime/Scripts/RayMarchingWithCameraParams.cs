using UnityEngine;

namespace UnityRayMarching
{
    public class RayMarchingWithCameraParams : RayMarching
    {
        protected virtual void OnRenderObject()
        {
            _material.SetVector("_CameraPos", Camera.current.transform.position);
            _material.SetVector("_CameraDir", Camera.current.transform.forward);
            _material.SetVector("_CameraUp", Camera.current.transform.up);
            base.OnRenderObject();
        }
    }
}