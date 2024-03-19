%% script for calculation human scores on each dataset

fileID = fopen('scores_BestHuman.txt','w');
datasetPath = 'DATASET_PATH\*.txt';
humanPath = 'HUMAN_RESULT_PATH\*.txt';
fprintf('file name , humanScore');
[vals, fnames, numfids] = readDatasets(datasetPath);
[HumanSeg, stNames] = readHumanGuess(humanPath);

fprintf(fileID,'_,');
for(ind =1:1)
    fprintf(fileID,stNames(ind,:));
    fprintf(fileID,',');
end
fprintf(fileID,'\n');

studentNum = 22;
dataSetNum = 12;
[~, humanNum] = size(HumanSeg);
allScores(1:dataSetNum,1:studentNum) = 0;
for filesInd = 1:numfids
    [groundTruthSegPos, subSequence] = getSegmentPos(fnames(filesInd,:));
     bestHumanScore = 0;
    for humanInd = 1:humanNum
        disp('Working on....');
        disp(fnames(filesInd,:));
        colData = vals{1,filesInd}(:,1);
        [~, numSegms] = size(groundTruthSegPos);
        [dataLength, ~] = size(colData);
        scoreProposedAlgorithm = calcScore(groundTruthSegPos, HumanSeg{1,humanInd}(filesInd), dataLength);
        allScores(filesInd,humanInd) = scoreProposedAlgorithm;
    end
    write2FileScores(fileID,fnames(filesInd,:), filesInd,allScores);
end
fclose(fileID);

% Score Calculation
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


function [HumanSeg, names] = readHumanGuess(path)
path = strrep(path, '*.txt', '')
files1 = dir(strcat(path,'*.txt'));
files = strvcat( files1.name );

[numfids, ~] = size(files);
vals = cell(1,numfids);
for filesInd = 1:numfids
    vals{filesInd} = importdata(strcat(path,files(filesInd,:)));
end

names = files;
HumanSeg = vals;
end

%% read data from all files
function  [vals, files, numfids] = readDatasets(path)
path = strrep(path, '*.txt', '')
files1 = dir(strcat(path,'*.txt'));
files = strvcat( files1.name );

[numfids, ~] = size(files);
vals = cell(1,numfids);
for (filesInd = 1:numfids)
    vals{filesInd} = importdata(strcat(path,files(filesInd,:)));
end
end

%% read sementation position from the name of file
function [groundTruthSegPos, length] = getSegmentPos(names)
segmentPos = strfind(names,'_');
[~, n] = size(segmentPos);
data = [ 0 0];
for(i = 1:1:n)
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

%% write false result in file for test
function write2FileScores(fileID, dataSetName, ind, Scores)
 [~, n] = size(Scores);
fprintf(fileID,dataSetName);
fprintf(fileID,',');

for i = 1:n
    fprintf(fileID,num2str(Scores(ind,i)));
    fprintf(fileID,',');
end
fprintf(fileID,'\n');
end