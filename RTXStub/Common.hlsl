#ifndef _RT_COMMON_HLSL_
#define _RT_COMMON_HLSL_

#define PI 3.14159265359
#define HALF_PI 1.57079632679
#define TWO_PI 6.28318530718
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

// Defines that must match the cpp code
#define BGFX_CONFIG_MAX_VERTEX_BUFFERS 4096
#define BGFX_CONFIG_MAX_INDEX_BUFFERS 4096
#define BGFX_CONFIG_MAX_TEXTURES 4096

// ---[ Structures ]---
#define OBJECT_CATEGORY_OPAQUE 		0
#define OBJECT_CATEGORY_ALPHA_TEST 	1
#define OBJECT_CATEGORY_ALPHA_BLEND 2
#define OBJECT_CATEGORY_WATER		3

// Instance masks for use in the acceleration structure.
#define INSTANCE_MASK_OPAQUE_OR_ALPHA_TEST_PRIMARY   (1 << 0)
#define INSTANCE_MASK_OPAQUE_OR_ALPHA_TEST_SECONDARY (1 << 1)
#define INSTANCE_MASK_OPAQUE_OR_ALPHA_TEST_IRR_CACHE (1 << 2)
#define INSTANCE_MASK_ALPHA_BLENDED_PRIMARY          (1 << 3)
#define INSTANCE_MASK_ALPHA_BLENDED_SECONDARY        (1 << 4)
#define INSTANCE_MASK_WATER                          (1 << 5)
#define INSTANCE_MASK_SUN_OR_MOON                    (1 << 6)

// Custom instance mask combinations.
#define INSTANCE_MASK_PRIMARY (INSTANCE_MASK_OPAQUE_OR_ALPHA_TEST_PRIMARY | INSTANCE_MASK_SUN_OR_MOON | INSTANCE_MASK_ALPHA_BLENDED_PRIMARY)
#define INSTANCE_MASK_SECONDARY (INSTANCE_MASK_OPAQUE_OR_ALPHA_TEST_SECONDARY | INSTANCE_MASK_ALPHA_BLENDED_SECONDARY)
#define INSTANCE_MASK_THROUGHPUT (INSTANCE_MASK_PRIMARY | INSTANCE_MASK_WATER)
#define INSTANCE_MASK_SHADOW (INSTANCE_MASK_OPAQUE_OR_ALPHA_TEST_SECONDARY | INSTANCE_MASK_ALPHA_BLENDED_SECONDARY | INSTANCE_MASK_WATER)

// For tracking media during refraction
// It would be nice if these could be an enum, but that crashes the dxc compiler
#define MEDIA_TYPE_WATER 		0
#define MEDIA_TYPE_GLASS 		1
#define MEDIA_TYPE_AIR 			2
#define MEDIA_TYPE_CLOUD 		3
#define MEDIA_TYPE_SOLID 		4
#define MEDIA_TYPE_COUNT 		5
#define MEDIA_TYPE_WATER_OR_AIR 6

static const float kSkyDistance = 65504.0f;

// Flags for various object properties.
static const uint16_t objectFlagUsesIrradianceCache = (1 << 0);
static const uint16_t objectFlagHasMotionVectors    = (1 << 1);
static const uint16_t objectFlagHasSeasonsTexture   = (1 << 2);
static const uint16_t objectFlagMaskedMultiTexture  = (1 << 3);
static const uint16_t objectFlagMultiTexture        = (1 << 4);
static const uint16_t objectFlagMultiplicativeTint  = (1 << 5);
static const uint16_t objectFlagOverlay             = (1 << 6);
static const uint16_t objectFlagClouds              = (1 << 7);
static const uint16_t objectFlagChunk               = (1 << 8);
static const uint16_t objectFlagSun                 = (1 << 9);
static const uint16_t objectFlagMoon                = (1 << 10);
static const uint16_t objectFlagVanillaRemapAlpha   = (1 << 11); // For back-compat with vanilla water and glass textures
static const uint16_t objectFlagAlphaTestThresholdHalf = (1 << 12);
static const uint16_t objectFlagTextureAlphaControlsVertexColour = (1 << 13);
static const uint16_t objectFlagGlint               = (1 << 14);

// Custom object flag combinations.
static const uint16_t objectFlagSunOrMoon = (objectFlagSun | objectFlagMoon);

// Pre-defined object instance struct.
struct ObjectInstance
{
	float4x3 modelToWorld;
	float4x3 prevModelToWorld;

	uint vertexOffsetInBaseVertices;     // Use this when indexing the original (base) Minecraft vertex buffers
	uint vertexOffsetInParallelVertices; // Use this when indexing our parallel vertex buffers
	uint indexOffsetInIndices;

	uint16_t vbIdx;
	uint16_t ibIdx;
	uint16_t vertexStride; // bytes
	uint16_t indexSize;
	uint16_t colourTextureIdx;
	uint16_t secondaryTextureIdx;
	uint16_t tertiaryTextureIdx;
	uint16_t flags; // See kObjectInstanceFlag... above
	uint16_t blasIdx;
	uint16_t irradianceCacheMaxHistoryLength;

	uint32_t tintColour0;
	uint32_t tintColour1;

	float irradianceCacheUpdateScore;

	uint16_t objectCategory;

	uint16_t offsetPack1; // positionByteOffset && normalByteOffset
	uint16_t offsetPack2; // colourByteOffset && uv0ByteOffset
	uint16_t offsetPack3; // uv1ByteOffset && uv2ByteOffset
	uint16_t offsetPack4; // uv3ByteOffset && PBRTextureIdxByteOffset
	uint16_t offsetPack5; // previousPositionOffset && mediaType

	uint positionByteOffset() 
	{
		return offsetPack1 & 0xFF;
	}

	uint normalByteOffset()
	{
		return offsetPack1 >> 8;
	}

	uint colourByteOffset()
	{
		return offsetPack2 & 0xFF;
	}

	uint uv0ByteOffset()
	{
		return offsetPack2 >> 8;
	}

	uint uv1ByteOffset()
	{
		return offsetPack3 & 0xFF;
	}

	uint uv2ByteOffset()
	{
		return offsetPack3 >> 8;
	}

	uint uv3ByteOffset()
	{
		return offsetPack4 & 0xFF;
	}

	uint pBRTextureIdxByteOffset()
	{
		return offsetPack4 >> 8;
	}

	uint previousPositionByteOffset()
	{
		return offsetPack5 & 0xFF;
	}

	uint mediaType()
	{
		return offsetPack5 >> 8;
	}

	bool usesImplicitIndices()
	{
		// If the index buffer is invalid, then it means that we're not using an index
		// buffer, and the vertex buffer should be assumed to be laid out in quads thusly...
		//                         
		//      1 +-----------+ 2  
		//        |         / |    
		//        |       /   |    
		//        |     /     |    
		//        |   /       |    
		//        | /         |    
		//      0 +-----------+ 3  
		//                         
		// This presents problems for how to index our parallel buffers that are indexed
		// by primitive idx.
		// Normally, we'd have one of each of these buffers for each index buffer.
		// But that doesn't work when we don't have index buffers.
		// At the moment, we _only_ have geometry with implicit indices, so we're
		// moving all those buffers to be parallel to the vertex buffers instead.
		// We'll need to figure out what to do if and when we need to deal with
		// explicitly indexed geometry.
		return true;
	}

	uint getFaceIndexedBufferIdx()
	{
		if (usesImplicitIndices())
		{
			return vbIdx;
		}
		// We don't have a solution for this case yet.
		// Return an invalid buffer index.
		return 0xffffffff;
	}

	// Returns the absolute quad index to use when indexing one of our parallel quad-indexed face buffers
	uint calcParallelQuadIdx()
	{
		if (usesImplicitIndices())
		{
			uint parallelQuadIdx = vertexOffsetInParallelVertices / 4;
			return parallelQuadIdx;
		}
		else
		{
			return indexOffsetInIndices / 6;
		}
	}
};

// Pre-defined PBR texture data struct.
struct PBRTextureData
{
    // MAD parameters to transform colour UV into a material UV
    float2 colourToMaterialUvScale;
    float2 colourToMaterialUvBias;
    // MAD parameters to transform colour UV into a normal UV
    float2 colourToNormalUvScale;
    float2 colourToNormalUvBias;
    // See flag constants below
    int flags;
    // Uniform parameters to use in the case of a missing material texture
    float uniformRoughness;
    float uniformEmissive;
    float uniformMetalness;
    float uniformSubsurface;
	
    float maxMipColour;
    float maxMipMer;
    float maxMipNormal;
};

// Flags for various PBR texture properties.
static const int pbrTextureFlagHasMaterialTexture 	= (1 << 0);
static const int pbrTextureFlagHasSubsurfaceChannel = (1 << 1);
static const int pbrTextureFlagHasNormalTexture 	= (1 << 2);
static const int pbrTextureFlagHasHeightMapTexture 	= (1 << 3);

// Pre-defined struct for actions taken when checkerboard rendering, not useful in this example.
struct CheckerboardActions {
    uint16_t mOddAction;
    uint16_t mEvenAction;
    uint16_t mSplitAction;
    uint16_t mTotalReflectionAction;
    float mCosCriticalAngle;
};

// Pre-defined struct for face data.
struct FaceData
{
	uint      packedNormal;
	uint      packedTangent;
	uint      packedBitangent;
	float16_t lodConstant;
	uint16_t  colourTextureMaxMip;
};

// Pre-defined struct for the vertex irradiance cache, not useful in this example.
struct VertexIrradianceCache
{
	float16_t4 incomingFrontAndHistoryLength;
	float16_t4 incomingBackAndPad;

	float3 getIncomingFront() { return (float3) incomingFrontAndHistoryLength.rgb; }
	float3 getIncomingBack() { return (float3) incomingBackAndPad.rgb; }
	uint getHistoryLength() { return (uint) incomingFrontAndHistoryLength.w; }
};

// Pre-defined struct for the face irradiance cache, not useful in this example.
struct FaceIrradianceCache
{
	float16_t4 outgoingFrontAndHistoryLength;
	float16_t4 outgoingBackAndPad;

	float3 getOutgoingFront() { return (float3) outgoingFrontAndHistoryLength.rgb; }
	float3 getOutgoingBack() { return (float3) outgoingBackAndPad.rgb; }
	uint getHistoryLength() { return (uint) outgoingFrontAndHistoryLength.w; }
};

// Pre-defined struct for vertex irradiance cache updates, not useful in this example.
struct VertexIrradianceCacheUpdateChunk
{
	uint objectInstanceIdxAndNumVertices;
	uint firstVertexIdx;
};

// Pre-defined struct for face irradiance cache updates, not useful in this example.
struct FaceIrradianceCacheUpdateChunk
{
	uint objectInstanceIdxAndNumFaces;
	uint firstFaceIdx;
};

// Pre-defined struct for denoising parameters, not useful in this example.
struct DenoisingParameters
{
	float phiLuminance;
	float phiDepth;
	float phiNormal;
	float pad0;

	float despeckleFilterRelativeDifferenceEpsilon;
	float despeckleFilterRelativeDifferenceEpsilonDisocclusion;
	float pad1;
	float pad2;
};

// Expands a float4 containing the explcit light colour and size from the packed explicit light data.
float4 expandPackedColourAndSize(uint32_t packed, out bool isLarge)
{
    // MSB in red channel encodes whether light is small or large
    isLarge = (packed >> 24) & 0x80;

    return float4(
        (float)((packed >> 24) & 0x7f) * (1.f / 127.f),
        (float)((packed >> 16) & 0xff) * (1.f / 255.f),
        (float)((packed >> 8) & 0xff) * (1.f / 255.f),
        (float)((packed >> 0) & 0xff) * (1.f / 255.f)
		);
}

// Pre-defined struct for explicity light information, not useful in this example.
struct LightInfo
{
	float16_t3 position;
	uint32_t packedData; //< Packed light colour, intensity and size (small/large)

	float3 getIntensityAndSize(out float lightSize) {
		bool isLarge;
		float4 lightIntensity = expandPackedColourAndSize(packedData, isLarge);
		lightSize = getLightSize(isLarge);

		// Keep multiplication constant in sync with 'maxIntensity' in VanillaMinecraftRenderer.cpp
		return lightIntensity.rgb * (lightIntensity.a * 10.0f);
	}

	bool isValid() {
		return packedData != 0;
	}

	float getLightSize(bool isLarge) {
		if (isLarge) 
			return 0.23f; //< Lanterns, etc.
		else 
			return 0.115f; //< Torches, etc.
	}

	float getLightSize() {
		return getLightSize(packedData & 0x80000000);
	}
};

// Some pre-defined denoiser flags
static const int kAdaptiveDenoiserLightFlagNewToTheListButNotANewLight = (1 << 0);
static const int kAdaptiveDenoiserLightFlagMovingOutOfTheList          = (1 << 1);

// A pre-defined struct for adpative denoising of explicit lights.
struct AdaptiveDenoiserLightInfo
{
	float3 position;
	float  luminance;
	int    flags;
};

// ---[ Constant Buffers ]---

// The view struct, housing all necessary parameters 
struct View
{
	// Matrices (16-byte aligned)
	row_major float4x4 view;              // Offset:    0
	row_major float4x4 viewProj;          // Offset:   64
	row_major float4x4 proj;              // Offset:  128
	row_major float4x4 invProj;           // Offset:  192
	row_major float4x4 invView;           // Offset:  256
	row_major float4x4 invViewProj;       // Offset:  320
	row_major float4x4 prevViewProj;      // Offset:  384
	row_major float4x4 prevView;          // Offset:  448
	row_major float4x4 prevInvViewProj;   // Offset:  512
	row_major float4x4 invTransposeView;  // Offset:  576
	
	// 16-byte aligned fields
	float4 posNdcToDirection[3];          		  // Offset:  640     // For simpler, faster calculation of primary ray direction in world space
	float4 posNdcToPrevDirection[3];      		  // Offset:  688
	DenoisingParameters denoisingParams[2];       // Offset:  736
	
	// 16-byte aligned combos (typically float3 followed by a 4-byte value)
	float3 sunColour;                             // Offset:  800
	float  sunAzimuth;                            // Offset:  812

	float2 distanceFadeScaleBias;                 // Offset:  816
	float renderDistance;                         // Offset:  824
	float skyTextureW;                            // Offset:  828

	float3 directionToSun;                        // Offset:  832
	float sunColourTextureCoord;                  // Offset:  844 // -1 means to use 'sunColour'
	float3 underwaterDirectionToSun;              // Offset:  848
	uint   numFramesSinceTeleport;                // Offset:  860
	float3 volumetricLightingResolution;          // Offset:  864
	uint   cameraIsUnderWater;                    // Offset:  876 // bool
	float3 recipVolumetricLightingResolution;     // Offset:  880
	uint previousVolumetricsAreValid;             // Offset:  892
	float3 volumetricGILightingResolution;        // Offset:  896
	float rainLevel;                              // Offset:  908
	float3 recipVolumetricGILightingResolution;   // Offset:  912
	float pad1;                                   // Offset:  924
	float3 skyColor;                              // Offset:  928
	float skyColorBlend;                          // Offset:  940
	float3 constantAmbient;                       // Offset:  944 // For the Nether.  Hack.
	float nightVisionLevel;                       // Offset:  956 // 0 to 1
	// 'Primary Media' refers to either water or air, depending on whether the camera is underwater or not.
	float3 primaryMediaAbsorption;                // Offset:  960 // Absorption per metre.  This is considered 'lost' light.
	float primaryMediaHenyeyGreensteinG;          // Offset:  972
	float3 primaryMediaScattering;                // Offset:  976 // Proportion of light scattered per metre.
	float pad7;                                   // Offset:  988
	float3 primaryMediaExtinction;                // Offset:  992 // Sum of absorption and scattering.
	float pad8;                                   // Offset: 1004
	float4 mediaExtinction[MEDIA_TYPE_COUNT];     // Offset: 1008 // Sum of absorption and scattering.
	float3 waveWorksOriginInSteveSpace;           // Offset: 1088
	float causticsWCoord;                         // Offset: 1100 // For animation
	float3 previousToCurrentCameraPosWorldSpace;  // Offset: 1104
	float pad9;                                   // Offset: 1116
	float3 previousToCurrentCameraPosSteveSpace;  // Offset: 1120
	float pad10;                                  // Offset: 1132
	float3 steveSpaceDelta;                       // Offset: 1136 // Steve-Space translation in world space
	float pad11;                                  // Offset: 1148
	float3 viewOriginSteveSpace;                  // Offset: 1152
	float tanHalfFovY;                            // Offset: 1164
	float3 previousViewOriginSteveSpace;          // Offset: 1168
	float pad12;                                  // Offset: 1180

	float2 skyTextureUVScale;                     // Offset: 1184
	uint skyTextureIdx;                           // Offset: 1192
	uint padSky;                                  // Offset: 1196

	float3 skyColorUp;                            // Offset: 1200
	uint skyLightingType;                         // Offset: 1212

	float3 skyColorDown;                          // Offset: 1216
	uint skyBackgroundType;                       // Offset: 1228

	float3 finalCombineSkyColourOverride;         // Offset: 1232
	float finalCombineSkyColourOverrideStrength;  // Offset: 1244

	// 8-byte aligned fields
	float2 renderResolution;                      // Offset: 1248
	float2 recipRenderResolution;                 // Offset: 1256
	float2 displayResolution;                     // Offset: 1264
	float2 recipDisplayResolution;                // Offset: 1272
	float2 fieldSize;                             // Offset: 1280 // size of checkerboard field if CSFR is enabled, or screen size otherwise
	float2 volumetricFroxelIdxToNdcXyScale;       // Offset: 1288   // (2,-2) / (volumetricLightingResolution-1)
	float2 volumetricGIFroxelIdxToNdcXyScale;     // Offset: 1296 // (2,-2) / (volumetricGILightingResolution-1)
	float2 subPixelJitter;                        // Offset: 1304
	float2 previousSubPixelJitter;                // Offset: 1312
	float2 steveToCausticsScale;                  // Offset: 1320
	float2 steveToCausticsBias;                   // Offset: 1328
	float2 steveToWibblyScale;                    // Offset: 1336
	float2 steveToWibblyBias;                     // Offset: 1344
	
	// 4-byte aligned fields
	uint   frameCount;                            // Offset: 1352
	float emissiveMultiplier;                     // Offset: 1356
	float emissiveDesaturation;                   // Offset: 1360

	// This should be set to the 1, but we can game the system by having
	// emissive surfaces cast more light than they appear.
	// This can stop them over-saturating the display without requiring tone-mapping.
	// If we get tone-mapping implemented, then try setting this to 1.
	float indirectEmissiveBoostMultiplier;        // Offset: 1364
	float surfaceWetness;                         // Offset: 1368
	float smoothertron;                           // Offset: 1372
	float mipmapBias;                             // Offset: 1376
	uint  enableIrradianceCache;                  // Offset: 1380
	uint injectGlobalIlluminationIntoFog;         // Offset: 1384
	float fogHenyeyGreensteinG;                   // Offset: 1388
	float waterHenyeyGreensteinG;                 // Offset: 1392
	float renderResolutionDivDisplayResolution;   // Offset: 1396
	float displayResolutionDivRenderResolution;   // Offset: 1400
	uint  enableAdaptiveDenoiser;                 // Offset: 1404
	float previousResolutionDivRenderResolution;  // Offset: 1408

	// Reprojection
	float diffuseTemporalAlpha;                   // Offset: 1412
	float diffuseTemporalAlphaMoments;            // Offset: 1416
	float specularTemporalAlpha;                  // Offset: 1420
	float specularTemporalAlphaMoments;           // Offset: 1424

	float primaryRaySpreadAngle;                  // Offset: 1428
	float primaryRayAlphaTestSpreadAngle;         // Offset: 1432

	float heightMapPixelEdgeWidth;                // Offset: 1436
	float recipHeightMapDepth;                    // Offset: 1440

	uint rayCountMultiplier;                      // Offset: 1444

	// Parameters to transform a height value into a fog density multiplier
	float heightToFogScale;                       // Offset: 1448
	float heightToFogBias;                        // Offset: 1452

	uint refModeAccumulatedFrames;                // Offset: 1456
	uint renderMethod;                            // Offset: 1460
	uint debugMode;                               // Offset: 1464
	uint enableProbabilityBasedRaycasts;          // Offset: 1468
	uint enableCausticsStabilizationInRefMode;    // Offset: 1472
	uint enableRayReordering;                     // Offset: 1476
	uint enableExplicitLightSampling;             // Offset: 1480
	uint cpuLightsCount;                          // Offset: 1484
	float explicitLightsIntensityBias;            // Offset: 1488
	float focalDistance;                          // Offset: 1492
	float apertureSize;                           // Offset: 1496
	uint apertureType;                            // Offset: 1500
	float toneMappingShadowContrast;              // Offset: 1504
	float toneMappingShadowContrastEnd;           // Offset: 1508
	float toneMappingCurveShift;                  // Offset: 1512
	float toneMappingDynamicRange;                // Offset: 1516
	float toneMappingShadowMinSlope;              // Offset: 1520
	float toneMappingMaxExposureIncrease;         // Offset: 1524
	uint toneMappingNeedsReset;                   // Offset: 1528
	uint enableTAA;                               // Offset: 1532
	uint enableSHDiffuse;                         // Offset: 1536
	uint cameraIsUnderLava;                       // Offset: 1540
	float cpuLightsCountRcp;                      // Offset: 1544
	uint reducedLightsCount;                      // Offset: 1548
	float reducedLightsCountRcp;                  // Offset: 1552
	float lightCullingDistance;                   // Offset: 1556
	float time;                                   // Offset: 1560
	float skyIntensityAdjustment;                 // Offset: 1564
	float moonMeshIntensity;                      // Offset: 1568
	float sunMeshIntensity;                       // Offset: 1572
    float maxHistoryLength;                       // Offset: 1576
    uint missingTextureIndex;					  // New for 1.21

	// These are all 0 to 1 values that you're free to use how you like when developing and debugging.
	float genericDebugSlider0;                    // Offset: 1580
	float genericDebugSlider1;                    // Offset: 1584
	float genericDebugSlider2;                    // Offset: 1588
	float genericDebugSlider3;                    // Offset: 1592
};

// Register the view buffer.
cbuffer ViewCB : register(b0)
{
	View g_view;
}

// Register pre-computed random hemisphere samples.
struct RandomSamples
{
	float4 hemisphereSamples[288]; //< 288 = 3x3x32 samples
};
cbuffer RandomSamplesCB : register(b1)
{
	RandomSamples g_randomSamples;
}

// The use of these varies with shader.
// They're a great way to pass up small amounts of information to the
// shader that can vary per batch, without all that tedious mucking
// about with proper constant buffers.
cbuffer RootConstants : register(b2)
{
	uint32_t g_rootConstant0;
	uint32_t g_rootConstant1;
	uint32_t g_dispatchDimensions; // 10-bits per dimension.  Number of thread-groups in each dimension.
}

// Pre-defined struct for auto exposure parameters and configuration.
struct LightMeterData
{
	float lightAccumulationAlpha;
	float maxEV;
	float minEV;
	int accumulationNeedsReset;
	float lobesDifferenceThreshold;
	float lobesDifferenceAlphaMin;
	float lobesDifferenceAlphaMax;
	float manualExposureAdjustmentEv;
};
cbuffer LightMeterDataCB : register(b3)
{
	LightMeterData g_lightMeterSamples;
}

// ---[ Output Buffers ]---

RWTexture2D<float>  outputBufferPrimaryPathLength           : register(u0);
RWTexture2D<float2> outputBufferNormal						: register(u1);
RWTexture2D<float2> outputBufferHistoryLength               : register(u2);
RWTexture2D<float4> outputBufferAlbedoAndRoughness          : register(u3);
RWTexture2D<float4> outputBufferEmissionAndMetalness        : register(u4);
RWTexture2D<float4> outputBufferIndirectDiffuse             : register(u5);
RWTexture2D<float4> outputBufferIndirectSpecular            : register(u6);
RWTexture2D<float2> outputBufferOpacityAndObjectCategory	: register(u7);
// u8 empty
// u9 empty
RWTexture2D<float2> outputBufferMotionVectors               : register(u10);
RWTexture2D<float4> outputBufferSunLight     				: register(u11);
RWTexture2D<float4> outputBufferFinal                       : register(u12);
RWTexture2D<float3> outputBufferDirectLightTransmission		: register(u13);
RWTexture2D<float4> outputBufferDebug                       : register(u14);
RWTexture2D<float>  outputBufferReflectionDistance          : register(u15);
RWTexture2D<float2> outputBufferReflectionMotionVectors     : register(u16);
RWTexture2D<float>  outputBufferPreviousRoughness           : register(u17);
RWTexture2D<float4> outputBufferDiffuse               		: register(u18);
RWTexture2D<int>    outputBufferObjectInstanceIndex			: register(u19);
RWTexture2D<float>  outputBufferReprojectedPathLength       : register(u20);
RWTexture2D<float4> outputBufferSunLightShadow              : register(u21);
RWTexture2D<float4> outputBufferPreviousSunLightShadow      : register(u22);
RWTexture2D<float4> outputBufferRawFinal         			: register(u23);
RWTexture2D<float4> outputBufferRayDirection                : register(u24);
RWTexture2D<float3> outputBufferRayThroughput               : register(u25);
RWTexture2D<uint>   outputBufferToneMappingHistogram		: register(u26);
RWTexture2D<float>  outputBufferToneCurve                   : register(u27);
RWTexture2D<float3> outputBufferIndirectDiffuseChroma       : register(u28);
RWTexture2D<float4> outputBufferPrimaryPosLowPrecision      : register(u29);
RWTexture2D<float4> outputBufferTAAHistory                  : register(u30);
RWTexture2D<float2> outputBufferGeometryNormal				: register(u31);

RWStructuredBuffer<uint> outputVisibleBLASs                 : register(u32);

RWTexture2D<float4> outputBufferPositionAndHitT             : register(u33);
RWTexture2D<float4> outputPrimaryViewDirection              : register(u34);
RWTexture2D<float4> outputBufferPrimaryThroughput           : register(u35);

RWTexture2D<float2> outputAdaptiveDenoiserGradients[2]      : register(u36);
RWTexture2D<float2> outputAdaptiveDenoiserReference         : register(u38);
RWTexture2D<int>    outputAdaptiveDenoiserPlaneIdentifier   : register(u39);

// Indexable for the filter moments shaders
// First two entries are for diffuse
// Second two entries are for specular
RWTexture2D<float2> outputDenoisingMoments[4]               : register(u40); // 40, 41, 42, 43
// Aliases for the reprojection pass
RWTexture2D<float2> outputBufferDiffuseMoments              : register(u40);
RWTexture2D<float2> outputBufferSpecularMoments             : register(u42);

RWTexture2D<int>    outputTileClassification                : register(u44);

RWStructuredBuffer<float4> outputBufferIncidentLight        : register(u0, space14);

RaytracingAccelerationStructure SceneBVH : register(t0);

SamplerState  defaultSampler                              : register(s0);
SamplerState  linearSampler                               : register(s1);
SamplerState  linearWrapSampler                           : register(s2);
SamplerState  pointSampler                                : register(s3);

// Static textures
Texture2DArray<float4> blueNoiseTexture                   : register(t58);
Texture2DArray<float3> skyTexture                         : register(t59);
Texture2DArray<float>  causticsTexture                    : register(t60);
Texture2D<float2> wibblyTexture                           : register(t61);
Texture2D<float4> waterNormalsTexture                     : register(t62);

// Structured buffer, indexed by object instance that contains info for the other bindless resources
StructuredBuffer<ObjectInstance>   objectInstances     : register(t1);
// Buffers to guide the single DispatchRays for the irradiance cache updating.
StructuredBuffer<VertexIrradianceCacheUpdateChunk> vertexIrradianceCacheUpdateChunks : register(t2);
StructuredBuffer<FaceIrradianceCacheUpdateChunk>   faceIrradianceCacheUpdateChunks   : register(t3);
    
// ---[ Input Buffers ]---

Texture2D<float>  previousPrimaryPathLengthBuffer               : register(t4);
Texture2D<float2> previousPrimaryNormalBuffer                   : register(t5);
Texture2D<float2> previousHistoryLengthBuffer                   : register(t6);
Texture2D<float4> previousDiffuseBuffer                         : register(t7);
Texture2D<float3> previousSpecularBuffer                        : register(t8);
// t9 empty
// t10 empty
// t11 volumetricResolvedInscatter
// t12 volumetricResolvedTransmission
// t13 volumetricInscatterPrevious
Texture2D<float>  inputBufferPrimaryPathLength                  : register(t14);
Texture2D<float2> inputBufferNormal 							: register(t15);
Texture2D<float4> inputBufferAlbedoAndRoughness					: register(t16);
Texture2D<float2> inputBufferOpacityAndObjectCategory			: register(t17);
Texture2D<float4> inputBufferSunLight            				: register(t18);
StructuredBuffer<float4> inputBufferIncidentLight               : register(t19);
Texture2D<float3> inputBufferDirectLightTransmission			: register(t20);
Texture2D<float2> inputBufferMotionVectors                      : register(t21);
Texture2D<float2> inputBufferReflectionMotionVectors            : register(t22);
Texture2D<float>  previousReflectionDistanceBuffer              : register(t23);
Texture2D<float>  previousRoughnessBuffer                       : register(t24);
Texture2D<float4> inputBufferDiffuse               				: register(t25);
Texture2D<float4> inputBufferPreInterleavePrevious              : register(t26);
Texture2D<int>    inputBufferObjectInstanceIndex				: register(t27);
// t28 empty
Texture2D<float>  inputBufferReprojectedPathLength              : register(t29);
Texture2D<float4> previousSunLightShadowBuffer                  : register(t30);
Texture2D<float4> inputBufferRawFinal                     		: register(t31);
// t32 empty
// t33 empty
// t34 empty
StructuredBuffer<PBRTextureData> pbrTextureDataBuffer           : register(t35);
Texture2D<uint>   inputBufferToneMappingHistogram               : register(t36);
Texture2D<float>  inputBufferToneCurve                          : register(t37);
// t38 volumetricGIResolvedInscatter
// t39 volumetricGIInscatterPrevious
Texture2D<float4> inputTAAHistory                               : register(t40);
Texture2D<float4> inputThisFrameTAAHistory                      : register(t41);
Texture2D<float4> inputBufferFinalColour						: register(t42);
Texture2D<float2> inputBufferGeometryNormal						: register(t43);
Texture2D<float4> inputBufferEmissionAndMetalness				: register(t44);
Texture2D<float4> inputBufferPositionAndHitT                    : register(t45);
Texture2D<float4> inputPrimaryViewDirection                     : register(t46);
Texture2D<float4> inputBufferPrimaryThroughput                  : register(t47);
Texture2D<float3> previousDiffuseChromaBuffer                   : register(t48);
Texture2D<float2> inputPreviousGeometryNormal                   : register(t49);
Texture2D<float4> inputPrimaryPosLowPrecision                   : register(t50);
Texture2D<float2> inputAdaptiveDenoiserGradients[2]             : register(t51);
Texture2D<float2> inputAdaptiveDenoiserReference                : register(t53);
Texture2D<int>    inputAdaptiveDenoiserPlaneIdentifier          : register(t54);
StructuredBuffer<CheckerboardActions> checkerboardActionsBuffer	: register(t55);
Buffer<float>     refractionIndicesBuffer                       : register(t56);
Texture2D<int>    inputTileClassification                       : register(t57);

// Bindless resources (part of the global root signature)
Buffer<uint16_t>                  indexBuffers[BGFX_CONFIG_MAX_INDEX_BUFFERS]            : register(t0, space1);
ByteAddressBuffer                 vertexBuffers[BGFX_CONFIG_MAX_VERTEX_BUFFERS]          : register(t0, space2);
StructuredBuffer<FaceData>        faceDataBuffers[BGFX_CONFIG_MAX_INDEX_BUFFERS]         : register(t0, space3);
StructuredBuffer<uint4>			  faceUvBuffers[BGFX_CONFIG_MAX_INDEX_BUFFERS]           : register(t0, space5);
Texture2D                         textures[BGFX_CONFIG_MAX_TEXTURES]                     : register(t0, space6);
RWByteAddressBuffer               vertexBuffersRW[BGFX_CONFIG_MAX_VERTEX_BUFFERS]        : register(u0, space9);

// Light buffers
StructuredBuffer<LightInfo>       inputLightsBuffer                                      : register(t0, space13);
RWStructuredBuffer<LightInfo>     outputLightsBuffer                                     : register(u0, space13);

StructuredBuffer<LightInfo>       inputReducedLightsBuffer                               : register(t1, space13);
RWStructuredBuffer<LightInfo>     outputReducedLightsBuffer                              : register(u1, space13);

static const uint32_t kNumTemporallyStableLights = 32;
StructuredBuffer<AdaptiveDenoiserLightInfo> inputTemporallyStableLights                  : register(t2, space13);

// Irradiance caches
RWStructuredBuffer<VertexIrradianceCache> vertexIrradianceCache[BGFX_CONFIG_MAX_VERTEX_BUFFERS] : register(u0, space1);
RWStructuredBuffer<FaceIrradianceCache>   faceIrradianceCache[BGFX_CONFIG_MAX_INDEX_BUFFERS]    : register(u0, space2);

// RW variants used during repareGeometry
RWStructuredBuffer<FaceData>      faceDataBuffersRW[BGFX_CONFIG_MAX_INDEX_BUFFERS]       : register(u0, space10);
RWStructuredBuffer<uint4>		  faceUvBuffersRW[BGFX_CONFIG_MAX_INDEX_BUFFERS]         : register(u0, space11);

// Volumetric lighting
RWTexture3D<float3> volumetricResolvedInscatterRW    : register(u60); // Written during the volumetric lighting pass
RWTexture3D<float3> volumetricResolvedTransmissionRW : register(u61); // Written during the volumetric lighting pass
RWTexture3D<float4> volumetricInscatterRW            : register(u62); // Written during the volumetric lighting pass
RWTexture3D<float3> volumetricGIResolvedInscatterRW  : register(u63); // Written during the volumetric lighting pass
RWTexture3D<float4> volumetricGIInscatterRW[2]       : register(u64); // Written during the volumetric lighting pass
//RWTexture3D<float4> volumetricGIInscatterBlurredRW   : register(u45); // Written during the volumetric lighting pass
Texture3D<float3>   volumetricResolvedInscatter      : register(t11); // Lookup for final combine
Texture3D<float3>   volumetricResolvedTransmission   : register(t12); // Lookup for final combine
Texture3D<float4>   volumetricInscatterPrevious      : register(t13); // Lookup for TAA history
Texture3D<float3>   volumetricGIResolvedInscatter    : register(t38); // Lookup for final combine
Texture3D<float4>   volumetricGIInscatterPrevious    : register(t39); // Lookup for TAA history

// Denoising inputs and outputs
// Why 8? There are 4 buffers each for diffuse and specular.
// 2 for ping-pong, and 1 extra because we need to save the output of the first iteration for temporal feedback.
// adn 1 extra for ping-ponging the raw path tracing output
Texture2D<float4>   denoisingInputs[8]                   : register(t0, space8);
Texture2D<float4>   denoisingChromaAndVarianceInputs[4]  : register(t8, space8);
RWTexture2D<float4> denoisingOutputs[8]                  : register(u0, space3);
RWTexture2D<float4> denoisingChromaAndVarianceOutputs[4] : register(u8, space3);
// Indexable for the filter moments shaders
// First two entries are for diffuse
// Second two entries are for specular
Texture2D<float2>   denoisingMomentsInputs[4]            : register(t0, space9);
// Aliases for second moments buffer, so *after* the filterMoments passes.
// These can be used during denoising, or for reading the previous frame's moments in the reprojection pass
Texture2D<float2>   inputFinalDiffuseMoments             : register(t1, space9);
Texture2D<float2>   inputFinalSpecularMoments            : register(t3, space9);

// Shadow denoising inputs and outputs
Texture2D<float4>   shadowDenoisingInputs[2]     : register(t0, space4);
RWTexture2D<float4> shadowDenoisingOutputs[2]    : register(u0, space4);

// Custom Definitions:

// ---[ Constants ]---

// The maximum distance a ray can travel until it is considered a miss.
#define MAX_RAY_DISTANCE 10000.0

// ---[ Structures ]---

// Contains information about a ray intersection.
struct HitInfo
{
	// The triangle barycentrics of the intesection.
    float2 barycentrics;
	// The object instance index.
    uint instIdx;
	// The triangle index.
    uint triIdx;
	// The distance the ray travelled until the intersection.
    float hitT;

	// Returns `true` if the ray has hit something.
    bool hasHit() {
        return hitT < MAX_RAY_DISTANCE - 1.0f;
	}

	void clear() {
		barycentrics = float2(0.0, 0.0);
		instIdx = 0;
		triIdx = 0;
		hitT = MAX_RAY_DISTANCE;
	}
};

// Contains information about the total throughput of a ray post-traversal.
struct ThroughputPayload
{
    float3 throughput;
    // The distance the ray travelled until the intersection.
    float hitT;
};

// Contains transmission information gathered during shadow ray traversal.
struct ShadowPayload
{
    float3 transmission;
};

// Contains informations about the surface of a ray intersection.
struct SurfaceInfo
{
	// The albedo value at the surface.
    float3 albedo;
	// The opacity of the surface.
    float opacity;
	// The roughness of the surface.
    float roughness;
	// The light emission from the surface.
    float3 emission;
	// The metalness of the surface.
    float metalness;
	// The surface normal vector.
    float3 normal;
};

// Contains information about the geometry of a ray intersection.
struct GeometryInfo
{
	// The position of the geometry.
    float3 position;
    // UV coordinates on the geometry.
    float2 uv;
    // The geometry's normal vector.
    float3 normal;
    // The geometry's tangent vector.
    float3 tangent;
    // The geometry's bitangent vector.
    float3 bitangent;
	// The vectex-interpolated colour of the geometry.
    float4 colour;
	// Motion of the geometry relative to last frame.
    float3 motion;

	// PBR texture data index.
    uint pbrTextureDataIdx;

	// Whether this is the front face of the geometry.
    bool isFrontFace;
};

#endif