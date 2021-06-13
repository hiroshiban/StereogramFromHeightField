% generateRDS.m
%
% a simple script to generate a Red-Green/Red-Cyan/Dual
% Random-Dot-Stereogram (RDS) image from an input height map
%
%
% Created    : "2010-12-03 11:50:05 banh"
% Last Update: "2021-06-13 22:47:08 ban"

%% add path to the subfunctions

addpath(fullfile(pwd,'Common'));


%% Initialize a random seed

InitializeRandomSeed();


%% some constant parameters to generate RDS image

imgfile=fullfile(pwd,'depth_maps','HB_face.srf_smoothed_low_res.png'); % a height (=depth) field map

imsize=[700,700];      % the whole image size to be generated, [row,col]
ipd=6.4;               % inter-pupils distance in centimeter
vdist=65;              % viewing distance in centimeter
pix_per_cm_x=27;       % pixels per centimeter along x-axis (horizontal)
pix_per_cm_y=27;       % pixels per centimeter along y-axis (vertical)
dotDens=7;             % dot density, larger is denser
dotRadius=[0.08,0.08]; % dot radius in deg
colors=[0,255,128];    % dot and background colors in gray-scale, [dot_1, dot_2, background]
oversampling_ratio=3;  % ratio of the image oversampling

% image height (depth magnitude) adjusting parameter
img_height_adj_flg=0;  % 0 or 1. whether adjusting image height. if 0, the height (depth) map is adjusted to be 'max_height' defined below
max_height=20;         % max height of the image in cm, used when the input image is adjusted its size later

% image format, 'redgreen', 'redcyan', or 'dual'
img_mode='redcyan';

% noise parameters
% 1. noise_mode   : 'acor' (= anti-correlated noises) or 'snr' (= adding normally distributed depth noises)
% 2. noise_ratio  : used for both anti-correlated and SNR RDS images, percentage of noise dots, 0-100%.
% 3. noise_mean   : only used for SNR noise RDS images, mean of the noise in centimeter.
% 4. noise_sd     : only used for SNR noise RDS images, SD of the noise in centimeter.
% 5. noise_adding_method : how to put noises, 'add' or 'replace'.
%                   'add' adds noises on the baseline depths (e.g. face surface),
%                   while 'replace' replaces the baseline depths with the noise depths.

noise_mode='snr';
noise_ratio=0;
noise_mean=0;
noise_sd=2;
noise_adding_method='replace';


%% image adjustment

% load image & subtract mean as to the flat plane becomes 0 height
img=imread(imgfile);
if numel(size(img))==3, img=double(rgb2gray(img)); end

% resize image
img_field=zeros(imsize);
img_field(size(img_field,1)/2-size(img,1)/2+1:size(img_field,1)/2+size(img,1)/2,...
          size(img_field,2)/2-size(img,2)/2+1:size(img_field,2)/2+size(img,2)/2)=img;

% image height adjusting
if img_height_adj_flg~=0
  img_field=(img_field-min(img_field(:)))./(max(img_field(:))-min(img_field(:))); % normalizing 0.0-1.0
  img_field=max_height*img_field;
else
  img_field=img_field./10; % just devide by 10. specific to the face images sent from Dorita-chan.
end


%% adjust parameters for oversampling

if oversampling_ratio~=1
  img_field=imresize(img_field,oversampling_ratio,'bilinear');
  dotDens=dotDens/(oversampling_ratio^2);
  %dotRadius=dotRadius.*oversampling_ratio;
  ipd=ipd*oversampling_ratio;
  vdist=vdist*oversampling_ratio;
  pix_per_cm_x=pix_per_cm_x*oversampling_ratio;
  pix_per_cm_y=pix_per_cm_y*oversampling_ratio;
end


%% fast RDS

% generate ovals to be used in RDS
dotSize=round(dotRadius.*[pix_per_cm_y,pix_per_cm_x]*2); % radius(cm) --> diameter(pix)
basedot=double(MakeFineOval(dotSize,[colors(1:2) 0],colors(3),1.2,2,1,0,0));
wdot=basedot(:,:,1);     % get only gray scale image (white)
bdot=basedot(:,:,2);     % get only gray scale image (black)
dotalpha=basedot(:,:,4)./max(max(basedot(:,:,4))); % get alpha channel value 0-1.0;

% calculate left/right eye image shifts
[posL,posR]=RayTrace_ScreenPos_X_MEX(img_field,ipd,vdist,pix_per_cm_x,0);

% generate correlated RDS
if strcmpi(noise_mode,'acor')
  % anti-correlated dots are assigned in the MEX function below.
  [imgL,imgR]=RDSfastest_with_acor_noise_MEX(posL,posR,wdot,bdot,dotalpha,dotDens,noise_ratio,colors(3));
elseif strcmpi(noise_mode,'snr')
  % noise dots are assigned in advance of generating the RDS.
  obj_idx=find(img_field~=0);
  obj_idx=shuffle(obj_idx);
  obj_idx=obj_idx(1:round(numel(obj_idx)*noise_ratio/100));
  noise_field=noise_mean+randn(numel(obj_idx),1).*noise_sd;
  [noiseL,noiseR]=RayTrace_ScreenPos_X_MEX(noise_field,ipd,vdist,pix_per_cm_x,0);

  if strcmpi(noise_adding_method,'add') % if you want to add noises on the baseline depths, please use the lines below.
    posL(obj_idx)=posL(obj_idx)+noiseL;
    posR(obj_idx)=posR(obj_idx)+noiseR;
  elseif strcmpi(noise_adding_method,'replace') % if you want to replace the baseline depths with generated noises, please use the lines below.
    posL(obj_idx)=noiseL;
    posR(obj_idx)=noiseR;
  else
    error('noise_adding_method should be ''acor'' or ''snr''.');
  end

  [imgL,imgR]=RDSfastest_with_snr_noise_MEX(posL,posR,wdot,bdot,dotalpha,dotDens,colors(3));
else
  error('noise_mode should be ''acor'' or ''snr''.');
end

% convert the generated image(s) for anaglyphs or haploscope viewing
if strcmpi(img_mode,'redgreen')
  img=reshape([imgR imgL colors(3)*ones(size(imgL))],[size(imgL),3]);
elseif strcmpi(img_mode,'redcyan')
  img=reshape([imgR imgL imgL],[size(imgL),3]);
elseif strcmpi(img_mode,'dual')
  % do nothing now
else
  error('noise_mode should be ''redgreen'', ''redcyan'' or ''dual''.');
end

% resize the oversampoled image(s)
if oversampling_ratio~=1
  if ~strcmpi(img_mode,'dual')
    img=imresize(img,1/oversampling_ratio);
  else
    img_L=imresize(img_L,1/oversampling_ratio);
    img_R=imresize(img_R,1/oversampling_ratio);
  end
end


%% save generated images

save_dir=fullfile(pwd,'images');
if ~exist(save_dir,'dir'), mkdir(save_dir); end
if ~strcmpi(img_mode,'dual')
  imwrite(img,fullfile(save_dir,'img.bmp'),'bmp');
else
  imwrite(img_L,fullfile(save_dir,'img_L.bmp'),'bmp');
  imwrite(img_R,fullfile(save_dir,'img_R.bmp'),'bmp');
end


%% remove path to the subfunctions

rmpath(fullfile(pwd,'Common'));
