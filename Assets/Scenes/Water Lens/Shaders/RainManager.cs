using UnityEngine;

public class RainManager : MonoBehaviour
{
    [Range(0f, 1f)]
    public float rainIntensity = 0.5f;

    public Material lensMaterial;
    public Material surfaceRainMaterial;

    static readonly int RainIntensityID = Shader.PropertyToID("_RainIntensity");

    void Update()
    {
        Shader.SetGlobalFloat(RainIntensityID, rainIntensity);

        if (lensMaterial) lensMaterial.SetFloat(RainIntensityID, rainIntensity);
        if (surfaceRainMaterial) surfaceRainMaterial.SetFloat(RainIntensityID, rainIntensity);
    }
}
