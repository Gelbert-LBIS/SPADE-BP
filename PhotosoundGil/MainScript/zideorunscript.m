% make video from zohar record

matFiles = dir('*normal.mat');
fileNames = {matFiles.name};
disp(fileNames);

for indx=1:length(fileNames)
    ZoharMakeVideo(fileNames{indx});
end