% m is winSieze
function [dist] = MASS_V4(x, y)
%x is the data, y is the query
if size(x,2)>size(x,1)
    x=x.';
end
if size(y,2)>size(y,2)
    y=y.';
end
%y = (y-mean(y))./std(y,1);                      %Normalize the query
y = y(end:-1:1);%Reverse the query
m = length(y);
n = length(x);
y(m+1:n) = 0;
%x(n+1:2*n) = 0;
X = fft(x);
cum_sumx = cumsum(x);
cum_sumx2 =  cumsum(x.^2);
sumx2 = cum_sumx2(m:n)-[0;cum_sumx2(1:n-m)];
sumx = cum_sumx(m:n)-[0;cum_sumx(1:n-m)];
meanx = sumx./m;
sigmax2 = (sumx2./m)-(meanx.^2);
sigmax = sqrt(sigmax2);

%The main trick of getting dot products in O(n log n) time
Y = fft(y);
Z = X.*Y;
z = ifft(Z);

%compute y stats -- O(n)
sumy = sum(y);
sumy2 = sum(y.^2);
meany=sumy/m;
sigmay2 = sumy2/m-meany^2;
sigmay = sqrt(sigmay2);

%computing the distances -- O(n) time
%dist = (sumx2 - 2*sumx.*meanx + m*(meanx.^2))./sigmax2 - 2*(z(m:n) - sumy.*meanx)./sigmax + sumy2;
%dist = 1-dist./(2*m);

dist = 2*(m-(z(m:n)-m*meanx*meany)./(sigmax*sigmay));
dist = sqrt(dist);

if size(x,2)>size(x,1)
    dist=dist.';
end