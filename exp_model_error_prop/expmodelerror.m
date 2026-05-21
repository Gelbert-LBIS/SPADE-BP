figure; nexttile;

beta = log(130/80)/(((1.7/1.5)^2)-1);

ratio = (2*130*beta*1.7)/(1.5*1.5);
ratio/1000;

diams=1:0.01:2.4;
plot(diams,80*exp(beta*(((diams/1.5).^2)-1)),'LineWidth',2);

hold on;
scatter(1.5,80,50,'filled','MarkerFaceColor','r');
scatter(1.7,130,50,'filled','MarkerFaceColor','r');

gg=gca;
gg.FontName='Montserrat';
gg.FontSize=20;
gg.FontWeight="normal"; 
gg.Box="on";
gg.BoxStyle="full";
gg.GridLineWidth=1;
gg.LineWidth=1;
grid minor;
grid on;

xticks([1 1.2 1.4 1.6 1.8 2]);
yticks([0 50 100 150 200 250]);

xlabel('Diameter [mm]')
ylabel('Pressure [mmHg]');

ylim([0 250]); xlim([1 2])

nexttile;
err = -100:100;
plot(err,80*exp(beta*((((0.001*err+1.7)/1.5).^2)-1))-130,'LineWidth',2);

gg=gca;
gg.FontName='Montserrat';
gg.FontSize=20;
gg.FontWeight="normal"; 
gg.Box="on";
gg.BoxStyle="full";
gg.GridLineWidth=1;
gg.LineWidth=1;
grid on;

xticks([-50 -40 -30 -20 -10 0 10 20 30 40 50]);
yticks([-20 -15 -10 -5 0 5 10 15 20]);

xlim([-50,50])
ylim([-15,15])

xlabel('Diameter est. error [µm]')
ylabel('Pressure est. error [mmHg]');

%%
nexttile;
vec=0:50;
plot(vec,0.001*vec*130*2*beta*1.7/2.25,'LineWidth',2)

gg=gca;
gg.FontName='Montserrat';
gg.FontSize=20;
gg.FontWeight="normal"; 
gg.Box="on";
gg.BoxStyle="full";
gg.GridLineWidth=1;
gg.LineWidth=1;
grid on;

xticks([0 10 20 30 40 50]);
yticks([0 5 10 15 20]);

xlim([0 50])
ylim([0 20])

xlabel('Diameter est. STD [µm]')
ylabel('Pressure est. STD [mmHg]');

hold on;
scatter(10,0.001*10*130*2*beta*1.7/2.25,50,'filled','MarkerFaceColor','r');