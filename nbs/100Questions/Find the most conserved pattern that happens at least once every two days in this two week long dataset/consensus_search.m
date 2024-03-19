classdef consensus_search
    properties
        ts;
        sublen;
        mu;
        invn;
        mp;
        mp_pooledmin;
        mpi;
        ffts;
    end
    methods
        function obj = consensus_search(ts, sublen, kmin)
            consensus_search.validateParams(ts, sublen, kmin);
            % takes a cell array of time series,
            %       a subsequence length, 
            %       and the minimum number of time series which a candidate
            %       subsequence must match against
            %       Since this is a work in progress pending agreement on a couple definitions, 
            %       we currently only support the case where a candidate
            %       must match against every time series

            N = length(ts);
            obj.ts = ts;
            obj.sublen = sublen;
            obj.mu = cell(N, N - kmin + 1);
            obj.invn = cell(N, N - kmin + 1);
            obj.mp = cell(N, N - kmin + 1);
            obj.mp_pooledmin = cell(N,1);
            obj.mpi = cell(N,N - kmin + 1);
            obj.ffts = cell(N, 1);
            
            % this could be replaced with conv2 on shorter subsequence lengths
            % but really this thing won't be much faster without building
            % bundling C code via an MEX.
            
            for i = 1 : size(ts,1)
                [obj.mu{i}, obj.invn{i}] = muinvn(obj.ts{i}, sublen);
                obj.ffts{i} = fft(obj.ts{i});
            end
            for i = 1 : size(ts,1)-1
                [obj.mp{i}, obj.mpi{i}] = obj.ABjoin(i,i+1);
            end
            [obj.mp{size(ts,1)},obj.mpi{size(ts,1)}] = obj.ABjoin(size(ts,1),1);
        end
        
        
        function [p] = pooled_min(obj)
            count = consensus_search.maxlen_2dcell(obj.mp);
            p = cell(size(obj.mp,1),1);
            for i = 1 : size(obj.mp,1)
                p{i} = inf(count(i),1);
                for j = 1 : size(obj.mp,2)
                    k = size(obj.mp{i,j},1);
                    p{i}(1 : k) = min(p{i}(1:k),obj.mp{i,j});
                end
            end
        end
        
        function tscount = k(obj)
            tscount = size(obj.ts,1);
        end
        
        function [bsf] = solve_multiple(obj,plot_sol,kmin)

            % This section is just some random notes. Consider it an
            % extended to do list, where the exact problem is still under
            % consideration. I have filled in some of the code sections in
            % accordance with what I suspect will be the final definition
            
            % Preliminaries:
            % An AB join provides a lower bound for the 
            % radius of any subsequence in time series A with respect to
            % the sequence of time series T^(1)....T^(N), provided that B is in T^(1)....T^(k).
            
            % We may instead want to consider the case where we are willing
            % to compute the minimum radius over all k - sized subsets of T^(1)....T^(N)
            % An AB join is no longer a lower bound to the radius of A over all N choose k possible problems.
            % The elementwise minimum of join(A,B_1)...join(A,B_(N - k + 1)) does provide a lower bound for all
            % problems containing time series A. We can therefore adopt the same strategy used in the other problem.
            
            % Obtain a lower bound for the radius of every subsequence in
            % some time series A. 
            % Sort the indices of A in increasing order with respect to their lower bound.
            % Test each subsequence in order of increasing lower bound.
            
            % In both problems, it's possible to consider subsequences
            % across multiple time series simultaneously by performing an
            % aggregated search. It takes many hours to verify that kind of thing. 
            % I'll implement it if we actually decide on where this is going.

            consensus_search.not_implemented();

            
            base = struct(...
                'nearest_neighbor_dists', repmat(2 * sqrt(obj.sublen), length(obj.ts),1),...
                'nearest_neighbor_ts', [],...
                'nearest_neighbor_indices', repmat(-1, length(obj.ts), 1),...
                'radius', 2 * sqrt(obj.sublen),...
                'diam', 2 * sqrt(obj.sublen),...
                'count', size(obj.ts,1),...
                'sublen', obj.sublen);
            bsf = base;  % for multiple should be repmat(base, N - kmin + 1)
            % Todo: revisit and clean up later
            % assume for now the only AB join used is 1 ahead modulo count
            % might be better to do this using a random shuffle if we have a large number of time series.
            for i = 1:length(obj.ts)
                [prof, S] = sort(obj.mp_pooledmin{i});
                for j = 1:length(prof)
                    if prof(j) > bsf.radius
                        break;
                    end
                    cand = base;
                    % AB join pair is implicitly (i, mod(i, number of time series) + 1)
                    A = i;
                    cand.nearest_neighbor_dists(A) = 0;
                    cand.nearest_neighbor_indices(A) = S(j);
                    q = (obj.ts{A}(S(j) : S(j) + obj.sublen - 1) - obj.mu{A}(S(j))) .* obj.invn{A}(S(j));
                    for k = 1 : length(obj.ts)
                        if (k == A) || (k == B)
                            continue;
                        end
                        % since the time series may be heterogeneous in
                        % length, we have the practical choices of blocked
                        % convolution or re-computing the query transform
                        [dist, ind] = obj.findnearest(q, k);
                        cand.nearest_neighbor_dists(k) = dist;
                        cand.nearest_neighbor_indices(k) = ind;
                        if dist > cand.radius
                            cand.radius = dist;
                        end
                        if cand.radius < 0
                            disp('rounding problem?');
                            pause;
                        end
                        if(cand.radius > bsf.radius)
                            break;
                        end
                    end
                    [cand.nearest_neighbor_dists, cand.nearest_neighbor_ts] = sort(cand.nearest_neighbor_dists);
                    cand.nearest_neighbor_indices = cand.nearest_neighbor_indices(cand.nearest_neighbor_ts);
                    cand.radius = cummax(cand.nearest_neighbor_dists);
                    if cand.radius < bsf.radius
                        cand.nearest_neighbor_indices = cand.nearest_neighbor_indices(cand.nearest_neighbor_ts);
                        bsf = cand;
                    end
                    % This is to be fully implemented. In general we can
                    % replace mink with sort so that it's k to N
                end
            end
            if plot_sol && bsf.radius <= radlim % can be worked in better
                A = find(bsf.nearest_neighbor_dists == 0);
                if numel(A) > 1
                    warning('possibly duplicate data');
                    A = A(1);
                end
                figure();
                ax = axes();
                hold on;
                for i = 1:length(obj.ts)
                    disp(bsf.nearest_neighbor_indices(i));
                    if i == A
                        plot(ax, (obj.ts{i}(bsf.nearest_neighbor_indices(i):bsf.nearest_neighbor_indices(i)+obj.sublen-1) - obj.mu{i}(bsf.nearest_neighbor_indices(i))) .* obj.invn{i}(bsf.nearest_neighbor_indices(i)), 'LineWidth', 2);
                    else
                        plot(ax, (obj.ts{i}(bsf.nearest_neighbor_indices(i):bsf.nearest_neighbor_indices(i)+obj.sublen-1) - obj.mu{i}(bsf.nearest_neighbor_indices(i))) .* obj.invn{i}(bsf.nearest_neighbor_indices(i)));
                    end
                end
                hold off;
                drawnow;
            end
        end
        
        function bsf = solve_opt(obj,plot_sol,radlim)
            if nargin == 1
                plot_sol = false;
                radlim = 2*sqrt(obj.sublen);
            elseif nargin == 2
                plot_sol = false;
            end
            base = struct(...
                'nearest_neighbor_dists', repmat(2 * sqrt(obj.sublen), length(obj.ts),1),...
                'nearest_neighbor_indices', repmat(-1, length(obj.ts), 1),...
                'radius', 2 * sqrt(obj.sublen));
            bsf = base;
            % assume for now the only AB join used is 1 ahead modulo count
            for i = 1:length(obj.ts)
                [prof, S] = sort(obj.mp{i});
                for j = 1:length(prof)
                    if prof(j) > bsf.radius
                        break;
                    end
                    cand = base;
                    % AB join pair is implicitly (i, mod(i, number of time series) + 1)
                    A = i;
                    B = mod(i, length(obj.ts)) + 1;
                    cand.nearest_neighbor_indices(A) = S(j);
                    cand.nearest_neighbor_indices(B) = obj.mpi{i}(S(j));
                    cand.nearest_neighbor_dists(A) = 0;
                    cand.nearest_neighbor_dists(B) = prof(j);
                    cand.radius = prof(j);
                    q = (obj.ts{A}(S(j) : S(j) + obj.sublen - 1) - obj.mu{A}(S(j))) .* obj.invn{A}(S(j));
                    for k = 1 : length(obj.ts)
                        if (k == A) || (k == B)
                            continue;
                        end
                        % since the time series may be heterogeneous in
                        % length, we have the practical choices of blocked
                        % convolution or re-computing the query transform
                        [dist, ind] = obj.findnearest(q, k);
                        cand.nearest_neighbor_dists(k) = dist;
                        cand.nearest_neighbor_indices(k) = ind;
                        if dist > cand.radius
                            cand.radius = dist;
                        end
                        if cand.radius < 0
                            disp('rounding problem?');
                            pause;
                        end
                        if(cand.radius > bsf.radius)
                            break;
                        end
                    end
                    if cand.radius < bsf.radius
                    % This was used for debugging. The reduction from
                    % normalized cross correlation to euclidean distance is
                    % only weakly stable. This can sometimes make it
                    % difficult to verify. This code compares against a very
                    % simple and stable function which computes the same result.
                    % 
                    % here to those obtained by a fairly stable function.
                    %    [rad, diam] = obj.comp_rad(cand.nearest_neighbor_indices, A);
                    %    fprintf('residual diff:%g\n',rad - cand.radius);
                    %    cand.radius = rad;
                    %    cand.diam = diam;
                        bsf = cand;
                    end
                end
            end
            if plot_sol && bsf.radius <= radlim % can be worked in better
                A = find(bsf.nearest_neighbor_dists == 0);
                if numel(A) > 1
                    warning('possibly duplicate data');
                    A = A(1);
                end
                figure();
                ax = axes();
                hold on;
                for i = 1:length(obj.ts)
                    if i == A
                        plot(ax, (obj.ts{i}(bsf.nearest_neighbor_indices(i):bsf.nearest_neighbor_indices(i)+obj.sublen-1) - obj.mu{i}(bsf.nearest_neighbor_indices(i))) .* obj.invn{i}(bsf.nearest_neighbor_indices(i)), 'LineWidth', 2);
                    else
                        plot(ax, (obj.ts{i}(bsf.nearest_neighbor_indices(i):bsf.nearest_neighbor_indices(i)+obj.sublen-1) - obj.mu{i}(bsf.nearest_neighbor_indices(i))) .* obj.invn{i}(bsf.nearest_neighbor_indices(i)));
                    end
                end
                hold off;
                title(sprintf('radius: %g',bsf.radius));
                drawnow;
            end
        end
        
        function bsf = solve_brute_force(obj,plot_sol)
            % brute force method for comparison
            if nargin == 1
                plot_sol = false;
            end
            
            base = struct(...
                'nearest_neighbor_dists', repmat(2 * sqrt(obj.sublen), length(obj.ts),1),...
                'nearest_neighbor_indices', repmat(-1, length(obj.ts), 1),...
                'radius', 2 * sqrt(obj.sublen));
            bsf = base;
            for i = 1:length(obj.ts)
                for j = 1 : length(obj.ts{i}) - obj.sublen + 1
                    cand = base;
                    q = (obj.ts{i}(j : j + obj.sublen - 1) - obj.mu{i}(j)) .* obj.invn{i}(j);
                    % normally the distance will never be exactly 0, we use
                    % this to mark the point treated as our pseudo -
                    % centroid. -1 is typically used to indicate uninitialized data
                    cand.nearest_neighbor_dists(i) = 0;
                    cand.nearest_neighbor_indices(i) = j;
                    for k = 1 : length(obj.ts)
                        if i == k
                            continue;
                        end
                        for h = 1 : length(obj.ts)
                            [cand.nearest_neighbor_dists(k), cand.nearest_neighbor_indices(k)] = obj.findnearest(q, k);
                        end
                    end
                    cand.radius = max(cand.nearest_neighbor_dists);
                    if cand.radius < bsf.radius
                        A = find(cand.nearest_neighbor_dists == 0);
                        if numel(A) > 1
                            warning('possibly duplicate data');
                        end
                        bsf = cand;
                    end
                end
            end
            if plot_sol
                A = find(bsf.nearest_neighbor_dists == 0);
                figure();
                ax = axes();
                hold on;
                for i = 1:length(obj.ts)
                    if i == A
                        plot(ax, (obj.ts{i}(bsf.nearest_neighbor_indices(i):bsf.nearest_neighbor_indices(i)+obj.sublen-1) - obj.mu{i}(bsf.nearest_neighbor_indices(i))) .* obj.invn{i}(bsf.nearest_neighbor_indices(i)), 'LineWidth', 2);
                    else
                        plot(ax, (obj.ts{i}(bsf.nearest_neighbor_indices(i):bsf.nearest_neighbor_indices(i)+obj.sublen-1) - obj.mu{i}(bsf.nearest_neighbor_indices(i))) .* obj.invn{i}(bsf.nearest_neighbor_indices(i)));
                    end
                end
                hold off;
                drawnow;
            end
        end
        
        function [dist,index] = findnearest(obj, q, tsmi)
            % This assumes q has been mean centered, so sum(q) is approximately 0
            cv = ifft(obj.ffts{tsmi} .* conj(fft(q, length(obj.ffts{tsmi}))), 'symmetric');
            [cr,index] = max(cv(1 : end - obj.sublen + 1) .* obj.invn{tsmi});
            dist = sqrt(2 * obj.sublen * (1 - cr));
        end
        
        function plot_ts(obj,tsi,ax)
            if nargin == 3
                if(~isobject(ax) || ~isvalid(ax))
                    error('invalid graphics object handle');
                end
            else
                fg = figure();
                ax = axes(fg);
            end
            hold(ax,'on');
            for i = 1 : length(tsi)
                if tsi(i) > length(obj.ts)
                    error('time series index out of range');
                end
                plot(ax,obj.ts{tsi(i)});
            end
            hold(ax,'off');
        end
        
        function plot_ss(obj,tsi,tssi,ax)
            if nargin == 3
                fg = figure();
                ax = axes(fg);
            end
            hold(ax,'on');
            for i = 1 : length(tsi)
                if tsi(i) > length(obj.ts)
                    error('time series index out of range');
                elseif tssi(i) > length(obj.ts{  tsi(i)})
                    error('time series subsequence index is out of range');
                end
                if nargin == 4
                    if isvalid(ax)
                        plot(ax, (obj.ts{tsi(i)}(tssi(i) : tssi(i) + obj.sublen - 1) - obj.mu{tsi(i)}(tssi(i))) .* obj.invn{tsi(i)}(tssi(i)));
                    else
                        error('invalid axis handle');
                    end
                else
                    plot((obj.ts{tsi(i)}(tssi(i) : tssi(i) + obj.sublen - 1) - obj.mu{tsi(i)}(tssi(i))) .* obj.invn{tsi(i)}(tssi(i)));
                end
            end
            hold(ax,'off');
        end
        
        function data = export_basic(obj)
            % this gives a struct which may be saved to and loaded
            % from a .mat without access to the original class definition
            % need to include a constructor to instantiate from this as
            % well
            data = struct('ts',   obj.ts, 'sublen', obj.sublen, 'mu', obj.mu,...
                'invn', obj.invn,   'mp', obj.mp,     'mpi',obj.mpi,...
                'ffts', obj.ffts);
        end
        
        function [rad, diam] = comp_rad(obj, nn_indices, seed_index)
            % Utility function to check radius and diameter.
            % Todo: Remove any remaining use of zscore functions
            if isempty(nn_indices) || isempty(seed_index)
                error('check inputs');
            elseif length(nn_indices) > length(obj.ts)
                error('Input index sequence contains more entries than the number of time series available');
            end
            ss = zeros(obj.sublen,length(nn_indices));
            for i = 1 : size(ss,2)
                ss(:,i) = (obj.ts{i}(nn_indices(i) : nn_indices(i) + obj.sublen - 1) - obj.mu{i}(nn_indices(i))) .* obj.invn{i}(nn_indices(i));
            end
            rad = 0;
            for i = 1 : size(ss,2)
                if i == seed_index
                    continue;
                end
                rad = max(rad, norm(zscore(ss(:,seed_index),1) - zscore(ss(:,i),1)));
            end
            diam = rad;
            for i = 1 : size(ss,2)
                if i == seed_index
                    continue;
                end
                z0 = zscore(ss(:,i),1);
                for j = 1 : size(ss,2)
                    if j == i
                        continue;
                    end
                    z1 = zscore(ss(:,j),1);
                    diam = max(diam, norm(z0 - z1));
                end
            end
        end
        
        function [mp,mpi] = ABjoin(obj,a,b)
            % This is a simple implementation. We have a faster C++ one for self joins,
            % but I haven't managed to sit down and write an AB extension of it.
            % Also note this isn't the most stable way to compute normalized
            % euclidean distance, but motif discovery isn't terribly
            % sensitive to minor perturbations.
            
            mp = zeros(length(obj.ts{a}) - obj.sublen + 1, 1);
            mpi = zeros(length(obj.ts{a}) - obj.sublen + 1, 1);
            
            for i = 1 : length(obj.ts{a}) - obj.sublen + 1
                q = (obj.ts{a}(i : i + obj.sublen - 1) - obj.mu{a}(i)) .* obj.invn{a}(i);
                [mp(i), mpi(i)] = obj.findnearest(q,b);
            end
        end
    end
    methods(Static)
        % These just act as static constructors
        
        function ts_c = packed_rows_to_cell(ts)
            % Assume the leading non-nan values in each row constitute a time series
            % and convert them to a cell array representation
            ts_c = cell(size(ts, 1), 1);
            for i = 1 : size(ts, 1)
                f = find(isnan(ts(i, :)), 1);
                if ~isempty(f)
                    ts_c{i} = reshape(ts(i, 1 : f - 1), f - 1, 1);
                else
                    ts_c{i} = reshape(ts(i, :), f, 1);
                end
            end
        end
        
        function ts_c = packed_cols_to_cell(ts)
            % Assume the leading non-nan values in each row constitute a time series
            % and convert them to a cell array representation
            ts_c = cell(size(ts, 2), 1);
            for i = 1 : size(ts, 2)
                f = find(isnan(ts(:, i)),1);
                if ~isempty(f)
                    ts_c{i} = ts(1 : f - 1, i);
                else
                    ts_c{i} = ts(:, i);
                end
            end
        end
        
        function [sol,obj] = from_packed_rows(ts, sublen, kmin, plotsol)
            % Takes a sequence of time series and subsequence length where
            % each time series is a row in a larger matrix, the columns of
            % which are NaN padded to the length of the longest time series
            
            ts_c = consensus_search.packed_rows_to_cell(ts);
            consensus_search.validateParams(ts_c, sublen, kmin);
            if nargin < 4
                plotsol = false;
            end
            if (nargin < 3) || (plotsol == false)
                kmin = length(ts_c);
            end
            obj = consensus_search(ts_c, sublen, kmin);
            sol =  obj.solve_opt(plotsol,inf);
        end
        
        function [sol,obj] = from_packed_cols(ts, sublen, kmin, plotsol)
            % Takes a sequence of time series and subsequence length where
            % each time series is a column in a larger matrix, the rows of
            % which are NaN padded to the length of the longest time series
            
            [ts_c] = consensus_search.packed_cols_to_cell(ts);
            if nargin < 4
                plotsol = false;
            end
            if nargin < 3
                kmin = length(ts_c);
            end
            consensus_search.validateParams(ts_c, sublen, kmin);
            obj = consensus_search(ts_c, sublen, kmin);
            sol =  obj.solve_opt(plotsol, inf);
            % default limit here of sqrt of subsequence length disallows weakly anti-correlated radii.
            % which would of course be ridiculous
        end
        
        function [sol,obj] = from_file_list(ts, sublen, kmin, plotsol)
            % Takes a sequence of time series and subsequence length where
            % each time series is a column in a larger matrix, the rows of
            % which are NaN padded to the length of the longest time series
            
            % This is a convenience function, but it's not that highly
            % tested on different datasets. It assumes a file list is
            % generated using matlab's dir function with whatever filtering
            % is required.
            
            [ts_c] = consensus_search.load_from_files(ts,'cols',1);
            if nargin < 4
                plotsol = false;
            end
            if nargin < 3
                kmin = length(ts_c);
            end
            consensus_search.validateParams(ts_c, sublen, kmin);
            obj = consensus_search(ts_c,sublen,kmin,plotsol);
            sol =  obj.solve_opt(plotsol, inf);
        end
        
        function [sol, obj] = from_nan_cat(ts, sublen, plotsol)
            % Take a time series comprised of multiple concatenated time series
            % This will treat any and all nan values as the end of a time
            % series

            if nargin < 2 || isempty(ts)
                error('invalid input');
            end
            f = find(isnan(ts));
            if isempty(f)
                error('requires more than one time series');
            elseif f(1) == 1
                error('input must begin with a valid time series');
            end
            start = zeros(length(f) + 1, 1);
            fin = zeros(length(f) + 1, 1);
            ind = 2;
            start(1) = 1;
            fin(1) = f(1) - 1;
            for i = 1 : length(f) - 1
                if f(i + 1) > f(i) + 1
                    start(ind) = f(i) + 1;
                    fin(ind) = f(i + 1) - 1;
                    ind = ind + 1;
                end
            end
            if f(end) < length(ts)
                start(ind) = f(end) + 1;
                fin(ind) = length(ts);
            end
            ts_c = cell(ind,1);
            for i = 1 : ind
                ts_c{i} = ts(start(i) : fin(i));
            end
            if nargin < 3
                plotsol = false;
            end
            kmin = length(ts_c);
            consensus_search.validateParams(ts_c, sublen, kmin);
            obj = consensus_search(ts_c, sublen, kmin);
            sol =  obj.solve_opt(plotsol, inf);
        end
        
        function ts = load_from_files(f, format, num)
            ts = cell(length(f), 1);
            if strcmp('rows',format)
                for i = 1 : length(f)
                    ts{i} = load(strcat(f(i).folder,filesep,f(i).name));
                    if size(ts{i},1) ~= 1
                        ts{i} = ts{i}(num, :);
                    end
                end
            elseif strcmp('cols',format)
                for i = 1 : length(f)
                    ts{i} = load(strcat(f(i).folder,filesep,f(i).name));
                    if size(ts{i}, 2) ~= 1
                        ts{i} = ts{i}(:, num);
                    end
                end
            else
                error('format unsupported, choose rows or cols');
            end
        end
        
        function m = min_len(ts)
            m = inf;
            for i = 1:length(ts)
                m = min(m, length(ts{i}));
            end
        end
        
        function validateParams(ts, sublen, kmin)
            if kmin == 0 || kmin > length(ts)
                error('minimum k is out of range');
            end
            if iscell(ts)
                m = inf;
                for i = 1:length(ts)
                    m = min(m,length(ts{i}));
                end
                if m < sublen
                    error('shortest time series is shorter than the desired subsequence length');
                end
            else
                error('Input must be a cell array');
            end
            if length(ts) < 2
                error('need at least 2 comparator time series');
            end
            for i = 1 : length(ts)
                if size(ts{i},1) < size(ts{i},2)
                    error('function accepts a cell array of column based time series');
                end
            end
        end
        
        function mx = maxlen_2dcell(dat)
            % hack function needed to find array size
            mx = zeros(size(dat,1),1);
            for i = 1 : size(dat,1)
                for j = 1 : size(dat,2)
                    mx(i) = max(mx, size(dat{i,j},1));
                end
            end
        end
        
        function not_implemented()
            error('Not implemented in the current framework');
        end
    end
end