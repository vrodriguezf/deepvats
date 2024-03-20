%% Similarity matrix computation based on MPX
%% 'minlag' is optional and is set to 0 by default
%% First input time series (timeSeriesA) & subsequence length are required input arguments
%% Second input time series (timeSeriesB) is optional and it's required only for AB join
%%
function [similarityMatrix] = SimMat(timeSeriesA, subseqLen, timeSeriesB, minlag)

% Code and update formulas are by Kaveh Kamgar.  
% GUI and top k motif critera are based on some code by Michael Yeh. 
% The suggested use of the fourier transform to compute euclidean distance based on cross correlation 
% is from Abdullah Mueen. 
%
% Additional References
% Yan Zhu, et al, Matrix Profile II: Exploiting a Novel Algorithm and GPUs to break the one Hundred Million Barrier for Time Series Motifs and Join
% Zachary Zimmerman, et al, Scaling Time Series Motif Discovery with GPUs: Breaking the Quintillion Pairwise Comparisons a Day Barrier. (pending review)
% Philippe Pebay, et al, Formulas for Robust, One-Pass Parallel Computation of Covariances and Arbitrary-Order Statistical Moments
% Takeshi Ogita, et al, Accurate Sum and Dot Product


% difference equations have 0 as their first entry here to simplify index
% calculations slightly. Alternatively, it's also possible to swap this to the last element
% and reorder the comparison step (or omit on the last step). This is a
% special case when comparing a single time series to itself. The more general
% case with time series A,B can be computed using difference equations for
% each time series.

if nargin < 2
    error('incorrect number of input arguments');
elseif ~isvector(timeSeriesA)
    error('first argument must be a 1D vector');
elseif ~(isfinite(subseqLen) && floor(subseqLen) == subseqLen) || (subseqLen < 2) || (subseqLen > length(timeSeriesA)) 
    error('subsequence length must be an integer value between 2 and the length of the timeSeries');
end


if ~exist('minlag', 'var')
    minlag = 0;
end

selfjoin = (~exist('timeSeriesB', 'var')) || all(isnan(timeSeriesB));

if ~(selfjoin)
    %warning('Computing AB-join similarity matrix');
    if ~isvector(timeSeriesB)
        error('Third argument must be a 1D vector');
    elseif ~(isfinite(subseqLen) && floor(subseqLen) == subseqLen) || (subseqLen < 2) || (subseqLen > length(timeSeriesB)) 
        error('subsequence length must be an integer value between 2 and the length of both input timeSeries');
    end
    Atransposed_ = isrow(timeSeriesA);
    if Atransposed_
        timeSeriesA = transpose(timeSeriesA);
    end
    Btransposed_ = isrow(timeSeriesB);
    if Btransposed_
        timeSeriesB = transpose(timeSeriesB);
    end
    timeSeries = cat(1, timeSeriesA, timeSeriesB);
    subsequenceCountA = length(timeSeriesA) - subseqLen + 1;
    subsequenceCountB = length(timeSeriesB) - subseqLen + 1;
else
    %warning('Computing Self-join similarity matrix');
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

df = [0; (1/2)*(timeSeries(1 + subseqLen : n) - timeSeries(1 : n - subseqLen))];
dg = [0; (timeSeries(1 + subseqLen : n) - mu(2 : n - subseqLen + 1)) + (timeSeries(1 : n - subseqLen) - mu(1 : n - subseqLen))];

% Output Similarity matrix
similarityMatrixLength = n - subseqLen + 1;
if selfjoin
    similarityMatrix = NaN(similarityMatrixLength, similarityMatrixLength);
else
    similarityMatrix = NaN(subsequenceCountA, subsequenceCountB);
end

% The terms row and diagonal here refer to a hankel matrix representation of a time series
% This uses normalized cross correlation as an intermediate quantity for performance reasons. 
% It is later reduced to z-normalized euclidean distance.

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
            %init = similarityMatrixLength - subsequenceCountB;
        elseif row + diag - 1 < similarityMatrixLength - subsequenceCountB + 1
            continue;
        else
            corr_ = cov_ * invsig(row) * invsig(row + diag - 1);
            col = row + diag - 1 - similarityMatrixLength + subsequenceCountB;
            similarityMatrix(row, col) = corr_;
        end
    end
end

 
similarityMatrix = sqrt(max(0, 2 * (subseqLen - similarityMatrix), 'includenan'));

if transposed_ || ~selfjoin  % matches the profile and profile index but not the motif or discord index to the input format
    similarityMatrix = transpose(similarityMatrix);
end


%similarityMatrix = transpose(similarityMatrix);

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
