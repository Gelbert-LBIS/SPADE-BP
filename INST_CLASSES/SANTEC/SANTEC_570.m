classdef SANTEC_570 < handle

	% for general non-reslock use
	
    properties
        hw
    end

    methods
        function this = SANTEC_570()
            % set on santec as follows
            % mask 255.255.255.128
            % gateway 132.68.57.126
            PORT = 5900;
            IP = '132.68.57.111';
            this.hw = tcpclient(IP,PORT,'ConnectTimeout',3);
            configureTerminator(this.hw,'CR');
            resp = writeread(this.hw,"*IDN?");
            display(['SANTEC_570: Connected. version is ' convertStringsToChars(resp)]);
        end

        function startLD(this)
            Laser_ON = str2double(writeread(this.hw,':POWer:STAT?'));
            if ~Laser_ON
                writeline(this.hw,':POWer:STAT 1');
                while ~Laser_ON
                    pause(3);
                    Laser_ON = str2double(writeread(this.hw,':POWer:STAT?'));
                end
            end
        end

        function OpenShutter(this)
            writeline(this.hw,':POWer:SHUTter 0');
        end

        function CloseShutter(this)
            writeline(this.hw,':POWer:SHUTter 1');
        end

        function lambda = getWl(this)
            lambda = str2double(writeread(this.hw,':SOURce:WAVelength?'));
        end

        function setWl(this,lambdaSet)
            writeline(this.hw,[':SOURce:WAVelength ' num2str(lambdaSet)]);
            pause(0.15); % no less than 150ms due to overshoot
        end

        function I = getPow(this)
            I = str2double(writeread(this.hw,':POWer:LEVel?')); % [-17 13]
        end

        function setPow(this,ISet)
            writeline(this.hw,':POWer:ATTenuation:AUTo 1');
            writeline(this.hw,[':POWer ' num2str(ISet)]);
        end

        function lambda = getWlF(this)
            lambda = str2double(writeread(this.hw,':SOURce:WAVelength:FINe?'));
        end

        function setWlF(this,lambdaSet)
            writeline(this.hw,[':SOURce:WAVelength:FINe ' num2str(lambdaSet)]);
        end

        function setSweep(this,Lmin,Lmax,rate)
            % Set Continuous sweep mode.
            writeline(this.hw,':WAV:SWE:MOD 3'); % cont 2 way
            writeline(this.hw,[':WAV:SWE:STAR ' num2str(Lmin)]);
            writeline(this.hw,[':WAV:SWE:STOP ' num2str(Lmax)]);
            writeline(this.hw,[':WAV:SWE:SPE ' num2str(rate)]);
            writeline(this.hw,':WAV:SWE:CYCL 1');
			writeline(this.hw,':WAV:SWE:DEL 0');
            writeline(this.hw,':TRIG:INP:STAN 1'); % wait for trig
            writeline(this.hw,':WAV:SWE:REP');
        end

        function SweepGO(this)
            pause(4);
            writeline(this.hw,':WAV:SWE:SOFT');
        end

        function delete(~)
            clear this.hw;
        end
    end
end
