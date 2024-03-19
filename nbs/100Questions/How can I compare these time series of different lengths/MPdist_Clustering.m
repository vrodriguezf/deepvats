function MPdist_Clustering(TSs)

numOfData = 6; % change this number if you have different number of sample data
count = 0;
SL = 30; % the length of subsequence
method = 'complete';

[m n] = size(TSs);
if m > n
    for i = 1:numOfData
        TSs{i} = TSs{i}';
    end
end

for i = 1:numOfData
    for j = i+1:numOfData
        count = count + 1;
        data{count} = [TSs{j}', TSs{i}'];
        changepoint(count) = length(TSs{j});
    end
end

for ind = 1:count
    distance(ind) = distance_Algorithm(data{ind}, changepoint(ind), SL);
end

figure
rng('default')

Z=linkage(distance,method);%%'complete' , 'average'
subplot(numOfData+2, 2, [2 4 6 8 10 12 14 16]); % [2 4 6 8 10 12] [2 4 6 8 10 12 14 16 18 20] [2 4 6 8 10 12 14]); subplot spanning the entire third and fourth row
[H, T, outperm] = dendrogram(Z,'Orientation','right');%% single

xLimits = get(gca,'XLim');  %# Get the range of the y axis
h = gca;
xlim([0 xLimits(2)]);
set(h,{'ycolor'},{'w'});
% %% Calc Dedrogram
maxLength = 0;
for ind = 1:length(TSs)
    lengthData = length(TSs{ind});
    if lengthData > maxLength
        maxLength = lengthData;
    end
end

LO = length(outperm);
for i = 1:LO
    subplot(numOfData+2, 2, 2*i+1 );  % create a plot with subplots in a grid of 4 x 2
    Zd1 = zscore(TSs{outperm(LO-i+1)});
    d1new(1: maxLength) = nan;
    d1new((maxLength - length(Zd1))+1: maxLength) = Zd1;
    plot(Zd1); % subplot at first row, first column
    set(gca,'Visible','off');
    xlim([0 maxLength]);
end
end

function distance = distance_Algorithm(data, changePoint, SL)
thr = 0.05;
[ABBAJoinMP, ABBAJoinMPI] = MatrixProfileSplitConstraint(data, SL, changePoint);

% distance Calculation
TSLength = length(data);
distLoc = ceil(thr*TSLength);
MPSorted = sort(ABBAJoinMP);

if MPSorted(distLoc)~= inf
    distance = MPSorted(distLoc);
else
    MPRemoveInf = ABBAJoinMP(ABBAJoinMP(:)~=inf);
    distance = max(MPRemoveInf);
end
end

function distance = calMPdist(MP, thr, dataLength)
distLoc = ceil(thr*dataLength);
MPSorted = sort(MP);

MPRemoveInf = MPSorted(MPSorted(:)~=inf);
if length(MPRemoveInf) >= distLoc
    distance = MPRemoveInf(distLoc);
else
    distance = MPRemoveInf(length(MPRemoveInf));
end
end

