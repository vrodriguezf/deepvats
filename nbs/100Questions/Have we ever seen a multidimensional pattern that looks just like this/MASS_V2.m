% This code is created by Abdullah Mueen, Yan Zhu, Michael Yeh, Kaveh Kamgar, Krishnamurthy Viswanathan, Chetan Kumar Gupta and Eamonn Keogh.
% The overall time complexity of the code is O(n log n). The code is free to use for research purposes.
% The code may produce imaginary numbers due to numerical errors for long time series where batch processing on short segments can solve the problem.

function [dist] = MASS_V2(x, y)
%x is the data, y is the query
m = length(y);
n = length(x);

%compute y stats -- O(n)
meany = mean(y);
sigmay = std(y,1);

%compute x stats -- O(n)
meanx = movmean(x,[m-1 0]);
sigmax = movstd(x,[m-1 0],1);

y = y(end:-1:1);%Reverse the query
y(m+1:n) = 0; %aappend zeros

%The main trick of getting dot products in O(n log n) time
X = fft(x);
Y = fft(y);
Z = X.*Y;
z = ifft(Z);

dist = 2*(m-(z(m:n)-m*meanx(m:n)*meany)./(sigmax(m:n)*sigmay));
dist = sqrt(dist);