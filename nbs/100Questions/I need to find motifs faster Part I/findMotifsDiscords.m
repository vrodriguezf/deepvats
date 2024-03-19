function [motifIdxs, discordIdxs, matrixProfile] = findMotifsDiscords(timeSeries, mu, invsig, matrixProfile, profileIndex, subseqLen, motifCount, neighborCount, exclusionLen, radius)

% ExclusionLen refers to the number of elements surrounding a particular index,
% which are excluded from prior consideration, including the base index.
% This may not be consistent with earlier implementations. This is meant to
% implement the intent of some older code written by Michael Yeh, which finds 
% motifs and discords within a time series based on nearest neighbor comparisons using 
% z-normalized euclidean distance. Its output may not always match.

% mu is a vector containing the mean of each subsequence

% invsig is a vector of 1/standard_deviation for each subsequence

% motifCount is how many motifs to locate

% exclusionLen is the minimum distance between indices counted as motifs or
% discords. For example, given index i and exclusionLen = 1, we exclude only i.
% For exclusionLen = 2, we exclude i - 1, i, i + 1.


% radius is a distance bound. For all neighbors <= neighborCount of the motif pair indexed by positions i,j, 
% if the kth nearest neighbor of min(i,j) excluding max(i,j) has distance less than or equal to
% radius * norm(zscore(timeSeries(i : i + subseqLen - 1), 1) - zscore(timeSeries(j : j + subseqLen - 1), 1))
% then this can be regarded as a neighbor.

[motifIdxs, matrixProfile] = findMotifs(timeSeries, mu, invsig, matrixProfile, profileIndex, subseqLen, motifCount, neighborCount, exclusionLen, radius);
[discordIdxs, matrixProfile] = findDiscords(matrixProfile, motifCount, exclusionLen);

end

% http://www.cs.unm.edu/~mueen/FastestSimilaritySearch.html
% normalized cross correlation reduced to z-normalized euclidean distance
% Also see J.P. Lewis, Fast-normalized cross correlation
function distProfile = EucDist(timeSeries, invsig, query)
padLen = 2^nextpow2(length(timeSeries));
if padLen < 2 * length(query) - 1
    padLen = padLen * 2;
end
product = ifft(fft(timeSeries, padLen) .* conj(fft(query, padLen)), 'symmetric');
distProfile = sqrt(max(0, 2 * (length(query) - product(1 : length(invsig)) .* invsig)));
end


function [discordIdx, matrixProfile] = findDiscords(matrixProfile, discordCount, exclusionLen)
discordIdx = NaN(3, 1);
for i = 1 : discordCount
    infCount = numel(find(isinf(matrixProfile)));
    [dist, idx] = maxk2(matrixProfile, infCount + 1);
    if ~isfinite(dist)
        % if we didn't have enough finite elements ordi
        % the remainder are NaN, then we skip the remainder
        discordIdx = discordIdx(1 : i - 1);
        return;
    end
    discordIdx(i) = idx(end);
    exclusionPrior = max(1, discordIdx(i) - exclusionLen);
    exclusionPost = min(length(matrixProfile), discordIdx(i) + exclusionLen);
    matrixProfile(exclusionPrior : discordIdx(i)) = inf;
    matrixProfile(discordIdx(i) : exclusionPost) = inf;
end

end

function [motifIdxs, matrixProfile] = findMotifs(timeSeries, mu, invsig, matrixProfile, profileIndex, subseqLen, motifCount, neighborCount, exclusionLen, radius)
% This is adapted match the output of some inline code written by Michael Yeh
% to find the top k motifs in a time series.

motifIdxs = cell(motifCount, 2);

for i = 1 : motifCount
    [dist, motIdx] = min(matrixProfile);
    if ~isfinite(dist)
        break;
    end
    % order subsequence motif pair as [time series index of 1st appearance, time series index of 2nd appearance]
    motifIdxs{i, 1} = [min(motIdx, profileIndex(motIdx)), max(motIdx, profileIndex(motIdx))];
    mI1 = motifIdxs{i, 1}(1);
    [distProfile] = EucDist(timeSeries, invsig, (timeSeries(mI1 : mI1 + subseqLen - 1) - mu(mI1)) .* invsig(mI1));
    % remove anything already picked as a motif or neighbor from further consideration
    distProfile(~isfinite(matrixProfile)) = inf;
    if exclusionLen > 0
        for j = 1 : 2
            exclusionPrior = max(1, motifIdxs{i, 1}(j) - exclusionLen + 1);
            exclusionPost = min(length(matrixProfile), motifIdxs{i, 1}(j) + exclusionLen - 1);
            matrixProfile(exclusionPrior : motifIdxs{i, 1}(j)) = inf;
            matrixProfile(motifIdxs{i, 1}(j) + 1 : exclusionPost) = inf;
            distProfile(exclusionPrior : motifIdxs{i, 1}(j)) = inf;
            distProfile(motifIdxs{i, 1}(j) : exclusionPost) = inf;
        end
    end
    neighbors = zeros(neighborCount, 1);
    
    for j = 1 : neighborCount
        [neighborDist, neighbor] = min(distProfile);
        if isempty(neighbor) || ~isfinite(neighbor) || radius * dist < neighborDist
            neighbors = neighbors(1 : j - 1);
            break;
        end
        neighbors(j) = neighbor;
        if exclusionLen > 0
            exclusionPrior = max(1, neighbors(j) - exclusionLen + 1);
            exclusionPost = min(length(matrixProfile), neighbors(j) + exclusionLen - 1);
            matrixProfile(exclusionPrior : neighbors(j)) = inf;
            matrixProfile(neighbors(j) + 1 : exclusionPost) = inf;
            distProfile(exclusionPrior : neighbors(j)) = inf;
            distProfile(neighbors(j) + 1 : exclusionPost) = inf;
        end
    end
    motifIdxs{i, 2} = neighbors;
end

end



