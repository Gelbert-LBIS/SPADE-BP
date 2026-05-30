close all;
diam = 0.0025; depth = 0.004; 
[t, p] = GGBB(diam,depth);
p=p/max(p);
p(p<-1.5)=-1.5;
figure;
plot(t*1e6,p,'LineWidth',2,'Color','k');

yticks([-1.5 0 1]);
ylim([-1.6 1.1]);
ylabel('Pressure');
vpot=cumsum(p);

vpot=vpot/max(vpot);
yyaxis("right")
plot(t*1e6,vpot,'LineWidth',2); 
ylim([-0.1 1.1]);
yticks([0 0.5 1]);
xticks([0.87 1.74 3.323 4]);
xticklabels({'t_1','t_2','t_3','t_4'})
ylabel('Velocity Potential');
gg=gca;
gg.FontSize=20;
gg.FontWeight="normal"; 
gg.Box="on";
gg.BoxStyle="full";
gg.GridLineWidth=1;
gg.LineWidth=1;

xlim([0.5 5.5]);

hold on;
xline(1.74,'--','LineWidth',1); xline(3.323,'--','LineWidth',1);