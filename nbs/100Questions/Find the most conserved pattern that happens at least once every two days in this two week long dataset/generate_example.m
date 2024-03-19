% consensus motif example for a sequence of 10 time series
% Commented out sections were used to generate the file random_walk.txts
function  [sol,obj] = generate_example(T, subsequence_len)
if (size(T,2) > 1)
    T = T';
end
figure();
ax = axes();
hold on;

nanInexies = isnan(T);
tsNum = sum(nanInexies);
inds = find(nanInexies(:)==1);
indsX = diff(inds);
inds(end+1) = length(T);
st = 1;
for i = 1 : length(inds)
    plot(zscore(T(st : inds(i)-1 ),1) + tsNum*i);
    st = inds(i)+1;
end


hold off;
title(sprintf('k = %d time series',tsNum));
ax.YTick = [];
drawnow;

[sol,obj] = consensus_search.from_nan_cat(T,subsequence_len,true);
radios = sol.radius;

% title(sprintf('corresponding consensus motif for subsequence length: %d radius %g',subsequence_len,sol.radius));
% drawnow;
% optional to test against brute force version. Beware this can take a long time
%[sol_0] = obj.solve_brute_force(true);
% end
 end
