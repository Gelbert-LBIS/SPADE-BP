% special compact code for the gui

% Gil Gelbert
% Technion IIT | EE | LBIS
% 2022
% Generate pressure signal using 2D kwave

function [t,sensor_data,layout] = Kwave2DForGUI(inp,FullSpect)
Diameter            = inp.Diameter;      % [m]
Dist                = inp.Dist;          % [m]
d                   = inp.d;             % [m] 3e-5 is good
VLint               = inp.VLint;         % u.l.
VRint               = inp.VRint;         % u.l.
VLdiam              = inp.VLdiam;        % [m]
VRdiam              = inp.VRdiam;        % [m]
separation          = inp.separation;    % [m]
angle               = inp.angle;         % [deg]
t_end               = inp.t_end;         % [sec]
lengthsens          = inp.lengthsens;    % [m]
toastflag           = inp.toastflag;     % 0/1
mediumflag          = inp.medium;        % 0/1
hydrogelFlag        = inp.hydrogel;      % 0/1
attenCompFlag       = inp.attenComp;     % 0/1
absorbersnoiseFlag  = inp.absorbersnoise;% 0/1
lasernoiseFlag      = inp.lasernoise;    % 0/1
elipticalFlag       = inp.eliptical;     % 0/1
MultispectFlag 		= inp.Multispect;    % 0-no  1-yes,run mcmatalab  2-yes,no run

% Grid ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
x = ceil(log2(0.02/d));
Nx = 2^x; Ny = 2^x;
dx = d; dy = d;
kgrid = kWaveGrid(Nx, dx, Ny, dy);
% Source ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
S_diameter = Diameter / dx;
S_VLdiam = VLdiam / dx;
S_VRdiam = VRdiam / dx;
S_separation = separation / dx;

Artery = makeDisc(Nx,Ny,Nx/2,Ny/2,round(0.5*S_diameter));

RLdiff = (S_VLdiam - S_VRdiam)*0.5;
if S_separation < 0 % conflict
    if RLdiff > 0       %left bigger
        R_l = round(S_diameter*0.5 + S_VLdiam*0.5) ;
        R_r = round(S_diameter*0.5 + S_VRdiam*0.5 + max(0,RLdiff+S_separation));
    elseif RLdiff < 0   %right bigger
        R_r = round(S_diameter*0.5 + S_VRdiam*0.5) ;
        R_l = round(S_diameter*0.5 + S_VLdiam*0.5 - min(0,RLdiff-S_separation));
    else                %equal
        R_r = round(S_diameter*0.5 + S_VRdiam*0.5) ;
        R_l = round(S_diameter*0.5 + S_VLdiam*0.5) ;
    end
    
    Rx_ofset = round (R_r * sind(angle));
    Ry_ofset = round (R_r * cosd(angle));
    
    Lx_ofset = round (R_l * sind(angle));
    Ly_ofset = round (R_l * cosd(angle));
    
    VeinL = makeDisc(Nx,Ny,Lx_ofset+Nx/2,Ly_ofset+Ny/2,round(0.5*S_VLdiam));
    VeinR = makeDisc(Nx,Ny,-Rx_ofset+Nx/2,Ry_ofset+Ny/2,round(0.5*S_VRdiam));
    
else
    
    Vdiam=max(S_VLdiam,S_VRdiam);
    R = round(S_diameter*0.5 + Vdiam*0.5 + S_separation) ;% [vox]
    
    x_ofset = round (R * sind(angle));
    y_ofset = round (R * cosd(angle));
    
    VeinL = makeDisc(Nx,Ny,x_ofset+Nx/2,y_ofset+Ny/2,round(0.5*S_VLdiam));
    VeinR = makeDisc(Nx,Ny,-x_ofset+Nx/2,y_ofset+Ny/2,round(0.5*S_VRdiam));
    
end

binmaskA = Artery;
binmaskLV = VeinL;
binmaskRV = VeinR;

if toastflag == 1 % toast
    % Artery
    [H, mask] = ToastGen(Diameter/2,d);
    H=imrotate(H,90);
    Artery(Artery==1)=H(mask==1);
    
    % LV
    [H, mask] = ToastGen(VLdiam/2,d);
    H=imrotate(H,90);
    VeinL(VeinL==1)=H(mask==1);
    
    % RV
    [H, mask] = ToastGen(VRdiam/2,d);
    H=imrotate(H,90);
    VeinR(VeinR==1)=H(mask==1);
    
elseif toastflag == 2 % MCMATLAB
    
    if MultispectFlag == 2
        counter = FullSpect{5}.counter;
        HLV=FullSpect{counter}.L;
        HRV=FullSpect{counter}.R;
        HA=FullSpect{counter}.A;
        MSK_LV=FullSpect{4}.maskLV;
        MSK_RV=FullSpect{4}.maskRV;
        MSK_A=FullSpect{4}.maskA;
    else
        [HLV,HRV,HA,MSK_LV,MSK_RV,MSK_A,FullSpect] = MCMatlabGen(inp);
    end
    
    HLV=imrotate(HLV,90);
    HRV=imrotate(HRV,90);
    HA=imrotate(HA,90);
    
    MSK_LV=imrotate(MSK_LV,90);
    MSK_RV=imrotate(MSK_RV,90);
    MSK_A=imrotate(MSK_A,90);
    
    Artery(Artery==1)=HA(MSK_A==1);
    VeinL(VeinL==1)=HLV(MSK_LV==1);
    VeinR(VeinR==1)=HRV(MSK_RV==1);
    
end

% laser noise mask
LaserNoiseMask = zeros(Nx, Ny);
LaserNoiseLength = round(0.5*lengthsens/dy); % like sensor
for i=-LaserNoiseLength:1:LaserNoiseLength
    LaserNoiseMask(Nx/2 + i, Ny/2 - round(Dist/dx)+1) = 2;
    LaserNoiseMask(Nx/2 + i, Ny/2 - round(Dist/dx)+2) = -2;
end

% eliptical artery
if elipticalFlag
    % narrowing
    [wi,he] = size(Artery);
    heX = round(wi*0.9);
    if rem(heX,2)
        heX=heX+1;
    end
    Artery=imresize(Artery,[wi heX]);
    Artery=padarray(Artery',round((he-heX)*0.5),'both')';

    % widenning
    [wi,he] = size(Artery);
    wiX = round(wi*1.1);
    if rem(wiX,2)
        wiX=wiX+1;
    end
    Artery=imresize(Artery,[wiX he]);
    trimx=round((wiX-wi)*0.5);
    Artery(1:trimx,:)=[];
    Artery(end-trimx+1:end,:)=[];
end

source.p0 =  Artery + VLint * VeinL + VRint * VeinR + lasernoiseFlag * LaserNoiseMask;

if absorbersnoiseFlag
    newnoise = imnoise(zeros(size(source.p0)),'gaussian');
    %newnoise = imnoise(newnoise,'salt & pepper',0.01);
    [~,b]=max(sum(source.p0,1)>0);
    newnoise(:,1:round(0.9*b))=0;
    newnoise(source.p0>0)=0;
    source.p0 = source.p0 + 0.5*newnoise;
end

% Medium ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

if mediumflag==0 % homogeneous
    medium.sound_speed = 1580; % [m/s]
    medium.density = 1060; % [Kg/m^3]
    medium.alpha_power  = 1.2;
    medium.BonA = 6;
    medium.alpha_coeff = 0.75; %[db/cm*Mhz]
else % hetrogeneous (pure bio system)
    vessels = imbinarize(binmaskA + binmaskLV + binmaskRV,0);
    skin = imbinarize(ones(size(binmaskA)),0);
    edge = find(sum(vessels,1)>0,1);
    vessel_depth_inskin = round(min(0.002,-0.0005+Dist-Diameter*0.5)/d);
    edge = edge - vessel_depth_inskin;
    water = skin; water(:,edge:end)=0;
    bone = zeros(size(binmaskA));
    %bone(:,round(Nx*0.65):end)=1;
    skin(water==1)=0; skin(vessels==1)=0; skin(bone==1)=0;

    medium.sound_speed  = vessels* 1580 + water* 1525  + skin* 1540 + bone* 3406;
    medium.density      = vessels* 1060 + water* 993 + skin* 1100 + bone* 1500;
    medium.BonA         = vessels* 6    + water* 5.01  + skin* 7.8  + bone* 7.43;
    medium.alpha_coeff  = vessels* 0.13 + water* 0.002  + skin* 0.75 + bone* 13.1;
    medium.alpha_power  = 1.2;
end
% limit max time ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
kgrid.t_array = makeTime(kgrid, medium.sound_speed, [], t_end);

% Sensor ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
SS_DIS = round(Dist/dx); % distance between center of vessel to sensor
if SS_DIS<=0.5*S_diameter
    error('Sensor is inside the vessel');
end

sensor.mask = zeros(Nx, Ny);

try
length_ = round(0.5*lengthsens/dy); % half dist in voxels
for i=-length_:length_
    sensor.mask(Nx/2 + i, Ny/2 - SS_DIS) = 1;
end
catch
    error('max scan width is 19mm under d=10um');
end

if hydrogelFlag
    hydrogelthickness = 0.001; %[m]
    hydrogelthickness_vox = hydrogelthickness/d;
    hydromask=zeros(Nx, Ny);
    for i=-length_:length_
        for l=1:hydrogelthickness_vox
            hydromask(Nx/2 + i, Ny/2 - SS_DIS + l) = 1;
        end
    end
    hydromask=imbinarize(hydromask,0);
    
    medium.sound_speed  (hydromask)= 1540; %not final values
    medium.density      (hydromask)= 1270;
    medium.BonA         (hydromask)= 6;
    medium.alpha_coeff  (hydromask)= 2;
end

% Show layout for GUI ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
layout=sensor.mask + source.p0;
if mediumflag  
    layout=mat2gray(layout+medium.sound_speed/500);
end
% Configurations and run ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
input_args = {'PlotPML', false, 'PlotSim', false, 'DataCast', 'single'};
%input_args = {'PlotSim', true,'RecordMovie', true, 'MovieName', 'example_movie_1','PlotScale', [-0.5, 0.5]};
switch MultispectFlag
    case 0
        %sensor_data = kspaceFirstOrder2D(kgrid,medium,source,sensor,input_args{:});
        sensor_data = kspaceFirstOrder2DG(kgrid,medium,source,sensor,input_args{:});
        t=kgrid.t_array;
        % attencomp ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        if (mediumflag==0) && (attenCompFlag==1)
            sensor_data = attenComp(sensor_data, t(3)-t(2), medium.sound_speed, medium.alpha_coeff, medium.alpha_power);
        end
    case 1
        FullSpect{5}.counter=1; inp.Multispect=2;
        [t,sensor_data750,layout750] = Kwave2DForGUI(inp,FullSpect);
        FullSpect{5}.counter=2;
        [~,sensor_data800,layout800] = Kwave2DForGUI(inp,FullSpect);
        FullSpect{5}.counter=3;
        [~,sensor_data900,layout900] = Kwave2DForGUI(inp,FullSpect);
        
        layout = cat(3,layout750,layout800,layout900);
        sensor_data = cat(3,sensor_data750,sensor_data800,sensor_data900);
    case 2
        sensor_data = kspaceFirstOrder2DG(kgrid,medium,source,sensor,input_args{:});
        t=kgrid.t_array;
end
end

