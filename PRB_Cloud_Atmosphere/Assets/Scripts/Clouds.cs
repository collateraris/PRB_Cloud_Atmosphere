using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Clouds : MonoBehaviour
{
    [SerializeField]
    private Material m_cloudsMaterial;

    private Camera m_camera;

    public float m_sunIntensity = 2.0f;
    public int m_AtmosphereSamples = 32;
    public float m_AtmosphereRadius = 6471000;
    public Vector3 m_ObservationPos = new Vector3(0.0f, 6371000.0f, 0.0f);
    public GameObject m_sun;


    public Texture3D m_cloudBaseTexture;
    public Texture3D m_cloudDetailTexture;
    public Texture2D m_weatherMapTexture;

    [SerializeField, Range(0, 2)]
    private float coverageScale = 1.2f;

    [SerializeField, Range(0, 2)]
    private float sunAttenuation = 1.0f;

    [SerializeField]
    private float AbsportionCoEff = 0;
    [SerializeField, Range(0.01f, 1f)]
    private float ScatteringCoEff = 0.104f;
    [SerializeField, Range(0f, 1f)]
    private float PowderCoEff = 0.132f;
    [SerializeField, Range(0f, 1f)]
    private float PowderScale = 0.718f;

    [SerializeField, Range(0.01f, 0.9f)]
    private float _hg = 0.6f;

    [SerializeField, Range(0.01f, 5f)]
    private float _silverIntensity = 1.49f;
    [SerializeField, Range(0.01f, 1f)]
    private float _silverSpread = 0.82f;

    [SerializeField, Range(0.1f, 100)]
    private float cloudDensityScale = 1.24f;

    void OnGUI()
    {
        GUI.Label(new Rect(10, 10, 100, 30), "Cloud Coverage");
        coverageScale = GUI.HorizontalSlider(new Rect(10, 30, 100, 30), coverageScale, 0, 2);

        GUI.Label(new Rect(10, 40, 100, 30), "Cloud Density");
        cloudDensityScale = GUI.HorizontalSlider(new Rect(10, 60, 100, 30), cloudDensityScale, 0, 100);
    }
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

        m_cloudsMaterial.SetInt("ATMOSPHERE_SAMPLES", m_AtmosphereSamples);
        m_cloudsMaterial.SetFloat("ATMOSPHERE_RADIUS", m_AtmosphereRadius);
        m_cloudsMaterial.SetFloat("iTime", Time.time);
        m_cloudsMaterial.SetFloat("SUN_INTENSITY", m_sunIntensity);
        m_cloudsMaterial.SetVector("EARTH_POS", m_ObservationPos);
        m_cloudsMaterial.SetVector("SUN_DIR", m_sun.transform.forward);
        m_cloudsMaterial.SetTexture("_NoiseTex", m_cloudBaseTexture);
        m_cloudsMaterial.SetTexture("_CloudDetailTexture", m_cloudDetailTexture);
        m_cloudsMaterial.SetTexture("_WeatherMapTex", m_weatherMapTexture);


        m_cloudsMaterial.SetFloat("_CoverageScale", coverageScale);
        m_cloudsMaterial.SetFloat("_SunAttenuation", sunAttenuation);
        m_cloudsMaterial.SetFloat("_AbsportionCoEff", AbsportionCoEff);
        m_cloudsMaterial.SetFloat("_ScatteringCoEff", ScatteringCoEff);
        m_cloudsMaterial.SetFloat("_PowderCoEff", PowderCoEff);
        m_cloudsMaterial.SetFloat("_PowderScale", PowderScale); 
        m_cloudsMaterial.SetFloat("_HG", _hg);
        m_cloudsMaterial.SetFloat("_SilverIntensity", _silverIntensity);
        m_cloudsMaterial.SetFloat("_SilverSpread", _silverSpread);
        m_cloudsMaterial.SetFloat("_CloudDensityScale", cloudDensityScale);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, m_cloudsMaterial);
    }
}
