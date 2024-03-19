% The prototype for interactive matrix profile calculation using SCRIMP++
% Original tool created by Chin-Chia Michael Yeh / Eamonn Keogh 01/26/2016
% Modified by Yan Zhu 02/2018 (SCRIMP++)
%
% For details of the SCRIMP++ algorithm, see:
% Yan Zhu, Chin-Chia Michael Yeh, Zachary Zimmerman, Kaveh Kamgar, and Eamonn Keogh,
% "Solving Time Series Data Mining Problems at Scale with SCRIMP++", submitted to KDD 2018.
%
% Usage:
% [matrixProfile, profileIndex, motifIndex, discordIndex] = ...
%     interactiveMatrixProfileVer3_website(data, subLen);
% Output:
%     matrixProfile: matrix porfile of the self-join (vector)
%     profileIndex: matrix porfile index of the self-join (vector)
%     motifIndex: index of the first, second, and third motifs and their 
%                 associated neighbors when stopped (3x2 cell)
%                 +-----------------------+------------------------+
%                 | indices for 1st motif | neighbors of 1st motif |
%                 +-----------------------+------------------------+
%                 | indices for 2nd motif | neighbors of 2nd motif |
%                 +-----------------------+------------------------+
%                 | indices for 3rd motif | neighbors of 3rd motif |
%                 +-----------------------+------------------------+
%     discordIndex: index of discords when stopped (vector)
% Input:
%     data: input time series (vector)
%     subLen: subsequence length (scalar)
%
% We uploaded this code as a courtesy to the community. Note that as the
% Matlab GUI eats up a lot of time, the SCRIMP++ runtime reported in the
% paper is not measured by this tool, but the non-GUI implemtations on the
% website.

function [matrixProfile, profileIndex, motifIdxs, discordIdx] = ...
    interactiveMatrixProfileVer3(data, subLen)
%% options for the algorithm
excZoneLen = round(subLen );
radius = 1.8;
updatePeriod = 1; % in second
anytimeMode = 3; % 1: original with mass O(n^2 log n); 
                 % 2: SCRIMP
                 % 3: SCRIMP++
preStep = floor(subLen * 0.25);

%% check input
dataLen = length(data);
if subLen > dataLen / 2
    error(['Error: Time series is too short ', ...
        'relative to desired subsequence length']);
end
if subLen < 4
    error('Error: Subsequence length must be at least 4');
end
if subLen > dataLen / 5
    error('Error: subsequenceLength > dataLength / 20')
end
if dataLen == size(data, 2)
    data = data';
end

%% spawn main window
titleTxt = 'UCR Interactive Matrix Profile Calculation 3.0';
mainWindow.fig = figure('name', titleTxt, ...
    'visible', 'off', 'toolbar', 'none', 'ResizeFcn', @mainResize);
backColor = get(mainWindow.fig, 'color');
mainWindow.dataAx = axes('parent', mainWindow.fig, ...
    'units', 'pixels', 'xlim', [1, dataLen], 'xtick', [1, dataLen], ...
    'ylim', [-0.05, 1.05], 'ytick', [], 'ycolor', [1, 1, 1]);
mainWindow.profileAx = axes('parent', mainWindow.fig, ...
    'units', 'pixels', 'xlim', [1, dataLen], 'xtick', [1, dataLen], ...
    'ylim', [0, 2*sqrt(subLen)]);
mainWindow.discordAx = axes('parent', mainWindow.fig, ...
    'units', 'pixels', 'xlim', [1, subLen], 'xtick', [1, subLen], ...
    'ylim', [-0.05, 1.05], 'ytick', [], 'ycolor', [1, 1, 1]);
mainWindow.stopBtn = uicontrol('parent', mainWindow.fig, ...
    'style', 'pushbutton', 'string', 'Stop', 'fontsize', 10, ...
    'callback', @pushStopBtn);
mainWindow.dataText = uicontrol('parent', mainWindow.fig, ...
    'style', 'text', 'string', '', 'fontsize', 10, ...
    'backgroundcolor', backColor, 'horizontalalignment', 'left');
mainWindow.profileText = uicontrol('parent', mainWindow.fig, ...
    'style', 'text', 'string', 'The best-so-far matrix profile', ...
    'fontsize', 10, 'backgroundcolor', backColor, ...
    'horizontalalignment', 'left');
mainWindow.discordText = uicontrol('parent', mainWindow.fig, ...
    'style', 'text', 'string', '', 'fontsize', 10, ...
    'backgroundcolor', backColor, 'horizontalalignment', 'left');
mainWindow.motifAx = zeros(3, 1);
for i = 1:3
    mainWindow.motifAx(i) = axes('parent', mainWindow.fig, ...
        'units', 'pixels', 'xlim', [1, subLen], 'xtick', [1, subLen], ...
        'ylim', [-0.05, 1.05], 'ytick', [], 'ycolor', [1, 1, 1]);
end
mainWindow.motifText = zeros(3, 1);
for i = 1:3
    mainWindow.motifText(i) = uicontrol('parent', mainWindow.fig, ...
        'style', 'text', 'string', '', 'fontsize', 10, ...
        'backgroundcolor', backColor, 'horizontalalignment', 'left');
end
mainWindow.discardBtn = zeros(3, 1);
for i = 1:3
    mainWindow.discardBtn(i) = uicontrol('parent',mainWindow.fig, ...
        'style', 'pushbutton', 'string', 'Discard', 'fontsize', 10, ...
        'callback', @(src, cbdata) pushDiscardBtn(src, cbdata, i));
end

%% plot data
dataPlot = zeroOneNorm(data);
hold(mainWindow.dataAx, 'on');
plot(1:dataLen, dataPlot, 'r', 'parent', mainWindow.dataAx);
hold(mainWindow.dataAx, 'off');

%% locate nan and inf
proLen = dataLen - subLen + 1;
isSkip = false(proLen, 1);
for i = 1:proLen
    if any(isnan(data(i:i + subLen - 1))) || ...
            any(isinf(data(i:i + subLen - 1)))
        isSkip(i) = true;
    end
end
data(isnan(data) | isinf(data)) = 0;

%% preprocess for matrix profile
[dataFreq, dataMu, dataSig] = massPre(data, dataLen, subLen);
matrixProfile = inf(proLen, 1);
profileIndex = zeros(proLen, 1);
if anytimeMode == 1
    idxOrder = randperm(proLen);
elseif anytimeMode == 2 
    idxOrder = excZoneLen + 1:proLen;
    idxOrder = idxOrder(randperm(length(idxOrder)));
elseif anytimeMode == 3
    Preidx = 1 : preStep : proLen;
    PreidxOrder = Preidx(randperm(length(Preidx)));
    idxOrder = excZoneLen + 1:proLen;
    idxOrder = idxOrder(randperm(length(idxOrder)));
end

%% color and text settings
txtTemp = {
    'The best-so-far 1st motifs are located at %d (green) and %d (cyan)';
    'The best-so-far 2nd motifs are located at %d (green) and %d (cyan)';
    'The best-so-far 3rd motifs are located at %d (green) and %d (cyan)';
    };
motifColor = {'g', 'c'};
discordColor = {'b', 'r', 'g'};
neighborColor = 0.5 * ones(1, 3);

%% iteratively plot
mainWindow.stopping = false;
mainWindow.discardIdx = [];
set(mainWindow.fig, 'userdata', mainWindow);
firstUpdate = true;
if anytimeMode ==1 || anytimeMode ==2
    iterationEnd = length(idxOrder);
elseif anytimeMode==3
    iterationEnd = length(PreidxOrder) + length(idxOrder);
    dotproduct = zeros(proLen,1);
    refine_distance = inf(proLen,1);
    orig_index = 1:proLen;
end
timer = tic();
for i = 1:iterationEnd
    if anytimeMode==1 || anytimeMode==2
        idx = idxOrder(i);
    elseif anytimeMode==3
        if i<= length(PreidxOrder)
            curStage=1;
            idx = PreidxOrder(i);
        else
            curStage=2;
            idx = idxOrder(i-length(PreidxOrder));
        end
    end
        
    if isSkip(idx)
        continue
    end
    drawnow;
    
    % compute the distance profile
    query = data(idx:idx+subLen-1);
    if anytimeMode == 1
        distProfile = mass(dataFreq, query, dataLen, subLen, ...
            dataMu, dataSig, dataMu(idx), dataSig(idx));
        distProfile = abs(distProfile);
        distProfile = sqrt(distProfile);
        
        distProfile(isSkip) = inf;
        excZoneStart = max(1, idx - excZoneLen);
        excZoneEnd = min(proLen, idx + excZoneLen);
        distProfile(excZoneStart:excZoneEnd) = inf;
        
        updatePos = distProfile < matrixProfile;
        profileIndex(updatePos) = idx;
        matrixProfile(updatePos) = distProfile(updatePos);
        [matrixProfile(idx), profileIndex(idx)] = min(distProfile);
    elseif anytimeMode == 2 || (anytimeMode == 3 && curStage == 2)
        distProfile = diagonalDist(...
            data, idx, dataLen, subLen, proLen, dataMu, dataSig);
        distProfile = abs(distProfile);
        distProfile = sqrt(distProfile);
        
        pos1 = idx:proLen;
        pos2 = 1:proLen - idx + 1;
        
        updatePos = matrixProfile(pos1) > distProfile;
        profileIndex(pos1(updatePos)) = pos2(updatePos);
        matrixProfile(pos1(updatePos)) = distProfile(updatePos);
        updatePos = matrixProfile(pos2) > distProfile;
        profileIndex(pos2(updatePos)) = pos1(updatePos);
        matrixProfile(pos2(updatePos)) = distProfile(updatePos);
        
        matrixProfile(isSkip) = inf;
        profileIndex(isSkip) = 0;
    elseif (anytimeMode==3 && curStage ==1) %PreSCRIMP
        % sampling
        distProfile = mass(dataFreq, query, dataLen, subLen, ...
            dataMu, dataSig, dataMu(idx), dataSig(idx));
        distProfile = abs(distProfile);
        distProfile = sqrt(distProfile);
        
        distProfile(isSkip) = inf;
        excZoneStart = max(1, idx - excZoneLen);
        excZoneEnd = min(proLen, idx + excZoneLen);
        distProfile(excZoneStart:excZoneEnd) = inf;
        
        updatePos = distProfile < matrixProfile;
        profileIndex(updatePos) = idx;
        matrixProfile(updatePos) = distProfile(updatePos);
        [matrixProfile(idx), profileIndex(idx)] = min(distProfile);
        
        % refinement
        idx_nn = profileIndex(idx);
        idx_diff = idx_nn-idx;
        dotproduct(idx) = (subLen - matrixProfile(idx)^2/2)*dataSig(idx)*dataSig(idx_nn) + subLen*dataMu(idx)*dataMu(idx_nn);
    
        endidx = min([proLen, idx+preStep-1, proLen-idx_diff]);
        dotproduct(idx+1:endidx) =  dotproduct(idx)+cumsum(data(idx+subLen:endidx+subLen-1).*data(idx_nn+subLen:endidx+subLen-1+idx_diff)-data(idx:endidx-1).*data(idx_nn:endidx-1+idx_diff));
        refine_distance(idx+1:endidx) = sqrt(abs(2*(subLen-(dotproduct(idx+1:endidx)-subLen*dataMu(idx+1:endidx).*dataMu(idx_nn+1:endidx+idx_diff))./(dataSig(idx+1:endidx).*dataSig(idx_nn+1:endidx+idx_diff)))));
    
        beginidx = max([1, idx-preStep+1, 1-idx_diff]);
        dotproduct(idx-1:-1:beginidx) = dotproduct(idx)+cumsum(data(idx-1:-1:beginidx).*data(idx_nn-1:-1:beginidx+idx_diff)-data(idx-1+subLen:-1:beginidx+subLen).*data(idx_nn-1+subLen:-1:beginidx+idx_diff+subLen));
        refine_distance(beginidx:idx-1) = sqrt(abs(2*(subLen-(dotproduct(beginidx:idx-1)-subLen*dataMu(beginidx:idx-1).*dataMu(beginidx+idx_diff:idx_nn-1))./(dataSig(beginidx:idx-1).*dataSig(beginidx+idx_diff:idx_nn-1)))));
    
        update_pos1 = find(refine_distance(beginidx:endidx)<matrixProfile(beginidx:endidx));
        matrixProfile(update_pos1+beginidx-1) = refine_distance(update_pos1+beginidx-1);
        profileIndex(update_pos1+beginidx-1) = orig_index(update_pos1+beginidx-1)+idx_diff;
    
        update_pos2 = find(refine_distance(beginidx:endidx)<matrixProfile(beginidx+idx_diff:endidx+idx_diff));
        matrixProfile(update_pos2+beginidx+idx_diff-1) = refine_distance(update_pos2+beginidx-1);
        profileIndex(update_pos2+beginidx+idx_diff-1) = orig_index(update_pos2+beginidx+idx_diff-1)-idx_diff;
    end
        
    
    % check update condition
    if toc(timer) < updatePeriod && i ~= iterationEnd
        continue;
    end
    
    % plot matrix profile
    if exist('prefilePlot', 'var')
        delete(prefilePlot);
    end
    hold(mainWindow.profileAx, 'on');
    prefilePlot = plot(1:proLen, matrixProfile, ...
        'b', 'parent', mainWindow.profileAx);
    hold(mainWindow.profileAx, 'off');
    
    % remove old plot
    if exist('motifMarkPlot', 'var')
        for j = 1:2
            delete(motifMarkPlot(j));
        end
    end
    if exist('discordPlot', 'var')
        for j = 1:length(discordPlot)
            delete(discordPlot(j));
        end
    end
    if exist('motifPlot', 'var')
        for j = 1:3
            for k = 1:2
                for l = 1:length(motifPlot{j, k})
                    delete(motifPlot{j, k}(l));
                end
            end
        end
    end
    
    % apply discard
    mainWindow = get(mainWindow.fig, 'userdata');
    discardIdx = mainWindow.discardIdx;
    matrixProfileCur = matrixProfile;
    for j = 1:length(discardIdx)
        discardZoneStart = max(1, discardIdx(j)-excZoneLen);
        discardZoneEnd = min(proLen, discardIdx(j)+excZoneLen);
        matrixProfileCur(discardZoneStart:discardZoneEnd) = inf;
        matrixProfileCur(abs(profileIndex - discardIdx(j)) < ...
            excZoneLen) = inf;
    end
    
    % find motif
    [motifIdxs, matrixProfileCur] = findMotifs(...
        matrixProfileCur, profileIndex, dataLen, subLen, proLen, ...
        data, dataFreq, dataMu, dataSig, isSkip, excZoneLen, radius);
    
    % plot motif on data
    motifMarkPlot = zeros(2, 1);
    for j = 1:2
        motifPos = motifIdxs{1, 1}(j):motifIdxs{1, 1}(j) + subLen - 1;
        hold(mainWindow.dataAx, 'on');
        motifMarkPlot(j) = plot(motifPos, dataPlot(motifPos), ...
            motifColor{j}, 'parent', mainWindow.dataAx);
        hold(mainWindow.dataAx, 'off');
    end
    
    % plot motif's neighbor
    motifPlot = cell(3, 2);
    for j = 1:3
        motifPlot{j, 2} = zeros(length(motifIdxs{j, 2}), 1);
        for k = 1:length(motifIdxs{j, 2})
            neighborPos = ...
                motifIdxs{j, 2}(k):motifIdxs{j, 2}(k) + subLen - 1;
            hold(mainWindow.motifAx(j), 'on');
            motifPlot{j, 2}(k) = plot(1:subLen, ...
                zeroOneNorm(dataPlot(neighborPos)),...
                'color', neighborColor, 'linewidth', 2, ...
                'parent', mainWindow.motifAx(j));
            hold(mainWindow.motifAx(j), 'off');
        end
    end
    
    % plot motif on motif axis
    for j = 1:3
        motifPlot{j, 1} = zeros(2, 1);
        for k = 1:2
            motifPos = ...
                motifIdxs{j, 1}(k):motifIdxs{j, 1}(k) + subLen - 1;
            hold(mainWindow.motifAx(j), 'on');
            set(mainWindow.motifText(j), 'string', ...
                sprintf(txtTemp{j}, ...
                motifIdxs{j, 1}(1), motifIdxs{j, 1}(2)));
            motifPlot{j, 1}(k) = plot(1:subLen, ...
                zeroOneNorm(dataPlot(motifPos)),...
                motifColor{k}, 'parent', mainWindow.motifAx(j));
            hold(mainWindow.motifAx(j), 'off');
        end
    end
    
    % find discord
    matrixProfileCur(isinf(matrixProfileCur)) = -inf;
    [~, profileIdxOrder] = sort(matrixProfileCur, 'descend');
    discordIdx = zeros(3, 1);
    for j = 1:3
        if length(profileIdxOrder) < j
            break
        end
        discordIdx(j) = profileIdxOrder(1);
        profileIdxOrder(1) = [];
        profileIdxOrder(abs(profileIdxOrder - discordIdx(j)) < ...
            excZoneLen) = [];
    end
    discordIdx(discordIdx == 0) = nan;
    
    % plot discord
    discordPlot = zeros(sum(~isnan(discordIdx)), 1);
    for j = 1:3
        if isnan(discordIdx(j))
            break;
        end
        discordPos = discordIdx(j):discordIdx(j) + subLen - 1;
        hold(mainWindow.discordAx, 'on');
        discordPlot(j) = plot(1:subLen, ...
            zeroOneNorm(dataPlot(discordPos)),...
            discordColor{j}, 'parent', mainWindow.discordAx);
        hold(mainWindow.discordAx, 'off');
    end
    
    % update process text
    if anytimeMode==3
        if curStage==1
            set(mainWindow.dataText, 'string', ...
            sprintf(['PreSCRIMP %.1f%% done: The input time series: ', ...
            'The best-so-far motifs are color coded (see bottom panel)'], ...
            i * 100 / length(PreidxOrder)));
        elseif curStage==2
            set(mainWindow.dataText, 'string', ...
            sprintf(['SCRIMP %.1f%% done: The input time series: ', ...
            'The best-so-far motifs are color coded (see bottom panel)'], ...
            (i-length(PreidxOrder)) * 100 / length(idxOrder)));
        end
    else 
        set(mainWindow.dataText, 'string', ...
        sprintf(['We are %.1f%% done: The input time series: ', ...
        'The best-so-far motifs are color coded (see bottom panel)'], ...
        i * 100 / length(idxOrder)));
    end
        
    
    set(mainWindow.discordText, 'string', ...
        sprintf(['The top three discords ', ...
        '%d(blue), %d(red), %d(green)'], ...
        discordIdx(1), discordIdx(2), discordIdx(3)));
    
    % show the figure
    if firstUpdate
        set(mainWindow.fig, 'userdata', mainWindow);
        set(mainWindow.fig, 'visible', 'on');
        firstUpdate = false;
    end
    
    % check for stop
    mainWindow = get(mainWindow.fig, 'userdata');
    mainWindow.motifIdxs = motifIdxs;
    set(mainWindow.fig, 'userdata', mainWindow);
    if i == iterationEnd
        set(mainWindow.fig, 'name', [titleTxt, ' (Completed)']);
    elseif mainWindow.stopping
        set(mainWindow.fig, 'name', [titleTxt, ' (Stopped)']);
    end
    if i == iterationEnd || mainWindow.stopping
        for j = 1:3
            set(mainWindow.discardBtn(j), 'enable', 'off');
        end
        set(mainWindow.stopBtn, 'enable', 'off');
        return;
    end
    
    % restart timer
    for j = 1:3
        set(mainWindow.discardBtn(j), 'enable', 'on');
    end
    timer = tic();
end


function [motifIdxs, matrixProfileCur] = findMotifs(...
    matrixProfileCur, profileIndex, dataLen, subLen, proLen, ...
    data, dataFreq, dataMu, dataSig, isSkip, excZoneLen, radius)
motifIdxs = cell(3, 2);
for i = 1:3
    [motifDistance, minIdx] = min(matrixProfileCur);
    motifDistance = motifDistance ^ 2;
    motifIdxs{i, 1} = sort([minIdx, profileIndex(minIdx)]);
    motifIdx = motifIdxs{i, 1}(1);
    query = data(motifIdx:motifIdx + subLen - 1);
    
    distProfile = mass(dataFreq, query, ...
        dataLen, subLen, dataMu, dataSig, ...
        dataMu(motifIdx), dataSig(motifIdx));
    distProfile = abs(distProfile);
    distProfile(distProfile > motifDistance * radius) = inf;
    motifZoneStart = max(1, motifIdx - excZoneLen);
    motifZoneEnd = min(proLen, motifIdx + excZoneLen);
    distProfile(motifZoneStart:motifZoneEnd) = inf;
    motifIdx = motifIdxs{i, 1}(2);
    motifZoneStart = max(1, motifIdx - excZoneLen);
    motifZoneEnd = min(proLen, motifIdx + excZoneLen);
    distProfile(motifZoneStart:motifZoneEnd) = inf;
    distProfile(isSkip) = inf;
    [distanceOrder, distanceIdxOrder] = sort(distProfile, 'ascend');
    longestLength = length(distanceOrder);
    motifNeighbor = zeros(1, longestLength);
    for j = 1:longestLength
        if isinf(distanceOrder(1)) || length(distanceOrder) < j
            motifNeighbor = motifNeighbor(motifNeighbor ~= 0);
            break;
        end
        motifNeighbor(j) = distanceIdxOrder(1);
        distanceOrder(1) = [];
        distanceIdxOrder(1) = [];
        distanceOrder(abs(distanceIdxOrder - motifNeighbor(j)) < ...
            excZoneLen) = [];
        distanceIdxOrder(abs(distanceIdxOrder - motifNeighbor(j)) < ...
            excZoneLen) = [];
    end
    motifNeighbor(motifNeighbor == 0) = [];
    motifIdxs{i, 2} = motifNeighbor;

    removeIdx = cell2mat(motifIdxs(i, :));
    for j = 1:length(removeIdx)
        removeZoneStart = max(1, removeIdx(j) - excZoneLen);
        removeZoneEnd = min(proLen, removeIdx(j) + excZoneLen);
        matrixProfileCur(removeZoneStart:removeZoneEnd) = inf;
    end
end


function pushDiscardBtn(src, ~, btnNum)
mainWindowFig = get(src, 'parent');
mainWindow = get(mainWindowFig, 'userdata');
mainWindow.discardIdx = [mainWindow.discardIdx, ...
    mainWindow.motifIdxs{btnNum, 1}];
for i = 1:3
    set(mainWindow.discardBtn(i), 'enable', 'off');
end
set(mainWindow.fig, 'userdata', mainWindow);


function pushStopBtn(src, ~)
mainWindowFig = get(src, 'parent');
mainWindow = get(mainWindowFig, 'userdata');
mainWindow.stopping = true;
for i = 1:3
    set(mainWindow.discardBtn(i), 'enable', 'off');
end
set(src, 'enable', 'off');
set(mainWindow.fig, 'userdata', mainWindow);


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


function distProfile = mass(dataFreq, query, ...
    dataLen, subLen, dataMu, dataSig, queryMu, querySig)
query = query(end:-1:1);
query(subLen+1:(subLen+dataLen)) = 0;
queryFreq = fft(query);
productFreq = dataFreq .* queryFreq;
product = ifft(productFreq);
distProfile = 2 * (subLen - ...
    (product(subLen:dataLen) - subLen * dataMu * queryMu) ./ ...
    (dataSig * querySig));


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


function x = zeroOneNorm(x)
x = x - min(x(~isinf(x) & ~isnan(x)));
x = x / max(x(~isinf(x) & ~isnan(x)));


function mainResize(src, ~)
mainWindow = get(src, 'userdata');
figPosition = get(mainWindow.fig, 'position');
axGap = 38;
axesHeight = round((figPosition(4) - axGap * 5 - 60) / 6);
set(mainWindow.dataAx, 'position', ...
    [30, 5 * axesHeight+5 * axGap + 30, figPosition(3) - 60, axesHeight]);
set(mainWindow.profileAx, 'position', ...
    [30, 4 * axesHeight+4 * axGap + 30, figPosition(3) - 60, axesHeight]);
set(mainWindow.discordAx, 'position', ...
    [30, 30, figPosition(3) - 160, axesHeight]);
set(mainWindow.stopBtn, 'position', ...
    [figPosition(3) - 120, 30, 90, 20]);
set(mainWindow.dataText, 'position', ...
    [30, 6 * axesHeight + 5 * axGap + 30, figPosition(3) - 60, 18]);
set(mainWindow.profileText, 'position', ...
    [30, 5 * axesHeight + 4 * axGap + 30, figPosition(3) - 60, 18]);
set(mainWindow.discordText, 'position', ...
    [30, 1 * axesHeight + 30, figPosition(3) - 160, 18]);
for i = 1:3
    set(mainWindow.motifAx(i), 'position', ...
        [30, (4 - i) * axesHeight + (4 - i) * axGap + 30, ...
        figPosition(3) - 160, axesHeight]);
end
for i = 1:3
    set(mainWindow.motifText(i), 'position', ...
        [30, (5 - i) * axesHeight + (4 - i) * axGap + 30, ...
        figPosition(3) - 160, 18]);
end
for i = 1:3
    set(mainWindow.discardBtn(i), 'position', ...
        [figPosition(3) - 120, ...
        (4 - i) * axesHeight + (4 - i) * axGap + 30, 90, 20]);
end