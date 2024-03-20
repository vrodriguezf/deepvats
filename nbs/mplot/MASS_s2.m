
function [dist] = MASS_s2(x, y)
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
