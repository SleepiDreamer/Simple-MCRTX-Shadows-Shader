#include "Common.hlsl"
#include "Helpers.hlsl"

// Calculates the area of a triangle.
float calcTriangleArea(float3 posA, float3 posB, float3 posC)
{
	return 0.5 * length(cross((posB - posA), (posC - posA)));
}

// A pre-pass of all objects, writing to the appropiate face data buffer index.
[numthreads(128, 1, 1)]
void CalculateFaceData(uint objectRelativeQuadIdx : SV_DispatchThreadID)
{
	// Dont stomp on other peoples data - eom
	if (objectRelativeQuadIdx >= g_rootConstant1)
	{
		return;
	}

	ObjectInstance objectInstance = objectInstances[g_rootConstant0];

	ByteAddressBuffer vertexBuffer = vertexBuffers[int(objectInstance.vbIdx)];
	uint4 indices;
	// Indices 0,1,2 of the quad are the first triangle indices
	indices.xyz = getTriangleIndices(objectInstance, objectRelativeQuadIdx * 2);
	// The second triangle has indices 2,3,0 - so get the fourth index from .y
	indices.w   = getTriangleIndices(objectInstance, objectRelativeQuadIdx * 2 + 1).y;

	uint bufferIdx = objectInstance.getFaceIndexedBufferIdx();
	uint bufferQuadIdx = objectInstance.calcParallelQuadIdx() + objectRelativeQuadIdx;
	
	float3 positions[4];
	float2 uvs[4];

	uint pbrTextureDataIdx = 0;

	[unroll]
	for (uint i = 0; i < 4; i++)
	{
		int address = (indices[i] + objectInstance.vertexOffsetInBaseVertices) * objectInstance.vertexStride;
		uint packedUv = vertexBuffer.Load(address +  objectInstance.uv0ByteOffset());
		positions[i] = vertexBuffer.Load<float16_t4>(address + objectInstance.positionByteOffset()).xyz;
		uvs[i] = unpackVertexTexCoord(packedUv);
		if (i == 0)
		{
			pbrTextureDataIdx = vertexBuffer.Load(address + objectInstance.pBRTextureIdxByteOffset()) & 0xffff;
		}

		faceUvBuffersRW[bufferIdx][bufferQuadIdx][i] = packedUv;
	}

	float3 tangent, bitangent;
	computeTangent(positions, uvs, tangent, bitangent);

	float3 normal = normalize(cross((positions[1] - positions[0]), (positions[2] - positions[0])));

	FaceData faceData;

	faceData.packedNormal = packNormal(normal);
	faceData.packedTangent = packNormal(tangent);
	faceData.packedBitangent = packNormal(bitangent);

	/** Smart mip-mapping for ray tracing
		See https://media.contentapi.ea.com/content/dam/ea/seed/presentations/2019-ray-tracing-gems-chapter-20-akenine-moller-et-al.pdf
	*/

	// Triangle LOD constant
	// Triangle-UV-area / Triangle-area
	float triangleArea = calcTriangleArea(positions[0], positions[1], positions[2]);

	// Calculate UV area by re-using calcTriangleArea by making float3s for the UVs
	float3 uvA = float3(uvs[0].x, uvs[0].y, 0.f);
	float3 uvB = float3(uvs[1].x, uvs[1].y, 0.f);
	float3 uvC = float3(uvs[2].x, uvs[2].y, 0.f);	
	float triangleUvArea = calcTriangleArea(uvA, uvB, uvC);

	if (objectInstance.colourTextureIdx != (uint16_t)-1)
	{
		float triangleLodConstant = 0.5 * log2(triangleUvArea / triangleArea);

		uint fullTextureWidthPixels, fullTextureHeightPixels;
		textures[int(objectInstance.colourTextureIdx)].GetDimensions(fullTextureWidthPixels, fullTextureHeightPixels);
		float halfLog2NumTexPixels = 0.5 * log2(fullTextureWidthPixels * fullTextureHeightPixels);
		triangleLodConstant += halfLog2NumTexPixels;
		faceData.lodConstant = (float16_t)triangleLodConstant;

		PBRTextureData pbrTextureData = pbrTextureDataBuffer[pbrTextureDataIdx];
		faceData.colourTextureMaxMip = (uint16_t)pbrTextureData.maxMipColour;
	}
	else
	{
		faceData.lodConstant = 0;
		faceData.colourTextureMaxMip = 0;

	}
    faceDataBuffersRW[bufferIdx][bufferQuadIdx] = faceData;
}
