using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SunnySky : MonoBehaviour
{

    public Material m_sunnySkyMaterial;
    public float m_sunIntensity = 100.0f;
    public int m_AtmosphereSamples = 32;
    public float m_AtmosphereRadius = 6471000;
    public Vector3 m_ObservationPos = new Vector3(0.0f, 6371000.0f, 0.0f);
    public GameObject m_sun;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        UpdateMat(m_sunnySkyMaterial);
    }

    public void UpdateMat(Material mat)
    {
        if (mat == null) return;

        mat.SetInt("ATMOSPHERE_SAMPLES", m_AtmosphereSamples);
        mat.SetFloat("ATMOSPHERE_RADIUS", m_AtmosphereRadius);
        mat.SetFloat("SUN_INTENSITY", m_sunIntensity);
        mat.SetVector("EARTH_POS", m_ObservationPos);
        mat.SetVector("SUN_DIR", m_sun.transform.forward * -1.0f);

    }
}
