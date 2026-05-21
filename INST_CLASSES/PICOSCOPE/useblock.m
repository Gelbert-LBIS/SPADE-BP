%% connect to pico
if exist('PICO','var')
    PICO.delete();
end
clc; close all; clear;
addpath(genpath('C:\Users\Gil\Desktop\MASTER'));
PICO = PicoScope5_Block();

%% setup
fs = 5e3;
durationMS = 10*1000;
PICO.setup(1/fs,durationMS);

%% read
[times, data, Amean, Bmean] = PICO.read();
plot(times,data(:,:,1));

%% close
PICO.delete();
clear;

%% save
save('ppg_finger_ecg','data','times');