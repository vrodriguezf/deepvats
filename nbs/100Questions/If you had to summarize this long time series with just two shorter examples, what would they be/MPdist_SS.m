% This part of the code is downloaded from website for MPdist.
% This code is created by Shaghayegh Gharghabi / Eamonn Keogh.
% We used this code for our snippet-finder algorithm.

% The prototype for distance calculation
% Shaghayegh Gharghabi / Eamonn Keogh 08/29/2017
%
% [distance] = ...
%     MP_distance_SS(Ts1, Ts2, subLen, Thr);
% Output:
%     distance: the distance between Ts1 and Ts2 with different length(scalar)
% Input:
%     Ts1: the first input time series (vector)
%     Ts2: the second input time series (vector)
%     subLen: subsequence length (scalar)
%     Thr: threshol for distance in MP
% This code does not use STAMP or STOMP, it uses SCRIMP

function distance = MPdist_SS( Ts1, Ts2 , SubLen, Thr)

l1 = length(Ts1); l2 = length(Ts2);
if l1 < l2
    temp = Ts1; Ts1 = Ts2; Ts2 = temp;
    temp = l1; l1 = l2; l2 = temp;
end

tic
distance(1:abs(l1-l2+1)) = 0;
for i = 1:l1-l2+1
    distance(i) = MPdist(Ts2, Ts1(i: i+l2-1), SubLen, Thr);
end
toc

end
