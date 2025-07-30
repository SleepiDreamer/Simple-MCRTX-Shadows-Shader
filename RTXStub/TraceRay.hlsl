#ifndef _TRACERAY_HLSL_
#define _TRACERAY_HLSL_

#include "Common.hlsl"
#include "Helpers.hlsl"
#include "HitLogic.hlsl"

// Ray query flags. Skip procedural primitives by default.
static const uint RAYFLAGS = RAY_FLAG_SKIP_PROCEDURAL_PRIMITIVES;

float3 offsetRay(float3 p, float3 n)
{
    const float origin = 1.0f / 32.0f;
    const float float_scale = 1.0f / 65536.0f;
    const float int_scale = 256.0f;

    int3 of_i = int3(int_scale * n.x, int_scale * n.y, int_scale * n.z);

    float3 p_i = float3(
        asfloat(asint(p.x) + ((p.x < 0) ? -of_i.x : of_i.x)),
        asfloat(asint(p.y) + ((p.y < 0) ? -of_i.y : of_i.y)),
        asfloat(asint(p.z) + ((p.z < 0) ? -of_i.z : of_i.z))
    );

    return float3(
        abs(p.x) < origin ? p.x + float_scale * n.x : p_i.x,
        abs(p.y) < origin ? p.y + float_scale * n.y : p_i.y,
        abs(p.z) < origin ? p.z + float_scale * n.z : p_i.z
    );
}

// Primary ray traversal logic.
void TracePrimaryRay(in RayDesc ray, out HitInfo hitInfo)
{
    RayQuery<RAYFLAGS> q;
    q.TraceRayInline(SceneBVH, 0, INSTANCE_MASK_PRIMARY, ray);

    float closestHitT = MAX_RAY_DISTANCE;

    while (q.Proceed())
    {
        ObjectInstance object = objectInstances[q.CandidateInstanceIndex()];
        if (q.CandidateInstanceID() == OBJECT_CATEGORY_ALPHA_TEST)
        {
            if (AlphaTestHitLogic(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics()))
            {
                q.CommitNonOpaqueTriangleHit();
            }
        }
        else if (object.flags & objectFlagClouds)
            q.CommitNonOpaqueTriangleHit();
    }

    float committedHitT = q.CommittedRayT();
    hitInfo.hitT = committedHitT;

    if (hitInfo.hasHit())
    {
        hitInfo.barycentrics = q.CommittedTriangleBarycentrics();
        hitInfo.instIdx = q.CommittedInstanceIndex();
        hitInfo.triIdx = q.CommittedPrimitiveIndex();
    }
}

void TraceSecondaryRay(in RayDesc ray, out HitInfo hitInfo) 
{
    RayQuery<RAYFLAGS> q;
    q.TraceRayInline(SceneBVH, 0, INSTANCE_MASK_SECONDARY, ray);

    float closestHitT = MAX_RAY_DISTANCE;

    while (q.Proceed())
    {
        ObjectInstance object = objectInstances[q.CandidateInstanceIndex()];
        if (q.CandidateInstanceID() == OBJECT_CATEGORY_ALPHA_TEST)
        {
            if (AlphaTestHitLogic(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics()))
            {
                q.CommitNonOpaqueTriangleHit();
            }
        }
        else if (object.flags & objectFlagClouds)
        {
            q.CommitNonOpaqueTriangleHit();
        }
    }

    float committedHitT = q.CommittedRayT();
    hitInfo.hitT = committedHitT;

    if (hitInfo.hasHit())
    {
        hitInfo.barycentrics = q.CommittedTriangleBarycentrics();
        hitInfo.instIdx = q.CommittedInstanceIndex();
        hitInfo.triIdx = q.CommittedPrimitiveIndex();
    }
}

// Helper function for tracing a throughput ray.
void TraceThroughputRayInline(in RayDesc ray, out ThroughputPayload payload)
{
    RayQuery<RAYFLAGS> q;
    q.TraceRayInline(SceneBVH, RAY_FLAG_NONE, INSTANCE_MASK_THROUGHPUT, ray);

    while (q.Proceed())
    {
        if (q.CandidateInstanceID() == OBJECT_CATEGORY_ALPHA_TEST)
        {
            if (AlphaTestHitLogic(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics()))
            {
                q.CommitNonOpaqueTriangleHit();
            }
        }
        else
            q.CommitNonOpaqueTriangleHit();
    }

    payload.hitT = q.CommittedRayT();

    if (q.CommittedStatus() == COMMITTED_TRIANGLE_HIT)
    {
        if (q.CommittedInstanceID() == OBJECT_CATEGORY_ALPHA_BLEND)
            payload.throughput = GetAlphaBlendTransmission(q.CommittedInstanceIndex(), q.CommittedPrimitiveIndex(), q.CommittedTriangleBarycentrics());
        else if (q.CommittedInstanceID() == OBJECT_CATEGORY_WATER)
            payload.throughput = GetWaterTransmission(q.CommittedInstanceIndex(), q.CommittedPrimitiveIndex(), q.CommittedTriangleBarycentrics());
        else
            payload.throughput = 0;
    }
    else
        payload.throughput = 0;
}

// Loops throughput ray traces to ensure ordered traversal by distance.
void TraceThroughputRay(in RayDesc ray, out float3 throughput)
{
    RayDesc currentRay = ray;
    throughput = 1;

    [unroll]
    for (uint i = 0; i < 8; ++i)
    {
        ThroughputPayload payload;
        TraceThroughputRayInline(currentRay, payload);
        if (!any(payload.throughput)) break;
        throughput *= payload.throughput;

        currentRay.Origin += (payload.hitT + 1.0e-4) * ray.Direction;
    }
}

// Shadow ray traversal logic.
void TraceShadowRay(in RayDesc ray, out ShadowPayload payload)
{
#if 0 // original code
    RayQuery<RAYFLAGS> q;
    q.TraceRayInline(SceneBVH, RAY_FLAG_NONE, INSTANCE_MASK_SHADOW, ray);

    float3 transmission = 1;

    while (q.Proceed())
    {
        uint category = q.CandidateInstanceID();
        ObjectInstance object = objectInstances[q.CandidateInstanceIndex()];
        bool isCloud = object.flags & objectFlagClouds;
        if (category == OBJECT_CATEGORY_ALPHA_TEST)
        {
            if (AlphaTestHitLogic(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics()))
            {
                q.CommitNonOpaqueTriangleHit();
            }
        }
        else if (category == OBJECT_CATEGORY_ALPHA_BLEND && !isCloud)
        {
            transmission *= GetAlphaBlendTransmission(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics());
            if (!any(transmission))
                q.CommitNonOpaqueTriangleHit();
        }
        else
        {
            transmission *= GetWaterTransmission(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics());
            if (!any(transmission))
                q.CommitNonOpaqueTriangleHit();
        }
    }

    payload.transmission = q.CommittedStatus() == COMMITTED_NOTHING ? transmission : 0;
#else // updated code to fix water transmission crash
    RayQuery<RAYFLAGS> q;
    q.TraceRayInline(SceneBVH, RAY_FLAG_NONE, INSTANCE_MASK_SHADOW, ray);

    float3 transmission = 1;

    while (q.Proceed())
    {
        uint category = q.CandidateInstanceID();
        ObjectInstance object = objectInstances[q.CandidateInstanceIndex()];
        bool isCloud = object.flags & objectFlagClouds;
        if (category == OBJECT_CATEGORY_ALPHA_TEST)
        {
            if (AlphaTestHitLogic(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics()))
            {
                q.CommitNonOpaqueTriangleHit();
            }
        }
        else if (category == OBJECT_CATEGORY_ALPHA_BLEND && !isCloud)
        {
            transmission *= GetAlphaBlendTransmission(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics());
            if (!any(transmission))
                q.CommitNonOpaqueTriangleHit();
        }
        else
        {
            transmission *= GetWaterTransmission(q.CandidateInstanceIndex(), q.CandidatePrimitiveIndex(), q.CandidateTriangleBarycentrics());
            if (!any(transmission))
            {
                q.CommitNonOpaqueTriangleHit();
            }
        }
    }

    payload.transmission = q.CommittedStatus() == COMMITTED_NOTHING ? transmission : 0;
#endif
}

#endif 