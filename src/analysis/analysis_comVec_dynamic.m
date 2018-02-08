%% ANALYSIS LOOKING AT MODEL PREDICTION

clc
clearvars

config_file='config_template.m';
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
addpath(strcat(pwd,'/config'))
run(config_file);

outIntermPrefix = strcat(OUTPUT_DIR, '/interim/', OUTPUT_STR);
outProcessPrefix = strcat(OUTPUT_DIR, '/processed/', OUTPUT_STR);

load(strcat(outProcessPrefix,'_fit_wsbm_script_v7p3.mat'))
load(strcat(outProcessPrefix,'_fit_mod_v7p3.mat'))
load(strcat(outIntermPrefix,'_comVecs.mat'))
%load('data/interim/subj_dataStruct.mat')
load(strcat(outIntermPrefix,'_templateModel_1.mat'))
load(strcat(outProcessPrefix,'_basicData_v7p3.mat'))

%% lets look at how some metrics look across lifespan, using changing ca
% definition of paritions

nSubj = length(dataStruct) ;
nBlocks = templateModel.R_Struct.k ;
nNodes = templateModel.Data.n ;

totDensity = zeros([nSubj 1]);

nBlockInteract = (nBlocks^2 + nBlocks) / 2 ;

getIdx = ~~triu(ones(nBlocks));

subjDataMat = zeros([ nNodes nNodes nSubj ]);
subjWsbmCA = zeros([ nNodes nSubj ]);
subjModCA = zeros([ nNodes nSubj ]);

%% unroll block vec vars

blockVec_wsbm = zeros([nBlockInteract nSubj]);
blockVec_mod = zeros([nBlockInteract nSubj]) ;

avgBlockVec_wsbm = zeros([nBlockInteract nSubj]);
avgBlockVec_mod = zeros([nBlockInteract nSubj]) ;

binBlockVec_wsbm = zeros([nBlockInteract nSubj]);
binBlockVec_mod = zeros([nBlockInteract nSubj]) ;

%% also community comvec
com_avgBlockVec_wsbm = zeros([nBlocks nBlocks nSubj]);
com_avgBlockVec_mod = zeros([nBlocks nBlocks nSubj]) ;

%% gather some of the data
for idx = 1:nSubj
    
    tmpAdj = dataStruct(idx).countVolNormMat(selectNodesFrmRaw, selectNodesFrmRaw);
    % get rid of the diagonal
    %n=size(tmpAdj,1);
    tmpAdj(1:nNodes+1:end) = 0; 
    % mask out AdjMat entries below mask_thr
    tmpAdj_mask = dataStruct(idx).countMat(selectNodesFrmRaw, selectNodesFrmRaw) > 1 ;    
    tmpAdj_mask(tmpAdj_mask > 0) = 1 ;   
    tmpAdj = tmpAdj .* tmpAdj_mask ;
  
    subjDataMat(:,:,idx) = tmpAdj ;
  
    totDensity(idx) = sum(tmpAdj(:));
    
    % get the fit community assignments 
    [~,tmpCA] = community_assign(fitWSBMAllStruct(idx).centModel) ;
    subjWsbmCA(:,idx) = CBIG_HungarianClusterMatch(comVecs.wsbm,tmpCA);
    subjModCA(:,idx) = CBIG_HungarianClusterMatch(comVecs.mod,...
        fitModAllStruct(idx).caMod_subj);
    
end

%% some runs of modularity did not render paritions with correct num coms
% and therefore have community assignment of all 0's
% we need to record these to skip over them

modExclude = (sum(subjModCA) == 0) ;

%% iterate
for idx = 1:nSubj
       
    % wsbm
    [tmpBl,avgtmpbl,~,bintmpbl] = get_block_mat(tmpAdj,subjWsbmCA(:,idx));
    blockVec_wsbm(:,idx) = tmpBl(getIdx);
    avgBlockVec_wsbm(:,idx) = avgtmpbl(getIdx);
    binBlockVec_wsbm(:,idx) = bintmpbl(getIdx);
   
    com_avgBlockVec_wsbm(:,:,idx) = avgtmpbl ;
    
    if modExclude(idx) == 0
    
        % mod
        [tmpBl,avgtmpbl,~,bintmpbl] = get_block_mat(tmpAdj,subjModCA(:,idx));
        blockVec_mod(:,idx) = tmpBl(getIdx);
        avgBlockVec_mod(:,idx) = avgtmpbl(getIdx);
        binBlockVec_mod(:,idx) = bintmpbl(getIdx);
        com_avgBlockVec_mod(:,:,idx) = avgtmpbl;  
        
    else
        
        % set zeros
        blockVec_mod(:,idx) = zeros([nBlockInteract 1]);
        avgBlockVec_mod(:,idx) = zeros([nBlockInteract 1]);
        binBlockVec_mod(:,idx) = zeros([nBlockInteract 1]);
        com_avgBlockVec_mod(:,:,idx) = zeros(nBlocks);  
          
    end
    
end
  
%% correlate each block pattern with model

% now different is predicted from actual?
templateData = templateModel.Data.Raw_Data;
templateData(isnan(templateData)) = 0 ;

% model_edgeVec = templateModel.Para.predict_e ;
% model_weiVec = templateModel.Para.predict_w ;
wsbmPred_weiVec =  templateModel.Para.predict_e .*  templateModel.Para.predict_w; 
wsbmPred_weiVec(isnan(wsbmPred_weiVec)) = 0;
[~,wsbm_weiVec_sqr] = make_square(wsbmPred_weiVec);

% and now creat the 'model' for the modular parition
[~,mod_weiVec_empir] = get_block_mat(templateData,comVecs.mod);
mod_weiVec_empir = mod_weiVec_empir(getIdx);
[~,mod_weiVec_empir_sqr] = make_square(mod_weiVec_empir);

%% community pattern vars

wsbm_comms_weiVec_corr = zeros([nBlocks nSubj]) ;
mod_comms_weiVec_corr = zeros([nBlocks nSubj]) ;

wsbm_comms_weiVec_cb = zeros([nBlocks nSubj]) ;
mod_comms_weiVec_cb = zeros([nBlocks nSubj]) ;

wsbm_comms_weiVec_cos = zeros([nBlocks nSubj]) ;
mod_comms_weiVec_cos = zeros([nBlocks nSubj]) ;

%% iterate
for idx = 1:nSubj
   
    % correlation 
    corrStr='pearson';
    wsbm_weiVec_corr(idx) = corr(wsbmPred_weiVec,avgBlockVec_wsbm(:,idx),...
        'type',corrStr) ;
    mod_weiVec_corr(idx) = corr(mod_weiVec_empir,avgBlockVec_mod(:,idx),...
        'type',corrStr) ;
    
    % other distances   
    wsbm_weiVec_cb(idx) = pdist([wsbmPred_weiVec' ; avgBlockVec_wsbm(:,idx)'],'cityblock') ;
    mod_weiVec_cb(idx) = pdist([mod_weiVec_empir' ; avgBlockVec_mod(:,idx)'],'cityblock') ;

    wsbm_weiVec_eud(idx) = pdist([wsbmPred_weiVec' ; avgBlockVec_wsbm(:,idx)'],'euclidean') ;
    mod_weiVec_eud(idx) = pdist([mod_weiVec_empir' ; avgBlockVec_mod(:,idx)'],'euclidean') ;
    
    wsbm_weiVec_cos(idx) = 1 - pdist([wsbmPred_weiVec' ; avgBlockVec_wsbm(:,idx)'],'cosine') ;
    mod_weiVec_cos(idx) = 1 - pdist([mod_weiVec_empir' ; avgBlockVec_mod(:,idx)'],'cosine') ;
    
    % distances of each community
    for jdx=1:nBlocks
        
        % correlation 
        wsbm_comms_weiVec_corr(jdx,idx) = corr(wsbm_weiVec_sqr(:,jdx),...
            com_avgBlockVec_wsbm(:,jdx,idx),...
            'type',corrStr) ;
        mod_comms_weiVec_corr(jdx,idx) = corr(mod_weiVec_empir_sqr(:,jdx),...
            com_avgBlockVec_mod(:,jdx,idx),...
            'type',corrStr) ;
        
        % other distances
        wsbm_comms_weiVec_cb(jdx,idx) = pdist([wsbm_weiVec_sqr(:,jdx)' ;...
            com_avgBlockVec_wsbm(:,jdx,idx)' ],...
            'cityblock') ;
        mod_comms_weiVec_cb(jdx,idx) = pdist([mod_weiVec_empir_sqr(:,jdx)' ; ...
            com_avgBlockVec_mod(:,jdx,idx)'],...
            'cityblock') ;
 
        wsbm_comms_weiVec_cos(jdx,idx) = 1 - pdist([wsbm_weiVec_sqr(:,jdx)' ;...
            com_avgBlockVec_wsbm(:,jdx,idx)' ],...
            'cosine') ;
        mod_comms_weiVec_cos(jdx,idx) = 1 - pdist([mod_weiVec_empir_sqr(:,jdx)' ; ...
            com_avgBlockVec_mod(:,jdx,idx)'],...
            'cosine') ; 
    end
    
end

%% look and how community distances are distributed

wsbm_com_totLen = zeros([ nBlocks nSubj ]);
mod_com_totLen = zeros([ nBlocks nSubj ]);

wsbm_com_totDist = zeros([ nBlocks nSubj ]);
mod_com_totDist = zeros([ nBlocks nSubj ]);

subjLensMat = zeros([ nNodes nNodes nSubj ]);
subjDistMat = zeros([ nNodes nNodes nSubj ]);

% gather some data
for idx = 1:nSubj

    % mask out AdjMat entries below mask_thr
    tmpMask = dataStruct(idx).countMat(selectNodesFrmRaw, selectNodesFrmRaw) > MASK_THR_INIT ;    
    tmpMask(tmpMask > 0) = 1 ;   
    
    % get streamline lengths
    tmpLens = dataStruct(idx).lensMat(selectNodesFrmRaw,selectNodesFrmRaw);
    %tmpAdj(isnan(tmpAdj)) = 0 ;
    subjLensMat(:,:,idx) = tmpLens .* tmpMask ;
    
    % get eud distances
    subjDistMat(:,:,idx) = dataStruct(idx).distCoorMM(selectNodesFrmRaw,selectNodesFrmRaw) ;

end
    
for idx = 1:nSubj
    
    % get the length matrix
    tmpAdj = subjLensMat(:,:,idx) ;
    
    wsbm_tmpBlMat = get_block_mat(tmpAdj,subjWsbmCA(:,idx)) ;
    wsbm_com_totLen(:,idx) = sum(wsbm_tmpBlMat(~~eye(nBlocks)),2) ;
    
    if modExclude(idx) == 0
        mod_tmpBlMat = get_block_mat(tmpAdj,subjModCA(:,idx));
        mod_com_totLen(:,idx) = sum(mod_tmpBlMat(~~eye(nBlocks)),2) ; 
    else
        mod_com_totLen(:,idx) = zeros([nBlocks 1]) ; 
    end
    
    % get the dist matrix
    tmpAdj = subjDistMat(:,:,idx) ;
    
    wsbm_tmpBlMat = get_block_mat(tmpAdj,subjWsbmCA(:,idx)) ;
    wsbm_com_totDist(:,idx) = sum(wsbm_tmpBlMat(~~eye(nBlocks)),2) ;
    
    if modExclude(idx) == 0
        mod_tmpBlMat = get_block_mat(tmpAdj,subjModCA(:,idx));
        mod_com_totDist(:,idx) = sum(mod_tmpBlMat(~~eye(nBlocks)),2) ; 
    else
        mod_com_totDist(:,idx) = zeros([nBlocks 1]) ; 
    end
    
end

%% quick analysis... lets look at variability of nodal assignment

wsbm_vers = get_nodal_versatility(subjWsbmCA(:,~modExclude)) ;
mod_vers = get_nodal_versatility(subjModCA(:,~modExclude));

% and gets look at consensus in age bins...
% number of actual groups is thresholds + 1
thresholds = 4 ;
age_bins = thresholds + 1;

[agesSorted,ageSortIdx] = sort(datasetDemo.age) ;

low_quantile = [ 0 quantile(1:length(datasetDemo.age),4) ] ; 
high_quantile = [ quantile(1:length(datasetDemo.age),4) (length(datasetDemo.age)+1) ] ;

templateIdMat = zeros( [ size(datasetDemo.age,1) (thresholds+1) ] ) ;

for templateIdx=1:age_bins

    subjectsIdxVec = ageSortIdx > low_quantile(templateIdx) & ...
        ageSortIdx < high_quantile(templateIdx) ;
    
    templateIdMat(:,templateIdx) = ~~subjectsIdxVec ;
end

templateIdMat2 = ~~templateIdMat(~modExclude,:) ;
subjWsbmCA2 = subjWsbmCA(:,~modExclude) ;
subjModCA2 = subjModCA(:,~modExclude);

wsbm_agebin_vers = zeros([ nNodes 5]) ;
mod_agebin_vers = zeros([ nNodes 5]) ;

for idx=1:age_bins
    
    wsbm_agebin_vers(:,idx) = get_nodal_versatility(subjWsbmCA2(:,templateIdMat2(:,idx))) ;
    mod_agebin_vers(:,idx) = get_nodal_versatility(subjModCA2(:,templateIdMat2(:,idx))) ; 
end

%% save it

outName = strcat(OUTPUT_DIR, '/processed/', OUTPUT_STR, '_comVec_dynamic_results.mat');
save(outName,...
    '*_weiVec_corr',...
    '*_weiVec_cb',...
    '*_weiVec_eud',...
    '*_weiVec_cos',...
    '*_vers',...
    'totDensity',...
    'modExclude',...
    'wsbmCnsns','modCnsns',...
    ...
    '-v7.3')
