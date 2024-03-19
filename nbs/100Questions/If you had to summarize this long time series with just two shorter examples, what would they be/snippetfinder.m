function [fraction,snippet,snippetidx]= snippetfinder(data,N,sub,per)
close all
%%Anonymous-Author information blinded for review
%%This is the source code for the ICDM paper "Time Series Snippets: A New Primitive
%%for Time Series Data Mining". For more details, please refer to the
%%supporting website: https://sites.google.com/site/snippetfinder

%%input:
%%data : Time Series
%%N : number of snippets the user wishes to find
%%sub : the length of snippet
%%per : the MPdist subsequence length percentage.
%%For example, if per is 100 then the MPdist subsequence is the same as sub.

%%output: 
%%snippet : a list of N snippets
%%fraction : fraction of each snippet
%%snippetidx : the location of each
%%snippet within time sereis
 
%% check input
if length(data) < 2 *sub
     error('Error: Time series is too short relative to desired snippet Length');
end
if length(data) == size(data, 2)
   data = data'; 
end
%% initialization
distances = [];
indexes = [];
snippet = [];
minis = inf;
fraction=[];
snippetidx=[];
distancesSnipp = [];

len = sub * ceil(length(data)/sub) - length(data);
%% padding zeros to the end of the time series. 
data = [data;zeros(len,1)];
 
%% compute all the profiles
for i = 1:sub:length(data) - sub 
    indexes = [indexes,i];
    distance = fastMPdist_SS(data,data(i:i+ sub) ,round(sub*per/100),0.05);
    distances = [distances;distance];
end
%% calculating the Nth snippets 
CM = jet(N);
for n = 1:N
    minims = inf;
    for i = 1:size(distances,1)
        if minims > sum(min(distances(i,:),minis)) 
               minims = sum(min(distances(i,:),minis));
               index = i;
        end
    end
    minis = min(distances(index,:),minis);
    snippet = [snippet;data(indexes(index):indexes(index)+sub)];
    snippetidx = [snippetidx;indexes(index)];

    distance = fastMPdist_SS(data,data(indexes(index):indexes(index)+ sub) ,round(sub*per/100),0.05);
    distancesSnipp = [distancesSnipp;distance];
    
%     figure;
%     plot(distance);title(['MPdist-' num2str(n) '  location-' num2str(indexes(index))]);box off; xlim([0 length(distance)])
    figure;
    if N == 2
        plot(data(indexes(index):indexes(index)+sub),'color',CM(n,:));title([ ' snippet-' num2str(n) '  location-'  num2str(indexes(index))],'color',CM(n,:))
        box off;xlim([0 length(data(indexes(index):indexes(index)+sub))]);
    else
        plot(data(indexes(index):indexes(index)+sub),'color',CM(n,:));title([ ' snippet-' num2str(n) '  location-'  num2str(indexes(index))],'color',CM(n,:))
        box off;xlim([0 length(data(indexes(index):indexes(index)+sub))]);
    end
      
end
%% Calculating the fraction of each snippet 
totalmin = min(distancesSnipp);
a = 0;

for i = 1:N
    a = distancesSnipp(i,:) <= totalmin ;
    b = a;
    a(a==0)=[];
    fraction = [fraction;length(a)/(length(data)-sub)];
% % % %     just in case we have the same value for both
    totalmin = totalmin - b ;
end


figure;hold on;ylim([0.9 1.1])  
% plot(ones(length(totalmin),1),'r');
totalmin = min(distancesSnipp);
for ii = 1:N
    a = distancesSnipp(ii,:) <= totalmin ;
    for i = 1:round(sub/N)+1:length(a)-sub+1
        if sum(a(i:i+round(sub/N)+ 1)) > (1/2 * (round(sub/N)+1))
            plot(i:i+round(sub/N)+ 1,ones(size(i:i+round(sub/N)+ 1)),'color',CM(ii,:),'LineWidth',20);
            totalmin(i:i+round(sub/N)+ 1) = totalmin(i:i+round(sub/N)+ 1) - 1;
        end
    end
end
          
    
    
%% Calculating the horizantal regime bar for 2 snippets
% if N == 2
%      totalmin = min(distancesSnipp);
%      a = 0;
%      i = 1;
%      a = distancesSnipp(i,:) <= totalmin ;
% 
%     for i = 1:sub:length(a) - sub
%         if sum(a(i:i+sub-1)) > 1/2 * sum(ones(length(a(i:i+sub-1)),1))
%             a(i:i+sub-1) = ones(length(a(i:i+sub-1)),1);
%         else
%             a(i:i+sub-1) = zeros(length(a(i:i+sub-1)),1);
%         end
%     end
% 
%     % % % % % % % % % % % % % % % % % 
%     i = 1;
%     c = zeros(length(a),3);
%     j = 1;
%     while i <= length(a)
%         b = find(a(i+1:end) ~= a(i),1);
%         if isempty(b)
%             break;
%         else
%             c(j,:) = [i,i+b-1,a(i)];
%             j = j+1;
%             i = i+b;
%         end
%     end
%     if i <= length(a)
%         c(j,:) = [i,length(a),a(i)]; 
%     end
%     c = c(1:j,:);
%     figure();
%     
%     axes();
%     hold on;
%     m = mean(data) + 4;
%     plot(data/m);xlim([0 length(data)]);xticks([0 length(data)]);
%     for i = 1:size(c,1)
%         d = (c(i,1):c(i,2))';
%         if c(i,3) == 0
%             plot(d,ones(length(d),1),'color',CM(2,:),'lineWidth',2);
%         else
%             plot(d,ones(length(d),1),'color',CM(1,:),'lineWidth',2);
%         end
%     end
%     title('Horizantal regime bar')
% end


end   
