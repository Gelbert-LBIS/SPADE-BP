function ZoharMakeVideo(filename)
clc; close all;
load(filename);
filename(end-3:end)=[];

fig2 = figure('Name','recon');
fig2.Position = [19 80 745 610];
axes2=gca;
set(axes2,'nextplot','replacechildren','YDir','reverse');

pause(0.2);
RecordSettings.delay = 0;
RecordSettings.LaserFreq = 100;
RecordSettings.Duration = 10;
RecordSettings.Depth = 10;
RecordSettings.fs = 40e6; % Fetch the maximum sampling rate
RecordSettings.ts = 1/RecordSettings.fs;
RecordSettings.samples_per_event = RecordSettings.fs * RecordSettings.Depth * 1e-6;

reconobj = ZoharRecon(RecordSettings);
Frames=[];
for indx=1:size(mapped_data,3)
    reconobj.RunRecon(mapped_data(:,:,indx)',get(fig2,'CurrentAxes'));
    Frames{indx} = getframe(fig2);
end

writerObj = VideoWriter([filename '.avi']);
writerObj.FrameRate = RecordSettings.LaserFreq;
open(writerObj);
for i=1:length(Frames)
    writeVideo(writerObj, Frames{i}.cdata);
end
close(writerObj);
end