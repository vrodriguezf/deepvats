% Script for running time series segmentation and random segmentatio and calculating their scores.
% Output is a scores.txt file in which the floss detected Segments position
% and its' scores, random function predicted segments and scores 

stepSize = 5;
randFunctionRepeat = 100;
fileID = fopen('scores.txt','w');
path =  'DATASET_PATH\*.txt';
fprintf(fileID,'file name , flossSegments , flossScore, randomSegments, randomScores\n');

[vals, fnames, numfids] = readFiles(path);

for filesInd = 1:numfids
    [groundTruthSegPos, subSequence] = getSegmentPos(fnames(filesInd,:));
    [nrows, ncols] = size(vals{filesInd});
    disp('Working on....');
    disp(fnames(filesInd,:));
    colData = vals{1,filesInd}(:,1);
    minDistance = stepSize*subSequence;
    crosscount = RunSegmentation(colData,subSequence);
    [~, numSegms] = size(groundTruthSegPos);
    [dataLength, ~] = size(colData);
    [localMinimums, proposedAlgRredictedResult] = findLocalMinimums(crosscount, minDistance, numSegms);
    %% create random segments
    randScore = 0;
    for(i = 1:1:randFunctionRepeat)
        randPredictedResult = floor(dataLength*rand(1,numSegms));
        randScore = calcScore(groundTruthSegPos, randPredictedResult, dataLength) + randScore ;
    end
    randScore = randScore / randFunctionRepeat;
    %%% score calculation
    scoreProposedAlgorithm = calcScore(groundTruthSegPos, proposedAlgRredictedResult, dataLength);
    write2File(fileID,fnames(filesInd,:), proposedAlgRredictedResult, scoreProposedAlgorithm, randPredictedResult, randScore);
    
end
fclose(fileID);

function score = calcScore(groundTruth, detectedSegLoc, dataLength)
[~, n] = size(groundTruth);
[~, k] = size(detectedSegLoc);
ind(1:n) = -1;
minV(1:n) = inf;

for j = 1:1:n
    for i = 1:1:k
        if(abs(detectedSegLoc(i)-groundTruth(j)) < abs(minV(j)))
            minV(j) = abs(detectedSegLoc(i) - groundTruth(j));
            ind(j) = i;
        end
    end
end

sumOfDiff = sum(minV);
score = sumOfDiff/dataLength;
end

%% read data from all files
function  [vals, files, numfids] = readFiles(path)
path = strrep(path, '*.txt', '');
files1 = dir(strcat(path,'*.txt'));
files = strvcat( files1.name );
[numfids, ~] = size(files);

vals = cell(1,numfids);
for filesInd = 1:numfids
    vals{filesInd} = importdata(strcat(path,files(filesInd,:)));
end
end

function [groundTruthSegPos, length] = getSegmentPos(names)
segmentPos = strfind(names,'_');
[~, n] = size(segmentPos);
data = [ 0 0];
for i = 1:1:n
    if(i+1 <= n)
        data(i) = str2num(names(segmentPos(i)+1:(segmentPos(i+1)-1)));
    else
        endPos = strfind(names,'.txt');
        data(i) = str2num(names(segmentPos(i) + 1:(endPos-1)));
    end
end
length = data(1);
groundTruthSegPos =  data(2:end);
end

function [minV ind]= findLocalMinimums(data, length, n)
%% length
%% the number of minimum
minV(1:n) = inf;
ind(1:n) = -1;
for(i=1:n)
    [minV(i) ind(i)] = min(data);
    data(ind(i)-length:ind(i)+length) = inf;
end
end


%% write false result in file for test
function write2File(fileID,name, predictedSegment, score, randPredictedResult, randScore)
fprintf(fileID,name);
fprintf(fileID,',');
[~, n]= size(predictedSegment);
for(i=1:1:n)
    fprintf(fileID,num2str(predictedSegment(i)));
    if(i~=n)
        fprintf(fileID,'_');
    else
        fprintf(fileID,',');
    end
end
fprintf(fileID,num2str(score));
fprintf(fileID,',');

[~, n]= size(randPredictedResult);
for(i=1:1:n)
    fprintf(fileID,num2str(randPredictedResult(i)));
    if(i~=n)
        fprintf(fileID,'_');
    else
        fprintf(fileID,',');
    end
end
fprintf(fileID,num2str(randScore));
fprintf(fileID,'\n');
end

