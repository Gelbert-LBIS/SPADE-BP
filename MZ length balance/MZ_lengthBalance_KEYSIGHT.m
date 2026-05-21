%% connect to pico5
if exist('PICO','var')==0
addpath(genpath('C:\Users\Gil\Desktop\MASTER'));
PICO = PicoScope5_Block();
end
fs = 500e3;
%% Connect to KEYSIGHT

keysigt_ = KEYSIGHT();
keysigt_.setprints(0);

% Turn on laser
keysigt_.startLaser;

% Set power
keysigt_.setOpticalPower(10); % [-30 10]

% Set center wavelength
lambda = 1545; % [1500 1600]

%% Measurement
sweep_rate=10;
durationS = keysigt_.Sweep3nmAroundSETUP(lambda-5,lambda+5,0.001,sweep_rate);
PICO.setup(1/fs,durationS*1e3);

keysigt_.SweepGoNoRet();
pause(0.2); % FIX
[t, T, ~, ~] = PICO.read();
T=T(:,2);
t=t+1/fs;
%% Plot raw data

figure(4); subplot(1,2,2)
plot(t,T); hold on;
xlabel('Time (sec)','FontSize', 16);
ylabel('Transmision (mV)','FontSize', 16);
h=gca;
h.FontSize=16;
% axis tight
grid on;

%% Define k-space

lambda_min = lambda-5;
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
        clear;
    case 'No'
end
