
function [t, p] = GGBB(diam,depth)
% diam, depth  [m]
a = diam/2;      % rad
r = depth;       % depth
dt = 1e-9;
t = 0:dt:6e-6;
c = 1580;       % speed of sound m/s
% note that dx = 1.58um
newtau = 1+(c*t-r)/a;

integ=zeros(size(newtau));

indx=0;
for tt = newtau
    indx=indx+1;
    if tt<=0
        integ(indx)=0;
        continue;
    end
    qmax=0;
    fun = @(x) (x+1)./(sqrt(x+tt).*sqrt(1-(x+1).^2));
    if tt>2
        qmin=-2; 
        integ(indx) = integral(fun,qmin,qmax);
    else
    qmin=-tt;
    integ(indx) = integral(fun,qmin,qmax);
    end
end


alpha = 0.001;
beta = 1;
F = 1;
Cp = 1;
rho = r;


factor = (alpha*beta*F*c^2)/(pi*Cp*sqrt(2*rho/a));

p = factor*integ;

end

