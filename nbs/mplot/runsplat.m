function [result, time_splat] = runsplat(subsequence_length, timeseriesA, timeseriesB, multiresolution, calibration, display_mplot, piecewise, patch_size)

    if isempty(timeseriesA)
        %% Toy set
        test_sine =([randn(1,600)/5 sin(0:0.1:9) randn(1,800)/5 sin(0:0.1:9) randn(1,900)/5  sin(0:0.05:9) randn(1,800)/5  ]);
        test_sine = test_sine+rand(size(test_sine))/10; %% add a little bit of noise

        x = test_sine;
        
        %% Setting the parameters
        subsequence_length = 100;
        timeseriesA = cat(1,transpose(x),transpose(x),transpose(x),transpose(x),transpose(x),transpose(x),transpose(x),transpose(x),transpose(x));
    end 
    if isempty(timeseriesB)
        timeseriesB = nan; %If running AB-join
    end

        %SPLAT
        if isempty(multiresolution)
            multiresolution = 0;
        end
        if isempty(calibration)
            calibration = 0;
        end
        if isempty(display_mplot)
            display_mplot = 1;
        end
        if isempty(piecewise)
        
            piecewise = 1;
        end
        if isempty(patch_size)
            patch_size = 5000;
        end

    if piecewise
        tic;
        disp("opción piecewiseSplat")
        disp(piecewise)
        %[lastpatch] = piecewiseSplat(timeseriesA, subsequence_length, patch_size, display_mplot, timeseriesB);
         [result] = piecewiseSplat(timeseriesA, subsequence_length, patch_size, display_mplot, timeseriesB);
        time_splat = toc;
    else
        tic;
        disp("opción Splat")
        disp(display_mplot)
        %[splat] = SPLAT(timeseriesA, subsequence_length, timeseriesB, display_mplot, multiresolution, calibration);
        [result] = SPLAT(timeseriesA, subsequence_length, timeseriesB, display_mplot, multiresolution, calibration);
        time_splat = toc;
        %disp("result ~")
        %disp(length(result))
        %disp("time: ")
        %disp(time_splat)
    end
end