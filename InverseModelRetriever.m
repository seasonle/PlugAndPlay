classdef InverseModelRetriever < matlab.mixin.Copyable
% CLASS INVERSEMODELGENERATOR -  Generates the inverse-model coherent
%                                images under the assumption of the given 
%                                forward-model. 
%                                  .
%              
% Constructor:
%   obj = InverseModelRetriever(objectSizePixels)
%
% Inputs:
%    objectSizePixels          : Size of the object in pixels given as [rows,cols]. 
%    inversionModelType        : Type of inversion-model: Can be ML, EM, EMPnP.
%    noiseType                 : Noise type of the measurement (can be one of 'Poisson' or 'Gaussian').
%    sigma_w                   : Std. deviation of the additive
%    white-Gaussian noise (optional). 
%    maxIters                  : maximum number of iterations (for Plug and Play algorithm)
%    sigmaLambda               : tuning-paramter for the PnP
%    inversion-operator
%    sigman                    : tuning-paramter for the PnP
%    denoising-operator
%    denoiserType              : type of denoiser-used ('TV')
%    rGT                       : ground-truth of the reflectance of the
%    object 
%    realOnly                  : object real-only (true for realOnly)
%
%
% Output:
%    obj                       : InverseModelRetriever type object with 
%                              overloaded functions.
%
% Overloaded Methods:
%    conj(obj)      : Returns a copy of the object.
%    transpose(obj) : Returns a copy of the operator.
%    ctranspose(obj): Returns a copy of the operator.
%    mtimes(obj,x)  : Called when used as (obj*x). Applies the specified 
%                     InverseModelRetriever on the measurements x after reshaping it to
%                     objectSizePixels. The number of elements in x must be
%                     prod(objectSizePixels).
%

% Author   : Sudarshan Nagesh             
% Institute: NorthWestern University (NU) 
properties(Constant)
    listOfSupportedinversionModelType  = {'ML','PnP'};
    listOfSupportednoiseType           = {'Poisson','Gaussian'};
    listOfSupporteddenoiserType        = {'TV'};
end


properties
    % Properties provided as input.
    objectSizePixels
    inversionModelType
    noiseType
    sigma_w
    maxIters
    sigmaLambda
    sigman
    denoiserType
    rGT
    realOnly
end
methods (Static)
    function [r]   = inversionOperator(y,rtilde,sigma_w,sigmaLambda)
        r = zeros(size(rtilde));
        for ind = 1:size(y,1)*size(y,2)
            alpha1 = 1;
            alpha2 = -rtilde(ind)+2*sigma_w^2;
            alpha3 = -2*rtilde(ind)*sigma_w^2+sigma_w^4+sigmaLambda^2;
            alpha4 = sigmaLambda^2*sigma_w^2-rtilde(ind)*sigma_w^4;
            rootsList  = roots([alpha1 alpha2 alpha3 alpha4]);
            imagList   = imag(rootsList);
            [~,minPos] = min(imagList);
            r(ind)     = real(rootsList(minPos)); 
        end
    end
    function [v]   = denoisingOperator(vtilde,sigman,realOnly,denoiserType)
        G = denoiser(denoiserType,realOnly,sigman);
        v = G*vtilde;
    end
end


methods
    % Function detectorSamplingOperator - Constructor.
    function obj = InverseModelRetriever(objectSizePixels,inversionModelType,noiseType,sigma_w,maxIters,sigmaLambda,sigman,denoiserType,rGT, realOnly)
        obj.objectSizePixels                       = objectSizePixels;
        obj.inversionModelType                     = inversionModelType;
        obj.noiseType                              = noiseType;
        obj.sigma_w                                = sigma_w;
        obj.maxIters                               = maxIters;
        obj.sigmaLambda                            = sigmaLambda;
        obj.sigman                                 = sigman;
        obj.denoiserType                           = denoiserType;
        obj.realOnly                               = realOnly;
        obj.rGT                                    = rGT;
    end
    
    % Overloaded function for conj().
    function res = conj(obj)
        res = obj;
    end
    
    % Overloaded function for .' (transpose()).
    function res = transpose(obj)
         res = obj;
    end
    
    % Overloaded function for ' (ctranspose()).
    function res = ctranspose(obj)
        res = obj;
    end
    
    % Overloaded function for * (mtimes()).
    function res = mtimes(obj,x)
        x   = reshape(x,obj.objectSizePixels);
        if (strcmp(obj.noiseType,'Gaussian'))
            if (strcmp(obj.inversionModelType,'ML'))
                r        = abs(x).^2-obj.sigma_w^2;
            end
            if (strcmp(obj.inversionModelType,'PnP'))
                v = x;
                u = zeros(size(x));
                for iters =1:obj.maxIters
                    rtilde = v-u;
                    r      = InverseModelRetriever.inversionOperator(x,rtilde,obj.sigma_w,obj.sigmaLambda);
                    vtilde = r+u;
                    v      = InverseModelRetriever.denoisingOperator(vtilde,obj.sigman,obj.realOnly,obj.denoiserType);
                    u      = u+(r-v);
                    rPSNR(iters) = psnr(r,obj.rGT);
                    costFunction(iters) = 0;
                    for ind = 1:size(r,1)*size(r,2)
                        costFunction(iters) = costFunction(iters)+log(r(ind)+obj.sigma_w^2)+(abs(x(ind)^2))/(r(ind)+obj.sigma_w^2)+1/(2*obj.sigmaLambda^2)*(r(ind)-rtilde(ind))^2;
                    end
                    figure(100), subplot(1,3,1), imshow(r,[]), colorbar
                    subplot(1,3,2), plot(iters,rPSNR(iters),'o'), xlim([1 obj.maxIters]), hold on, title('PSNR')
                    subplot(1,3,3), plot(iters,real(costFunction(iters)),'o'), xlim([1 obj.maxIters]), hold on, title('Cost-Function')
                    pause(0.1)
                 end
            end
        end
        res = [r(:)];
    end
end

methods    
    % Check validity of properties provided as input.
    
    function set.objectSizePixels(obj,objectSizePixels)
        validateattributes(objectSizePixels,...
                           {'numeric'},...
                           {'nonsparse','vector','numel',2,'integer','positive'},...
                           mfilename,'objectSizePixels',1);
        if ~isa(objectSizePixels,'double')
            objectSizePixels = double(objectSizePixels);
        end
        if ~isrow(objectSizePixels)
            objectSizePixels = objectSizePixels(:)';
        end
        obj.objectSizePixels = objectSizePixels;
    end
    function set.sigma_w(obj,sigma_w)
        validateattributes(sigma_w,...
                           {'double','single'},...
                           {'nonsparse','scalar','real','nonnan','finite','positive',},...
                           mfilename,'sigma_w');
        if ~isa(sigma_w,'double')
            sigma_w = double(sigma_w);
        end
        obj.sigma_w = sigma_w;
    end
    function set.inversionModelType(obj,inversionModelType)
        if ~isempty(inversionModelType)
            validateattributes(inversionModelType,...
                               {'char'},{'nonempty'},...
                               mfilename,'transform',1);
            if ~ismember(inversionModelType,obj.listOfSupportedinversionModelType)
                error(strcat('Variable inversionModelType contains a method that is not supported.\n',...
                             'Supported inversion model types are: %s.'),...
                             strjoin(cellfun(@(x) sprintf('''%s''',x),obj.listOfSupportedinversionModelType,'UniformOutput',false),', '));
            end
        else
            inversionModelType = 'ML';
        end
        obj.inversionModelType = inversionModelType;
    end
    function set.noiseType(obj,noiseType)
        if ~isempty(noiseType)
            validateattributes(noiseType,...
                               {'char'},{'nonempty'},...
                               mfilename,'transform',1);
            if ~ismember(noiseType,obj.listOfSupportednoiseType)
                error(strcat('Variable noiseType contains a method that is not supported.\n',...
                             'Supported noise types are: %s.'),...
                             strjoin(cellfun(@(x) sprintf('''%s''',x),obj.listOfSupportednoiseType,'UniformOutput',false),', '));
            end
        else
            noiseType = 'Gaussian';
        end
        obj.noiseType = noiseType;
    end
    function set.maxIters(obj,maxIters)
        if ~isempty(maxIters)
        validateattributes(maxIters,...
                           {'double','single'},...
                           {'nonsparse','scalar','real','nonnan','finite','positive',},...
                           mfilename,'maxIters');
        if ~isa(maxIters,'double')
            maxIters = double(maxIters);
        end
        obj.maxIters = maxIters;
        else
            obj.maxIters = 25;
        end
    end
    function set.sigmaLambda(obj,sigmaLambda)
        if ~isempty(sigmaLambda)
        validateattributes(sigmaLambda,...
                           {'double','single'},...
                           {'nonsparse','scalar','real','nonnan','finite','positive',},...
                           mfilename,'sigmaLambda');
        if ~isa(sigmaLambda,'double')
            sigmaLambda = double(sigmaLambda);
        end
        obj.sigmaLambda = sigmaLambda;
        else
            obj.sigmaLambda = 0.1;
        end
    end
    function set.sigman(obj,sigman)
        if ~isempty(sigman)
        validateattributes(sigman,...
                           {'double','single'},...
                           {'nonsparse','scalar','real','nonnan','finite','positive',},...
                           mfilename,'sigman');
        if ~isa(sigman,'double')
            sigman = double(sigman);
        end
        obj.sigman = sigman;
        else
            obj.sigman = 0.1;
        end
    end
    function set.denoiserType(obj,denoiserType)
        if ~isempty(denoiserType)
            validateattributes(denoiserType,...
                               {'char'},{'nonempty'},...
                               mfilename,'transform',1);
            if ~ismember(denoiserType,obj.listOfSupporteddenoiserType)
                error(strcat('Variable denoiserType contains a method that is not supported.\n',...
                             'Supported noise types are: %s.'),...
                             strjoin(cellfun(@(x) sprintf('''%s''',x),obj.listOfSupporteddenoiserType,'UniformOutput',false),', '));
            end
        else
            denoiserType = 'TV';
        end
        obj.denoiserType = denoiserType;
    end
    function set.realOnly(obj,realOnly)
        if ~isempty(realOnly)
            validateattributes(realOnly,{'logical'},{'nonempty'});
        else
            realOnly = true; 
        end
        obj.realOnly = realOnly;
    end
end

end