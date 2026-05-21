classdef SANTEC_550 < handle

    properties
        hw
    end

    methods
        function this = SANTEC_550()
            this.hw = instrfind('Type', 'visa-gpib', 'RsrcName', 'GPIB0::1::INSTR', 'Tag', '');
            % Create the VISA-GPIB object if it does not exist
            % otherwise use the object that was found.
            if isempty(this.hw)
                this.hw = visa('NI', 'GPIB0::1::INSTR');
            else
                fclose(this.hw);
                this.hw = this.hw(1);
            end
            % Connect to instrument object, obj1.
            fopen(this.hw);
            % Flush the data in the input buffer.
            flushinput(this.hw);
            t1=1;
            while t1<5
                tic;
                fscanf(this.hw);
                t1=toc;
            end
            % Communicating with instrument object, obj1.
            IDN = query(this.hw, '*IDN?');
            display(IDN);
        end

        function startLD(this)
            Laser_ON = str2double(query(this.hw,':POWer:STAT?'));
            if ~Laser_ON
                fprintf(this.hw,':POWer:STAT 1');
                while ~Laser_ON
                    pause(3);
                    Laser_ON = str2double(query(this.hw,':POWer:STAT?'));
                end
            end
        end

        function OpenShutter(this)
            fprintf(this.hw,':POWer:SHUTter 0');
        end

        function CloseShutter(this)
            fprintf(this.hw,':POWer:SHUTter 1');
        end

        function lambda = getWl(this)
            lambda = str2double(query(this.hw,':SOURce:WAVelength?'));
        end

        function setWl(this,lambdaSet)
            fprintf(this.hw,[':SOURce:WAVelength ' num2str(lambdaSet)]);
            pause(0.15); % no less than 150ms due to overshoot
        end

        function I = getPow(this)
            I = str2double(query(this.hw,':POWer:LEVel?')); % [-17 13]
        end

        function setPow(this,ISet)
            fprintf(this.hw,':POWer:ATTenuation:AUTo 1');
            fprintf(this.hw,[':POWer ' num2str(ISet)]);
        end

        function lambda = getWlF(this)
            lambda = str2double(query(this.hw,':SOURce:WAVelength:FINe?'));
        end

        function setWlF(this,lambdaSet)
            fprintf(this.hw,[':SOURce:WAVelength:FINe ' num2str(lambdaSet)]);
        end

        function setSweep(this,Lmin,Lmax,rate)
            % Set Continuous sweep mode.
            fprintf(this.hw,':WAV:SWE:MOD 3');
            fprintf(this.hw,[':WAV:SWE:STAR ' num2str(Lmin)]);
            fprintf(this.hw,[':WAV:SWE:STOP ' num2str(Lmax)]);
            fprintf(this.hw,[':WAV:SWE:SPE ' num2str(rate)]);
            fprintf(this.hw,':WAV:SWE:CYCL 1');
            fprintf(this.hw,':WAV:SWE:REP');
        end

        function SweepGO(this)
            pause(4);
            fprintf(this.hw,':WAV:SWE:SOFT');
        end

        function delete(this)
            fclose(this.hw);
        end
    end
end
