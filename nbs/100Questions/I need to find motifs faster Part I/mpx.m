function [matrixProfile, matrixProfileIdx, motifsIdx, discordsIdx] = mpx(timeSeries, minlag, subseqLen)

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

n = length(timeSeries);

% difference equations have 0 as their first entry here to simplify index
% calculations slightly. Alternatively, it's also possible to swap this to the last element
% and reorder the comparison step (or omit on the last step). This is a
% special case when comparing a single time series to itself. The more general
% case with time series A,B can be computed using difference equations for
% each time series.

if nargin ~= 3
    error('incorrect number of input arguments');
elseif ~isvector(timeSeries)
    error('first argument must be a 1D vector');
elseif ~(isfinite(subseqLen) && floor(subseqLen) == subseqLen) || (subseqLen < 2) || (subseqLen > length(timeSeries)) 
    error('subsequence length must be an integer value between 2 and the length of the timeSeries');
end

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
matrixProfile = repmat(-subseqLen, n - subseqLen + 1, 1);
matrixProfile(nanmap) = NaN;
matrixProfileIdx = NaN(n - subseqLen + 1, 1);

% The terms row and diagonal here refer to a hankel matrix representation of a time series
% This uses normalized cross correlation as an intermediate quantity for performance reasons. 
% It is later reduced to z-normalized euclidean distance.
for diag = minlag + 1 : n - subseqLen + 1
    cov_ = (sum((timeSeries(diag : diag + subseqLen - 1) - mu(diag)) .* (timeSeries(1 : subseqLen) - mu(1))));
    for row = 1 : n - subseqLen - diag + 2
        cov_ = cov_ + df(row) * dg(row + diag - 1) + df(row + diag - 1) * dg(row);
        corr_ = cov_ * invsig(row) * invsig(row + diag - 1);
        if corr_ > matrixProfile(row)
            matrixProfile(row) = corr_;
            matrixProfileIdx(row) = row + diag - 1;
        end
        if corr_ > matrixProfile(row + diag - 1)
            matrixProfile(row + diag - 1) = corr_;
            matrixProfileIdx(row + diag - 1) = row;
        end
    end
end
 
matrixProfile = sqrt(max(0, 2 * (subseqLen - matrixProfile), 'includenan'));
[motifsIdx, discordsIdx] = findMotifsDiscords(timeSeries, mu, invsig, matrixProfile, matrixProfileIdx, subseqLen, 3, 10, minlag - 1, 2);
mpgui.launchGui(timeSeries, matrixProfile, motifsIdx, discordsIdx, subseqLen);
if transposed_  % matches the profile and profile index but not the motif or discord index to the input format
    matrixProfile = transpose(matrixProfile);
    matrixProfileIdx = transpose(matrixProfileIdx);
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
