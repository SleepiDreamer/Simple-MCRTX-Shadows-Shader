[numthreads(128, 1, 1)]
void BlurGradients(
    int2 groupID: SV_GroupID,
    int groupThreadID: SV_GroupThreadID,
    int2 iposCurrentPixels: SV_DispatchThreadID) {}
