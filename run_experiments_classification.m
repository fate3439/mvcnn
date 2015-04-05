% function run_experiments_classification()

setup;
% multiviewOn = {'modelnet10toon', 'modelnet10toonedge', ...
%                 'modelnet40toon', 'modelnet40toonedge'};
trainGpuMode = true;
evalAug = 'none';
logPath = fullfile('log','eval1.txt'); 
skipEval = false; % if true, skip all evaluation
skipTrain = true; % if true, ski all training 

models = {};
ex = struct([]);

ex(end+1).model     = 'imagenet-vgg-m';
ex(end).featLayer   = 'fc7'; 
ex(end).evalGpuMode = false;
ex(end).evalMView   = true;
ex(end).evalDataset = { 'modelnet10toon'};

ex(end+1).model     = 'imagenet-vgg-verydeep-16'; 
ex(end).featLayer   = 'fc7'; 
ex(end).evalGpuMode = false;
ex(end).evalMView   = true;
ex(end).evalDataset = { 'modelnet10toon'};

ex(end+1).baseModel = 'imagenet-vgg-m';
ex(end).trainDataset= 'modelnet10toon';
ex(end).batchSize   = 64;
ex(end).trainAug    = 'f2';
ex(end).trainMView  = true;
ex(end).numEpochs   = 15;
ex(end).featLayer   = 'fc7'; 
ex(end).evalGpuMode = false;
ex(end).evalMView   = true;
ex(end).evalDataset = {'modelnet10toon'};

ex(end+1).baseModel = 'imagenet-vgg-verydeep-16';
ex(end).trainDataset= 'modelnet10toon';
ex(end).batchSize   = 32;
ex(end).trainAug    = 'none';
ex(end).trainMView  = true;
ex(end).numEpochs   = 15;
ex(end).featLayer   = 'fc7'; 
ex(end).evalGpuMode = false;
ex(end).evalMView   = true;
ex(end).evalDataset = {'modelnet10toon'};

for i=1:length(ex), 
    % train / fine-tune 
    if ~isfield(ex(i),'model') || isempty(ex(i).model), 
        prefix = sprintf('BS%d_AUG%s_MV%d', ...
            ex(i).batchSize, ex(i).trainAug, ex(i).trainMView);
        ex(i).model = sprintf('%s-finetuned-%s-%s', ex(i).baseModel, ...
            ex(i).trainDataset, prefix);
        if ~exist(fullfile('data','models',[ex(i).model '.mat']),'file'),
            if skipTrain, continue; end; 
            net = run_train(ex(i).trainDataset, ...
                'modelName', ex(i).baseModel,...
                'numEpochs', ex(i).numEpochs, ...
                'prefix', prefix, ...
                'batchSize', ex(i).batchSize, ...
                'augmentation', ex(i).trainAug, ...
                'multiview', ex(i).trainMView, ...
                'gpuMode', trainGpuMode);
            models{end+1} = ex(i).model;
            save(fullfile('data','models',[ex(i).model '.mat']),'-struct','net');
        end
    end
    % compute and evaluate features 
    if isfield(ex(i),'evalDataset') && ~isempty(ex(i).evalDataset) && ~skipEval, 
        for dataset = ex(i).evalDataset, 
            featDir = fullfile('data', 'features', ...
                [dataset{1} '-' ex(i).model '-' evalAug], 'NORM0');
            % skip the evaluation if feature ready exists
            if exist(fullfile(featDir, [ex(i).featLayer '.mat']),'file'), 
                continue; 
            end
            if ~ex(i).evalGpuMode, poolObj = gcp(); end;
            feats = imdb_compute_cnn_features(dataset{1}, ex(i).model, ...
                'augmentation', evalAug, ...
                'gpuMode', ex(i).evalGpuMode, ...
                'normalization', false);
            run_evaluate_classification(feats.(ex(i).featLayer), ...
                'cv', 2, ...
                'logPath', logPath, ...
                'predPath', fullfile(featDir,'pred.mat'), ...
                'log2c', [-8:4:4], ...
                'multiview', ex(i).evalMView);
        end
    end
end
