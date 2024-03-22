function [similarityMatrix] = SPLAT(timeSeriesA, subseqLen, timeSeriesB, plotting, multiresolution, calibration)

disp("plotting inside")
disp(plotting)

if nargin < 2
    error('incorrect number of input arguments');
elseif ~isvector(timeSeriesA)
    error('first argument must be a 1D vector');
elseif ~(isfinite(subseqLen) && floor(subseqLen) == subseqLen) || (subseqLen < 2) || (subseqLen > length(timeSeriesA)) 
    error('subsequence length must be an integer value between 2 and the length of the timeSeries');
end
disp("Multires inside")
disp(multiresolution)
if ~multiresolution
    disp("MultiRes option is false")
    max_length = inf;
elseif ~exist('calibration','var') || ~(calibration)
    disp("-> Here - option 2 calibration")
    max_length = 10000;
else
    disp("-> Or here - option 3 getPaafactor")
    [max_length] = getPaaFactor(timeSeriesA, subseqLen);
end
disp("minlag")
minlag = 0;
disp(minlag)
selfjoin = (~exist('timeSeriesB', 'var')) || all(isnan(timeSeriesB));


if length(timeSeriesA) > max_length || (~selfjoin && length(timeSeriesB) > max_length)
    if length(timeSeriesA) > max_length
        disp("--> Getting paaFactor - Opction A")
        paa_factor = ceil(length(timeSeriesA)/max_length);
        warning('Downsampling rate is set to %d',paa_factor);
    elseif (~selfjoin && length(timeSeriesB) > max_length)
        disp("--> Getting paaFactor - Opction B")
        paa_factor = ceil(length(timeSeriesB)/max_length);
        warning('Downsampling rate is set to %d',paa_factor);
    end
    if paa_factor ~= 1
        disp("--> paaFactor not equal to 1")
        timeSeriesA = paa(timeSeriesA, ceil(length(timeSeriesA)/paa_factor));
        subseqLen = ceil(subseqLen/paa_factor);
        if ~(selfjoin)
            disp("--> Adjust b (not selfjoin)")
            timeSeriesB_newlength = floor(length(timeSeriesB)/paa_factor);
            timeSeriesB = paa(timeSeriesB, timeSeriesB_newlength);
        end
    end
end

if ~(selfjoin)
    if ~isvector(timeSeriesB)
        error('Third argument must be a 1D vector');
    elseif ~(isfinite(subseqLen) && floor(subseqLen) == subseqLen) || (subseqLen < 2) || (subseqLen > length(timeSeriesB)) 
        error('subsequence length must be an integer value between 2 and the length of both input timeSeries');
    end
    Atransposed_ = isrow(timeSeriesA);
    if Atransposed_
        disp("--> Transpose A")
        timeSeriesA = transpose(timeSeriesA);
    end
    Btransposed_ = isrow(timeSeriesB);
    if Btransposed_
        disp("--> Transpose B")
        timeSeriesB = transpose(timeSeriesB);
    end
    timeSeries = cat(1, timeSeriesA, timeSeriesB);
    subsequenceCountA = length(timeSeriesA) - subseqLen + 1;
    subsequenceCountB = length(timeSeriesB) - subseqLen + 1;
else
    warning('Computing Self-join similarity matrix');
    timeSeries  = timeSeriesA;
end


n = length(timeSeries);
transposed_ = isrow(timeSeries);
if transposed_
    timeSeries = transpose(timeSeries);
end

nanmap = find(~isfinite(movsum(timeSeries, [0 subseqLen-1], 'Endpoints', 'discard')));
timeSeries(isnan(timeSeries)) = 0;
% We need to remove any NaN or inf values before computing the moving mean,
% because it uses an accumulation based method. We add additional handling
% elsewhere as needed.
mu = moving_mean(timeSeries, subseqLen);
invsig = 1./movstd(timeSeries, [0 subseqLen-1], 1, 'Endpoints', 'discard');
invsig(nanmap) = NaN;

disp("--> ADFG A DG DGF2DGF")
df = [0; (1/2)*(timeSeries(1 + subseqLen : n) - timeSeries(1 : n - subseqLen))];
dg = [0; (timeSeries(1 + subseqLen : n) - mu(2 : n - subseqLen + 1)) + (timeSeries(1 : n - subseqLen) - mu(1 : n - subseqLen))];

disp("--> Output similarityMatrix")
% Output Similarity matrix
similarityMatrixLength = n - subseqLen + 1;
if selfjoin
    similarityMatrix = NaN(similarityMatrixLength, similarityMatrixLength);
else
    similarityMatrix = NaN(subsequenceCountA, subsequenceCountB);
end


for diag = minlag + 1 : n - subseqLen + 1
    cov_ = (sum((timeSeries(diag : diag + subseqLen - 1) - mu(diag)) .* (timeSeries(1 : subseqLen) - mu(1))));
    for row = 1 : n - subseqLen - diag + 2
        if ~selfjoin && row > subsequenceCountA
           break;
        end
        cov_ = cov_ + df(row) * dg(row + diag - 1) + df(row + diag - 1) * dg(row);
        if selfjoin
            corr_ = cov_ * invsig(row) * invsig(row + diag - 1);
            similarityMatrix(row, row + diag - 1) = corr_;
            similarityMatrix(row + diag - 1, row) = corr_;
        elseif row + diag - 1 < similarityMatrixLength - subsequenceCountB + 1
            continue;
        else
            corr_ = cov_ * invsig(row) * invsig(row + diag - 1);
            col = row + diag - 1 - similarityMatrixLength + subsequenceCountB;
            similarityMatrix(row, col) = corr_;
        end
    end
end
if selfjoin
    exclusionLength = ceil(subseqLen/2);
    for rr = 1:size(similarityMatrix,1)
        startIndex = max(1,rr-exclusionLength+1);
        endIndex = min(size(similarityMatrix,1), rr+exclusionLength-1);
        similarityMatrix(startIndex:endIndex,rr) = 2*sqrt(subseqLen);
    end
end

%similarityMatrix = sqrt(max(0, 2 * (subseqLen - similarityMatrix), 'includenan'));
similarityMatrix = sqrt(max(0, 2 * (subseqLen - similarityMatrix)));

if transposed_ || ~selfjoin  % matches the profile and profile index but not the motif or discord index to the input format
    similarityMatrix = transpose(similarityMatrix);
end

disp("plotting antes del if")
disp(plotting)
if plotting
    disp("Ploteate")
    %histmaximum = max(similarityMatrix,[],'all');
    histmaximum = max(max(similarityMatrix));
    mplot = similarityMatrix > 0.9*histmaximum;
    figure(1)
    ax1 = subplot(10,10,[2:9]);
    disp(isgraphics(ax1));
    %ax1.FontSize = 18;
    %plot(timeSeriesA);
    %ax1.XTick = [];
    %ax1.YTick = [];
    %ax1.Box = 'off';
    %ax1.Color = 'None';
    set(ax1, 'FontSize', 18, 'XTick', [], 'YTick', [], 'Box', 'off', 'Color', 'None');

    ax2 = subplot(10,10,[12:20,22:30,32:40,42:50,52:60,62:70,72:80,82:90,92:100]);
    %ax2.FontSize = 18;
    set(ax2, 'FontSize', 18)
    imagesc(mplot)
    colormap(ax2,flipud(gray))
    colorbar;
    %ax2.DataAspectRatio = [1 1 1];

    ax3 = subplot(10,10,[11,21,31,41,51,61,71,81,91]);
    %ax3.FontSize = 18;
    set(ax3, 'FontSize', 18)
    if selfjoin
        plot(timeSeriesA);
    else
        plot(timeSeriesB)
    end
    set(ax3, 'XTick', [], 'YTick', [], 'Box', 'off', 'Color', 'None')
    %ax3.XTick = [];
    %ax3.YTick = [];
    %ax3.Box = 'off';
    %ax3.Color = 'None';
    view([90,-90])
    set(ax3,'xdir','reverse','ydir','reverse', 'XAxisLocation','top');
    
    if selfjoin
        %sgtitle('Mplot (self-join similarity matrix)');
        title('Mplot (self-join similarity matrix)');
    else
        %sgtitle('Mplot (AB-join similarity matrix)');
        title('Mplot (AB-join similarity matrix)');
        
    end
    disp("--> drawnow")
    drawnow; 
    disp("drawnow -->")
end

end


function [ res ] = moving_mean(a,w)
% moving mean over sequence a with window length w
% based on Ogita et. al, Accurate Sum and Dot Product

% A major source of rounding error is accumulated error in the mean values, so we use this to compensate. 
% While the error bound is still a function of the conditioning of a very long dot product, we have observed 
% a reduction of 3 - 4 digits lost to numerical roundoff when compared to older solutions.

res = zeros(length(a) - w + 1, 1);
p = a(1);
s = 0;

for i = 2 : w
    x = p + a(i);
    z = x - p;
    s = s + ((p - (x - z)) + (a(i) - z));
    p = x;
end

res(1) = p + s;

for i = w + 1 : length(a)
    x = p - a(i - w);
    z = x - p;
    s = s + ((p - (x - z)) - (a(i - w) + z));
    p = x;
    
    x = p + a(i);
    z = x - p;
    s = s + ((p - (x - z)) + (a(i) - z));
    p = x;
    
    res(i - w + 1) = p + s;
end

res = res ./ w;

end
