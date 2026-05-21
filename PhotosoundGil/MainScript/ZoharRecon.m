classdef ZoharRecon < handle

    properties
        dtx
        timesx
        numsens
        kgrid
        input_args
        source
        sensor
        Ny
        kdt
        SOS
        dy
    end

    methods
        function this = ZoharRecon(RecordSettings)
            resamplerate = 4;
            this.dtx = RecordSettings.ts;
            RecordSettings.samples_per_event=RecordSettings.samples_per_event-round(1.5e-6/this.dtx);
            this.timesx=linspace(0,0+RecordSettings.samples_per_event*RecordSettings.ts,RecordSettings.samples_per_event);
            this.numsens=64;
            this.SOS=1570;

            PML_size = 20;
            dx = 0.2*1e-3 / resamplerate;
            this.dy = 0.2*1e-3 / resamplerate;
            this.Ny = 64 * resamplerate;
            Nx = round(max(this.timesx)*this.SOS/dx);
            this.kgrid = kWaveGrid(Nx, dx, this.Ny, this.dy);
            medium.sound_speed  = this.SOS;
            this.kgrid.t_array = makeTime(this.kgrid, medium.sound_speed, [],this.timesx(end));
            this.kdt = this.kgrid.t_array(5)-this.kgrid.t_array(4);
            this.source.p0 = 0;
            this.sensor.mask = zeros(Nx, this.Ny);
            this.sensor.mask(1, :) = 1;
            this.input_args = {'PMLInside', false, 'PMLSize', PML_size, 'PlotSim', false};
        end

        function recon = RunRecon(this,sig,UIAxes)
            bgpoint=round(0.05*size(sig,1)); % 5 precent of the end
            sinogramZero = mean(mean(sig(end-bgpoint:end,:)));
            if abs(sinogramZero)/max(sig(:)) > 0.001
                sig=sig-sinogramZero;
            end

            sig(1:round(1.5e-6/this.dtx),:)=[];

            matfull_rec = sig;
			
			matfull_rec=sgolayfilt(double(matfull_rec),4,11); 
			matfull_rec=sgolayfilt(matfull_rec',4,11)'; 

            matfull_rec = imresize(matfull_rec,[length(this.kgrid.t_array),this.Ny]);

            x_axis = [0, (length(this.kgrid.t_array)) * this.kdt * this.SOS];
            y_axis = [0, size(matfull_rec,2) * this.dy];
            [~, scale, prefix] = scaleSI(max([x_axis(end), y_axis(end)]));

            results = kspaceLineRecon(matfull_rec, this.dy, this.kdt, this.SOS,'Plot', false, 'PosCond', false); %, 'Interp', '*linear');
            plot_scale = max(results(:)); plot_scale_min=min(results(:));

            imagesc(UIAxes,y_axis * scale, x_axis * scale, results,[plot_scale_min, plot_scale]);
            xlabel(UIAxes,['Sensor Position [' prefix 'm]']);
            ylabel(UIAxes,['Depth [' prefix 'm]']);
            axis(UIAxes,'image');
            colormap(UIAxes,gray);
            recon=results;
        end
    end
end