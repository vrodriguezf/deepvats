function [matrixProfile, profileIndex] = ...
    MatrixProfileSplitConstraint(data, subLen, split)
%% options for the algorithm
excZoneLen = round(subLen * 0.5);
updatePeriod = 1; % in second
%% check input
dataLen = length(data);
if subLen > dataLen / 2
    error(['Error: Time series is too short ', ...
        'relative to desired subsequence length']);
end
if subLen < 4
    error('Error: Subsequence length must be at least 4');
end
if dataLen == size(data, 2)
    data = data';
end

%% locate nan and inf
proLen = dataLen - subLen + 1;
isSkip = false(proLen, 1);
for i = 1:proLen
    if any(isnan(data(i:i + subLen - 1))) || ...
            any(isinf(data(i:i + subLen - 1)))
        isSkip(i) = true;
    end
end
% isSkip(split - subLen+2 : split - 1 ) = true;

data(isnan(data) | isinf(data)) = 0; %% jaye tamame dadehaye nan ya inf sefr gharar dade shode

%% preprocess for matrix profile
[~, dataMu, dataSig] = massPre(data, dataLen, subLen); %% just data sigma and mu calculation
matrixProfile = inf(proLen, 1);
profileIndex = zeros(proLen, 1);
    idxOrder = excZoneLen + 1:proLen;
    idxOrder = idxOrder(randperm(length(idxOrder)));

%% main loop
timer = tic();
for i = 1:length(idxOrder)%length(idxOrder)
    idx = idxOrder(i);
    if isSkip(idx)
        continue
    end
    % compute the distance profile and update matrix profile
    distProfile = diagonalDist(...
        data, idx, dataLen, subLen, proLen, dataMu, dataSig);
    
    distProfile = abs(distProfile);
    distProfile = sqrt(distProfile);
    
    pos1 = idx:proLen;
    pos2 = 1:proLen - idx + 1;
    
    if ~isinf(split)
        distProfile = distProfile(pos2 <= split - subLen + 1& pos1 > split);
        pos1Split = pos1(pos2 <= split - subLen + 1 & pos1 > split);
        pos2Split = pos2(pos2 <= split - subLen + 1 & pos1 > split);
        pos1 = pos1Split;
        pos2 = pos2Split;
    end

%     if ~isinf(split)
%         distProfile = distProfile(pos2 <= (split) & pos1 > split);
%         pos1Split = pos1(pos2 <= (split) & pos1 > split);
%         pos2Split = pos2(pos2 <= (split) & pos1 > split);
%         pos1 = pos1Split;
%         pos2 = pos2Split;
%     end
% 
    updatePos = matrixProfile(pos1) > distProfile;
    profileIndex(pos1(updatePos)) = pos2(updatePos);
    matrixProfile(pos1(updatePos)) = distProfile(updatePos);
    updatePos = matrixProfile(pos2) > distProfile;
    profileIndex(pos2(updatePos)) = pos1(updatePos);
    matrixProfile(pos2(updatePos)) = distProfile(updatePos);
    
    matrixProfile(isSkip) = inf;
    profileIndex(isSkip) = 0;
    
    % check update condition
    if toc(timer) < updatePeriod && i ~= length(idxOrder)
        continue;
        %         close all
    end
    timer = tic();
    
end


% The following two functions are modified from the code provided in the
% following URL
% http://www.cs.unm.edu/~mueen/FastestSimilaritySearch.html
function [dataFreq, dataMu, dataSig] = massPre(data, dataLen, subLen)
data(dataLen + 1:(subLen + dataLen)) = 0;
dataFreq = fft(data);
dataCumsum = cumsum(data);
data2Cumsum =  cumsum(data .^ 2);
data2Sum = data2Cumsum(subLen:dataLen) - ...
    [0; data2Cumsum(1:dataLen - subLen)];
dataSum = dataCumsum(subLen:dataLen) - ...
    [0; dataCumsum(1:dataLen - subLen)];
dataMu = dataSum ./ subLen;
data2Sig = (data2Sum ./ subLen) - (dataMu .^ 2);
dataSig = sqrt(data2Sig);


function distProfile = diagonalDist(...
    data, idx, dataLen, subLen, proLen, dataMu, dataSig)
xTerm = ones(proLen - idx + 1, 1) * ...
    (data(idx:idx + subLen - 1)' * data(1:subLen));
mTerm = data(idx:proLen - 1) .* ...
    data(1:proLen - idx);
aTerm = data(idx + subLen:end) .* ...
    data(subLen + 1:dataLen - idx + 1);
if proLen ~= idx
    xTerm(2:end) = xTerm(2:end) - cumsum(mTerm) + cumsum(aTerm);
end
distProfile = (xTerm - ...
    subLen .* dataMu(idx:end) .* dataMu(1:proLen - idx + 1)) ./ ...
    (subLen .* dataSig(idx:end) .* dataSig(1:proLen - idx + 1));
distProfile = 2 * subLen * (1 - distProfile);
