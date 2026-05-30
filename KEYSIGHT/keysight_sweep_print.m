% keysight .mat > pic

%% picture

filename = '30-Dec-2024 14-54-23 FP7A_REDO_coupled KEYSIGHT';
load(filename);
power=loss*1000;
lambda=1e9*lda;

lossdb=10*log10(power)-double(input_power);
f=figure;
plot(lambda,lossdb,'LineWidth',1);
xlabel('Wavelength [nm]');
ylabel('Loss [dB]');

grid minor;
set(gca,'fontname','david');
set(gca,'linewidth',1.2);
ax = gca;
ax.FontSize = 19;

f.Position = 1e3*[0.3 0.2 1 0.75];
%print([filename, '.png'],'-dpng');

%% invert option
% 0 for max    1 for min

invert = 1;
if invert
    power=1-power;
    B = smoothdata(power,"movmean",20000);
    power=power-B;
end

%% Q on response
close all;

param=0.01;
[pks,locs,w,p] = findpeaks(power,lambda,'MinPeakProminence',param,'WidthReference','halfheight','Annotate','extents');
f=figure;
findpeaks(power,lambda,'MinPeakProminence',param,'WidthReference','halfheight','Annotate','extents')
text(locs+.1,pks,num2str(round(locs./w)),"FontSize",15)
text(locs+.1,pks-.005,num2str(locs),"FontSize",15,'Color','r')

title('Q factors')

xlabel('Wavelength [nm]');
ylabel('Loss [mag]');

set(gca,'fontname','david');
set(gca,'linewidth',1.2);
ax = gca;
ax.FontSize = 19;

f.Position = 1e3*[0.3 0.2 1.3 0.75];
%print([filename, 'Q1.png'],'-dpng');

%% Q on its own

Q=locs./w;

figure(4);
scatter(locs,Q/1e3,"filled"); axis tight;  grid; 
ylabel('Q [thousands]'); xlabel('Wavelength [nm]');

title('Q factors')
set(gca,'fontname','david');
set(gca,'linewidth',1.2);
ax = gca;
ax.FontSize = 19;

%print([filename,'Q2', '.png'],'-dpng');