classdef PicoScope5_Block < handle

    properties (Access = public)
        ps5000aEnuminfoX
        ps5000aDeviceObj
        triggerGroupObj
        blockGroupObj
        ts
        nSamples
    end

    methods (Access = public)
        function this = PicoScope5_Block()
            % Load configuration information
            PS5000aConfig;
            % save vars into class properties
            this.ps5000aEnuminfoX = ps5000aEnuminfo;
            % Create a device object.
            this.ps5000aDeviceObj = icdevice('picotech_ps5000a_generic', '');
            % Connect device object to hardware.
            connect(this.ps5000aDeviceObj);
        end

        function setup(this,ts,durationMS)
            %% supress console prints
            set(this.ps5000aDeviceObj, 'displayOutput', 0);
            %% Trigger
            this.triggerGroupObj = get(this.ps5000aDeviceObj, 'Trigger');
            this.triggerGroupObj = this.triggerGroupObj(1);
            invoke(this.triggerGroupObj, 'setTriggerOff');
            %% CHANNELS
            % Channels       : 0,1,2,3 (this.ps5000aEnuminfoX.enPS5000AChannel)
            % Enabled        : 1,0 (PicoConstants.TRUE, PicoConstants.FALSE)
            % Type           : 1 (this.ps5000aEnuminfoX.enPS5000ACoupling.PS5000A_DC)
            % Range          : 7 (this.ps5000aEnuminfoX.enPS5000ARange.PS5000A_2V)
            %                : 4 (this.ps5000aEnuminfoX.enPS5000ARange.PS5000A_200MV)
            Range = 5;
            % Analog Offset  : 0.0 V
            invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, 1, Range, 0.0);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 1, 1, Range, 0.0);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 1, 1, Range, 0.0);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 1, 1, Range, 0.0);
			%% Analog BW limiter 20 / 200 MHz
            invoke(this.ps5000aDeviceObj, 'ps5000aSetBandwidthFilter', 0, 1);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetBandwidthFilter', 1, 1);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetBandwidthFilter', 2, 1);
            invoke(this.ps5000aDeviceObj, 'ps5000aSetBandwidthFilter', 3, 1);
            %% Resolution
            invoke(this.ps5000aDeviceObj, 'ps5000aSetDeviceResolution', 12); %  bit
            %% Time
            this.ts = ts;
            if this.ts < 16e-9
                timebaseIndex = 1+ceil(log2(this.ts*0.5e9));
            else
                timebaseIndex = 3+ceil(this.ts*62.5e6);
            end
            [~, timeIntervalns, nMaxSamples] = invoke(this.ps5000aDeviceObj,'ps5000aGetTimebase2', timebaseIndex, 0);
            set(this.ps5000aDeviceObj, 'timebase', timebaseIndex);
            fprintf('Timebase index: %d, sampling interval: %f ms, sampling frequency: %d KHz\n', timebaseIndex, timeIntervalns*1e-6, 1e6/timeIntervalns);
            this.ts = double(timeIntervalns*1e-9);
            %% block settings
            this.blockGroupObj = get(this.ps5000aDeviceObj, 'Block');
            this.blockGroupObj = this.blockGroupObj(1);
            this.nSamples = round(durationMS*1e-3 / this.ts);
            if nMaxSamples<this.nSamples
                error('buffer too small - reduce Fs or duration');
            end
            set(this.ps5000aDeviceObj, 'numPreTriggerSamples', 0);
            set(this.ps5000aDeviceObj, 'numPostTriggerSamples', this.nSamples);
        end

        function [times, data, Bmean, Dmean] = read(this)
            invoke(this.blockGroupObj, 'runBlock', 0); % Capture the block
            % Retrieve block data values:
            startIndex              = 0;
            segmentIndex            = 0;
            downsamplingRatio       = 1;
            downsamplingRatioMode   = this.ps5000aEnuminfoX.enPS5000ARatioMode.PS5000A_RATIO_MODE_NONE;
            [numSamples, overflow, chA, chB, chC, chD] = invoke(this.blockGroupObj, 'getBlockData', startIndex, segmentIndex, ...
                downsamplingRatio, downsamplingRatioMode);
            data=cat(2,chA,chB,chC,chD);
            if sum(overflow(:))
                warning('Scope 1 Over voltage! adjust channel scale');
            end
            times = double(this.ts) * downsamplingRatio * double(0:numSamples - 1);
            % here for resemblance to PICO2
			Bmean=mean(data(:,2));
            Dmean=mean(data(:,4));
        end

        function delete(this)
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