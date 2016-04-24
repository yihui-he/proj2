function main(directory,root,idx1,idx2)
    F_update = [1 0 1 0; 0 1 0 1; 0 0 1 0; 0 0 0 1];

    Npop_particles = 400;%4000;

    Xstd_rgb = .05;
    Xstd_pos = 25;
    Xstd_vec = 5;

    trgt = 1;
    objects=3;

    templates={'template2.mat','template3.mat','template4.mat'};
    %%
    if strcmp(root,'liptracking2')
        load(templates{1});
    elseif strcmp(root,'liptracking3')
        load(templates{2});
    elseif strcmp(root,'liptracking4')
        load(templates{3});      
    else
        disp('the root name must be liptracking*, I need this to indicate which template to use!');
    end
    %% particles
    for i=1:objects
        particles{i}=create_particles(y(i,:),x(i,:),Npop_particles);
        [objectx{i},objecty{i}] = snakeinterp(x(i,:),y(i,:),2,0.5);
        bound{i}=[mean(particles{i}(2,:)),...
        std(particles{i}(2,:)),...
        mean(particles{i}(1,:)),...
        std(particles{i}(1,:))];
    end


    outputVideo = VideoWriter([root,'.avi']);
    outputVideo.FrameRate = 24;
    open(outputVideo)

    resize = 1;
    
    start_frame=idx1;
    end_frame=idx2;
    
        %image processing
    dir=fullfile(directory,[root,'_',num2str(start_frame,'%05d'),'.jpg']);
    raw_img=imread(dir);
    raw_img=im2double(raw_img);
    img=rgb2hsv(raw_img);
    img=img(:,:,1);
    gray_img=rgb2gray(raw_img);
    MetricThreshold=900;
    points = detectSURFFeatures(gray_img,'MetricThreshold',MetricThreshold);    
    [features, points] = extractFeatures(gray_img, points);
    pointsPrevious = points;
    featuresPrevious = features;
    
        boundscale=2;
    %% processing
    for frame=start_frame:end_frame
        %image processing
        dir=fullfile(directory,[root,'_',num2str(frame,'%05d'),'.jpg']);
        raw_img=imread(dir);
        raw_img=im2double(raw_img);
        img=rgb2hsv(raw_img);
        img=img(:,:,1);
        gray_img=rgb2gray(raw_img);
        %thresh
%         img=img>.95;
        imshow(raw_img)
        %% detect features
        points = detectSURFFeatures(gray_img,'MetricThreshold',MetricThreshold);    
        [features, points] = extractFeatures(gray_img, points);
        % Unique matching
        [indexPairs,matchmetric] = ...
            matchFeatures(features, featuresPrevious,...
            'method', 'Approximate',...
            'Metric','SAD',...
            'MatchThreshold',100,'MaxRatio',1, 'Unique', true);
        % method Approximate ?
        %'MatchThreshold',.5
        %'MaxRatio',.8,
       
        matchedPoints = points(indexPairs(:,1), :);
        matchedPointsPrev = pointsPrevious(indexPairs(:,2), :);   
        hold on
        scatter(matchedPoints.Location(:,1),matchedPoints.Location(:,2));
        form = estimateGeometricTransform(matchedPoints, matchedPointsPrev,...
        'similarity',...
        'Confidence', 99.9,...
        'MaxNumTrials', 1000,...
        'MaxDistance',size(raw_img,1)/5.0);    
        
        hold on
        plot([size(raw_img,2)/2,size(raw_img,2)/2+form.T(3,1)],...
            size(raw_img,1)/2,'r*');
        disp(form.T)

        for i=1:objects
            % Forecasting
            particles{i} = update_particles(F_update, Xstd_pos, Xstd_vec, particles{i});

            % Calculating Log Likelihood
            L = calc_log_likelihood(Xstd_rgb, trgt, particles{i}(1:2, :), img);

            % Resampling
            particles{i} = resample_particles(particles{i}, L);
            % raw_img=img;
            if false
             meanx=mean(objectx{i}(:));
             meany=mean(objecty{i}(:));

             lam=1.5;
             objectx{i} =mean(particles{i}(2,:))+...
                lam*std(particles{i}(2,:))*(objectx{i}-meanx)/std(objectx{i}(:));  
             objecty{i} =mean(particles{i}(1,:))+...
                lam*std(particles{i}(1,:))*(objecty{i}-meany)/std(objecty{i}(:));

            [objectx{i},objecty{i}] = snakeinterp(objectx{i},objecty{i},2,.5);
            [objectx{i},objecty{i}]=snake(gray_img,objectx{i},objecty{i},3,1);
             
            end
        end
        bounding=zeros(size(matchedPoints.Location));
        for i=1:objects
                        % Showing Image
%              hold on
%              plot(particles{i}(2,:), particles{i}(1,:), '.')
%             hold off
%             snakedisp(objectx{i},objecty{i},'green')
            

%             bound=[mean(particles{i}(2,:)),...
%             std(particles{i}(2,:)),...
%             mean(particles{i}(1,:)),...
%             std(particles{i}(1,:))];
%             bounding=zeros(size(matchedPoints.Location));
%             bounding(:,1)=bounding(:,1)|((matchedPoints.Location(:,1)>bound(1)-boundscale*bound(2)) &...
%                 (matchedPoints.Location(:,1)<bound(1)+boundscale*bound(2)));
% 
% 
%             
%             bounding(:,2)=bounding(:,2)|((matchedPoints.Location(:,2)>bound(3)-boundscale*bound(4)) &...
%                 (matchedPoints.Location(:,2)<bound(2)+boundscale*bound(4)));
%         
%         idx=find(bounding(:,1)&bounding(:,2));
%         showPoints=matchedPoints(idx);
        
            
            
        end

        pointsPrevious = points;
        featuresPrevious = features;
        
        
        
        writeVideo(outputVideo,getframe);
    end
    close(outputVideo);

