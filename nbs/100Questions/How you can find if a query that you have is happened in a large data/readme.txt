%  for MP distance :
[distanceFastMPdist] = fastMPdist_SS(TS,query, round(length(query)*0.35), 0.05);
[val,index] = min(distanceFastMPdist);
figure; plot(TS(index:index+length(query)));title('MPdistance')

% for Euclidean distance:
[dist] = MASS_V4(TS,query);
[val,index] = min(dist)
figure; plot(TS(index:index+length(query)));title('EuclideanDistance')