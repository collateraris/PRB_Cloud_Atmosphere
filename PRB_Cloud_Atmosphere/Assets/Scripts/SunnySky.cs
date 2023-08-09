using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;

public class SunnySky : MonoBehaviour
{

    const float SCALE = 1000.0f;

    const int TRANSMITTANCE_WIDTH = 256;
    const int TRANSMITTANCE_HEIGHT = 64;
    const int TRANSMITTANCE_CHANNELS = 3;

    const int IRRADIANCE_WIDTH = 64;
    const int IRRADIANCE_HEIGHT = 16;
    const int IRRADIANCE_CHANNELS = 3;

    const int INSCATTER_WIDTH = 256;
    const int INSCATTER_HEIGHT = 128;
    const int INSCATTER_DEPTH = 32;
    const int INSCATTER_CHANNELS = 4;

    public Material m_sunnySkyMaterial;
    public float m_sunIntensity = 3.0f;
    public int m_AtmosphereSamples = 32;
    public float m_AtmosphereRadius = 6471000;
    public Vector3 m_ObservationPos = new Vector3(0.0f, 6371000.0f, 0.0f);
    public GameObject m_sun;

    public string m_filePath = "/Textures";

    private Texture2D m_transmittance, m_irradiance;

    private Texture3D m_inscatter;

    public Texture2D m_perlinNoise2D;

    public Texture3D m_cloudBaseTexture;
    public Texture3D m_cloudDetailTexture;
    public Texture2D m_weatherMapTexture;

    [SerializeField, Range(0,2)]
    private float coverageScale = 1.2f;

    [SerializeField, Range(0,2)]
    private float sunAttenuation = 1.0f;

    // void OnGUI()
	// {
	// 	GUI.Label (new Rect(10,10,100,30), "Cloud Coverage");
	// 	coverageScale = GUI.HorizontalSlider (new Rect (10, 30, 100, 30), coverageScale, 0,2);

    //     GUI.Label (new Rect(10,40,100,30), "Sun Attenuation");
	// 	sunAttenuation = GUI.HorizontalSlider (new Rect (10, 60, 100, 30), sunAttenuation, 0,2);
	// }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, m_sunnySkyMaterial);
    }

    // Start is called before the first frame update
    private void Start()
        {
            //NOTE - These raw files will not be included by Unity in the build so you will get a 
            //error saying they are missing. You will need to manually place them in the build folder
            //or change to using a supported format like exr.

            //Transmittance is responsible for the change in the sun color as it moves
            //The raw file is a 2D array of 32 bit floats with a range of 0 to 1
            string path = Application.dataPath + m_filePath + "/transmittance.raw";
            int size = TRANSMITTANCE_WIDTH * TRANSMITTANCE_HEIGHT * TRANSMITTANCE_CHANNELS;

            m_transmittance = new Texture2D(TRANSMITTANCE_WIDTH, TRANSMITTANCE_HEIGHT, TextureFormat.RGBAHalf, false, true);
            m_transmittance.SetPixels(ToColor(LoadRawFile(path, size), TRANSMITTANCE_CHANNELS));
            m_transmittance.Apply();

            path = Application.dataPath + m_filePath + "/irradiance.raw";
            size = IRRADIANCE_WIDTH * IRRADIANCE_HEIGHT * IRRADIANCE_CHANNELS;

            m_irradiance = new Texture2D(IRRADIANCE_WIDTH, IRRADIANCE_HEIGHT, TextureFormat.RGBAHalf, false, true);
            m_irradiance.SetPixels(ToColor(LoadRawFile(path, size), IRRADIANCE_CHANNELS));
            m_irradiance.Apply();

            //Inscatter is responsible for the change in the sky color as the sun moves
            //The raw file is a 4D array of 32 bit floats with a range of 0 to 1.589844
            //As there is not such thing as a 4D texture the data is packed into a 3D texture 
            //and the shader manually performs the sample for the 4th dimension
            path = Application.dataPath + m_filePath + "/inscatter.raw";
            size = INSCATTER_WIDTH * INSCATTER_HEIGHT * INSCATTER_DEPTH * INSCATTER_CHANNELS;

            //Should be linear color space. I presume 3D textures always are.
            m_inscatter = new Texture3D(INSCATTER_WIDTH, INSCATTER_HEIGHT, INSCATTER_DEPTH, TextureFormat.RGBAHalf, false);
            m_inscatter.SetPixels(ToColor(LoadRawFile(path, size), INSCATTER_CHANNELS));
            m_inscatter.Apply();

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
        mat.SetFloat("iTime", Time.time);
        mat.SetFloat("SUN_INTENSITY", m_sunIntensity);
        mat.SetVector("EARTH_POS", m_ObservationPos);
        mat.SetVector("SUN_DIR", m_sun.transform.forward);
        mat.SetTexture("_Transmittance", m_transmittance);
        mat.SetTexture("_Irradiance", m_irradiance);
        mat.SetTexture("_Inscatter", m_inscatter);
        mat.SetTexture("_PerlinNoise2D", m_perlinNoise2D);
        mat.SetTexture("_NoiseTex", m_cloudBaseTexture);
        mat.SetTexture("_CloudDetailTexture", m_cloudDetailTexture);
        mat.SetTexture("_WeatherMapTex", m_weatherMapTexture);


        mat.SetFloat("_CoverageScale", coverageScale);
        mat.SetFloat("_SunAttenuation", sunAttenuation);
    }

    private float[] LoadRawFile(string path, int size)
    {
        FileInfo fi = new FileInfo(path);

        if (fi == null)
        {
            Debug.Log("Raw file not found (" + path + ")");
            return null;
        }

        FileStream fs = fi.OpenRead();
        byte[] data = new byte[fi.Length];
        fs.Read(data, 0, (int)fi.Length);
        fs.Close();

        //divide by 4 as there are 4 bytes in a 32 bit float
        if (size > fi.Length / 4)
        {
            Debug.Log("Raw file is not the required size (" + path + ")");
            return null;
        }

        float[] map = new float[size];
        for (int x = 0, i = 0; x < size; x++, i += 4)
        {
            //Convert 4 bytes to 1 32 bit float
            map[x] = System.BitConverter.ToSingle(data, i);
        };

        return map;
    }

    private Color[] ToColor(float[] data, int channels)
    {
        int count = data.Length / channels;
        Color[] col = new Color[count];
        
        for(int i = 0; i < count; i++)
        {
            if (channels > 0) col[i].r = data[i * channels + 0];
            if (channels > 1) col[i].g = data[i * channels + 1];
            if (channels > 2) col[i].b = data[i * channels + 2];
            if (channels > 3) col[i].a = data[i * channels + 3];
        }

        return col;
    }
}
