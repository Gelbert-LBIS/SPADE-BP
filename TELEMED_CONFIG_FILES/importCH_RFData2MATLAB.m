function [HEADER, CH_DATA]= importCH_RFData2MATLAB(DIR, FILENAME)
%% Function which allows to import Channel RF data and other data acquisition parameters needed for imaging 

%% IN:
% FILENAME - *.bin binary file recorded using ArtUS device and Artus_RF_Data_Control II software
% DIR - directory of the file

%% OUT:
% HEADER - header containing information nedeed for B mode image
% reconstruction from recoded channel data and some data acquisition parameters 
% HEADER.flag - flag which is equal to 1 if tag Scannned beams position and angle information exists (exists only not for custom delays)
% HEADER.sampling_period - channel data sampling period in [ns]
% HEADER.BeamsPerFrame - number of scanned beams per frame 
% HEADER.SamplesPerChannel - number of samples for each channel
% HEADER.ChannelsPerBeam - number of active channels per beam
% HEADER.SampleBitCount - data bits
% HEADER.FrameSize - size of single channel data frame (in bytes)
% HEADER.SubFramesNumber - number of subframes (not 0 for B Compound mode)
% HEADER.SubBeamsNumber - The number of beams that are used to calculate final beam. 
% This structure member is used when several beams are captured from the same position with different scanning set. 
% For example - in multibeam scanning mode, when several beams with different 
% focus settings are captured from the same position.
% HEADER.SubFrameIndex - subframe index of first recorded subrframe (For example, if 
% compound frames number is equal to 5 and subframe index is equal to 3 that means 
% that sequence of recorded subframes starts from the 4th frame.)
% HEADER.number_of_frames_to_record - number of channel data frames in a
% recorded file
% HEADER.aperture_size - maximal possible channels number (64 for ArtUs system)
% HEADER.mask_of_active_channels - mask of zeros and ones indicating which
% channels are active
% HEADER.index_of_aperture - aperture index (0 – BeamsPerFrame-1),
% HEADER.aperture_pos_x - x coordinate of each aperture position relative
% to probes center (in um)
% HEADER.aperture_pos_y - y coordinate of each aperture position relative
% to probes center (in um)
% HEADER.angle_aperture - angle of aperture in radians 
% HEADER.dummy_ch - if the channels are outside the aperture, what is actual 
% for beams closer to probe edge, the number is negative and number of channels 
% are declared, for example if value is equal to -32, that means that for 
% first 32 channels of the beam there is no channel RF Data
% HEADER.chanel_idx - number of channel in aperture chanel_idx (0 – ChannelsPerBeam – 1),
% HEADER.channel_pos_x - x coordinate of each channel position relative
% to probes center (in um)
% HEADER.channel_pos_y - y coordinate of each channel position relative
% to probes center (in um)
% HEADER.angle_elements - angle of each channel in radians 
% HEADER.start_indices - array contains excitation pulse beginning indices 
% for each channel which were active in transmission of ultrasound. 
% HEADER.end_indices - array contains excitation pulse end indices 
% for each channel which were active in transmission of ultrasound. 
% HEADER.Start_Depth - Start depth index in samples for the RF data window (available if scanning mode mode is not custom).
% HEADER.beam_position_x - x coordinate of each beam position relative to
% probes center (in um) (available if scanning mode mode is not custom).
% HEADER.beam_position_y - y coordinate of each beam position relative to
% probes center (in um) (available if scanning mode mode is not custom).
% HEADER.beam_angle - angle of each beam relative to probes center (in radians) (available if scanning mode mode is not custom).   
% CH_DATA - Channel RF Data of N recorded frames. The data in the buffer are arranged as follows: 
% SamplesPerChannel × ChannelsPerBeam × BeamsPerFrame × number_of_frames_to_record.

fileID = fopen([DIR,FILENAME]);
file_type = (fread(fileID,6,'*char'))';
if (strcmp(file_type, 'CH0001'))
HEADER.flag = fread(fileID,1,'int32')
HEADER.sampling_period = fread(fileID,1,'int32'); 
HEADER.BeamsPerFrame = fread(fileID,1,'int32');    
HEADER.SamplesPerChannel = fread(fileID,1,'int32');
HEADER.ChannelsPerBeam = fread(fileID,1,'int32');
HEADER.SampleBitCount = fread(fileID,1,'int32');
HEADER.FrameSize = fread(fileID,1,'int32');
HEADER.SubFramesNumber = fread(fileID,1,'int32');
HEADER.SubBeamsNumber = fread(fileID,1,'int32');
HEADER.SubFrameIndex = fread(fileID,1,'int32');
HEADER.number_of_frames_to_record = fread(fileID,1,'int32');
HEADER.aperture_size = fread(fileID,1,'int32'); %% maximal possible channels number
HEADER.mask_of_active_channels = fread(fileID,HEADER.aperture_size,'int32');
index_and_position_of_aperture_and_dummy_channels = fread(fileID,HEADER.BeamsPerFrame*5,'int32');
HEADER.index_of_aperture = index_and_position_of_aperture_and_dummy_channels(1:5:end);
HEADER.aperture_pos_x = index_and_position_of_aperture_and_dummy_channels(2:5:end)
HEADER.aperture_pos_y = index_and_position_of_aperture_and_dummy_channels(3:5:end)
HEADER.angle_aperture = index_and_position_of_aperture_and_dummy_channels(4:5:end)/1000000
HEADER.dummy_ch = index_and_position_of_aperture_and_dummy_channels(5:5:end)
position_of_channels = fread(fileID,HEADER.ChannelsPerBeam*4,'int32');
HEADER.chanel_idx = position_of_channels(1:4:end);
HEADER.channel_pos_x = position_of_channels(2:4:end);
HEADER.channel_pos_y = position_of_channels(3:4:end);
HEADER.angle_elements = position_of_channels(4:4:end)/1000000;
start_end_indices_channels = fread(fileID,HEADER.ChannelsPerBeam*2*HEADER.BeamsPerFrame*HEADER.SubBeamsNumber*HEADER.SubFramesNumber,'int32');
HEADER.start_indices = start_end_indices_channels(1:2:end);
HEADER.end_indices = start_end_indices_channels(2:2:end);

%% Scannned beams position and angle information (if available if flag == 1 and mode not custom)
if (HEADER.flag == 1)
 HEADER.Start_Depth = fread(fileID,1,'int32');
 beam_postion_and_orientation = fread(fileID,HEADER.BeamsPerFrame*HEADER.SubFramesNumber*3,'int32');
 HEADER.beam_position_x = beam_postion_and_orientation(1:3:end)
 HEADER.beam_position_y = beam_postion_and_orientation(2:3:end)
 HEADER.beam_angle = beam_postion_and_orientation(3:3:end)/1000000   
 HEADER.custom_mode = 0;
else
 HEADER.custom_mode = 1;   
end    

%% Channel DATA
channel_data = fread(fileID, HEADER.number_of_frames_to_record*HEADER.FrameSize/2,'int16');
CH_DATA = reshape(channel_data,[HEADER.SamplesPerChannel,HEADER.ChannelsPerBeam,HEADER.BeamsPerFrame,HEADER.number_of_frames_to_record]);

else
errordlg('Wrong structure of the file');
end
fclose(fileID);


