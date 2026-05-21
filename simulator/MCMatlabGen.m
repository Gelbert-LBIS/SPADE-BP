% Gil Gelbert
% Technion IIT | EE | LBIS
% 2023
% Generate 2D heating function of blood vessel using MCMATLAB simulation
% mediator function that converts the raw abs image of mcmatlab to clean image

function [HLV,HRV,HA,MSK_LV_new,MSK_RV_new,MSK_A_new,FullSpect] = MCMatlabGen(inp)
% dx is expected to be e-5 or smaller, radin [m]
rad = round(0.5*inp.Diameter/inp.d);  % convert to pixels

addpath(genpath(pwd));
[Hraw,mask] = MCMATLAB(inp);

MSK_A  = mask' == 4;
MSK_RV = mask' == 5;
MSK_LV = mask' == 6;
mask = (mask'>1);

props = regionprops(MSK_A,"Area");
res_rad = sqrt(props.Area/pi); % rad of mcmatlab mask in pixels
ratio = rad / res_rad;   % find ratio comparing to basic image

H750full = Hraw(:,:,:,1);
H750full = shiftdim(H750full,2);
H750avg = mean(H750full(:,:,100:300),3);

H800full = Hraw(:,:,:,2);
H800full = shiftdim(H800full,2);
H800avg = mean(H800full(:,:,100:300),3);

H900full = Hraw(:,:,:,3);
H900full = shiftdim(H900full,2);
H900avg = mean(H900full(:,:,100:300),3);

H750avg = regionfill(H750avg,~mask);
H750avg = imresize(H750avg,ratio,'bicubic'); % scale & interpolate
H800avg = regionfill(H800avg,~mask);
H800avg = imresize(H800avg,ratio,'bicubic'); % scale & interpolate
H900avg = regionfill(H900avg,~mask);
H900avg = imresize(H900avg,ratio,'bicubic'); % scale & interpolate

MSK_A  = imresize(MSK_A,ratio,'bicubic'); % scale
MSK_RV = imresize(MSK_RV,ratio,'bicubic'); % scale 
MSK_LV = imresize(MSK_LV,ratio,'bicubic'); % scale

[Nx,Ny] = size(MSK_A);

MSK_A_props = regionprops(MSK_A,"Centroid");
xy_offsets = round(MSK_A_props.Centroid);
MSK_A_new = makeDisc(Nx,Ny,xy_offsets(2) ,xy_offsets(1),round(0.5*inp.Diameter/inp.d));

MSK_RV_props = regionprops(MSK_RV,"Centroid");
xy_offsets = round(MSK_RV_props.Centroid);
MSK_RV_new = makeDisc(Nx,Ny,xy_offsets(2) ,xy_offsets(1),round(0.5*inp.VRdiam/inp.d));

MSK_LV_props = regionprops(MSK_LV,"Centroid");
xy_offsets = round(MSK_LV_props.Centroid);
MSK_LV_new = makeDisc(Nx,Ny,xy_offsets(2) ,xy_offsets(1),round(0.5*inp.VLdiam/inp.d));

HA  = MSK_A_new  .* H800avg;
HRV = MSK_RV_new .* H800avg;
HLV = MSK_LV_new .* H800avg;

FullSpect{1}.A=MSK_A_new  .* H750avg;
FullSpect{1}.R=MSK_RV_new .* H750avg;
FullSpect{1}.L=MSK_LV_new .* H750avg;
FullSpect{2}.A=HA;
FullSpect{2}.R=HRV;
FullSpect{2}.L=HLV;
FullSpect{3}.A=MSK_A_new  .* H900avg;
FullSpect{3}.R=MSK_RV_new .* H900avg;
FullSpect{3}.L=MSK_LV_new .* H900avg;
FullSpect{4}.maskA = MSK_A_new;
FullSpect{4}.maskRV = MSK_RV_new;
FullSpect{4}.maskLV = MSK_LV_new;
FullSpect{5}.counter = 1;

end