%                Yifei Ding 12/09/2016
%
% function [crosscount] = Norm_crosscount_all(crosscount,slWindow)
% Output:
%     crosscount:Before Norm
% Input:
%     crosscount:After Norm
%     slWindow  :SubLength
%
function [crosscount] = Norm_crosscount_all(crosscount,slWindow)
    l=length(crosscount);
    for i=1:l
       ac=crosscount(i);
       ic=2*(i)*(l-i)/l;
       crosscount(i)=min(ac/ic, 1);
    end
    %%exclusion zone
    zone=slWindow*5;
    for i=1:zone
        crosscount(i)=1;
    end
    for j=l-zone:l
        crosscount(j)=1;
    end