using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ObservaterView : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    // Update is called once per frame
    void Update()
    {

    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {

        Graphics.Blit(source, destination);
        return;
    }

}
