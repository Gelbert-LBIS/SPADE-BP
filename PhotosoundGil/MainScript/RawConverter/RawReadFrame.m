function [success,trig_source,trig_time,event_number,data] = RawReadFrame(fid,num_channels,num_samples)
%READRAWPACKET Reads the ADC data frame from current RAW data file position

if ~feof(fid)
    trig_source = double(fread(fid,1,'int32'));
    trig_time = fread(fid,1,'double');
    event_number = double(fread(fid,1,'uint32'));
    data = fread(fid,[num_channels num_samples],'int16=>int16');
    success = 1;
else    
    event_number = 0;
    trig_source = 0;
    trig_time = 0;
    success = 0;
    data = [];
end

end

