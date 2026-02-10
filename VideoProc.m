clear
vid = VideoReader('Videos/boat.mp4');
frame = 0;
while hasFrame(vid)
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
    if frame == 0
        imshow(~bw);
        writematrix(pixels', 'videodata.txt');
        prevFrame = pixels;
    else
        deltaNext = xor(pixels, prevFrame);
        if mod(frame, 2) == 0
        writematrix(deltaNext', 'videodata.txt', 'WriteMode','append');
        prevFrame = pixels;
        end
    end
    frame = frame + 1;
end