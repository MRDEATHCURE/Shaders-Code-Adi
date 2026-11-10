
using UnityEngine;

public class ToonShaderDemo : MonoBehaviour
{
    [Header("References")]
    [SerializeField] private Renderer targetRenderer;
    [SerializeField] private Light directionalLight;

    [Header("Animation")]
    [SerializeField] private bool animate = true;
    [SerializeField] private float animationSpeed = 1f;
    [SerializeField] private bool rotateLight = true;
    [SerializeField] private float lightRotationSpeed = 25f;

    [Header("Animated Properties")]
    [SerializeField] private bool animateShadowThreshold = true;
    [SerializeField] private bool animateHighlightThreshold = true;
    [SerializeField] private bool animateSmoothness = true;
    [SerializeField] private bool animateRim = true;
    [SerializeField] private bool animateColors = true;

    [Header("Shadow Threshold")]
    [Range(0f, 1f)]
    [SerializeField] private float minShadowThreshold = 0.15f;

    [Range(0f, 1f)]
    [SerializeField] private float maxShadowThreshold = 0.5f;

    [Header("Highlight Threshold")]
    [Range(0f, 1f)]
    [SerializeField] private float minHighlightThreshold = 0.6f;

    [Range(0f, 1f)]
    [SerializeField] private float maxHighlightThreshold = 0.9f;

    [Header("Band Smoothness")]
    [Range(0.001f, 0.3f)]
    [SerializeField] private float minSmoothness = 0.001f;

    [Range(0.001f, 0.3f)]
    [SerializeField] private float maxSmoothness = 0.15f;

    [Header("Rim Lighting")]
    [Range(0f, 3f)]
    [SerializeField] private float minRimIntensity = 0f;

    [Range(0f, 3f)]
    [SerializeField] private float maxRimIntensity = 2f;

    [Header("Colors")]
    [SerializeField]
    private Color shadowColorA =
        new Color(0.15f, 0.15f, 0.3f);

    [SerializeField]
    private Color shadowColorB =
        new Color(0.4f, 0.1f, 0.2f);

    [SerializeField]
    private Color midColorA =
        new Color(0.6f, 0.6f, 0.7f);

    [SerializeField]
    private Color midColorB =
        new Color(0.8f, 0.5f, 0.3f);

    [SerializeField] private Color highlightColorA = Color.white;
    [SerializeField]
    private Color highlightColorB =
        new Color(1f, 0.85f, 0.5f);

    // Shader property IDs
    private static readonly int ShadowThresholdID =
        Shader.PropertyToID("_ShadowThreshold");

    private static readonly int HighlightThresholdID =
        Shader.PropertyToID("_HighlightThreshold");

    private static readonly int SmoothnessID =
        Shader.PropertyToID("_BandSmoothness");

    private static readonly int RimIntensityID =
        Shader.PropertyToID("_RimIntensity");

    private static readonly int ShadowColorID =
        Shader.PropertyToID("_ShadowColor");

    private static readonly int MidColorID =
        Shader.PropertyToID("_MidColor");

    private static readonly int HighlightColorID =
        Shader.PropertyToID("_HighlightColor");

    private MaterialPropertyBlock propertyBlock;
    private float animationTime;

    private void Awake()
    {
        if (targetRenderer == null)
        {
            Debug.LogError(
                "ToonShaderDemo: Assign a Target Renderer.",
                this
            );

            enabled = false;
            return;
        }

        propertyBlock = new MaterialPropertyBlock();
    }

    private void Update()
    {
        if (rotateLight && directionalLight != null)
        {
            directionalLight.transform.Rotate(
                Vector3.up,
                lightRotationSpeed * Time.deltaTime,
                Space.World
            );
        }

        if (!animate)
            return;

        animationTime += Time.deltaTime * animationSpeed;

        // Offset the animations so they don't
        // all change at exactly the same moment.
        float shadowT =
            Mathf.PingPong(animationTime * 0.4f, 1f);

        float highlightT =
            Mathf.PingPong(animationTime * 0.3f + 0.3f, 1f);

        float smoothnessT =
            Mathf.PingPong(animationTime * 0.2f + 0.5f, 1f);

        float rimT =
            Mathf.PingPong(animationTime * 0.5f, 1f);

        float colorT =
            (Mathf.Sin(animationTime * 0.7f) + 1f) * 0.5f;

        targetRenderer.GetPropertyBlock(propertyBlock);

        if (animateShadowThreshold)
        {
            float value = Mathf.Lerp(
                minShadowThreshold,
                maxShadowThreshold,
                shadowT
            );

            propertyBlock.SetFloat(ShadowThresholdID, value);
        }

        if (animateHighlightThreshold)
        {
            float value = Mathf.Lerp(
                minHighlightThreshold,
                maxHighlightThreshold,
                highlightT
            );

            propertyBlock.SetFloat(HighlightThresholdID, value);
        }

        if (animateSmoothness)
        {
            float value = Mathf.Lerp(
                minSmoothness,
                maxSmoothness,
                smoothnessT
            );

            propertyBlock.SetFloat(SmoothnessID, value);
        }

        if (animateRim)
        {
            float value = Mathf.Lerp(
                minRimIntensity,
                maxRimIntensity,
                rimT
            );

            propertyBlock.SetFloat(RimIntensityID, value);
        }

        if (animateColors)
        {
            propertyBlock.SetColor(
                ShadowColorID,
                Color.Lerp(shadowColorA, shadowColorB, colorT)
            );

            propertyBlock.SetColor(
                MidColorID,
                Color.Lerp(midColorA, midColorB, colorT)
            );

            propertyBlock.SetColor(
                HighlightColorID,
                Color.Lerp(
                    highlightColorA,
                    highlightColorB,
                    colorT
                )
            );
        }

        targetRenderer.SetPropertyBlock(propertyBlock);
    }

    [ContextMenu("Restart Animation")]
    public void RestartAnimation()
    {
        animationTime = 0f;
    }

    [ContextMenu("Clear Shader Overrides")]
    public void ClearShaderOverrides()
    {
        if (targetRenderer == null)
            return;

        if (propertyBlock == null)
            propertyBlock = new MaterialPropertyBlock();

        targetRenderer.GetPropertyBlock(propertyBlock);

        propertyBlock.Clear();
        targetRenderer.SetPropertyBlock(propertyBlock);
    }
}
