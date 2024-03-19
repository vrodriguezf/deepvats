function distance = calMPdist_withoutInf(MP, thr, dataLength)
distLoc = ceil(thr*dataLength);
MPSorted = sort(MP);

if length(MPSorted) >= distLoc
    distance = MPSorted(distLoc);
else
    MPRemoveInf = MPSorted(MPSorted(:)~=inf);
    distance = MPRemoveInf(length(MPRemoveInf));
end 
end