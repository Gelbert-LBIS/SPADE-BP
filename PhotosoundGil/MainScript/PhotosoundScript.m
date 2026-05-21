%% Start System
if exist('dev','var')
    dev.Disconnect;
end
clc; close all; clear;
mypath = 'C:\Users\Gil\Desktop\MASTER\PhotosoundGil\x64\PhotoSoundClasses.dll';
addpath(genpath(pwd));
% Define the channel mapping
map = [10, 28, 22, 1, 31, 30, 25, 19, 7, 13, 32, 27, 26, 21, 16, 9, ...
    2, 14, 17, 4, 29, 24, 12, 5, 8, 11, 20, 3, 23, 18, 15, 6, ...
    63, 42, 57, 62, 48, 40, 51, 60, 54, 45, 58, 34, 61, 38, 36, 64, ...
    59, 53, 47, 52, 46, 41, 49, 55, 43, 37, 33, 39, 50, 35, 44, 56];

% Load the assembly
asm = NET.addAssembly(mypath);

% Create a DeviceManager instance
dev = PhotoSoundClasses.DeviceManager;

% Connect to the device
disp('Connecting...');
addlistener(dev, 'OnError', @onerror); % Handle connection errors
dev.Connect;

% Wait for connection to complete
while ~dev.Connected && ~dev.ConnectFailure
    pause(0.1);
end
if dev.Connected
    disp('✅ Successfully connected to device.');
end

%% settings

filename = 'yes';
% bin = 1   allways
RecordSettings.delay = 0;              % [s] after trigger
RecordSettings.LaserFreq = 100;        % [Hz]
RecordSettings.Duration = 10;          % [s] record total duration
RecordSettings.Depth = 10;             % [us] length of each sample

% ---- Configure Data Acquisition ----
dev.Capture.AutoUpdate = false; % Disable auto-update for batch setting

dev.Trigger.AutoUpdate = false;         % Disable auto-update for batch setting
dev.Trigger.ConnectToGenerator = true;  % Use internal generator as trigger source
dev.Trigger.GeneratorFrequency = RecordSettings.LaserFreq;  % Set generator frequency to 100 Hz
dev.Trigger.InvertedInputsMask = 0;     % Do not invert trigger inputs
dev.Trigger.EnabledInputsMask = 3;      % Enable input 1 (loopback)
dev.Trigger.InputsDelay = RecordSettings.delay;    % delay after trigger
dev.Trigger.InputsGuard = 0;            % trig input clock cycle anti noise
dev.Trigger.SlaveDelays(1)=0;           % hdmi thing
dev.Trigger.Configure;
dev.Trigger.TriggerOutputs(1).AutoUpdate = false;
dev.Trigger.TriggerOutputs(1).ConnectToGenerator = true;  % Output from generator
dev.Trigger.TriggerOutputs(1).PulseWidth = 10;            % Set pulse width (adjustable)
dev.Trigger.TriggerOutputs(1).SourcesMask = 0;            % Ensure correct source routing
dev.Trigger.TriggerOutputs(1).Invert = false;             % No signal inversion
dev.Trigger.TriggerOutputs(1).Enable = true;              % Enable trigger output
dev.Trigger.TriggerOutputs(1).Delay = 1;                  % No output delay
dev.Trigger.TriggerOutputs(1).Configure;                  % Apply settings

RecordSettings.fs = 40e6; % Fetch the maximum sampling rate
RecordSettings.ts = 1/RecordSettings.fs;
RecordSettings.samples_per_event = RecordSettings.fs * RecordSettings.Depth * 1e-6; % Samples in 10µs
trig_events = RecordSettings.LaserFreq * RecordSettings.Duration;

disp('📌 Data Acquisition Settings:');
fprintf(' - Sampling Frequency: %.2f Hz\n', RecordSettings.fs);
fprintf(' - Samples per 10µs event: %d\n', round(RecordSettings.samples_per_event));
fprintf(' - Total Trigger Events: %d\n', trig_events);

dev.Capture.DecimationFactor = 1; % Max sampling rate (no decimation)
dev.Capture.SamplesToCapture = round(RecordSettings.samples_per_event); % Capture 10us worth of samples
dev.Capture.EnabledAdcMask = 2^dev.MaxAdcPerDevice - 1; % Enable all ADCs
dev.Capture.EnabledAdcMask = 2^5+2^6; % zohar
dev.Capture.FramesPerPacket = 1; % Capture one frame per packet
dev.Capture.WaitTrigger = true; % Wait for a trigger event
dev.Capture.Configure; % Apply settings

% ---- Configure AC Coupling in AFE5818 ADC ----
if ~isempty(dev.AFE5818) % Check if AFE5818 is available
    dev.AFE5818.AutoUpdate = false;
    dev.AFE5818.Vca1.F5MHzLpfEnabled = false; % Enable LNA HPF for AC coupling % was true ♦
    dev.AFE5818.Vca1.HpfCutoffDivided = false; % Standard HPF settings
    dev.AFE5818.Configure;
    disp('✅ AC Coupling Enabled (LNA HPF Activated).');
else
    disp('⚠️ Warning: AFE5818 not detected. AC coupling may not be applied.');
end

if ~isempty(dev.AFE5832) % If AFE5832 is present
    dev.AFE5832.ConfiguredDevicesMask = 1;
    dev.AFE5832.ConfiguredAdcMask = 255;
    dev.AFE5832.Odd.DtgcGain=6;
    dev.AFE5832.Odd.EnableLnaHpf=false;
    dev.AFE5832.Odd.LowPowerMode = false;
    dev.AFE5832.Odd.EnableDtgcAttenuator=true;
    dev.AFE5832.Even.DtgcGain=6;
    dev.AFE5832.Even.EnableLnaHpf=false;
    dev.AFE5832.Even.LowPowerMode = false;
    dev.AFE5832.Even.EnableDtgcAttenuator=true;
    dev.AFE5832.AutoUpdate = false;
    dev.AFE5832.OddEqualEven=false;
    dev.AFE5832.Configure;
    disp('✅ AC Coupling Enabled for AFE5832 (HPF Activated).');
end

%% live
close all;
if dev.Connected==0
    error('❌ Device not connected');
end

image = [];
fig2 = figure('Name','recon');
fig2.Position = [19 80 745 610];
axes2=gca;
set(axes2,'nextplot','replacechildren','YDir','reverse');
fig = figure('Name','Plot data example');
fig.Position=[774 86 736 600];
axes1=gca;
set(axes1,'nextplot','replacechildren','YDir','reverse');

logger = dev.CreateLogger('RealTime',1);
logger.DevicesMask = 1;
logger.LimitLoggingTime = false;
logger.LimitNumFrames = false;
FrameBuffer = NET.createArray('System.Int16',dev.MaxSamplesToCapture*dev.MaxChannelsToCapture);
logger.StartLoggingToMemory(true);

reconobj = ZoharRecon(RecordSettings);

while isvalid(fig)
    [valid,channels,samples,frame_num,trig_time,trig_src,sample_rate] = logger.GetFrame(FrameBuffer,false);
    if valid
        tmpData = single(FrameBuffer);
        frame = reshape(tmpData(1:(channels*samples)),samples,channels);
        mapped = frame(:,map);
        mapped(1:80,:)=0;
        xlim(axes1,[0 channels])
        ylim(axes1,[0 samples])
        colormap(fig,'gray')
        xlabel(axes1,'Channels')
        ylabel(axes1,'Samples')
        if isempty(image)
            image = imagesc(axes1,'XData',1:channels,'YData',1:samples,'CData', mapped/max(max(mapped)), [-1 1]);
        else
            set(image,'CData',mapped/max(max(mapped)));
        end
    end
    pause(0.1);
    %reconobj.RunRecon(mapped,get(fig2,'CurrentAxes'));
end
close(fig2);


%% Block read

if dev.Connected==0
    error('❌ Device not connected');
end
% ---- Configure Data Logger for Non-Blocking Capture ----
logger = dev.CreateLogger('Matlab'); % Create a data logger instance
logger.DataFolder = pwd; % Save in the current directory
logger.DevicesMask = 1; % Enable all available devices
% Limit the capture to exactly 1000 trigger events
logger.MaxLoggedFrames = trig_events;
logger.LimitNumFrames = true;

%pause(2); % time to adjust position

for runs=1:1
    record(recorder); %ECG
    logger.StartLoggingToFile('TriggerCapture'); % Start logging asynchronously
    disp('🚀 Data acquisition started asynchronously...');
    pause(1);
    % Monitor the progress asynchronously
    while logger.Logging
        fprintf(' - Captured frames: %d / %d\n', logger.NumLoggedFrames, trig_events);
        pause(1); % Update every second
    end

    % Stop logging after capture is complete
    logger.StopLogging;
    stop(recorder); %ECG
    disp('✅ Data acquisition complete.');

    finalname = convertStringsToChars(append(string(datetime),' ',filename,'.mat'));
    finalname = strrep(finalname,':','-');
    finalnameecg = append(finalname,'.wav');
    %save ECG
    y = getaudiodata(recorder)';
    fileWriter = dsp.AudioFileWriter(finalnameecg,'FileFormat','WAV','SampleRate',ECG_Fs);
    fileWriter(y'); release(fileWriter);

    Raw2Mat('TriggerCapture.raw');
    load('TriggerCapture.mat');
    VOLTAGE(:,1:80,:)=0;

    mapped_data = VOLTAGE(map, :, :); % Rearrange channels using map
    mapped_data(:,1:80,:)=0; % why?
    save(finalname, 'mapped_data');
    delete 'TriggerCapture.raw';
    delete 'TriggerCapture.mat';
end

%imshow(mapped_data(:,:,100),[]);

%%
% Disconnect from the device
dev.Disconnect;
disp('🔌 Disconnected.');
clear;

%%
function onerror(~,event)
    disp(['❌ Error: ' char(event.Message)]);
end
