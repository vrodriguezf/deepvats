%%
function [patch] = piecewiseSplat(timeSeriesA, subseqLen, patch_size, plotting, timeSeriesB)

disp("Some")
overlap = 0;
[max_length] = getPaaFactor(timeSeriesA, subseqLen);
disp("poom")
if length(timeSeriesA) <= max_length
    SPLAT(timeSeriesA, subseqLen, timeSeriesB, 1, 0, 0);
    return
end
disp("Body")
if nargin < 2
    disp("Want")
    error('incorrect number of input arguments');
elseif ~isvector(timeSeriesA)
    disp("Sorry")
    error('first argument must be a 1D vector');
elseif ~(isfinite(subseqLen) && floor(subseqLen) == subseqLen) || (subseqLen < 2) || (subseqLen > length(timeSeriesA)) 
    disp("My laaalaralarara")
    error('subsequence length must be an integer value between 2 and the length of the timeSeries');
end

disp("toy aqui")

selfjoin = (~exist('timeSeriesB', 'var')) || all(isnan(timeSeriesB));
length_A = length(timeSeriesA);


if ~(selfjoin)
    if ~isvector(timeSeriesB)
        error('Third argument must be a 1D vector');
    elseif ~(isfinite(subseqLen) && floor(subseqLen) == subseqLen) || (subseqLen < 2) || (subseqLen > length(timeSeriesB)) 
        error('subsequence length must be an integer value between 2 and the length of both input timeSeries');
    end
    length_B = length(timeSeriesB);
else
    length_B = length_A;
end

disp("aqui")

%% FIXME
if (patch_size > length_A) || (patch_size > length_B)
    error('Patch size exceeds the input time series length')
end

%% FIXME: Check 
matrix_size = length_A - subseqLen;
k = floor(length_A/patch_size);
patch_size = floor(matrix_size/k);

half = floor(patch_size/10);
while ~(rem(length_B,patch_size) < half) || ~(rem(length_A,patch_size) < half)
    patch_size = patch_size - 1;
end
patch_size = floor(patch_size);
warning('Patch size is set to %d',patch_size);
disp("Para quererteee")
patch = nan(patch_size);
curr_patch_idx = 0;
patch_idx_b = 0;
segment_size = patch_size + subseqLen - 1;
disp("toy aqui")
ii = 1;

disp("Before while")
while ii <= length_B-segment_size
    if selfjoin
            seg_B = timeSeriesA(ii:ii + segment_size);
        else
            seg_B = timeSeriesB(ii:ii + segment_size);
    end
    patch_idx_a = 0;
    patch_idx_b = patch_idx_b + 1;
    
    jj = 1;
    while jj <= length_A-segment_size
        if ii > jj
            jj = jj + patch_size - overlap;
            continue
        end
        %% removing exclusion zone
        exclusionzone = ceil(subseqLen/2);
        if abs(ii-jj) <= 3*exclusionzone
            jj = jj + patch_size - overlap;
            continue
        end
        seg_A = timeSeriesA(jj:jj + segment_size);
        if seg_A == seg_B
            patch = SimMat(seg_A, subseqLen);
        else
            patch = SimMat(seg_A, subseqLen, seg_B);
        end
        Y = patch> 0.9*max(patch,[],'all');
        
        patch_idx_a = patch_idx_a + 1;       
        curr_patch_idx = curr_patch_idx + 1;
             
        if plotting           
            disp("plot")
            close all;  
            figure(5);
            ax1 = subplot(10,10,[2:10]);
            ax1.FontSize = 18;
            plot(seg_A);
            ax1.XTick = [];
            ax1.YTick = [];
            ax1.Box = 'off';
            ax1.Color = 'None';

            ax2 = subplot(10,10,[12:20,22:30,32:40,42:50,52:60,62:70,72:80,82:90,92:100]);
            ax2.FontSize = 18;
            imagesc(Y)
            colormap(ax2,flipud(gray))
            colorbar
            ax2.DataAspectRatio = [1 1 1];
            hold on;
            
            ax3 = subplot(10,10,[11,21,31,41,51,61,71,81,91]);
            ax3.FontSize = 18;
            plot(seg_B);
            ax3.XTick = [];
            ax3.YTick = [];
            ax3.Box = 'off';
            ax3.Color = 'None';
            view([90,-90])
            set(ax3,'xdir','reverse','ydir','reverse', 'XAxisLocation','top');
            pos1 = get(gcf,'Position');
            set(gcf,'Position', pos1 - [pos1(3)/1.5,0,0,0]) 
            disp("Holi")
            input('press any key');
            disp("Chau")
        end
        jj = jj + patch_size - overlap;
    end
    ii = ii + patch_size - overlap;
end
disp("After while")

end

