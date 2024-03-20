function data = paa(s, numCoeff)
% PAA(s, numcoeff)
% s: sequence vector (Nx1 or Nx1)
% numCoeff: number of PAA segments
% data: PAA sequence (Nx1)
N = length(s); % length of sequence
segLen = floor(N/numCoeff); % assume it's integer
%segLen = numCoeff;
%numCoeff = floor(N/segLen);
sN = reshape(s(1:numCoeff*segLen), segLen, numCoeff); % break in segments
avg = mean(sN); % average segments
data = repmat(avg, 1, 1); % expand segments repmat(avg, segLen, 1)
data = data(:); % make column