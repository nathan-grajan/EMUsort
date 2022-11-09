load('/tmp/config.mat')

addpath(genpath([script_dir '/sorting/Kilosort-3.0']))
addpath(genpath([script_dir '/sorting/npy-matlab']))

chanMapFile = [script_dir '/geometries/neuropixPhase3B1_kilosortChanMap.mat'];
disp(['Using this channel map: ' chanMapFile])

phyDir = 'sortednew';

rootZ = [neuropixel_folder '/'];
rootH = [rootZ phyDir '/'];
rootS = [rootZ phyDir '/shifted/'];
mkdir(rootH);
mkdir(rootS);

if trange(2) == 0
    ops.trange = [0 Inf];
else
    ops.trange = trange;
end

ops.trange = [0 120];

run([script_dir '/sorting/Kilosort_config_3.m']);
ops.fproc   = fullfile(rootS, 'shifted.dat');
ops.chanMap = fullfile(chanMapFile);
ops.nblocks = 2;

ops.NchanTOT  = 385; % total number of channels in your recording

% find the binary file
fs          = dir(fullfile(rootZ, '*.bin'));
ops.fbinary = fullfile(rootZ, fs(1).name);

disp(['Using ' ops.fbinary])

rez                = preprocessDataSub(ops);
disp('Finished preprocessing')
rez                = datashift2(rez, 1);
disp('Finished datashift')
dshift = rez.dshift;
chanMap = 1:length(rez.ops.chanMap);
xcoords = rez.xcoords;
ycoords = rez.ycoords;
Wrot = rez.Wrot;
save([rootS 'chanmap'], 'xcoords', 'ycoords', 'chanMap');
save([rootS 'Wrot'], 'Wrot')

rmpath(genpath([script_dir '/sorting/Kilosort-3.0']))
addpath(genpath([script_dir '/sorting/Kilosort-2.0']))

%ops = rez.ops;
clear ops rez
run([script_dir '/sorting/Kilosort_config_2.m']);
ops.fbinary = [rootS 'shifted.dat'];
ops.fproc = [rootH 'proc.dat'];
ops.NchanTOT = 384;
ops.chanMap = fullfile(chanMapFile);
%rez = rmfield(rez, {'wTEMP','wPCA','iC','dist','dshift','st0','F','F0','F0m'});
%rez.ops = ops;

% preprocess data to create temp_wh.dat
rez = preprocessDataSub(ops);

% time-reordering as a function of drift
rez = clusterSingleBatches(rez);

% main tracking and template matching algorithm
rez = learnAndSolve8b(rez);

% OPTIONAL: remove double-counted spikes - solves issue in which individual spikes are assigned to multiple templates.
% See issue 29: https://github.com/MouseLand/Kilosort2/issues/29
rez = remove_ks2_duplicate_spikes(rez);

% final merges
rez = find_merges(rez, 1);

% final splits by SVD
rez = splitAllClusters(rez, 1);

% final splits by amplitudes
rez = splitAllClusters(rez, 0);

% decide on cutoff
rez = set_cutoff(rez);

fprintf('found %d good units \n', sum(rez.good>0))

% write to Phy
fprintf('Saving results to Phy  \n')
rezToPhy(rez, rootH);

save([rootH 'drift'], 'dshift');

%quit;