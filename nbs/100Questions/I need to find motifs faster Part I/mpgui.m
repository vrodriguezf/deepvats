classdef mpgui < handle
    
    properties(Access = private)
        fig;
        dataAx;
        profileAx;
        discordAx;
        motifAx;
        dataText;
        profileText;
        discordText;
        motifText;
    end
    
    properties(Constant, Access = private)
        txtTemp = {
            'The best motif pair is located at %d (green) and %d (cyan)';
            'The 2nd best motif pair is located at %d (green) and %d (cyan)';
            'The 3rd best motif pair is located at %d (green) and %d (cyan)';
            };
        discordColor = {'b', 'r', 'g'};
        motifColor = {'g', 'c'};
        neighborColor = [0.5, 0.5, 0.5];
        titleTxt = 'UCR Interactive Matrix Profile Calculation 2.1';
    end
    
    methods(Access = private)
        function gui = mpgui(dataLen, subLen)
            rs = @(fig, obj) gui.mainResize();
            gui.fig = figure('name', gui.titleTxt, ...
                'visible', 'off', 'toolbar', 'none', 'ResizeFcn', rs);
            backColor = get(gui.fig, 'color');
            gui.dataAx = axes(gui.fig, ...
                'units', 'pixels', 'xlim', [1, dataLen], 'xtick', [1, dataLen], ...
                'ylim', [-0.05, 1.05], 'ytick', [], 'ycolor', [1, 1, 1]);
            gui.profileAx = axes(gui.fig, ...
                'units', 'pixels', 'xlim', [1, dataLen], 'xtick', [1, dataLen], ...
                'ylim', [0, 2*sqrt(subLen)]);
            gui.discordAx = axes('parent', gui.fig, ...
                'units', 'pixels', 'xlim', [1, subLen], 'xtick', [1, subLen], ...
                'ylim', [-0.05, 1.05], 'ytick', [], 'ycolor', [1, 1, 1]);
            gui.dataText = uicontrol('parent', gui.fig, ...
                'style', 'text', 'string', '', 'fontsize', 10, ...
                'backgroundcolor', backColor, 'horizontalalignment', 'left');
            gui.profileText = uicontrol('parent', gui.fig, ...
                'style', 'text', 'string', 'The best-so-far matrix profile', ...
                'fontsize', 10, 'backgroundcolor', backColor, ...
                'horizontalalignment', 'left');
            gui.discordText = uicontrol('parent', gui.fig, ...
                'style', 'text', 'string', '', 'fontsize', 10, ...
                'backgroundcolor', backColor, 'horizontalalignment', 'left');
            gui.motifAx = gobjects(3, 1);
            for i = 1:3
                gui.motifAx(i) = axes('parent', gui.fig, ...
                    'units', 'pixels', 'xlim', [1, subLen], 'xtick', [1, subLen], ...
                    'ylim', [-0.05, 1.05], 'ytick', [], 'ycolor', [1, 1, 1]);
            end
            gui.motifText = gobjects(3,1);
            for i = 1:3
                gui.motifText(i) = uicontrol('parent', gui.fig, ...
                    'style', 'text', 'string', '', 'fontsize', 10, ...
                    'backgroundcolor', backColor, 'horizontalalignment', 'left');
            end
        end
        
        function plotData(gui, data)
            hold(gui.dataAx, 'on');
            plot(mpgui.zeroOneNorm(data), 'r', 'parent', gui.dataAx);
            hold(gui.dataAx, 'off');
        end
        
        function plotProfile(gui, matrixProfile)
            hold(gui.profileAx, 'on');
            plot(1: length(matrixProfile), matrixProfile, 'b', 'parent', gui.profileAx);
            hold(gui.profileAx, 'off');
        end
        
        function plotMotifsDiscords(gui, data, motifIdxs, discordIdx, subLen)
            if isempty(motifIdxs)
                error('empty motif plot');
            end
            data = mpgui.zeroOneNorm(data);
            % plot top motif pair on data
            hold(gui.dataAx, 'on');
            for j = 1:2
                plot(motifIdxs{1, 1}(j) : motifIdxs{1, 1}(j) + subLen - 1, ...
                    data(motifIdxs{1, 1}(j) : motifIdxs{1, 1}(j) + subLen - 1), gui.motifColor{j},...
                    'parent', gui.dataAx);
            end
            hold(gui.dataAx, 'off');
            % plot motif's neighbors on motif axis
            % Neighbor counts are dependent on how many are within the
            % specified radius, up to a maximum count
            for j = 1:3
                hold(gui.motifAx(j), 'on');
                for k = 1:length(motifIdxs{j, 2})
                    plot(mpgui.zeroOneNorm(data(motifIdxs{j, 2}(k) : motifIdxs{j, 2}(k) + subLen - 1)),...
                        'color', gui.neighborColor, 'linewidth', 2, 'parent', gui.motifAx(j));
                end
                hold(gui.motifAx(j), 'off');
            end
             
            % The gui spawns a layout with 3 windows. If it can't find 3
            % motifs, it should plot fewer but throw a warning.
            
            % plot motif on motif axis
            for j = 1:3
                hold(gui.motifAx(j), 'on');
                for k = 1:2
                    set(gui.motifText(j), 'string', sprintf(gui.txtTemp{j}, motifIdxs{j, 1}(1), motifIdxs{j, 1}(2)));
                    plot(1:subLen,...
                        mpgui.zeroOneNorm(data(motifIdxs{j, 1}(k):motifIdxs{j, 1}(k) + subLen - 1)),...
                        gui.motifColor{k}, 'parent', gui.motifAx(j));
                end
                hold(gui.motifAx(j), 'off');
            end
            
            for j = 1:3
                if isnan(discordIdx(j))
                    break;
                end
                hold(gui.discordAx, 'on');
                plot(mpgui.zeroOneNorm(data(discordIdx(j):discordIdx(j) + subLen - 1)), gui.discordColor{j}, 'parent', gui.discordAx);
                hold(gui.discordAx, 'off');
            end
            set(gui.dataText, 'string', sprintf(['The input time series: ', ...
                'The motifs are color coded (see bottom panel)']));
            set(gui.discordText, 'string',sprintf(['The top three discords ', ...
                '%d(blue), %d(red), %d(green)'], discordIdx(1), discordIdx(2), discordIdx(3)));
        end
        
        function mainResize(gui)
            figPosition = get(gui.fig, 'position');
            axGap = 38;
            % zero guard is needed to avoid setting height or position to negative values
            % which will otherwise throw a runtime error.
            axesHeight = max(0, round((figPosition(4) - axGap * 5 - 60) / 6));
            ax_pos = max(figPosition(3) - 60, 0);
            disctxt_pos = max(figPosition(3) - 160, 0);
            
            set(gui.dataAx, 'position', [30, 5 * axesHeight+5 * axGap + 30, ax_pos, axesHeight]);
            set(gui.profileAx, 'position', [30, 4 * axesHeight+4 * axGap + 30, ax_pos, axesHeight]);
            set(gui.discordAx, 'position', [30, 30, disctxt_pos, axesHeight]);
            set(gui.dataText, 'position',  [30, 6 * axesHeight + 5 * axGap + 30, ax_pos, 18]);
            set(gui.profileText, 'position', [30, 5 * axesHeight + 4 * axGap + 30, ax_pos, 18]);
            set(gui.discordText, 'position', [30, 1 * axesHeight + 30, disctxt_pos, 18]);
            for i = 1:3
                set(gui.motifAx(i), 'position', [30, (4 - i) * axesHeight + (4 - i) * axGap + 30, disctxt_pos, axesHeight]);
            end
            for i = 1:3
                set(gui.motifText(i), 'position', [30, (5 - i) * axesHeight + (4 - i) * axGap + 30, disctxt_pos, 18]);
            end
        end
    end
    
    methods(Static)
        % These should be moved to function files or inlined
        % populate(gui, data, dataSig, matrixProfile, profileIndex, subLen, excZoneLen, radius)
        function gui = launchGui(data, matrixProfile, motifIdx, discordIdx, subLen)
            gui = mpgui(length(data), subLen);
            gui.plotData(data);
            gui.plotProfile(matrixProfile);
            gui.plotMotifsDiscords(data, motifIdx, discordIdx, subLen);
            gui.fig.Visible = 'on';
        end
        
        function data = zeroOneNorm(data)
            finite = find(isfinite(data));
            data = data - min(data(finite));
            data(finite) = data(finite) / max(data(finite));
        end
        
    end
end