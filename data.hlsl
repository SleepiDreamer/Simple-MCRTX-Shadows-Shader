// Group size
// AccumulateGIInscatter (16, 16, 1)
// AccumulateInscatter (16, 16, 1)
// FilterMoments (16, 16, 1)
// BlendCheckerboardFields (16, 16, 1)
// AdaptiveDenoiserCalculateGradientsInline (4, 8, 1)
// AdaptiveDenoiserGenerateReferenceInline (4, 8, 1)
// Atrous (16, 8, 1)
// AtrousSH (16, 8, 1)
// UpdateVertexIrradianceCacheInline (32, 1, 1)
// FilterMomentsSH (16, 16, 1)
// CopyToFinal (16, 16, 1)
// BlendCheckerboardFieldsSH (16, 16, 1)
// BlendCheckerboardFieldsShadow (16, 16, 1)
// BlurGIInscatter (16, 16, 1)
// BlurGradients (128, 1, 1)
// CalculateFaceData (128, 1, 1)
// PreBlasSkinning (64, 1, 1)
// CalculateGIInscatterInline (4, 4, 2)
// CalculateInscatterInline (4, 4, 2)
// TileClassification (16, 16, 1)
// CheckerboardInterleave (16, 16, 1)
// CheckerboardUpscale (16, 16, 1)
// CheckerboardUpscaleSH (16, 16, 1)
// TAA (16, 16, 1)
// ClearFaceIrradianceCache (128, 1, 1)
// ClearVertexIrradianceCache (128, 1, 1)
// FinalCombine (16, 16, 1)
// DiffuseFireflyFilter (16, 16, 1)
// ShadowDenoising (16, 16, 1)
// PrimaryCheckerboardRayGenInline (4, 8, 1)
// IncidentLightMeterInline (4, 4, 2)
// DiffuseFireflyFilterSH (16, 16, 1)
// DiffuseRayGenCombinedInline (4, 8, 1)
// DrawLights (16, 16, 1)
// ExplicitLightSamplingInline (4, 8, 1)
// FinalizeDenoising (16, 16, 1)
// PathTracingRayGenInline (4, 8, 1)
// RefractionRayGenInline (4, 8, 1)
// Reproject (16, 16, 1)
// ReprojectSH (16, 16, 1)
// ReprojectSpecularOnly (16, 16, 1)
// ResolveLightMeasurement (1, 1, 1)
// SpecularFireflyFilter (16, 16, 1)
// SpecularRayGenInline (4, 8, 1)
// SunShadowRayGenInline (4, 8, 1)
// TemporalDenoising (16, 16, 1)
// ToneCurve (256, 1, 1)
// ToneMappingHistogram (16, 16, 1)
// UpdateFaceIrradianceCacheInline (32, 1, 1)
// WFTest (16, 16, 1)

// Structs
struct AdaptiveDenoiserLightInfo {
    float position;  // 0
    float luminance; // 12
    int flags; // 16
};
struct CheckerboardActions {
    uint16_t mOddAction; // 0
    uint16_t mEvenAction; // 2
    uint16_t mSplitAction; // 4
    uint16_t mTotalReflectionAction; // 6
    float mCosCriticalAngle; // 8
};
struct DenoisingParameters {
    float phiLuminance; // 0
    float phiDepth; // 4
    float phiNormal; // 8
    float pad0; // 12
    float despeckleFilterRelativeDifferenceEpsilon; // 16
    float despeckleFilterRelativeDifferenceEpsilonDisocclusion; // 20
    float pad1; // 24
    float pad2; // 28
};
struct FaceData {
    uint packedNormal; // 0
    uint packedTangent; // 4
    uint packedBitangent; // 8
    half lodConstant; // 12
    uint16_t colourTextureMaxMip; // 14
};
struct FaceIrradianceCache {
    half outgoingFrontAndHistoryLength; // 0
    half outgoingBackAndPad; // 8
};
struct FaceIrradianceCacheUpdateChunk {
    uint objectInstanceIdxAndNumFaces; // 0
    uint firstFaceIdx; // 4
};
struct LightInfo {
    half position; // 0
    uint packedData; // 8
};
struct LightMeterData {
    float lightAccumulationAlpha; // 0
    float maxEV; // 4
    float minEV; // 8
    int accumulationNeedsReset; // 12
    float lobesDifferenceThreshold; // 16
    float lobesDifferenceAlphaMin; // 20
    float lobesDifferenceAlphaMax; // 24
    float manualExposureAdjustmentEv; // 28
};
struct MeshSkinningData {
    uint sizeOfVertex; // 0
    uint offsetToPosition; // 4
    uint offsetToPrevPos; // 8
    uint offsetToNormal; // 12
    uint offsetToBoneIndex; // 16
    uint vertexCount; // 20
    uint sourceVBIndex; // 24
    uint sourceVBOffset; // 28
    uint destVBIndex; // 32
    uint destVBOffset; // 36
    uint padding; // 40
    float4x4 bones[8];; // 48
};
struct ObjectInstance {
    float4x3 modelToWorld; // 0
    float4x3 prevModelToWorld; // 48
    uint vertexOffsetInBaseVertices; // 96
    uint vertexOffsetInParallelVertices; // 100
    uint indexOffsetInIndices; // 104
    uint16_t vbIdx; // 108
    uint16_t ibIdx; // 110
    uint16_t vertexStride; // 112
    uint16_t indexSize; // 114
    uint16_t colourTextureIdx; // 116
    uint16_t secondaryTextureIdx; // 118
    uint16_t tertiaryTextureIdx; // 120
    uint16_t flags; // 122
    uint16_t blasIdx; // 124
    uint16_t irradianceCacheMaxHistoryLength; // 126
    uint tintColour0; // 128
    uint tintColour1; // 132
    float irradianceCacheUpdateScore; // 136
    uint16_t objectCategory; // 140
    uint16_t offsetPack1; // 142
    uint16_t offsetPack2; // 144
    uint16_t offsetPack3; // 146
    uint16_t offsetPack4; // 148
    uint16_t offsetPack5; // 150
};
struct PBRTextureData {
    float colourToMaterialUvScale; // 0
    float colourToMaterialUvBias; // 8
    float colourToNormalUvScale; // 16
    float colourToNormalUvBias; // 24
    int flags; // 32
    float uniformRoughness; // 36
    float uniformEmissive; // 40
    float uniformMetalness; // 44
    float uniformSubsurface; // 48
    float maxMipColour; // 52
    float maxMipMer; // 56
    float maxMipNormal; // 60
};
struct RandomSamples {
    float hemisphereSamples[288];; // 0
};
struct VertexIrradianceCache {
    half incomingFrontAndHistoryLength; // 0
    half incomingBackAndPad; // 8
};
struct VertexIrradianceCacheUpdateChunk {
    uint objectInstanceIdxAndNumVertices; // 0
    uint firstVertexIdx; // 4
};
struct View {
    row_major float4x4 view; // 0
    row_major float4x4 viewProj; // 64
    row_major float4x4 proj; // 128
    row_major float4x4 invProj; // 192
    row_major float4x4 invView; // 256
    row_major float4x4 invViewProj; // 320
    row_major float4x4 prevViewProj; // 384
    row_major float4x4 prevView; // 448
    row_major float4x4 prevInvViewProj; // 512
    row_major float4x4 invTransposeView; // 576
    float posNdcToDirection[3];; // 640
    float posNdcToPrevDirection[3];; // 688
    DenoisingParameters denoisingParams[2];; // 736
    float sunColour; // 800
    float sunAzimuth; // 812
    float distanceFadeScaleBias; // 816
    float renderDistance; // 824
    float skyTextureW; // 828
    float directionToSun; // 832
    float sunColourTextureCoord; // 844
    float underwaterDirectionToSun; // 848
    uint numFramesSinceTeleport; // 860
    float volumetricLightingResolution; // 864
    uint cameraIsUnderWater; // 876
    float recipVolumetricLightingResolution; // 880
    uint previousVolumetricsAreValid; // 892
    float volumetricGILightingResolution; // 896
    float rainLevel; // 908
    float recipVolumetricGILightingResolution; // 912
    float pad1; // 924
    float skyColor; // 928
    float skyColorBlend; // 940
    float constantAmbient; // 944
    float nightVisionLevel; // 956
    float primaryMediaAbsorption; // 960
    float primaryMediaHenyeyGreensteinG; // 972
    float primaryMediaScattering; // 976
    float pad7; // 988
    float primaryMediaExtinction; // 992
    float pad8; // 1004
    float mediaExtinction[5];; // 1008
    float waveWorksOriginInSteveSpace; // 1088
    float causticsWCoord; // 1100
    float previousToCurrentCameraPosWorldSpace; // 1104
    float pad9; // 1116
    float previousToCurrentCameraPosSteveSpace; // 1120
    float pad10; // 1132
    float steveSpaceDelta; // 1136
    float pad11; // 1148
    float viewOriginSteveSpace; // 1152
    float tanHalfFovY; // 1164
    float previousViewOriginSteveSpace; // 1168
    float pad12; // 1180
    float skyTextureUVScale; // 1184
    uint skyTextureIdx; // 1192
    uint padSky; // 1196
    float skyColorUp; // 1200
    uint skyLightingType; // 1212
    float skyColorDown; // 1216
    uint skyBackgroundType; // 1228
    float finalCombineSkyColourOverride; // 1232
    float finalCombineSkyColourOverrideStrength; // 1244
    float renderResolution; // 1248
    float recipRenderResolution; // 1256
    float displayResolution; // 1264
    float recipDisplayResolution; // 1272
    float fieldSize; // 1280
    float volumetricFroxelIdxToNdcXyScale; // 1288
    float volumetricGIFroxelIdxToNdcXyScale; // 1296
    float subPixelJitter; // 1304
    float previousSubPixelJitter; // 1312
    float steveToCausticsScale; // 1320
    float steveToCausticsBias; // 1328
    float steveToWibblyScale; // 1336
    float steveToWibblyBias; // 1344
    uint frameCount; // 1352
    float emissiveMultiplier; // 1356
    float emissiveDesaturation; // 1360
    float indirectEmissiveBoostMultiplier; // 1364
    float surfaceWetness; // 1368
    float smoothertron; // 1372
    float mipmapBias; // 1376
    uint enableIrradianceCache; // 1380
    uint injectGlobalIlluminationIntoFog; // 1384
    float fogHenyeyGreensteinG; // 1388
    float waterHenyeyGreensteinG; // 1392
    float renderResolutionDivDisplayResolution; // 1396
    float displayResolutionDivRenderResolution; // 1400
    uint enableAdaptiveDenoiser; // 1404
    float previousResolutionDivRenderResolution; // 1408
    float diffuseTemporalAlpha; // 1412
    float diffuseTemporalAlphaMoments; // 1416
    float specularTemporalAlpha; // 1420
    float specularTemporalAlphaMoments; // 1424
    float primaryRaySpreadAngle; // 1428
    float primaryRayAlphaTestSpreadAngle; // 1432
    float heightMapPixelEdgeWidth; // 1436
    float recipHeightMapDepth; // 1440
    uint rayCountMultiplier; // 1444
    float heightToFogScale; // 1448
    float heightToFogBias; // 1452
    uint refModeAccumulatedFrames; // 1456
    uint renderMethod; // 1460
    uint debugMode; // 1464
    uint enableProbabilityBasedRaycasts; // 1468
    uint enableCausticsStabilizationInRefMode; // 1472
    uint enableRayReordering; // 1476
    uint enableExplicitLightSampling; // 1480
    uint cpuLightsCount; // 1484
    float explicitLightsIntensityBias; // 1488
    float focalDistance; // 1492
    float apertureSize; // 1496
    uint apertureType; // 1500
    float toneMappingShadowContrast; // 1504
    float toneMappingShadowContrastEnd; // 1508
    float toneMappingCurveShift; // 1512
    float toneMappingDynamicRange; // 1516
    float toneMappingShadowMinSlope; // 1520
    float toneMappingMaxExposureIncrease; // 1524
    uint toneMappingNeedsReset; // 1528
    uint enableTAA; // 1532
    uint enableSHDiffuse; // 1536
    uint cameraIsUnderLava; // 1540
    float cpuLightsCountRcp; // 1544
    uint reducedLightsCount; // 1548
    float reducedLightsCountRcp; // 1552
    float lightCullingDistance; // 1556
    float time; // 1560
    float skyIntensityAdjustment; // 1564
    float moonMeshIntensity; // 1568
    float sunMeshIntensity; // 1572
    float maxHistoryLength; // 1576
    uint missingTextureIndex; // 1580
    float genericDebugSlider0; // 1584
    float genericDebugSlider1; // 1588
    float genericDebugSlider2; // 1592
    float genericDebugSlider3; // 1596
};

// Samplers
SamplerState defaultSampler : register(s0);
SamplerState linearSampler : register(s1);
SamplerState linearWrapSampler : register(s2);

// CBVs
cbuffer LightMeterDataCB : register(u3) {
    LightMeterData g_lightMeterSamples; // 0
};
cbuffer PreBlasSkinningCB : register(u0, space99) {
    MeshSkinningData g_meshSkinningData; // 0
};
cbuffer RootConstants : register(u2) {
    uint g_rootConstant0; // 0
    uint g_rootConstant1; // 4
    uint g_dispatchDimensions; // 8
};
cbuffer ViewCB : register(u0) {
    View g_view; // 0
};

// SRVs
RaytracingAccelerationStructure SceneBVH : register(t0)
Texture2DArray<vector<float, 4> > blueNoiseTexture : register(t58)
Texture2DArray<float> causticsTexture : register(t60)
StructuredBuffer<CheckerboardActions> checkerboardActionsBuffer : register(t55)
StructuredBuffer<FaceIrradianceCacheUpdateChunk> faceIrradianceCacheUpdateChunks : register(t3)
Texture2D<vector<float, 2> > inputAdaptiveDenoiserGradients[2] : register(t51)
Texture2D<int> inputAdaptiveDenoiserPlaneIdentifier : register(t54)
Texture2D<vector<float, 2> > inputAdaptiveDenoiserReference : register(t53)
Texture2D<vector<float, 4> > inputBufferColourAndMetallic : register(t16)
Texture2D<vector<float, 4> > inputBufferIncomingIrradianceCache : register(t18)
Texture2D<vector<float, 2> > inputBufferMotionVectors : register(t21)
Texture2D<vector<float, 2> > inputBufferNormal : register(t15)
Texture2D<vector<float, 4> > inputBufferPreInterleaveCurrent : register(t25)
Texture2D<vector<float, 4> > inputBufferPreInterleavePrevious : register(t26)
Texture2D<int> inputBufferPreviousMedium : register(t63)
Texture2D<float> inputBufferPrimaryPathLength : register(t14)
Texture2D<vector<float, 2> > inputBufferReflectionMotionVectors : register(t22)
Texture2D<float> inputBufferReprojectedPathLength : register(t29)
Texture2D<vector<float, 2> > inputBufferSurfaceOpacityAndObjectCategory : register(t17)
Texture2D<vector<float, 4> > inputEmissiveAndLinearRoughness : register(t44)
Texture2D<vector<float, 4> > inputFinalColour : register(t42)
Texture2D<vector<float, 2> > inputFinalDiffuseMoments : register(t1, space9)
Texture2D<vector<float, 2> > inputFinalSpecularMoments : register(t3, space9)
Texture2D<vector<float, 2> > inputBufferGeometryNormal : register(t43)
StructuredBuffer<vector<float, 4> > inputIncidentLight : register(t19)
StructuredBuffer<LightInfo> inputLightsBuffer : register(t0, space13)
Texture2D<int> inputPlaneIdentifier : register(t27)
Texture2D<vector<float, 2> > inputPreviousGeometryNormal : register(t49)
Texture2D<vector<float, 4> > inputPrimaryPosLowPrecision : register(t50)
Texture2D<vector<float, 4> > inputPrimaryThroughput : register(t47)
Texture2D<vector<float, 4> > inputPrimaryViewDirection : register(t46)
Texture2D<vector<float, 4> > inputPrimaryWorldPosition : register(t45)
StructuredBuffer<LightInfo> inputReducedLightsBuffer : register(t1, space13)
Texture2D<vector<float, 4> > inputTAAHistory : register(t40)
StructuredBuffer<AdaptiveDenoiserLightInfo> inputTemporallyStableLights : register(t2, space13)
Texture2D<vector<float, 4> > inputThisFrameTAAHistory : register(t41)
Texture2D<int> inputTileClassification : register(t57)
StructuredBuffer<ObjectInstance> objectInstances : register(t1)
StructuredBuffer<PBRTextureData> pbrTextureDataBuffer : register(t35)
Texture2D<vector<float, 4> > previousDiffuseBuffer : register(t7)
Texture2D<vector<float, 3> > previousDiffuseChromaBuffer : register(t48)
Texture2D<vector<float, 2> > previousHistoryLengthBuffer : register(t6)
Texture2D<float> previousLinearRoughnessBuffer : register(t24)
Texture2D<vector<float, 2> > previousPrimaryNormalBuffer : register(t5)
Texture2D<float> previousPrimaryPathLengthBuffer : register(t4)
Texture2D<float> previousReflectionDistanceBuffer : register(t23)
Texture2D<vector<float, 3> > previousSpecularBuffer : register(t8)
Texture2D<vector<float, 4> > previousSunLightShadowBuffer : register(t30)
StructuredBuffer<float> refractionIndicesBuffer : register(t56)
Texture2D<vector<float, 4> > shadowDenoisingInputs[2] : register(t0, space4)
Texture2DArray<vector<float, 3> > skyTexture : register(t59)
Texture2D<vector<float, 4> > textures[4096] : register(t0, space6)
ByteAddressBuffer vertexBuffers[4096] : register(t0, space2)
StructuredBuffer<VertexIrradianceCacheUpdateChunk> vertexIrradianceCacheUpdateChunks : register(t2)
Texture3D<vector<float, 4> > volumetricGIInscatterPrevious : register(t39)
Texture3D<vector<float, 3> > volumetricGIResolvedInscatter : register(t38)
Texture3D<vector<float, 4> > volumetricInscatterPrevious : register(t13)
Texture3D<vector<float, 3> > volumetricResolvedInscatter : register(t11)
Texture3D<vector<float, 3> > volumetricResolvedTransmission : register(t12)
Texture2D<vector<float, 4> > waterNormalsTexture : register(t62)
Texture2D<vector<float, 2> > wibblyTexture : register(t61)

// UAVs
RWStructuredBuffer<vector<float, 4> > bufferIncidentLight : register(u0, space14)
RWTexture2D<vector<float, 4> > denoisingChromaAndVarianceOutputs[4] : register(u8, space3)
RWTexture2D<vector<float, 4> > denoisingOutputs[8] : register(u0, space3)
RWStructuredBuffer<FaceData> faceDataBuffersRW[4096] : register(u0, space10)
RWStructuredBuffer<FaceIrradianceCache> faceIrradianceCache[4096] : register(u0, space2)
RWStructuredBuffer<vector<unsigned int, 4> > faceUvBuffersRW[4096] : register(u0, space11)
RWTexture2D<vector<float, 2> > outputAdaptiveDenoiserGradients[2] : register(u36)
RWTexture2D<int> outputAdaptiveDenoiserPlaneIdentifier : register(u39)
RWTexture2D<vector<float, 2> > outputAdaptiveDenoiserReference : register(u38)
RWTexture2D<vector<float, 4> > outputBufferColourAndMetallic : register(u3)
RWTexture2D<vector<float, 4> > outputBufferDebug : register(u14)
RWTexture2D<vector<float, 2> > outputBufferDiffuseMoments : register(u40)
RWTexture2D<vector<float, 4> > outputBufferEmissiveAndLinearRoughness : register(u4)
RWTexture2D<vector<float, 4> > outputBufferFinal : register(u12)
RWTexture2D<vector<float, 2> > outputBufferHistoryLength : register(u2)
RWTexture2D<vector<float, 4> > outputBufferIncomingIrradianceCache : register(u11)
RWTexture2D<vector<float, 4> > outputBufferIndirectDiffuse : register(u5)
RWTexture2D<vector<float, 3> > outputBufferIndirectDiffuseChroma : register(u28)
RWTexture2D<vector<float, 4> > outputBufferIndirectSpecular : register(u6)
RWTexture2D<vector<float, 2> > outputBufferMotionVectors : register(u10)
RWTexture2D<vector<float, 2> > outputBufferNormal : register(u1)
RWTexture2D<vector<float, 4> > outputBufferPreInterleave : register(u18)
RWTexture2D<float> outputBufferPreviousLinearRoughness : register(u17)
RWTexture2D<int> outputBufferPreviousMedium : register(u45)
RWTexture2D<vector<float, 4> > outputBufferPreviousSunLightShadow : register(u22)
RWTexture2D<float> outputBufferPrimaryPathLength : register(u0)
RWTexture2D<vector<float, 4> > outputBufferPrimaryPosLowPrecision : register(u29)
RWTexture2D<vector<float, 4> > outputBufferReferencePathTracer : register(u23)
RWTexture2D<float> outputBufferReflectionDistance : register(u15)
RWTexture2D<vector<float, 2> > outputBufferReflectionMotionVectors : register(u16)
RWTexture2D<float> outputBufferReprojectedPathLength : register(u20)
RWTexture2D<vector<float, 2> > outputBufferSpecularMoments : register(u42)
RWTexture2D<vector<float, 4> > outputBufferSunLightShadow : register(u21)
RWTexture2D<vector<float, 2> > outputBufferSurfaceOpacityAndObjectCategory : register(u7)
RWTexture2D<vector<float, 4> > outputBufferTAAHistory : register(u30)
RWTexture2D<float> outputBufferToneCurve : register(u27)
RWTexture2D<unsigned int> outputBufferPrimaryObjectInstance : register(u26)
RWTexture2D<vector<float, 2> > outputDenoisingMoments[4] : register(u40)
RWTexture2D<vector<float, 2> > outputGeometryNormal : register(u31)
RWTexture2D<int> outputPlaneIdentifier : register(u19)
RWTexture2D<vector<float, 4> > outputPrimaryThroughput : register(u35)
RWTexture2D<vector<float, 4> > outputPrimaryViewDirection : register(u34)
RWTexture2D<vector<float, 4> > outputPrimaryWorldPosition : register(u33)
RWTexture2D<int> outputTileClassification : register(u44)
RWStructuredBuffer<unsigned int> outputVisibleBLASs : register(u32)
RWTexture2D<vector<float, 4> > shadowDenoisingOutputs[2] : register(u0, space4)
RWByteAddressBuffer vertexBuffersRW[4096] : register(u0, space9)
RWStructuredBuffer<VertexIrradianceCache> vertexIrradianceCache[4096] : register(u0, space1)
RWTexture3D<vector<float, 4> > volumetricGIInscatterRW[2] : register(u64)
RWTexture3D<vector<float, 3> > volumetricGIResolvedInscatterRW : register(u63)
RWTexture3D<vector<float, 4> > volumetricInscatterRW : register(u62)
RWTexture3D<vector<float, 3> > volumetricResolvedInscatterRW : register(u60)
RWTexture3D<vector<float, 3> > volumetricResolvedTransmissionRW : register(u61)