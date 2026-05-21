function Raw2Mat(filepath)
%RAW2MAT converts RAW data file to MAT format

fid = fopen(filepath,'r');
if fid == -1
    disp('Error: failed to open RAW data file');
    return;
end

[path,name,~] = fileparts(filepath);
mat_file = fullfile(path,[name '.mat']);

[format_version,num_frames,~,...
    ~,sample_rate,num_channels,num_samples,...
    num_boards,boards_mask,sel_adc_mask] = RawReadHeader(fid);

if (format_version ~= 2)
    disp('Error: invalid RAW data file format');
    fclose(fid);
    return;
end
    
tmp.NumBoards = num_boards;
tmp.SampleRate = sample_rate;
tmp.BoardsMask = boards_mask;
tmp.SelAdcMask = sel_adc_mask;

save(mat_file,'-v7.3','-struct','tmp');
h5create(mat_file, '/VOLTAGE', [num_channels num_samples num_frames], 'DataType', 'int16');

tmp = [];
tmp.TriggerTime = zeros(1,num_frames);
tmp.TriggerSource = zeros(1,num_frames);
tmp.EventNumber = zeros(1,num_frames);
k = 0;
fprintf('Converting: ');

tic
for n = 1:num_frames
    [success,tmp.TriggerSource(n),tmp.TriggerTime(n),tmp.EventNumber(n),data] = RawReadFrame(fid,num_channels,num_samples);
    if ~success
        fprintf('\nError: failed to read data packet\n');
        break;
    end
    h5write(mat_file,'/VOLTAGE',data,[1 1 n],[num_channels num_samples 1]);

    %plot(data(1,:));
    %drawnow;

    for m=1:k
        fprintf('\b');
    end
    k = fprintf('%d%%',round(n/num_frames*100));
end

save(mat_file,'-struct','tmp','-append');
fclose(fid);

fprintf('\nSuccess\n');
toc
