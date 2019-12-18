%----------------------------------------------
% Deconvolution
%
% Description:
%    Deconvolution Pipeline
%
% Generated on 18-Dec-2019 using the GUI of the GlobalBioIm library
% Link to GlobalBioIm: <https://biomedical-imaging-group.github.io/GlobalBioIm/>
%----------------------------------------------
useGPU(0);

%% Load/Read Parameters
% - Operator-1 : SelectorPatch
H1_InputSize = [300 300];
H1_idxmin = [1 1];
H1_idxmax = [256 256];
% - Operator-2 : Conv
H2_InputSize = [300 300];
tmp=load("/home/esoubies/Bureau/GitHub/GlobalBioIm/GUI/psf.mat"); fd=fields(tmp);
H2_PSF = tmp.(fd{1});
% - Data-fidelity : L2
DF_y = double(imread("/home/esoubies/Bureau/GitHub/GlobalBioIm/GUI/data.png"));
% - Regularization-1 : Hessian-Schatten
R1_lambda = 1e-1;
% - Regularization-2 : Total-Variation
R2_lambda = 1e-1;
% - Regularization-3 : Tikhonov
R3_lambda = 1e-1;
% - Algorithm PrimalDualCondat-NoFullSplit
Opt_tau = 1e-1;
Opt_sig = 1e-1;
Opt_TolCost = 1e-4;
Opt_TolStep = 1e-4;
% - Path to save results
resultPath = '/home/esoubies/Bureau/GitHub/GlobalBioIm/GUI/deconv';

%% GPU/CPU converter
H2_PSF = gpuCpuConverter(H2_PSF);
DF_y = gpuCpuConverter(DF_y);

%% Instanciate the Forward Model
% - Operator-1 : SelectorPatch
H1 = LinOpSelectorPatch(H1_InputSize,H1_idxmin,H1_idxmax,1);
% - Operator-2 : Conv
H2 = LinOpConv('PSF',H2_PSF,1,[],'Centered','Pad',H2_InputSize,0);

%% Instanciate the Cost function
% - Data-Fidelity : L2
DF = CostL2(H1.sizeout,DF_y);
% - Regularization-1 : Hessian-Schatten
OpReg1 = LinOpHess(H2.sizein);
CostReg1 = R1_lambda * CostMixNormSchatt1(OpReg1.sizeout);
% - Regularization-2 : Total-Variation
OpReg2 = LinOpGrad(H2.sizein);
CostReg2 = R2_lambda * CostMixNorm21(OpReg2.sizeout,length(OpReg2.sizeout));
% - Regularization-3 : Tikhonov
OpReg3 = LinOpGrad(H2.sizein);
CostReg3 = R3_lambda * CostL2(OpReg3.sizeout);

%% Instanciate and Run the Optimization method
% - Algorithm PrimalDualCondat-NoFullSplit
F0 = DF*(H1*H2) + CostReg3*(OpReg3);
Fn = {CostReg1,CostReg2};
Hn = {OpReg1,OpReg2};
P = CostNonNeg(F0.sizein);
Opt = OptiPrimalDualCondat(F0,P,Fn,Hn);
Opt.tau = Opt_tau;
Opt.sig = Opt_sig;
Opt.OutOp = OutputOpti(1,round(Opt.maxiter/10),[1  2  4  5]);
Opt.ItUpOut = round(Opt.maxiter/10);
Opt.CvOp = TestCvgCombine('CostRelative',Opt_TolCost, 'StepRelative',Opt_TolStep);
Opt.run(zeros(Opt.cost.sizein));

%% Display and Save Results
imdisp(Opt.xopt,['Deconvolution-Result'],1);
save([resultPath,'_OptiCell'],'Opt');
imwrite(uint8(Opt.xopt/max(Opt.xopt(:))*255),[resultPath,'.png']);

