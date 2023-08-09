using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Clouds : MonoBehaviour
{
    [SerializeField]
    private Material m_cloudsMaterial;

    private Camera m_camera;
    // Start is called before the first frame update
    void Start()
    {
        m_camera = GetComponent<Camera>();
    }

    // Update is called once per frame
    void Update()
    {
        var invMat = GL.GetGPUProjectionMatrix(m_camera.projectionMatrix, false).inverse;
        m_cloudsMaterial.SetMatrix("_MainCameraInvProj", invMat);
        m_cloudsMaterial.SetMatrix("_MainCameraInvView", m_camera.cameraToWorldMatrix);
        m_cloudsMaterial.SetVector("_CameraPosWS", m_camera.transform.position);
        m_cloudsMaterial.SetFloat("_CameraNearPlane", m_camera.nearClipPlane);


    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, m_cloudsMaterial);
    }
}
