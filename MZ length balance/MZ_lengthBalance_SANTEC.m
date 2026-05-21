%% connect to pico5
if exist('PICO','var')==0
addpath(genpath('C:\Users\Gil\Desktop\MASTER'));
PICO = PicoScope5_Block();
end
fs = 100e3;
%% Connect to SANTEC

if exist("Santec_","var")==0
    %Santec_ = SANTEC_550();
    Santec_ = SANTEC_570();
end

% Turn on laser
Santec_.startLD;

% open the shutter
Santec_.OpenShutter;

% Set  power
Santec_.setPow(5); % [-17 13]

% Set wavelengths limits % [1500 1630]
sweep_rate=1;
lambda_min=1550;    
lambda_max=1560;   
Santec_.setSweep(lambda_min,lambda_max,sweep_rate)

%% Measurement
durationS=(lambda_max-lambda_min)/sweep_rate;
PICO.setup(1/fs,durationS*1e3);

Santec_.SweepGO;
[t, T ,~ ,~] = PICO.read();
T=T(:,2);
t=t+1/fs;
%% Plot raw data

figure(4); subplot(1,2,2)
plot(t,T); hold on;
xlabel('Time (sec)','FontSize', 16);
ylabel('Transmision (AU)','FontSize', 16);
h=gca;
h.FontSize=16;
% axis tight
grid on;

%% Define k-space

k=1.5/lambda_min*(1-sweep_rate*t/lambda_min)*1e9;
dk=mean(diff(k));
dl=linspace(-1/dk/2,1/dk/2,length(k));

%% Plot the final power-spectrum

figure(4); subplot(1,2,1)
plot(dl*100,abs(fftshift(fft(T))));
hold on;

xlabel('\Deltal (cm)','FontSize', 16);
h=gca;
h.FontSize=16;
grid on;
xlim([-200 200]);

%% If you want to close the connection

finish = questdlg('Would you like to end hardware connections?', ...
    'finish?', ...
    'Yes','No','Yes');

switch finish
    case 'Yes'
        PICO.delete();
        Santec_.CloseShutter;
        Santec_.delete;
        clear;
    case 'No'
end
