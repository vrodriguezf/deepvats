% Chin-Chia Michael Yeh, Yan Zhu, Liudmila Ulanova, Nurjahan Begum, Yifei Ding, Hoang Anh Dau, 
% Diego Furtado Silva, Abdullah Mueen, and Eamonn Keogh, "Matrix Profile I: All Pairs Similarity 
% Joins for Time Series," ICDM 2016, http://www.cs.ucr.edu/~eamonn/MatrixProfile.html

% Script for running time series segmentation. Computes the matrix profile 
% and the matrix profile index and segments the time series. Returns all
% computed values for reference
% 
% function [crosscount, splitLoc, MatrixProfile, MPindex] = 
%                                      RunSegmentation(ts, slWindow)
% Input parameters:
% ts - time series to segment
% slWindow - sliding window size
%
% Output parameters:
% crosscount - number of crossings at each point
% splitLoc - split locations
% MatrixProfile - matrix profile
% MPindex - matrix profile index
function [crosscount] = ...
        RunSegmentation(ts, slWindow )    
    [MatrixProfile, MPindex] = Time_series_Self_Join_Fast(ts, slWindow);
    [crosscount] = SegmentTimeSeries(slWindow, MPindex);
    [crosscount] = Norm_crosscount_all(crosscount, slWindow);
   
