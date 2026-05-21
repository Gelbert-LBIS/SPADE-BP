classdef PicoScope5_RapidBlock < handle

    properties (Access = public)
        ps5000aEnuminfoX
        ps5000aStructsX
        ps5000aDeviceObj
        sigGenGroupObj
        triggerGroupObj
        rapidBlockGroupObj
        blockGroupObj
        nSegments
        nSamples
        nMaxSamples
        positions
    end

    methods (Access = public)
        function this = PicoScope5_RapidBlock() % assumed not connected!
            % Load configuration information
            PS5000aConfig;
            % save vars into class properties
            this.ps5000aEnuminfoX = ps5000aEnuminfo;
            this.ps5000aStructsX = ps5000aStructs;
            % Create a device object.
            this.ps5000aDeviceObj = icdevice('picotech_ps5000a_generic', '');
            % Connect device object to hardware.
            connect(this.ps5000aDeviceObj);
        end

        function setup(this,RecordSettings)
            %% Generator
            if RecordSettings.trigmode == 0  % internal
                this.sigGenGroupObj = get(this.ps5000aDeviceObj, 'Signalgenerator');
                this.sigGenGroupObj = this.sigGenGroupObj(1);
                invoke(this.sigGenGroupObj,'ps5000aSigGenSoftwareControl',0);  % disable generator
                % Set parameters (4000 mVpp, 0 mV offset, 100 Hz frequency)
                set(this.sigGenGroupObj, 'startFrequency', RecordSettings.LaserFreq);
                set(this.sigGenGroupObj, 'stopFrequency', RecordSettings.LaserFreq);
                set(this.sigGenGroupObj, 'offsetVoltage', 0.0);
                set(this.sigGenGroupObj, 'peakToPeakVoltage', 4000.0);
                % more settings
                waveType 			= this.ps5000aEnuminfoX.enPS5000AWaveType.PS5000A_SQUARE;
                increment 			= 0.0;  % Hz
                dwellTime 			= 0;    % seconds
                sweepType 			= this.ps5000aEnuminfoX.enPS5000ASweepType.PS5000A_DOWN;
                operation 			= this.ps5000aEnuminfoX.enPS5000AExtraOperations.PS5000A_ES_OFF;
                shots 				= 0;
                sweeps 				= 0;
                triggerType 		= this.ps5000aEnuminfoX.enPS5000ASigGenTrigType.PS5000A_SIGGEN_GATE_HIGH;
                triggerSource 		= this.ps5000aEnuminfoX.enPS5000ASigGenTrigSource.PS5000A_SIGGEN_SOFT_TRIG;
                extInThresholdMv 	= 0;
                invoke(this.sigGenGroupObj, 'setSigGenBuiltIn', waveType, increment, dwellTime, ...
                    sweepType, operation, shots, sweeps, triggerType, triggerSource, extInThresholdMv);
                fprintf('Internal Generator ON, SQUARE %d Hz 4V ptp\n',RecordSettings.LaserFreq);
            else % external, generator on DC for the gate
                this.sigGenGroupObj = get(this.ps5000aDeviceObj, 'Signalgenerator');
                this.sigGenGroupObj = this.sigGenGroupObj(1);
                invoke(this.sigGenGroupObj,'ps5000aSigGenSoftwareControl',0);   % disable generator
                % Set parameters +2V DC
                set(this.sigGenGroupObj, 'startFrequency', 1000.0); % any value over 0 is OK
                set(this.sigGenGroupObj, 'stopFrequency', 1000.0);
                set(this.sigGenGroupObj, 'offsetVoltage', 0.0);
                set(this.sigGenGroupObj, 'peakToPeakVoltage', 4000.0);
                % more settings
                increment 			= 0.0;  % Hz
                dwellTime 			= 0;    % seconds
                ARB = zeros(1,get(this.sigGenGroupObj, 'awgBufferSize')); ARB(1)=1;   
                sweepType 			= this.ps5000aEnuminfoX.enPS5000ASweepType.PS5000A_UP;
                operation 			= this.ps5000aEnuminfoX.enPS5000AExtraOperations.PS5000A_ES_OFF;
                indexMode 			= this.ps5000aEnuminfoX.enPS5000AIndexMode.PS5000A_SINGLE;
                shots 				= 1;
                sweeps 				= 0;
                triggerType 		= this.ps5000aEnuminfoX.enPS5000ASigGenTrigType.PS5000A_SIGGEN_RISING;
                triggerSource 		= this.ps5000aEnuminfoX.enPS5000ASigGenTrigSource.PS5000A_SIGGEN_SOFT_TRIG;
                extInThresholdMv 	= 0;
                invoke(this.sigGenGroupObj, 'setSigGenArbitrary', increment, dwellTime, ARB,  ...
                    sweepType, operation, indexMode, shots, sweeps, triggerType, triggerSource, extInThresholdMv);
                fprintf('Internal Generator ON, 2V DC\n');
            end
            %% Trigger
            this.triggerGroupObj = get(this.ps5000aDeviceObj, 'Trigger');
            this.triggerGroupObj = this.triggerGroupObj(1);
            % wait indefinitely for a trigger event
            set(this.triggerGroupObj, 'autoTriggerMs', 0);
            % Channel     : 4 (this.ps5000aEnuminfoX.enPS5000AChannel.PS5000A_EXTERNAL)
            % Threshold   : 500 mV
            % Direction   : 2 (this.ps5000aEnuminfoX.enPS5000AThresholdDirection.PS5000A_RISING)
            % delay after trigger in samples.
            set(this.triggerGroupObj,'delay',round(RecordSettings.delay/RecordSettings.ts));
            invoke(this.triggerGroupObj, 'setSimpleTrigger', 4, RecordSettings.TrigLVL, 2);
            fprintf('Trigger source = Ext , rise %d mV, \n',RecordSettings.TrigLVL);
            %% CHANNELS
            % Channels       : 0,1,2,3 (this.ps5000aEnuminfoX.enPS5000AChannel)
            % Enabled        : 1,0 (PicoConstants.TRUE, PicoConstants.FALSE)
            % Type           : 0 (this.ps5000aEnuminfoX.enPS5000ACoupling.PS5000A_AC)
            % Range          : 6 (this.ps5000aEnuminfoX.enPS5000ARange.PS5000A_1V)
            % Analog Offset  : 0.0 V
            resultingRange = (~RecordSettings.Coupling)*RecordSettings.Vrange_AC+RecordSettings.Coupling*RecordSettings.Vrange_DC;
            switch RecordSettings.numCH
                case 1
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 0, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 0, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 0, RecordSettings.Coupling, resultingRange, 0.0);
                case 2
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 1, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 0, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 0, RecordSettings.Coupling, resultingRange, 0.0);
                case -2
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, 0, RecordSettings.Vrange_AC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 0, 0, RecordSettings.Vrange_AC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 0, 1, RecordSettings.Vrange_DC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 1, 1, RecordSettings.Vrange_DC, 0.0);
                case 3
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, 0, RecordSettings.Vrange_AC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 0, 0, RecordSettings.Vrange_AC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 1, 1, RecordSettings.Vrange_DC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 1, 1, RecordSettings.Vrange_DC, 0.0);
                case 4
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 1, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 1, RecordSettings.Coupling, resultingRange, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 1, RecordSettings.Coupling, resultingRange, 0.0);
                case -4 % ACDC
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, 0, RecordSettings.Vrange_AC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 1, 1, RecordSettings.Vrange_DC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 1, 0, RecordSettings.Vrange_AC, 0.0);
                    invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 1, 1, RecordSettings.Vrange_DC, 0.0);
                otherwise
            end
            %% Analog BW limiter 20 / 200 MHz
            invoke(this.ps5000aDeviceObj, 'ps5000aSetBandwidthFilter', 0, RecordSettings.BWlim20MHz);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetBandwidthFilter', 1, RecordSettings.BWlim20MHz);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetBandwidthFilter', 2, RecordSettings.BWlim20MHz);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetBandwidthFilter', 3, RecordSettings.BWlim20MHz);
            %% Resolution
            invoke(this.ps5000aDeviceObj, 'ps5000aSetDeviceResolution', RecordSettings.BitDepth);
            %% Memory
            this.nSegments = RecordSettings.Duration*RecordSettings.LaserFreq;
            if (RecordSettings.ENABLE_STAGE) && (RecordSettings.bin>1) % descrete mode
                this.nSegments = RecordSettings.bin;
            end
            [~, this.nMaxSamples] = invoke(this.ps5000aDeviceObj, 'ps5000aMemorySegments', this.nSegments);
            this.nSamples = round(RecordSettings.Depth*1e-6 / RecordSettings.ts);
            % Set number of samples to collect pre- and post-trigger. Ensure that the
            % total does not exceeed nMaxSamples above.
            if this.nMaxSamples<this.nSamples
                RecordSettings.speaker.Speak('ERROR buffer too small - reduce Fs or duration');
                error('buffer too small - reduce Fs or duration');
            end
            set(this.ps5000aDeviceObj, 'numPreTriggerSamples', 0);
            set(this.ps5000aDeviceObj, 'numPostTriggerSamples', this.nSamples);
            fprintf('set %d memory segments, each at length %d\n',this.nSegments,this.nSamples);
            %% Time
            switch RecordSettings.BitDepth
                case 15
                    if RecordSettings.ts == 8e-9
                        timebaseIndex = log2(RecordSettings.ts*1e9);
                    else
                        timebaseIndex = 2+round(RecordSettings.ts*125e6);
                    end
                case 14
                    if RecordSettings.ts == 8e-9
                        timebaseIndex = log2(RecordSettings.ts*1e9);
                    else
                        timebaseIndex = 2+round(RecordSettings.ts*125e6);
                    end
                case 12
                    if RecordSettings.ts < 16e-9
                        timebaseIndex = 1+round(log2(RecordSettings.ts*0.5e9));
                    else
                        timebaseIndex = 3+round(RecordSettings.ts*62.5e6);
                    end
                case 8
                    if RecordSettings.ts < 8e-9
                        timebaseIndex = round(log2(RecordSettings.ts*1e9));
                    else
                        timebaseIndex = 2+round(RecordSettings.ts*125e6);
                    end
                otherwise
            end
            [~, timeIntervalns, ~] = invoke(this.ps5000aDeviceObj,'ps5000aGetTimebase2', timebaseIndex, 0);
            if round(timeIntervalns*1e-9 - RecordSettings.ts)
                RecordSettings.speaker.Speak('ERROR MISSMATCH of sampling rate');
                error('MISSMATCH of sampling rate');
            end
            fprintf('Timebase index: %d, sampling interval: %d ns, sampling frequency: %d MHz\n', timebaseIndex, timeIntervalns, 1e3/timeIntervalns);
            set(this.ps5000aDeviceObj, 'timebase', timebaseIndex);
            %% Rapid block final settings
            this.rapidBlockGroupObj = get(this.ps5000aDeviceObj, 'Rapidblock');
            this.rapidBlockGroupObj = this.rapidBlockGroupObj(1);
            this.blockGroupObj = get(this.ps5000aDeviceObj, 'Block');
            this.blockGroupObj = this.blockGroupObj(1);
            % Set number of captures - can be less than or equal to the
            % number of segments
            invoke(this.rapidBlockGroupObj, 'ps5000aSetNoOfCaptures', this.nSegments);
            %% Stages config
            if RecordSettings.ENABLE_STAGE
                axes = struct('X', 1, 'Y', 2, 'Z', 3);
                currPos = RecordSettings.stages.getPosition;
                axNum = axes.(RecordSettings.axScan);
                initPos = currPos(axNum);
                maxPos = initPos + RecordSettings.span;
                minPos = initPos - RecordSettings.span;
                range = [150 150 250]; % Z is limited to avoid hitting the tub
                vel = RecordSettings.stride * RecordSettings.LaserFreq;
                assert(initPos <= range(axNum), 'Initial position out of range');
                assert((maxPos < range(axNum)) || (minPos > 0), 'Span out of range for initial position');
                assert(vel <= RecordSettings.stages.getMaxVelocityAx(RecordSettings.axScan), "Scan velocity too high, try reducing the sampling frequency or decreasing the stride");
                trigParams.dest = maxPos;
                trigParams.trigPos = minPos;
                RecordSettings.stages.setTrigger(RecordSettings.axScan, 1, 'singlePosition', trigParams, 1);
                if RecordSettings.bin > 1 % descrete mode
                    this.positions = minPos:RecordSettings.stride:maxPos;
                end
            end
        end

        function [times, data ,recorder, elapsed] = read(this,RecordSettings,recorder)
            if RecordSettings.ENABLE_STAGE
                currPos = RecordSettings.stages.getPosition;
                axes = struct('X', 1, 'Y', 2, 'Z', 3);
                axNum = axes.(RecordSettings.axScan);
                vel = RecordSettings.stride * RecordSettings.LaserFreq;
                RecordSettings.stages.setVelocity(RecordSettings.axScan, 1);
                RecordSettings.stages.moveAbsAx(RecordSettings.axScan, currPos(axNum) - RecordSettings.span);
                RecordSettings.stages.setVelocity(RecordSettings.axScan, vel);
                if RecordSettings.bin > 1 % descrete mode
                    RecordSettings.stages.setVelocity(RecordSettings.axScan, 1);
                    invoke(this.sigGenGroupObj,'ps5000aSigGenSoftwareControl',1); % enable generator
                    downsamplingRatio       = 1;
                    downsamplingRatioMode   = this.ps5000aEnuminfoX.enPS5000ARatioMode.PS5000A_RATIO_MODE_NONE;
                    % no ECG, single channel only.
                    record(recorder); stop(recorder);
                    data=zeros(length(this.positions),this.nSegments,this.nSamples);
                    f = waitbar(0,'Discrete scanning');
                    for indx=1:length(this.positions)
                        waitbar(indx/length(this.positions),f);
                        RecordSettings.stages.moveAbsAx(RecordSettings.axScan, this.positions(indx));
                        pause(0.3); %reduce post motion jittering
                        invoke(this.blockGroupObj, 'runBlock', 0);  % Capture the blocks of data begin at seg 0 (blocking function)
                        [numSamples, overflow, chA] = invoke(this.rapidBlockGroupObj, 'getRapidBlockData', this.nSegments, ...
                            downsamplingRatio, downsamplingRatioMode);
                        data(indx,:,:)=chA';
                        if sum(overflow(:))
                            warning('Scope 1 Over voltage! adjust channel scale');
                            RecordSettings.speaker.Speak('Scope 1 Over voltage! adjust channel scale');
                        end
                    end
                    close(f);
                    center=round(0.5*length(this.positions));
                    RecordSettings.stages.moveAbsAx(RecordSettings.axScan, this.positions(center));
                    times = RecordSettings.delay + double(RecordSettings.ts) * downsamplingRatio * double(0:numSamples - 1);
                    invoke(this.sigGenGroupObj,'ps5000aSigGenSoftwareControl',0); % disable generator
                    if RecordSettings.trigmode % ext trig
                        ARB = zeros(1,get(this.sigGenGroupObj, 'awgBufferSize')); ARB(1)=1;
                        invoke(this.sigGenGroupObj, 'setSigGenOff');
                        invoke(this.sigGenGroupObj, 'setSigGenArbitrary',0,0,ARB,0,0,0,1,0,0,4,0);
                    end
                    elapsed=0; % gonna show a warning
                    return;
                end
            end
            scopeready=false;
            record(recorder); % record ecg start NB
            invoke(this.blockGroupObj, 'ps5000aRunBlock', 0); % Capture the blocks of data begin at seg 0 (non-blocking function)
            % invoke(this.blockGroupObj, 'runBlock', 0); % Capture the blocks of data begin at seg 0 (blocking function)
            pause(0.5); tic;
            if RecordSettings.ENABLE_STAGE
                RecordSettings.stages.startRoutine(RecordSettings.axScan);
            end
            invoke(this.sigGenGroupObj,'ps5000aSigGenSoftwareControl',1); % enable generator
            while scopeready == false
                [~, scopeready] = invoke(this.blockGroupObj, 'ps5000aIsReady');
                pause(0.01);
            end
            invoke(this.sigGenGroupObj,'ps5000aSigGenSoftwareControl',0); % disable generator
            if RecordSettings.trigmode % ext trig
                ARB = zeros(1,get(this.sigGenGroupObj, 'awgBufferSize')); ARB(1)=1;
                invoke(this.sigGenGroupObj, 'setSigGenOff');
                invoke(this.sigGenGroupObj, 'setSigGenArbitrary',0,0,ARB,0,0,0,1,0,0,4,0);
            end
            stop(recorder);  % record ecg stop NB
            elapsed=toc;

            % Retrieve rapid block data values:
            downsamplingRatio       = 1;
            downsamplingRatioMode   = this.ps5000aEnuminfoX.enPS5000ARatioMode.PS5000A_RATIO_MODE_NONE;
            switch RecordSettings.numCH
                case 1
                    [numSamples, overflow, chA] = invoke(this.rapidBlockGroupObj, 'getRapidBlockData', this.nSegments, ...
                        downsamplingRatio, downsamplingRatioMode);
                    data=chA';
                case -2
                    [numSamples, overflow, chA, ~, ~, chD] = invoke(this.rapidBlockGroupObj, 'getRapidBlockData', this.nSegments, ...
                        downsamplingRatio, downsamplingRatioMode);
                    data=cat(3,chA',0.1*chD'); % ch D in mmHg now
                    if mean(chD,'all')<40
                        warning('NOVA DID NOT RECORDE!');
                        RecordSettings.speaker.Speak('NOVA DID NOT RECORDE!');
                    end
                case 3
                    [numSamples, overflow, chA, ~, chC, chD] = invoke(this.rapidBlockGroupObj, 'getRapidBlockData', this.nSegments, ...
                        downsamplingRatio, downsamplingRatioMode);
                    data=cat(3,chA',0.1*chC',0.1*chD'); % ch C & D in mmHg now
                    if (mean(chD,'all')<40) || (mean(chC,'all')<40)
                        warning('NOVA DID NOT RECORDE!');
                        RecordSettings.speaker.Speak('NOVA DID NOT RECORDE!');
                    end
                case 2
                    [numSamples, overflow, chA, chB] = invoke(this.rapidBlockGroupObj, 'getRapidBlockData', this.nSegments, ...
                        downsamplingRatio, downsamplingRatioMode);
                    data=cat(3,chA',chB');
                case {4,-4}
                    [numSamples, overflow, chA, chB, chC, chD] = invoke(this.rapidBlockGroupObj, 'getRapidBlockData', this.nSegments, ...
                        downsamplingRatio, downsamplingRatioMode);
                    data=cat(3,chA',chB',chC',chD');
                    % 4  : sen1-1 sen1-2 sen2-1 sen2-1
                    % -4 : sen1-1AC sen1-1DC sen1-2AC sen1-2DC
                otherwise
            end
            if RecordSettings.ENABLE_STAGE
                pause(1);
                currPos = RecordSettings.stages.getPosition;
                axes = struct('X', 1, 'Y', 2, 'Z', 3);
                axNum = axes.(RecordSettings.axScan);
                RecordSettings.stages.setVelocity(RecordSettings.axScan, 1);
                RecordSettings.stages.moveAbsAx(RecordSettings.axScan, currPos(axNum) - RecordSettings.span);
            end
            if sum(overflow(:))
                warning('Scope 1 Over voltage! adjust channel scale');
                RecordSettings.speaker.Speak('Scope 1 Over voltage! adjust channel scale');
            end
            [~, numCaptures] = invoke(this.rapidBlockGroupObj, 'ps5000aGetNoOfCaptures');
            if abs(numCaptures-this.nSegments)
                RecordSettings.speaker.Speak('ERROR MISSMATCH of segments scope 1');
                error('MISSMATCH of segments scope 1');
            end
            times = RecordSettings.delay + double(RecordSettings.ts) * downsamplingRatio * double(0:numSamples - 1);

            % segment time stamp - just to check proper trigger operation
            if 0
                for k = numCaptures:-1:1
                    triggerInfo(k) = this.ps5000aStructsX.tPS5000ATriggerInfo.members;
                    triggerInfo(k).status=0;
                    triggerInfo(k).segmentIndex=0;
                    triggerInfo(k).triggerIndex=0;
                    triggerInfo(k).triggerTime=0;
                    triggerInfo(k).timeUnits=0;
                    triggerInfo(k).reserved0=0;
                    triggerInfo(k).timeStampCounter=0;
                end
                [~, triggerInfo] = invoke(this.rapidBlockGroupObj, 'getTriggerInfoBulk', triggerInfo, 0, numCaptures-1);
                Trigtimes=vertcat(triggerInfo.timeStampCounter)*RecordSettings.ts; Trigtimes=Trigtimes-Trigtimes(1);
                delta=Trigtimes-circshift(Trigtimes,1); delta(1)=[];
            end
        end

        function delete(this)
            try
                invoke(this.sigGenGroupObj, 'setSigGenOff');
                fprintf('Internal Generator OFF\n');
            catch
                warning('Generator stopping failed');            
            end
            try
                invoke(this.ps5000aDeviceObj, 'ps5000aStop');
                disconnect(this.ps5000aDeviceObj);
                delete(this.ps5000aDeviceObj);
            catch
                warning('PICO5 was not connected');
            end
        end
    end
end