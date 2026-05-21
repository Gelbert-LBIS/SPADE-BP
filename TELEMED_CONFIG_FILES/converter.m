%% make MAT form BIN
clear;
filename='S9_2_V2.bin';
[HEADER, CH_DATA]= importCH_RFData2MATLAB('./', filename);
HEADER.FPS=100;
REDUCED_DATA=squeeze(mean(CH_DATA,2));
mapped_data=zeros(64,size(REDUCED_DATA,1),size(REDUCED_DATA,3));
mapped_envelope=mapped_data;
for indx=1:64
    mapped_data(indx,:,:)=REDUCED_DATA(:,indx,:);
    mapped_envelope(indx,:,:)=abs(hilbert(mapped_data(indx,:,:)));
end
filename(end-3:end)='.mat';
filename=['TELEMED_' filename];
save(filename,'mapped_data','mapped_envelope','HEADER');


%% VIDEOs
ww = waitbar(0,'saving video');
writerObj = VideoWriter([filename '.avi']);
writerObj.FrameRate = HEADER.FPS;
open(writerObj);
for indx=1:size(mapped_data,3)
    BB = squeeze(mapped_data(:,:,indx));
    writeVideo(writerObj, mat2gray(imresize(BB,[1000,500])));
    waitbar(indx/size(mapped_data,3),ww);
end
close(writerObj); close(ww);

ww = waitbar(0,'saving video');
writerObj = VideoWriter([filename 'envelope.avi']);
writerObj.FrameRate = HEADER.FPS;
open(writerObj);
for indx=1:size(mapped_envelope,3)
    BB = squeeze(mapped_envelope(:,:,indx));
    writeVideo(writerObj, mat2gray(imresize(BB',[1000,500])));
    waitbar(indx/size(mapped_envelope,3),ww);
end
close(writerObj); close(ww);