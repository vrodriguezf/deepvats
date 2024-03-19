function distance = calMPdist(MP, thr, dataLength)
distLoc = ceil(thr*dataLength);
MPSorted = sort(MP);

MPRemoveInf = MPSorted(MPSorted(:)~=inf);
if length(MPRemoveInf) >= distLoc
    distance = MPRemoveInf(distLoc);
else
    distance = MPRemoveInf(length(MPRemoveInf));
end
end