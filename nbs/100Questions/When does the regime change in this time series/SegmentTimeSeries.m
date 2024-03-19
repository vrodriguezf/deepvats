% Chin-Chia Michael Yeh, Yan Zhu, Liudmila Ulanova, Nurjahan Begum, Yifei Ding, Hoang Anh Dau, 
% Diego Furtado Silva, Abdullah Mueen, and Eamonn Keogh, "Matrix Profile I: All Pairs Similarity 
% Joins for Time Series," ICDM 2016, http://www.cs.ucr.edu/~eamonn/MatrixProfile.html

% Segments the time series into several parts based on repeatability of a 
% pattern within each of the regions.
% 
% function [crosscount, splitLoc] = SegmentTimeSeries(slWindow, MPindex)
%
% Input parameters:
% slWindow - sliding window size, used to reduce spurious segmentation of
%           the regions which lengths are less than the sliding window size
% MPindex - matrix profile index for the time series to segment
%
% Output parameters:
% crosscount - number of crossings at each point
% splitLoc - split locations
%
function [crosscount] = SegmentTimeSeries(slWindow, MPindex)
    l = length(MPindex);
    %threshold = median(abs(MPindex - (1:l)'));
    threshold = prctile(abs(MPindex - (1:l)'), 100);
    
    crosscount=zeros(1,length(MPindex)-1);
    nnmark=zeros(1,length(MPindex));
    count=0;

    for i=1:length(MPindex)
     
        if (abs(MPindex(i)-i)<=threshold)  
            small=min(i,MPindex(i));
            large=max(i,MPindex(i));
            nnmark(small)=nnmark(small)+1; 
            nnmark(large)=nnmark(large)-1;
           
        end
      
    end
    for i=1:length(MPindex)-1
        count=count+nnmark(i);
        crosscount(i)=count;
    end
   
   