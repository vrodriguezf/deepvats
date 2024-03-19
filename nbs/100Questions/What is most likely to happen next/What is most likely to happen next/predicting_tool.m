function [] = predicting_tool(data, sub_len, saving_video, compression)
% The tool predicts the next subsequence based on the current subsequence
% If the current subsequence (S_current) is very similar to a subsequence
% in the past (S_past), then our best guess of the next subsequence is what
% followed S_past.
% The best guess is associated with a confidence level. The confidence
% level is the correlation between S_current and S_past.
% Only parameters data and sub_len are compulsory. The rest is optional.
% The code below is heavy on the visualization side. 
% The core idea is given a query subsequence and a longer time series,
% compute the best matches with z-normalized Euclidean distance fast.
% We show three best matches by default.
% 
% A working example:
% data = load('power_data.txt');
% sub_len = 150;
% predicting_tool(data, sub_len);
% If you want to output the visualisation video: 
% saving_video = 1;
% predicting_tool(data, sub_len, saving_video);
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameters
% Prediction plot shows 3 windows (3 subsequencs)
pre_window = 3;
% Time series plot shows 10 windows (10 subsequences)
ts_window = 10;

% Extra option: 
% set saving_video to a non-zero integer to save the video
% by default: don't save video and always compress video if save it
if ~exist('compression', 'var') || compression ~= 0
    compression = true; % default: always compress the video
else
    compression = false;
end

if ~exist('saving_video', 'var') || saving_video == 0
    saving_video = false; % default: not save the video
else
    saving_video = true;
end

if saving_video
    % Video frame rate
    frame_rate = 5; % number of frames per second
    % Video quality
    video_quality = 100; % 1-100
end

groundtruth_color = [160/255, 160/255, 160/255];
% groundtruth_color = [204/255, 0/255, 0/255];
confidence_color = [173/255, 235/255, 173/255];
ts_pre_color = [0/255, 0/255, 204/255];
ts_color = [0/255, 102/255, 0/255];
m1_color = [0/255, 153/255, 51/255];
m2_color = [153/255, 102/255, 51/255];
m3_color = [255/255, 204/255, 102/255]; %[197/255, 186/255,0/255];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% position: [left bottom width height]
f = figure('Visible','on','Position',[400,100,1250,500]);

% Assign the a name to appear in the window title.
f.Name = 'Time series prediction GUI';

% Move the window to the center of the screen.
movegui(f,'center')

stop_button = uicontrol('Style', 'pushbutton', 'String', 'Stop', 'Position',...
    [1150, 200,70, 25], 'Callback', {@stop_button_callback});
stop_button.FontSize = 11;

exit_button = uicontrol('Style', 'pushbutton', 'String', 'Exit', 'Position',...
    [1150, 130,70, 25], 'Callback', {@exit_button_callback});
exit_button.FontSize = 11;

% Change units to normalized so components resize automatically.
f.Units = 'normalized';
stop_button.Units = 'normalized';
exit_button.Units = 'normalized';

%%
% set up the plot axes
prediction_ax = subplot(2,6,[1 2 3 4 5]);
confidence_ax = subplot(2,6,6);
data_ax = subplot(2,6,[7 8 9 10 11 12]);

prediction_ax.FontSize = 11;
data_ax.FontSize = 11;
confidence_ax.FontSize = 11;

if length(data) < sub_len * ts_window
    error('Error: Time series is too short. It should be at least 10 times subsequence length');
end

% input must a row vector
if iscolumn(data)
    data = data';
end

if saving_video
    % set up the video recording
    if ~exist('video', 'dir')
        mkdir('video');
    end
    
    if compression
        myVideo = VideoWriter('video/demo', 'MPEG-4');
        myVideo.Quality = video_quality;
    else
        myVideo = VideoWriter('video/demo.mp4', 'Uncompressed AVI');
    end
    
    myVideo.FrameRate = frame_rate;
    open(myVideo);
    nframe = length(data)-(sub_len*ts_window -1);
    mov(1:nframe) = struct('cdata', [], 'colormap', []);
    set(gca, 'nextplot', 'replacechildren'); % to prevent the flickering effect
end

stopping = false;
exiting = false;
for index = 1:length(data)-(sub_len*ts_window -1)
    % to create a streaming effect, use hold on and hold off
    hold(data_ax, 'on');
    hold(confidence_ax, 'on');
    hold(prediction_ax, 'on');
    if exist('data_p', 'var')
        delete(data_p);
        delete(confidence_p);
        delete(prediction_p);
        delete(m1_p);
        delete(m2_p);
        delete(m3_p);
        delete(groundtruth_p);
    end
    
    current_data = data(index:index+sub_len*ts_window - 1);
    groundtruth = current_data(end-sub_len+1:end);
    t = sub_len*(pre_window-1)+1:sub_len*(pre_window-1)+sub_len;
    best_match_index = find_best_matches(current_data(1:end-sub_len), sub_len);
    m1 = current_data(best_match_index(1) + sub_len: best_match_index(1) + 2*sub_len -1);
    m2 = current_data(best_match_index(2) + sub_len: best_match_index(2) + 2*sub_len -1);
    m3 = current_data(best_match_index(3) + sub_len: best_match_index(3) + 2*sub_len -1);
    
    % compute correlation distance between groundtruth and best match,
    % normalize to be in range [0 1]
    confidence = 1 - (pdist2(groundtruth, m1, 'correlation'))/2;
    % compute cosine distance between groundtruth and best match, normalize
    % to be in range [0 1]
%     confidence = 1 - (pdist2(groundtruth, m1, 'cosine'))/2;
    
    % make the first data point of matches match first data point of
    % groundtruth for visual clarity
    m1 = m1 - m1(1) + groundtruth(1);
    m2 = m2 - m2(1) + groundtruth(1);
    m3 = m3 - m3(1) + groundtruth(1);
    
    % time series
    d2 = current_data(1:end-sub_len);
    data_p = plot(d2, 'Color', ts_color, 'parent', data_ax);
    title(data_ax, 'Time series'); box off;
    
    % Mark current window as 'now' on the x-axis
    xt = cellstr(get(data_ax, 'XTickLabel'));
    now_pos = int8(length(xt) - length(xt)/ts_window);
    xt{now_pos} = 'Now';
    set(data_ax, 'XTickLabel', xt);
    yt = cellstr(get(data_ax, 'YTickLabel'));
    
    % Prediction pane
    d1 = current_data(end-pre_window*sub_len+1:end-sub_len+1);
    prediction_p = plot(d1, 'Color', ts_pre_color, 'parent', prediction_ax);
    set(prediction_ax, 'ylim', [str2double(yt{1}) str2double(yt{end})]);
    
    hold on; m1_p = plot(t,m1, 'Color', m1_color, ...
        'LineWidth', 1.5,'parent', prediction_ax);
    m1_p.Color(4) = 0.8; % 30% transparent
    
    hold on; m2_p = plot(t,m2, 'Color', m2_color,...
        'LineWidth', 0.5, 'parent', prediction_ax);
    m2_p.Color(4) = 0.7; % 30% transparent
    
    hold on; m3_p = plot(t,m3, 'Color', m3_color, ...
        'LineWidth', 0.5, 'parent', prediction_ax);
    m3_p.Color(4) = 0.7; % 30% transparent
    
    hold on; groundtruth_p = plot(t, groundtruth, 'Color', groundtruth_color , ...
        'LineWidth', 5, 'DisplayName', 'Groundtruth','parent', prediction_ax);
    groundtruth_p.Color(4) = 0.5; % 50% tranparent
    title(prediction_ax, 'Prediction'); box off;
    
    legend([groundtruth_p m1_p], 'Groundtruth', 'Best match', 'Location','northwest');
    
    uistack(m1_p, 'top'); % put the best match line to top
    
    % Mark current window as 'now' on the x-axis
    xt = cellstr(get(prediction_ax, 'XTickLabel'));
    now_pos = int8(length(xt) - length(xt)/pre_window);
    xt{now_pos} = 'Now';
    set(prediction_ax, 'XTickLabel', xt); % same ylim as time series plot
    
    % confidence bar
    confidence_p = bar(confidence, 'FaceColor', confidence_color, ...
        'parent', confidence_ax);
    title(confidence_ax, ['Confidence = ', num2str(confidence,2)]); 
    set(confidence_ax, 'xtick', []);
    set(confidence_ax, 'ytick', [0 1]);
    set(confidence_ax, 'ylim', [0 1]);
    
    hold(data_ax, 'off');
    hold(confidence_ax, 'off');
    hold(prediction_ax, 'off');
    
    % adjust pause length depending on the time series length for visual
    % clarity
    if length(current_data) < 2000
        n = 0.2;
    else
        n = 0;
    end
    pause on;
    pause(n); % pause for n second between each iteration
    
    if stopping
        pause on
        pause();
        stopping = false;
        pause off;
    end
    
    if saving_video
        mov(index) = getframe(gcf); % record video
    end
    
    if exiting
        if saving_video
            disp('Saving the video');
            mov(index+1:nframe) = [];
            writeVideo(myVideo, mov); 
            close(myVideo);
        end
        disp('Closing the application');
        close(f);
        return;
    end
end

if saving_video
    writeVideo(myVideo, mov);
    close(myVideo);
end
    
function [] = stop_button_callback(~, ~)
    disp('Stopping. Unselect the stop button and press any key to resume.');
    stopping = true;
end

function [] = exit_button_callback(~, ~)
    exiting = true;
end   

end

function [best_match_index] = find_best_matches(data, sub_len)
%% set trivial match exclusion zone
exclusionZone = round(sub_len/2);

%% check input
data_len = length(data);
if sub_len > data_len/2
    error('Error: Time series is too short relative to desired subsequence length');
end

if sub_len < 4
    error('Error: Subsequence length must be at least 4');
end

if data_len == size(data, 2)
    data = data';
end

%% locate nan and inf
profile_len = data_len - sub_len + 1;
isSkip = false(profile_len, 1);
for i = 1:profile_len
    if any(isnan(data(i:i+sub_len-1))) || any(isinf(data(i:i+sub_len-1)))
        isSkip(i) = true;
    end
end
data(isnan(data)|isinf(data)) = 0;
    
%% preprocess for matrix profile
[dataFreq, data2Sum, dataSum, dataMean, data2Sig, dataSig] = ...
    fastfindNNPre(data, data_len, sub_len);

%%
idx = length(data)-sub_len+1;
query = data(idx:end);
distance_profile = fastfindNN(dataFreq, query, data_len, sub_len, ...
            data2Sum, dataSum, dataMean, data2Sig, dataSig);  
distance_profile = abs(distance_profile);

% apply skip zone
distance_profile(isSkip) = inf;

% apply exclusion zone
exclusion_zone_start = max(1, idx-exclusionZone);
exclusion_zone_end = min(profile_len, idx+exclusionZone);
distance_profile(exclusion_zone_start:exclusion_zone_end) = inf;

% find best matches
[~, profile_index_order] = sort(distance_profile, 'ascend');
best_match_index = zeros(3,1);
for j = 1:3
    best_match_index(j) = profile_index_order(1);
    distance_profile(profile_index_order(1))
    profile_index_order(1) = [];
    profile_index_order(abs(profile_index_order - best_match_index(j)) < exclusionZone) = [];
end
best_match_index(best_match_index == 0) = nan;
end

%% The following two functions are modified from the code provided in the following URL
%  http://www.cs.unm.edu/~mueen/FastestSimilaritySearch.html
function [dataFreq, data2Sum, dataSum, dataMean, data2Sig, dataSig] = ...
    fastfindNNPre(data, dataLen, subLen)
data(dataLen+1:2*dataLen) = 0;
dataFreq = fft(data);
cum_sumx = cumsum(data);
cum_sumx2 =  cumsum(data.^2);
data2Sum = cum_sumx2(subLen:dataLen)-[0;cum_sumx2(1:dataLen-subLen)];
dataSum = cum_sumx(subLen:dataLen)-[0;cum_sumx(1:dataLen-subLen)];
dataMean = dataSum./subLen;
data2Sig = (data2Sum./subLen)-(dataMean.^2);
dataSig = sqrt(data2Sig);
end

function distanceProfile = fastfindNN(dataFreq, query, dataLen, subLen, ...
    data2Sum, dataSum, dataMean, data2Sig, dataSig)
query = (query-mean(query))./std(query,1);
query = query(end:-1:1);
query(subLen+1:2*dataLen) = 0;
queryFreq = fft(query);
dataQueryProdFreq = dataFreq.*queryFreq;
dataQueryProd = ifft(dataQueryProdFreq);
querySum = sum(query);
query2Sum = sum(query.^2);
distanceProfile = (data2Sum - 2*dataSum.*dataMean + subLen*(dataMean.^2))./data2Sig ...
    - 2*(dataQueryProd(subLen:dataLen) - querySum.*dataMean)./dataSig + query2Sum;
distanceProfile = sqrt(distanceProfile);
end


