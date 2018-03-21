clc
close all
clear all
addpath(genpath('altmany-export_fig-83ee7fd\'))
addpath(genpath('denoisers\'))
%% Input parameters 
r            = im2double(rgb2gray(imread('CleanImages\ResolutionTarget.jpg')));
r            = imresize(r,[256 256]);
sigma_w      = 0.1;
A            = 'fft';
seedNum      = 100;
realOnly     = true;
figure, imshow(abs(r),[]), colorbar
title('Object-Reflectance')
set(gcf, 'Position', get(0, 'Screensize'));
export_fig('Figures\OpticalReflectance.png');
rng(seedNum,'twister')
%% Generate w,g, and y form input-parameters
[M,N]    = size(r);                                                         % Size of the input-image 
g        = sqrt(r/2).*randn(M,N)+1j*sqrt(r/2).*randn(M,N);                  % g ~ CN(0,D(r))
if(strcmp(A,'fft'))
    y = fftshift(fft2(g));
end
w        = sqrt(sigma_w/2)*randn([M,N])+1j*sqrt(sigma_w/2)*randn([M,N]);    % w ~ CN(0,\sigma_w^2)   
y        = y+w;                                                             % noisy-measurements 
figure, imshow(log10(abs(y)),[]), colorbar
title('Noisy-Fourier domain (log)')
set(gcf, 'Position', get(0, 'Screensize'));
export_fig('Figures\NoisyFourierDomainAmplitude.png');
figure, imshow(angle(y),[]), colorbar
title('Noisy-Fourier domain (log)')
set(gcf, 'Position', get(0, 'Screensize'));
export_fig('Figures\NoisyFourierDomainAngle.png');
figure, imshow(abs(g),[]), colorbar
title('Complex-optical field (Amplitude)')
set(gcf, 'Position', get(0, 'Screensize'));
export_fig('Figures\ComplexOpticalFieldAmplitude.png');
figure, imshow(angle(g),[]), colorbar
title('Complex-optical field (Phase)')
set(gcf, 'Position', get(0, 'Screensize'));
export_fig('Figures\ComplexOpticalFieldPhase.png');
%% Fourier-based reconstruction
rFBR         = abs(ifft2(y)).^2;
figure(10), subplot(1,3,1), imshow(rFBR,[])
title('FBR')
figure, imshow(rFBR,[]), colorbar
title('Fourier-Based Reconstruction (FBR)')
set(gcf, 'Position', get(0, 'Screensize'));
export_fig('Figures\FourierBasedReconstruction.png');
%% Plug and play ADMM algorithm (TV)      
maxIters     = 25;
denoiserType = 'TV';
v            = abs(ifft2(y)).^2; 
u            = zeros(size(v));
sigmaLambda  = 0.5*sqrt(var(v(:))); 
sigman       = 0.75; 
G            = denoiser(denoiserType,realOnly,sigman);
costFunction = zeros(maxIters,1);
r            = v-u;

for iters = 1:maxIters
    % r-update
    [c,mu]     = computeCovarianceAndMean(y,sigma_w,r);
    rtilde     = v-u;
    figure(2),
    subplot(2,2,1), imshow(abs(rtilde),[]), colorbar
    title('Input: Inversion-Op')
    r                       = inversionOperator(rtilde,sigmaLambda,c,mu); 
    costFunction(iters)     = abs(computeCostFunction(c,mu,r,sigmaLambda,r));
    subplot(2,2,2), imshow(abs(r),[]), colorbar
    title('Output: Inversion-Op')

    % v-update
    vold = v;
    vtildenext = r+u;
    subplot(2,2,3), imshow(abs(vtildenext),[]), colorbar
    title('Input: Denoiser-Op')
    v          = G*vtildenext;
    subplot(2,2,4), imshow(abs(v),[]), colorbar
    title('Output: Denoiser-Op')
    
    % u-update
    u                           = u+r-v;
    
    % history
    residual_norm(iters)        = norm(r - v);
    v_norm(iters)               = norm(vold-v);
end
figure, imshow(r,[]), colorbar
title('EM-P&P (TV)')
set(gcf, 'Position', get(0, 'Screensize'));
export_fig('Figures\EMBasedReconstructionTV.png');
figure, subplot(1,2,1), plot(residual_norm)
title('\|r-v\|_2')
subplot(1,2,2), plot(v_norm)
title('\|vold-v\|_2')
set(gcf, 'Position', get(0, 'Screensize'));
export_fig('Figures\ADMMCostFunction.png');
figure, plot(costFunction)
% %% Plug and play ADMM algorithm (BM3D)      
% maxIters     = 4;
% denoiserType = 'BM3D';
% v0           = abs(ifft2(y)).^2; 
% u0           = zeros(size(v0));
% sigmaLambda  = 0.5*sqrt(var(v0(:))); 
% sigman       = 2; 
% G            = denoiser(denoiserType,realOnly,sigman);
% costFunction= zeros(maxIters,1);
% 
% vPrev        = v0;
% uPrev        = u0; 
% rPrev        = v0-u0;
% 
% for iters = 1:maxIters
%     [c,mu]     = computeCovarianceAndMean(y,sigma_w,rPrev);
%     rtildenext = vPrev-uPrev;
%     figure(2),
%     subplot(2,2,1), imshow(abs(rtildenext),[]), colorbar
%     title('Input: Inversion-Op')
%     costFunctionPrior       = computeCostFunction(c,mu,rPrev,sigmaLambda,rtildenext);
%     rNext                   = inversionOperator(rtildenext,sigmaLambda,c,mu); 
%     costFunctionPost(iters) = computeCostFunction(c,mu,rNext,sigmaLambda,rPrev);
%     subplot(2,2,2), imshow(abs(rtildenext),[]), colorbar
%     title('Output: Inversion-Op')
%     vtildenext = rNext+uPrev;
%     subplot(2,2,3), imshow(abs(vtildenext),[]), colorbar
%     title('Input: Denoiser-Op')
%     vNext      = G*vtildenext;
%     subplot(2,2,4), imshow(abs(vNext),[]), colorbar
%     title('Output: Denoiser-Op')
%     
%     uNext                       = uPrev+rNext-vNext;
%     vPrev                       = vNext;
%     uPrev                       = uNext;
%     rPrev                       = rNext;
% end
% figure(11), subplot(1,2,2), plot(log10(costFunctionPost)), title('Computation-Cost (log10)')
% figure, imshow(rPrev,[]), colorbar
% title('EM-P&P (BM3D)')
% set(gcf, 'Position', get(0, 'Screensize'));
% export_fig('Figures\EMBasedReconstructionBM3D.png');
%%