function [Hraw,mask] = MCMATLAB(inp)

addpath(genpath(pwd));

if nargin == 0
    inp.wavelengths 	= [680 800 900];
    inp.saturations 	= [96 75 75];
    inp.Hshape 			= 'ARMADILLO'; % has no affect if uniform==1
    inp.Diameter 		= 0*0.003;
    inp.Dist 			= 0.004;
    inp.VLdiam 			= 0*0.0025;
    inp.VRdiam			= 0*0.0025;
    inp.separation		= 0.0005;
    inp.angle 			= 90;
end

%MCmatlab.closeMCmatlabFigures();
model = MCmatlab.model;

model.G.nx                = 400; % Number of bins in the x direction
model.G.ny                = 400; % Number of bins in the y direction
model.G.nz                = 300; % Number of bins in the z direction
model.G.Lx                = 2; % [cm] x size of simulation cuboid
model.G.Ly                = 2; % [cm] y size of simulation cuboid
model.G.Lz                = 1.5; % [cm] z size of simulation cuboid

model.G.mediaPropertiesFunc = @mediaPropertiesFunc; % Media properties defined as a function at the end of this file
model.G.geomFunc            = @geometryDefinition; % Function to use for defining the distribution of media in the cuboid. Defined at the end of this m file.

mycell=cell(1); mycell{1}=inp;

model.G.mediaPropParams=mycell;
model.G.geomFuncParams=mycell;

% Monte Carlo simulation
model.MC.nPhotonsRequested        = 1e6; %30e6 for review FR
model.MC.matchedInterfaces        = true; % Assumes all refractive indices are the same
model.MC.boundaryType             = 1; % 0: No escaping boundaries, 1: All cuboid boundaries are escaping, 2: Top cuboid boundary only is escaping, 3: Top and bottom boundaries are escaping, while the side boundaries are cyclic
model.MC.wavelength               = inp.wavelengths; % [nm] Excitation wavelength, used for determination of optical properties for excitation light
%model.MC.spectrumFunc             = @OPOspectralPower; % comment out for
                                                       % non OPO usage

% Source
xdist = zeros(1000,1); xdist (1:50) = 1; xdist (end-50:end) = 1;

model.MC.lightSource.sourceType   = 5; % 0: Pencil beam, 1: Isotropically emitting line or point source, 2: Infinite plane wave, 3: Laguerre-Gaussian LG01 beam, 4: Radial-factorizable beam (e.g., a Gaussian beam), 5: X/Y factorizable beam (e.g., a rectangular LED emitter)
model.MC.lightSource.focalPlaneIntensityDistribution.XDistr = xdist; % the two narrow bars of zohar
model.MC.lightSource.focalPlaneIntensityDistribution.YDistr = 0; % tophat

model.MC.lightSource.focalPlaneIntensityDistribution.XWidth = 0.3;    % cm (6mm is dist between bars)
model.MC.lightSource.focalPlaneIntensityDistribution.YWidth = 1.25/2; % cm (12.5mm is lengh of bar)

model.MC.lightSource.angularIntensityDistribution.XDistr = 1; % Gaussian
model.MC.lightSource.angularIntensityDistribution.YDistr = 1; % Gaussian

model.MC.lightSource.angularIntensityDistribution.XWidth = 0; % rad
model.MC.lightSource.angularIntensityDistribution.YWidth = 0; % rad

model.MC.lightSource.xFocus       = 0;      % [cm] x position of source
model.MC.lightSource.yFocus       = 0;      % [cm] y position of source
model.MC.lightSource.zFocus       = 0;      % [cm] z position of source

model.MC.lightSource.theta        = 0; % [rad] Polar angle of beam center axis
model.MC.lightSource.phi          = 0; % [rad] Azimuthal angle of beam center axis
model.MC.lightSource.psi          = 0; % [rad] Axial rotation angle of the beam.

switch inp.Hshape
    case '2_Lines_PAR'
        % keep model.MC.lightSource.psi = 0; % [rad] Axial rotation angle of the beam.
    case '2_Lines_SQR'
        model.MC.lightSource.psi = pi/2; % [rad] Axial rotation angle of the beam.
    case 'BOX_1CM_1CM'
        model.MC.lightSource.focalPlaneIntensityDistribution.XDistr = 0; % tophat
        model.MC.lightSource.focalPlaneIntensityDistribution.XWidth = 0.5; % cm
        model.MC.lightSource.focalPlaneIntensityDistribution.YWidth = 0.5; % cm
    case 'BOX_1CM_2CM'
        model.MC.lightSource.focalPlaneIntensityDistribution.XDistr = 0; % tophat
        model.MC.lightSource.focalPlaneIntensityDistribution.XWidth = 1; % cm
        model.MC.lightSource.focalPlaneIntensityDistribution.YWidth = 0.5; % cm        
    case 'DISC_1.25CM'
        model.MC.lightSource.sourceType = 4;
        model.MC.lightSource.focalPlaneIntensityDistribution.radialDistr = 0; % tophat
        model.MC.lightSource.focalPlaneIntensityDistribution.radialWidth = 0.625; % cm radius
        model.MC.lightSource.angularIntensityDistribution.radialDistr = 0; % tophat
        model.MC.lightSource.angularIntensityDistribution.radialWidth = 0; % rad
    case 'ARMADILLO'

        model.G.nx                = 800; % Number of bins in the x direction - tmp
        model.G.Lx                = 4; % [cm] x size of simulation cuboid - tmp

        xdist = ones(1000,1);
        xdist(500-66:500+66) = 0; % 4 mm bridge
        %xdist(500-33:500+33) = 0; % 2 mm bridge
        model.MC.lightSource.focalPlaneIntensityDistribution.XDistr = xdist;
        model.MC.lightSource.focalPlaneIntensityDistribution.XWidth = 3/2; % cm (30mm is length of bundle)
        model.MC.lightSource.focalPlaneIntensityDistribution.YWidth = 0.6/2; % cm (6mm is width of bundle)

end

% GPU
model.MC.useGPU                   = true; % (Default: false) Use CUDA acceleration for NVIDIA GPUs
model.MC.GPUdevice                = 0; % (Default: 0, the first GPU) The index of the GPU device to use for the simulation
model.MC.nExamplePaths            = 0; % not working with broadband.

% model = plot(model,'G');
model  = runMonteCarlo(model);

mask = squeeze(model.G.M_raw(:,end/2,:));
mask(mask<4)=0;

%model = plot(model,'MC'); % slow

% runtime = model.MC.simulationTime;

% remember it is an option
% combinedModel = combineModels([model, model2],'MC');

% abs used because in some extreme cases of wide spectral range the result
% get a (-).
Hraw = abs(model.MC.normalizedAbsorption);

if model.G.Lx==4
    Hraw=Hraw(201:598,:,:,:);
    mask=mask(201:598,:);
end

%FL_SHOW(model); return; % tmp

if nargin == 0
    figure;
    mon = montage(squeeze(mean(Hraw,2)),'DisplayRange',[]);
    colormap(mon.Parent,'hot'); colorbar(mon.Parent);
    imwrite(mat2gray(get(mon,'CData')),'MCMATLAB_OUTPUT.tif','tif');
end
end
%% Geometry function(s) (see readme for details)
function M = geometryDefinition(X,Y,Z,mycell)
inp=mycell{1};
% Blood vessel example:
zsurf = 0.01; % water on surface
epd_thick = 0.008; % [cm] epidermis at the skin is about 80um

vesselradiusA   = inp.Diameter*0.5*100; % m to cm conv
vesselradiusLV  = inp.VLdiam*0.5*100;
vesselradiusRV  = inp.VRdiam*0.5*100;
vesseldepthA    = inp.Dist*100;

inp.separation = max(inp.separation,0); % does not handle conflict

Vdiam = max(inp.VLdiam,inp.VRdiam);
R = inp.Diameter*0.5 + Vdiam*0.5 + inp.separation;
x_ofset =  100 * R * sind(inp.angle);
y_ofset =  100 * R * cosd(inp.angle);

M = ones(size(X)); % fill background with water (gel)
M(Z > zsurf) = 2; % epidermis
M(Z > zsurf + epd_thick) = 3; % dermis
M(X.^2 + (Z - (zsurf + vesseldepthA)).^2 < vesselradiusA^2) = 4; % blood A
M((X-x_ofset).^2 + (Z - (zsurf + vesseldepthA + y_ofset)).^2 < vesselradiusRV^2) = 5; % blood LV
M((X+x_ofset).^2 + (Z - (zsurf + vesseldepthA + y_ofset)).^2 < vesselradiusLV^2) = 6; % blood RV
end

%% Media Properties function (see readme for details)
function mediaProperties = mediaPropertiesFunc(mycell)
inp=mycell{1};
mediaProperties = MCmatlab.mediumProperties;

j=1;%--------------------------------------------------------------------
mediaProperties(j).name  = 'water';
mediaProperties(j).mua   = 0.00036; % [cm^-1]
mediaProperties(j).mus   = 10; % [cm^-1]
mediaProperties(j).g     = 1.0;

j=2;%--------------------------------------------------------------------
mediaProperties(j).name  = 'epidermis';
mediaProperties(j).mua = @func_mua2;
    function mua = func_mua2(wavelength)
        B = 0; % Blood content
        S = 0.75; % Blood oxygen saturation
        W = 0.75; % Water content
        M = 0.01; % Melanin content %0.03 for regular,  0 for gil
        F = 0; % Fat content
        mua = calc_mua(wavelength,S,B,W,F,M); % Jacques "Optical properties of biological tissues: a review" eq. 12
    end

mediaProperties(j).mus = @func_mus2;
    function mus = func_mus2(wavelength)
        aPrime = 40; % musPrime at 500 nm
        fRay = 0; % Fraction of scattering due to Rayleigh scattering
        bMie = 1; % Scattering power for Mie scattering
        g = 0.9; % Scattering anisotropy
        mus = calc_mus(wavelength,aPrime,fRay,bMie,g); % Jacques "Optical properties of biological tissues: a review" eq. 2
    end
mediaProperties(j).g   = 0.9;

j=3;%--------------------------------------------------------------------
mediaProperties(j).name = 'dermis';
mediaProperties(j).mua = @func_mua3;
    function mua = func_mua3(wavelength)
        B = 0.002; % Blood content
        S = 0.67; % Blood oxygen saturation
        W = 0.65; % Water content
        M = 0; % Melanin content
        F = 0; % Fat content
        mua = calc_mua(wavelength,S,B,W,F,M); % Jacques "Optical properties of biological tissues: a review" eq. 12
    end

mediaProperties(j).mus = @func_mus3;
    function mus = func_mus3(wavelength)
        aPrime = 42.4; % musPrime at 500 nm
        fRay = 0.62; % Fraction of scattering due to Rayleigh scattering
        bMie = 1; % Scattering power for Mie scattering
        g = 0.9; % Scattering anisotropy
        mus = calc_mus(wavelength,aPrime,fRay,bMie,g); % Jacques "Optical properties of biological tissues: a review" eq. 2
    end
mediaProperties(j).g   = 0.9;

j=4;%--------------------------------------------------------------------
mediaProperties(j).name  = 'bloodA';
mediaProperties(j).mua = @func_mua4;
    function mua = func_mua4(wavelength)
        B = 1; % Blood content
        S = inp.saturations(1)/100; % Blood oxygen saturation
        W = 0.51; % Water content
        M = 0; % Melanin content
        F = 0; % Fat content
        mua = calc_mua(wavelength,S,B,W,F,M); % Jacques "Optical properties of biological tissues: a review" eq. 12
    end

mediaProperties(j).mus = @func_mus4;
    function mus = func_mus4(wavelength)
        aPrime = 10; % musPrime at 500 nm
        fRay = 0; % Fraction of scattering due to Rayleigh scattering
        bMie = 1; % Scattering power for Mie scattering
        g = 0.9; % Scattering anisotropy
        mus = calc_mus(wavelength,aPrime,fRay,bMie,g); % Jacques "Optical properties of biological tissues: a review" eq. 2
    end
mediaProperties(j).g   = 0.9;

j=5;%------------------------------------------------------------------
mediaProperties(j).name  = 'bloodLV';
mediaProperties(j).mua = @func_mua5;
    function mua = func_mua5(wavelength)
        B = 1; % Blood content
        S = inp.saturations(2)/100; % Blood oxygen saturation
        W = 0.51; % Water content
        M = 0; % Melanin content
        F = 0; % Fat content
        mua = calc_mua(wavelength,S,B,W,F,M); % Jacques "Optical properties of biological tissues: a review" eq. 12
    end

mediaProperties(j).mus = @func_mus5;
    function mus = func_mus5(wavelength)
        aPrime = 10; % musPrime at 500 nm
        fRay = 0; % Fraction of scattering due to Rayleigh scattering
        bMie = 1; % Scattering power for Mie scattering
        g = 0.9; % Scattering anisotropy
        mus = calc_mus(wavelength,aPrime,fRay,bMie,g); % Jacques "Optical properties of biological tissues: a review" eq. 2
    end
mediaProperties(j).g   = 0.9;

j=6;%------------------------------------------------------------------
mediaProperties(j).name  = 'bloodRV';
mediaProperties(j).mua = @func_mua6;
    function mua = func_mua6(wavelength)
        B = 1; % Blood content
        S = inp.saturations(3)/100; % Blood oxygen saturation
        W = 0.51; % Water content
        M = 0; % Melanin content
        F = 0; % Fat content
        mua = calc_mua(wavelength,S,B,W,F,M); % Jacques "Optical properties of biological tissues: a review" eq. 12
    end

mediaProperties(j).mus = @func_mus6;
    function mus = func_mus6(wavelength)
        aPrime = 10; % musPrime at 500 nm
        fRay = 0; % Fraction of scattering due to Rayleigh scattering
        bMie = 1; % Scattering power for Mie scattering
        g = 0.9; % Scattering anisotropy
        mus = calc_mus(wavelength,aPrime,fRay,bMie,g); % Jacques "Optical properties of biological tissues: a review" eq. 2
    end
mediaProperties(j).g   = 0.9;
end

%% OPO spectral fix
function powers = OPOspectralPower(wavelengths)
powers = zeros(size(wavelengths));
count=0;
for indx = wavelengths
    count=count+1;
    powers(count) = (-2.63782e-9)*(indx.^4) + (1.04339e-5)*(indx.^3) + (-0.01533)*(indx.^2) + (9.886803791)*(indx) + (-2326.793645);
end
end