function [format_version, num_frames, header_length,...
    frame_length, sample_rate, num_channels,num_samples,...
    num_boards, boards_mask, sel_adc_mask] = RawReadHeader(fid)
%READRAWHEADER reads file header data from RAW data file

fseek(fid,0,'bof');
format_version = fread(fid,1,'double');
num_frames = double(fread(fid,1,'int32'));
header_length = double(fread(fid,1,'int32'));
frame_length = double(fread(fid,1,'int32'));
sample_rate = double(fread(fid,1,'int32'));
num_channels = double(fread(fid,1,'int32'));
num_samples = double(fread(fid,1,'int32'));
num_boards = double(fread(fid,1,'int32'));
boards_mask = double(fread(fid,1,'uint32'));
sel_adc_mask = zeros(1,num_boards);
for n = 1:num_boards
    sel_adc_mask(n) = double(fread(fid,1,'uint32'));
end

end

