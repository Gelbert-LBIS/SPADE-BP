classdef PicoScope2_Block < handle

    properties (Access = public)
        ps2000EnuminfoX
        ps2000DeviceObj
        triggerGroupObj
        blockGroupObj
        ts
        nSamples
        times
    end

    methods (Access = public)
        function this = PicoScope2_Block()
            % Load configuration information
            PS2000Config;
            % save vars into class properties
            this.ps2000EnuminfoX = ps2000Enuminfo;
            % Create a device object.
            this.ps2000DeviceObj = icdevice('picotech_ps2000_generic');
            % Connect device object to hardware.
            connect(this.ps2000DeviceObj);
        end

        function setup(this,ts,durationMS)
			%% Reset
			invoke(this.ps2000DeviceObj, 'resetDevice');
            %% Trigger
            this.triggerGroupObj = get(this.ps2000DeviceObj, 'Trigger');
            this.triggerGroupObj = this.triggerGroupObj(1);
            invoke(this.triggerGroupObj, 'setTriggerOff');
            %% Channels
            % Channels       : 0,1 (this.ps2000EnuminfoX.enPS2000Channel)
            % Enabled        : 1,0 (PicoConstants.TRUE, PicoConstants.FALSE)
            % Type           : 1 (0 AC , 1 DC)
            % Range          : 7 (this.ps2000EnuminfoX.enPS2000Range.PS2000_2V)
            Range = 8;
            invoke(this.ps2000DeviceObj, 'ps2000SetChannel', 0, 1, 1, Range);
            invoke(this.ps2000DeviceObj, 'ps2000SetChannel', 1, 1, 1, Range);
            %% Block settings
            this.blockGroupObj = get(this.ps2000DeviceObj, 'Block');
            this.blockGroupObj = this.blockGroupObj(1);
            %% Time
            this.ts = ts;
            timebaseIndex=ceil(log2(this.ts*1e8));
            %invoke(this.blockGroupObj,'getTimebases');
            timeIntervalns = 10*2^timebaseIndex;
            this.ts = double(timeIntervalns*1e-9);  
            [~, nMaxSamples]=invoke(this.blockGroupObj,'setBlockIntervalNs',timeIntervalns);
            fprintf('Timebase index: %d, sampling interval: %f ms, sampling frequency: %d KHz\n', timebaseIndex, timeIntervalns*1e-6, 1e6/timeIntervalns);
            %% Memory
            this.nSamples = round(durationMS*1e-3 / this.ts);
            if nMaxSamples<this.nSamples
                error('buffer too small - reduce Fs or duration');
            end
            set(this.ps2000DeviceObj,'numberOfSamples',this.nSamples);
            fprintf('recording %d samples\n',this.nSamples);
            %% Early makeing of time vector for speed
            this.times = double(this.ts) * double(0:this.nSamples - 1);
        end

        function [timesout, data, Amean, Bmean] = read(this)
            [~, chA, chB, numDataValues, overflow, ~] = invoke(this.blockGroupObj, 'getBlockData'); % Capture the block
            %data=2000-cat(2,chA,chB); % notch mode
            data=cat(2,chA,chB);
            if sum(overflow(:))
                warning('Scope 1 Over voltage! adjust channel scale');
            end
            timesout = this.times;
            %timesout = double(this.ts) * double(0:numDataValues - 1); % too slow
            Amean=mean(data(:,1));
            Bmean=mean(data(:,2));
        end

        function delete(this)
            try
                invoke(this.ps2000DeviceObj, 'ps2000Stop');
                disconnect(this.ps2000DeviceObj);
                delete(this.ps2000DeviceObj);
            catch
                warning('PICO2 was not connected');
            end
        end
    end
end