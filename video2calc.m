function video2calc(varargin)
    % Defaults
    videoPath = "";
    outName   = "VIDEO";
    chunkSize = "30000";
    fpsOut    = 15;

    if nargin < 1
        error("Usage: video2calc <video> [-o name] [-c chunksize] [-fps fps]");
    end

    % Flag arguments
    videoPath = varargin{1};
    i = 2;
    vid = VideoReader(videoPath);
    fpsIn = vid.FrameRate;

    while i <= nargin
        arg = lower(string(varargin{i}));

        switch arg
            case "-o"
                outName = string(varargin{i+1});
                i = i + 2;

            case "-c"
                chunkSize = string(varargin{i+1});
                i = i + 2;

            case "-fps"
                fpsOut = str2double(varargin{i+1});
                i = i + 2;
                if fpsOut > fpsIn
                    error("Target fps must be less than source");
                end

            otherwise
                error("Unknown option: %s", arg);
        end
    end
   

%FPS sampling
    vid.CurrentTime = 0;
    dt = 1 / fpsOut;
    t = 0;
    while t <= vid.Duration
        vid.CurrentTime = t;
        I = readFrame(vid);
        J = imresize(I, [64, 96]);
        gray = J(:,:,1)*.299 + J(:,:,2)*.587 + J(:,:,3)*.114;
        gray = uint8(gray);
        gray = imadjust(gray);
        
        bayer4 = [ ...
             0  8  2 10;
            12  4 14  6;
             3 11  1  9;
            15  7 13  5];
        bw = zeros(64,96);
        for i = 1:96
            for j = 1:64
                threshold = (bayer4(mod(j-1,4)+1, mod(i-1,4)+1) + 0.5) * 16;
                bw(j,i) = gray(j,i) > threshold;
            end
        end 
    
        bw = ~bw;
        pixels = bw.';     
        pixels = pixels(:);
        if t == 0
            writematrix(pixels', 'videodata.txt');
            prevFrame = pixels;
        else
            deltaNext = xor(pixels, prevFrame);
                writematrix(deltaNext', 'videodata.txt', 'WriteMode','append');
                prevFrame = pixels;
        end
        t = t + dt;
    end 
    cmd = sprintf('java Compress %s %s', outName, chunkSize);
    system(cmd);
end