classdef KEYSIGHT < handle

    properties
        TCPhandle
        WLmin % [nm]
        WLmax % [nm]
        printsflag 
        points % num of points in sweep
        time % time of sweep [s]
        avg_time % integration time at each WL point in sweep [s]

        reflossdb % ref loss vec raw
        reflda % ref lda vec nm
    end

    methods
        function this = KEYSIGHT()
            tries = 0;
            try
                myfile=load('ip_keysight');
            catch
                myfile.ip_last_dig = 1;
            end
            ip_last_dig=myfile.ip_last_dig;
            IP = sprintf('132.68.57.%d',ip_last_dig);
            while 1
                tries=tries+1;
                try
                    this.TCPhandle = tcpclient(IP,5025,'ConnectTimeout',3);
                    break;
                catch
                    ip_last_dig = inputdlg('Enter the last field of the Keysight`s IP address');
                    if size(ip_last_dig,1)<1 % user cancelled
                        error('user cancelled');
                    end
                    IP = ['132.68.57.' cell2mat(ip_last_dig)];
                    ip_last_dig = str2double(cell2mat(ip_last_dig));
                end
                if tries>3
                    disp('cannot connect - full reset to laser is needed');
					error('cannot connect');
                end
            end
            save('ip_keysight','ip_last_dig');
            
            try
            resp = writeread(this.TCPhandle,"*IDN?");
            catch ME
                warning(ME.message);
                error('start again after laser is ready');
            end
            disp(['KEYSIGHT: Connected. ' convertStringsToChars(resp)]);

            this.WLmin = 1500; % true
            this.WLmax = 1600; % trimmed a bit for clean operation

            % unlock
            status = writeread(this.TCPhandle,":LOCK?");
            if str2double(status)
                writeline(this.TCPhandle,"lock 0,1234");
            end

            % configs
            writeline(this.TCPhandle,"trig:conf loop");  % internal trig loop
            writeline(this.TCPhandle,"sour0:pow:unit 0");% 0 dbm , 1 watt
            writeline(this.TCPhandle,"sens1:pow:unit 0"); % 0 dbm , 1 watt
            writeline(this.TCPhandle,"trig1:inp ign");   % powermeter free run

            % refrence of SM fiber
            load('REF.mat');
            this.reflossdb = double(10*log10(loss*1e3));
            this.reflda = lda*1e9; % [nm]

            this.flushh;
        end

        function flushh(this)
            while 1
                resp=writeread(this.TCPhandle,":SYSTem:ERRor?");
                switch resp
                    case '+0,"No error"'
                        break;
                    otherwise
                end
            end
            flush(this.TCPhandle);
        end

        function resetlaser(this)
            writeline(this.TCPhandle,"*RST"); % needed after failed sweep
        end

        function setprints(this,flag)
            if flag
                this.printsflag = 1;
                disp('KEYSIGHT: prints enabled');
            else
                this.printsflag = 0;
                disp('KEYSIGHT: prints disabled');
            end
        end

        function startLaser(this)
            writeline(this.TCPhandle,"sour0:pow:stat 1");
            status = writeread(this.TCPhandle,"sour0:pow:stat?"); % hold
            if str2double(status)<1
                error('KEYSIGHT: laser did not start');
            else
                if this.printsflag
                    disp('KEYSIGHT: Laser ON');
                end
            end
        end

        function stopLaser(this)
            writeline(this.TCPhandle,"sour0:pow:stat 0");
            status = writeread(this.TCPhandle,"sour0:pow:stat?"); % hold
            if str2double(status)>0
                error('KEYSIGHT: laser did not stop');
            else
                if this.printsflag
                    disp('KEYSIGHT: Laser OFF');
                end
            end
        end

        function setWavelength(this, lambda)
            % lambda is in [nm]
            if (lambda > this.WLmax) || (lambda < this.WLmin)
                error('KEYSIGHT: requested WL is out range [%d %d]',this.WLmin,this.WLmax);
            end
            writeline(this.TCPhandle,['sour0:wav ' sprintf('%.4f', lambda) 'NM']);
            if this.printsflag
                disp(['KEYSIGHT: wavelegnth set to ' sprintf('%.4f', lambda)]);
            end

            % match power meter
            writeline(this.TCPhandle,['sens1:pow:wav ' sprintf('%.1f', lambda) 'NM']);
        end

        function WL = getWavelength(this)
            % WL is in [nm]
            WL = writeread(this.TCPhandle,":sour0:wav?");
            if this.printsflag
                disp(['KEYSIGHT: wavelength is ' sprintf('%.4f', str2double(WL)*1e9)]);
            end
            WL = str2double(WL) * 1e9;
        end

        function setOpticalPower(this, power)
            % Power is in [dbm]
            if power>13.524 || power < -30
                error("KEYSIGHT: optical power is out of supported range [-30 13.524]dBm");
            end
            writeline(this.TCPhandle,['sour0:pow ' sprintf('%.3f', power) 'dbm']);
            if this.printsflag
                disp(['KEYSIGHT: power set to ' sprintf('%.3f', power)]);
            end
        end

        function OP = getOpticalPower(this)
            % OP is in [dbm]
            OP = writeread(this.TCPhandle,"sour0:pow?");
            if this.printsflag
                disp(['KEYSIGHT: power is ' convertStringsToChars(OP)]);
            end
            OP = str2double(OP);
        end

        function timeret = SweepSETUP(this,lowlimit,highlimit,step,speed)
            this.flushh;
            % set step to 0.001nm (1pm) and speed to 40nm/s to get avgTime
            % of 25uS which the minimum allowed. No real reason to choose
            % any other set of step-speed.
            writeline(this.TCPhandle,"trig0:outp stf"); % configure laser output triggers for step finished
            writeline(this.TCPhandle,"trig0:inp sws"); % wait for a hardware or software trigger before beginning
            writeline(this.TCPhandle,sprintf('sour0:wav:swe:star %.4fNM', lowlimit));
            writeline(this.TCPhandle,sprintf('sour0:wav:swe:stop %.4fNM', highlimit));
            writeline(this.TCPhandle,sprintf('sour0:wav:swe:step %.4fNM', step));
            writeline(this.TCPhandle,sprintf('sour0:wav:swe:spe %.4fNM/S', speed));
            writeline(this.TCPhandle,"sour0:wav:swe:mode cont");
            writeline(this.TCPhandle,"sour0:wav:swe:cycl 1");
            writeline(this.TCPhandle,"sour0:wav:swe:llog 1"); % enables logging of swept wavelength values

            resp = writeread(this.TCPhandle,"sour0:wav:swe:chec?");
            switch resp
                case "0,OK"
                otherwise
                    error('Wrong Sweep Parameters wrong - Device RESET recommended!');
            end

            this.points = str2double(writeread(this.TCPhandle,"sour0:wav:swe:exp?"));
            this.time = (highlimit-lowlimit)/speed;
            timeret = this.time;
            this.avg_time = step/speed;

            if this.printsflag
                fprintf('KEYSIGHT: cont sweep from %.3fnm to %.3fnm ready\n %.3fnm/s step is %.2fpm\n',lowlimit,highlimit,speed,1000*step);
            end

            % power meter configuration
            writeline(this.TCPhandle,"sens1:func:stat logg,stop");
            writeline(this.TCPhandle,"trig1:inp sme") % wait for trigger
            writeline(this.TCPhandle,"sens1:pow:unit 0") % 0 dbm , 1 watt
            writeline(this.TCPhandle,"sens1:pow:rang:auto 0") % no auto ranging
            writeline(this.TCPhandle,"sens1:pow:rang 10dbm") % can be 10 0 -10 -20 -30.
            writeread(this.TCPhandle,"sens1:pow:rang?"); % hold
            writeline(this.TCPhandle,"sens1:pow:wav 1550NM")
            writeline(this.TCPhandle,['sens1:func:par:logg ' sprintf('%d,%fs', this.points,this.avg_time)])
            writeline(this.TCPhandle,"sens1:func:stat logg,star")

            writeline(this.TCPhandle,"sour0:wav:swe 1"); % "get ready to sweep"
        end

        function [lambdafinal,powerfinal] = SweepGO(this)

            while str2double(writeread(this.TCPhandle,"sour0:wav:swe:flag?")) < 1
                pause(0.1);
            end

            writeline(this.TCPhandle,"sour0:wav:swe:soft"); % trig the sweep
            pause(this.time + 1);

            this.flushh;
            writeline(this.TCPhandle,"sens1:func:res?");
            pause(1);
            powerfinal = this.handledata(32); % 32 is for data in SINGLE format

            this.flushh;
            writeline(this.TCPhandle,"sour0:read:data? llog");
            pause(1);
            lambdafinal = this.handledata(64); % 64 is for data in DOUBLE format

            % restart the powermeter
            writeline(this.TCPhandle,"trig1:inp ign"); % IGNore triggers
            writeline(this.TCPhandle,"sens1:func:stat logg,stop"); % no logging

            % apply ref
            if 1
                [~,closestIndexmin] = min(abs(this.reflda-lambdafinal(1)*1e9));
                [~,closestIndexmax] = min(abs(this.reflda-lambdafinal(end)*1e9));
                refvect = resize(this.reflossdb(closestIndexmin:closestIndexmax),size(powerfinal,1),'Pattern','edge');
                powerfinal = double(10*log10(powerfinal*1e3)) - refvect; %db
                powerfinal = real(powerfinal);
                powerfinal(powerfinal>20)=-55;
                powerfinal = single((10.^(powerfinal/10)/1000));
            end
        end
		
		function SweepGoNoRet(this)
            while str2double(writeread(this.TCPhandle,"sour0:wav:swe:flag?")) < 1
                pause(0.1);
            end
            writeline(this.TCPhandle,"sour0:wav:swe:soft"); % trig the sweep
        end

        function res = handledata(this,sizebit)
            rawDATA = read(this.TCPhandle); % get ALL from TCP
            while isempty(rawDATA)
                rawDATA = read(this.TCPhandle);
                pause(2);
            end
            while this.TCPhandle.NumBytesAvailable>0
                rawDATA=[rawDATA read(this.TCPhandle)];
                pause(0.5);
            end

            UTFDATA = native2unicode(rawDATA);
            second = str2double(UTFDATA(2));

            %binDATA=decimalToBinaryVector(rawDATA);
            numBits= 8; % uint8
            rawDATArep= double(repmat(rawDATA(:),1,numBits));
            dev_vec=(2.^(numBits-1:-1:0));
            binDATA = mod(floor(rawDATArep ./ dev_vec), 2);

            binDATA=flip(binDATA,2);
            binDATAshaped=reshape(binDATA',size(rawDATA,2)*8,[]);
            binDATAshaped(1:(2+second)*8)=[]; binDATAshaped(end-7:end)=[];
            binDATAshapedX=reshape(binDATAshaped,sizebit,[])';

            %res = binaryVectorToDecimal(binDATAshapedX,'LSBFirst');
            mult_vec= (2.^(0:sizebit-1));
            res= binDATAshapedX*mult_vec(:);
            %d= nnz(res-uint64(res2));

            switch sizebit
                case 32
                    res = uint32(res);
                    res = typecast(res,'single');
                case 64
                    res = uint64(res);
                    res = typecast(res,'double');
            end
        end

        function pwrnow = GetMonitorPower(this)
            pwrnow=str2double(writeread(this.TCPhandle,"fetc1:pow?"));

            if pwrnow>20
                pwrnow=-55;
            end

            % apply ref
            [~,closestIndex] = min(abs(this.reflda-this.getWavelength));
            pwrnow = pwrnow - this.reflossdb(closestIndex);
        end
    end
end